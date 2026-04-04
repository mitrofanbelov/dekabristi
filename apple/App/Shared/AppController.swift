import Combine
import Foundation
import SaveCore
#if os(iOS)
import Photos
#elseif os(macOS)
import AppKit
#endif

private enum FileImportPreparationError: LocalizedError {
    case noReadableFile
    case unsupportedSelection

    var errorDescription: String? {
        switch self {
        case .noReadableFile:
            return "The selected file could not be prepared for upload."
        case .unsupportedSelection:
            return "Choose a regular file to import."
        }
    }
}

private enum FileActionError: LocalizedError {
    case missingAttachment
    case photoLibraryAccessDenied

    var errorDescription: String? {
        switch self {
        case .missingAttachment:
            return "This file entry does not have a downloadable attachment yet."
        case .photoLibraryAccessDenied:
            return "Dekabristi does not have permission to save media to your photo library."
        }
    }
}

@MainActor
final class AppController: ObservableObject {
    @Published private(set) var currentUser: UserProfile?
    @Published private(set) var isAuthenticating = false
    @Published private(set) var authErrorMessage: String?
    @Published private(set) var noticeMessage: String?

    let syncCoordinator: SyncCoordinator
    let connectivityMonitor: ConnectivityMonitor

    private let apiClient: APIClient
    private let sessionStore: AuthSessionStore
    private let pendingSharedLinkStore: PendingSharedLinkStore
    private let fileManager = FileManager.default
    private var periodicTask: Task<Void, Never>?
    private var hasStarted = false

    init() {
        let sharedUserDefaults = SharedAppConfiguration.sharedUserDefaults()
        let sessionStore = AuthSessionStore(userDefaults: sharedUserDefaults)
        self.sessionStore = sessionStore
        self.pendingSharedLinkStore = PendingSharedLinkStore(userDefaults: sharedUserDefaults)
        self.apiClient = APIClient(
            baseURL: AppConfiguration.apiBaseURL(),
            sessionStore: sessionStore
        )
        self.connectivityMonitor = ConnectivityMonitor(apiClient: apiClient)
        self.syncCoordinator = SyncCoordinator(
            apiClient: apiClient,
            connectivityMonitor: connectivityMonitor,
            outboxStore: OutboxStore()
        )
    }

    func startIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true
        connectivityMonitor.start()
        await restoreSessionIfAvailable()
        await importPendingSharedLinksIfNeeded()
        await connectivityMonitor.refreshServerReachability()

        if currentUser != nil {
            await syncCoordinator.refreshFromLaunchOrManualTrigger()
        }

