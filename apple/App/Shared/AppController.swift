import Combine
import Foundation
import SaveCore

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

@MainActor
final class AppController: ObservableObject {
    @Published private(set) var currentUser: UserProfile?
    @Published private(set) var isAuthenticating = false
    @Published private(set) var authErrorMessage: String?

    let syncCoordinator: SyncCoordinator
    let connectivityMonitor: ConnectivityMonitor

    private let apiClient: APIClient
    private let fileManager = FileManager.default
    private var periodicTask: Task<Void, Never>?
    private var hasStarted = false

    init() {
        let sessionStore = AuthSessionStore()
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
        await connectivityMonitor.refreshServerReachability()

        periodicTask = Task { [weak self] in
            guard let self else { return }
            await self.runPeriodicWork()
        }
    }

    func handleAppBecameActive() async {
        await connectivityMonitor.refreshServerReachability()
        guard currentUser != nil else { return }
        await syncCoordinator.refreshFromLaunchOrManualTrigger()
    }

    func signIn(email: String, password: String) async {
        await authenticate {
            let session = try await apiClient.login(email: email, password: password)
            currentUser = session.user
            await syncCoordinator.refreshFromLaunchOrManualTrigger()
        }
    }

    func register(email: String, password: String) async {
        await authenticate {
            let session = try await apiClient.register(email: email, password: password)
            currentUser = session.user
            await syncCoordinator.refreshFromLaunchOrManualTrigger()
        }
    }

    func addLink(url: String, title: String?) async -> Bool {
        do {
            let normalizedURL = try LinkInputNormalizer.normalize(url)
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

    deinit {
        periodicTask?.cancel()
    }
}
