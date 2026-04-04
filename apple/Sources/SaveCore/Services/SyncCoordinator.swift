import Combine
import Combine
import Foundation

public actor SyncCheckpointStore {
    private var cursor: Date?

    public init() {}

    public func currentCursor() -> Date? {
        cursor
    }

    public func updateCursor(_ newCursor: Date?) {
        cursor = newCursor
    }
}

@MainActor
public final class SyncCoordinator: ObservableObject {
    @Published public private(set) var items: [RemoteItem] = []
    @Published public private(set) var isSyncing = false
    @Published public private(set) var lastSyncAt: Date?
    @Published public private(set) var lastErrorMessage: String?

    private let apiClient: APIClient
    private let connectivityMonitor: ConnectivityMonitor
    private let outboxStore: OutboxStore
    private let checkpointStore: SyncCheckpointStore

    public init(
        apiClient: APIClient,
        connectivityMonitor: ConnectivityMonitor,
        outboxStore: OutboxStore,
        checkpointStore: SyncCheckpointStore = SyncCheckpointStore()
    ) {
        self.apiClient = apiClient
        self.connectivityMonitor = connectivityMonitor
        self.outboxStore = outboxStore
        self.checkpointStore = checkpointStore
    }

    public func refreshFromLaunchOrManualTrigger() async {
        await refresh(forceFullReload: true)
    }

    public func refreshOnTimerTick() async {
        await refresh(forceFullReload: false)
    }

    public func queueLink(url: String, title: String?) async {
        await outboxStore.enqueue(
            OutboxEntry(
                kind: .link,
                title: title,
                sourceURLString: url,
                localFilePath: nil
            )
        )
    }

    public func queueFile(localFileURL: URL, title: String?) async {
        await outboxStore.enqueue(
            OutboxEntry(
                kind: .file,
                title: title,
                sourceURLString: nil,
                localFilePath: localFileURL.path
            )
        )
    }

    private func refresh(forceFullReload: Bool) async {
        isSyncing = true
        lastErrorMessage = nil
        defer { isSyncing = false }

        await connectivityMonitor.refreshServerReachability()
        guard connectivityMonitor.status == .backendReachable else {
            return
        }

        do {
            try await drainOutbox()

            if forceFullReload || items.isEmpty {
                let page = try await apiClient.listItems()
                items = page.items
                await checkpointStore.updateCursor(page.nextCursor)
            } else {
                let page = try await apiClient.sync(cursor: await checkpointStore.currentCursor())
                merge(page.items)
                await checkpointStore.updateCursor(page.nextCursor)
            }

            lastSyncAt = .now
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func drainOutbox() async throws {
        let pendingEntries = await outboxStore.snapshot()
        for entry in pendingEntries {
            await outboxStore.recordAttempt(for: entry.id)

            switch entry.kind {
            case .link:
                guard let url = entry.sourceURLString else { continue }
                _ = try await apiClient.createLink(url: url, title: entry.title)
            case .file:
                guard let path = entry.localFilePath else { continue }
                _ = try await apiClient.uploadFile(fileURL: URL(fileURLWithPath: path), title: entry.title)
            }

            await outboxStore.remove(entry.id)
        }
    }

    private func merge(_ incomingItems: [RemoteItem]) {
        var merged = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for item in incomingItems {
            merged[item.id] = item
        }
        items = merged.values.sorted { $0.updatedAt > $1.updatedAt }
    }
}
