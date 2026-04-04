import Combine
import Foundation
import SaveCore

@MainActor
final class AppController: ObservableObject {
    @Published private(set) var currentUser: UserProfile?
    @Published private(set) var isAuthenticating = false
    @Published private(set) var authErrorMessage: String?

    let syncCoordinator: SyncCoordinator
    let connectivityMonitor: ConnectivityMonitor

    private let apiClient: APIClient
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

    func addLink(url: String, title: String?) async {
        await syncCoordinator.queueLink(url: url, title: title)
        await syncCoordinator.refreshFromLaunchOrManualTrigger()
    }

    func importFile(from url: URL, title: String?) async {
        await syncCoordinator.queueFile(localFileURL: url, title: title)
        await syncCoordinator.refreshFromLaunchOrManualTrigger()
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

    deinit {
        periodicTask?.cancel()
    }
}