        periodicTask = Task { [weak self] in
            guard let self else { return }
            await self.runPeriodicWork()
        }
    }

    func handleAppBecameActive() async {
        await restoreSessionIfAvailable()
        await connectivityMonitor.refreshServerReachability()
        guard currentUser != nil else { return }
        await importPendingSharedLinksIfNeeded()
        await syncCoordinator.refreshFromLaunchOrManualTrigger()
    }

    func signIn(email: String, password: String) async {
        await authenticate {
            let session = try await apiClient.login(email: email, password: password)
            currentUser = session.user
            await importPendingSharedLinksIfNeeded()
            await syncCoordinator.refreshFromLaunchOrManualTrigger()
        }
    }

    func register(email: String, password: String) async {
        await authenticate {
            let session = try await apiClient.register(email: email, password: password)
            currentUser = session.user
            await importPendingSharedLinksIfNeeded()
            await syncCoordinator.refreshFromLaunchOrManualTrigger()
        }
    }

    func addLink(url: String, title: String?) async -> Bool {
        do {
            let normalizedURL = try LinkInputNormalizer.normalize(url)
            noticeMessage = nil
            syncCoordinator.clearErrorMessage()
            await syncCoordinator.queueLink(
                url: normalizedURL,
                title: normalizedOptionalText(title)
            )
        } catch {
            syncCoordinator.setErrorMessage(error.localizedDescription)
            return false
        }

        await syncCoordinator.refreshFromLaunchOrManualTrigger()
        return syncCoordinator.lastErrorMessage == nil
    }

    func importFile(from url: URL, title: String?) async -> Bool {
        do {
            let stagedURL = try stageImportedFile(from: url)
            noticeMessage = nil
            syncCoordinator.clearErrorMessage()
            await syncCoordinator.queueFile(
                localFileURL: stagedURL,
                title: normalizedOptionalText(title) ?? stagedURL.lastPathComponent
            )
        } catch {
            syncCoordinator.setErrorMessage(error.localizedDescription)
            return false
        }

        await syncCoordinator.refreshFromLaunchOrManualTrigger()
        return syncCoordinator.lastErrorMessage == nil
    }

    func refreshNow() async {
        guard currentUser != nil else { return }
        await syncCoordinator.refreshFromLaunchOrManualTrigger()
    }

    func saveComment(for item: RemoteItem, comment: String?) async -> Bool {
        do {
            noticeMessage = nil
            syncCoordinator.clearErrorMessage()
            let updatedItem = try await apiClient.updateItemComment(
                itemID: item.id,
                comment: normalizedOptionalText(comment)
            )
            syncCoordinator.applyServerItem(updatedItem)
            return true
        } catch {
            syncCoordinator.setErrorMessage(error.localizedDescription)
            return false
        }
    }

    func delete(_ item: RemoteItem) async -> Bool {
        do {
            noticeMessage = nil
            syncCoordinator.clearErrorMessage()
            let deletedItem = try await apiClient.deleteItem(itemID: item.id)
            syncCoordinator.applyServerItem(deletedItem)
            noticeMessage = item.kind == .link ? "Link deleted." : "File deleted."
            return true
        } catch {
            syncCoordinator.setErrorMessage(error.localizedDescription)
            return false
        }
    }

    func downloadFile(for item: RemoteItem) async -> Bool {
        guard let attachment = item.attachments.first else {
            syncCoordinator.setErrorMessage(FileActionError.missingAttachment.localizedDescription)
            return false
        }

        do {
            noticeMessage = nil
            syncCoordinator.clearErrorMessage()
            let downloadedAttachment = try await apiClient.downloadAttachment(attachment.id)
            let savedLocationMessage = try await persistDownloadedAttachment(
                downloadedAttachment,
                preferredFilename: attachment.originalFilename,
                contentType: attachment.contentType
            )
            noticeMessage = savedLocationMessage
            return true
        } catch {
            syncCoordinator.setErrorMessage(error.localizedDescription)
            return false
        }
    }

    func clearNoticeMessage() {
        noticeMessage = nil
    }

    private func restoreSessionIfAvailable() async {
        guard currentUser == nil, let session = await sessionStore.session() else { return }
        currentUser = session.user

        do {
            let profile = try await apiClient.me()
            currentUser = profile
            await sessionStore.update(
                AuthSession(
                    accessToken: session.accessToken,
                    tokenType: session.tokenType,
                    user: profile
                )
            )
        } catch let APIClientError.serverError(statusCode, _) where statusCode == 401 || statusCode == 403 {
            await sessionStore.clear()
            currentUser = nil
        } catch {
            currentUser = session.user
        }
    }

    private func importPendingSharedLinksIfNeeded() async {
        guard currentUser != nil else { return }

        let pendingLinks = await pendingSharedLinkStore.drain()
        guard !pendingLinks.isEmpty else { return }

        for pendingLink in pendingLinks {
            await syncCoordinator.queueLink(url: pendingLink.url, title: pendingLink.title)
        }

        let noun = pendingLinks.count == 1 ? "link" : "links"
        noticeMessage = "Imported \(pendingLinks.count) shared \(noun)."
    }

    private func authenticate(_ work: @escaping () async throws -> Void) async {
        isAuthenticating = true
        authErrorMessage = nil
        defer { isAuthenticating = false }

        do {
            try await work()
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    private func runPeriodicWork() async {
        var tickIndex = 0

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(600))
            guard !Task.isCancelled else { return }

            tickIndex += 1
            if currentUser != nil {
                await syncCoordinator.refreshOnTimerTick()
            }

            if tickIndex.isMultiple(of: 3) {
                await connectivityMonitor.refreshServerReachability()
            }
        }
    }

    private func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func stageImportedFile(from sourceURL: URL) throws -> URL {
        let didAccessSecurityScopedResource = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScopedResource {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let resourceValues = try sourceURL.resourceValues(forKeys: [.isRegularFileKey])
        if resourceValues.isRegularFile == false {
            throw FileImportPreparationError.unsupportedSelection
        }

        let appSupportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let importsDirectory = appSupportDirectory
            .appendingPathComponent("Dekabristi", isDirectory: true)
            .appendingPathComponent("ImportedFiles", isDirectory: true)

        try fileManager.createDirectory(at: importsDirectory, withIntermediateDirectories: true)

        let preferredFilename = sourceURL.lastPathComponent.isEmpty
            ? UUID().uuidString
            : sourceURL.lastPathComponent
        let destinationURL = uniqueFileURL(in: importsDirectory, preferredFilename: preferredFilename)

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            do {
                let fileData = try Data(contentsOf: sourceURL)
                try fileData.write(to: destinationURL, options: .atomic)
            } catch {
                throw FileImportPreparationError.noReadableFile
            }
        }

        return destinationURL
    }

    private func uniqueFileURL(in directory: URL, preferredFilename: String) -> URL {
        let baseName = (preferredFilename as NSString).deletingPathExtension
        let fileExtension = (preferredFilename as NSString).pathExtension
        var candidateURL = directory.appendingPathComponent(preferredFilename)
        var index = 1

        while fileManager.fileExists(atPath: candidateURL.path) {
            let numberedName = fileExtension.isEmpty
                ? "\(baseName)-\(index)"
                : "\(baseName)-\(index).\(fileExtension)"
            candidateURL = directory.appendingPathComponent(numberedName)
            index += 1
        }

        return candidateURL
    }

    private func persistDownloadedAttachment(
        _ downloadedAttachment: DownloadedAttachment,
        preferredFilename: String,
        contentType: String?
    ) async throws -> String {
#if os(iOS)
        if isPhotoLibraryMedia(contentType: contentType, fileURL: downloadedAttachment.temporaryFileURL) {
            let stagingDirectory = fileManager.temporaryDirectory
                .appendingPathComponent("DekabristiMediaDownloads", isDirectory: true)
            try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)

            let stagedURL = uniqueFileURL(in: stagingDirectory, preferredFilename: preferredFilename)
            try moveDownloadedFile(from: downloadedAttachment.temporaryFileURL, to: stagedURL)
            try await saveMediaToPhotoLibrary(from: stagedURL, contentType: contentType)
            try? fileManager.removeItem(at: stagedURL)
            return "Saved to Photos."
        }
#endif

        let downloadsDirectory = try downloadDestinationDirectory()
        let destinationURL = uniqueFileURL(in: downloadsDirectory, preferredFilename: preferredFilename)
        try moveDownloadedFile(from: downloadedAttachment.temporaryFileURL, to: destinationURL)

#if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
        return "Downloaded to Downloads."
#else
        return "Saved to Files."
#endif
    }

    private func downloadDestinationDirectory() throws -> URL {
#if os(iOS)
        if let downloadsDirectory = try? fileManager.url(
            for: .downloadsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            return downloadsDirectory
        }

        let documentsDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let fallbackDownloads = documentsDirectory.appendingPathComponent("Downloads", isDirectory: true)
        try fileManager.createDirectory(at: fallbackDownloads, withIntermediateDirectories: true)
        return fallbackDownloads
#else
        return try fileManager.url(
            for: .downloadsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
#endif
    }

    private func moveDownloadedFile(from sourceURL: URL, to destinationURL: URL) throws {
        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            try? fileManager.removeItem(at: sourceURL)
        }
    }

#if os(iOS)
    private func isPhotoLibraryMedia(contentType: String?, fileURL: URL) -> Bool {
        let filename = fileURL.lastPathComponent.lowercased()
        if let contentType {
            return contentType.hasPrefix("image/") || contentType.hasPrefix("video/")
        }

        return [".jpg", ".jpeg", ".png", ".gif", ".heic", ".webp", ".mov", ".mp4", ".m4v"]
            .contains { filename.hasSuffix($0) }
    }

    private func saveMediaToPhotoLibrary(from fileURL: URL, contentType: String?) async throws {
        let authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw FileActionError.photoLibraryAccessDenied
        }

        let isVideo = contentType?.hasPrefix("video/") == true
            || [".mov", ".mp4", ".m4v"].contains { fileURL.lastPathComponent.lowercased().hasSuffix($0) }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                if isVideo {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
                } else {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
                }
            }, completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: FileActionError.photoLibraryAccessDenied)
                }
            })
        }
    }
#endif

    deinit {
        periodicTask?.cancel()
    }
}
