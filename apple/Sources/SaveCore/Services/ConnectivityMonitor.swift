import Combine
import Foundation
import Network

public enum ConnectionStatus: Equatable, Sendable {
    case offline
    case localNetworkAvailable
    case backendReachable
    case backendUnreachable
}

@MainActor
public final class ConnectivityMonitor: ObservableObject {
    @Published public private(set) var status: ConnectionStatus = .offline

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "ConnectivityMonitor.monitor")
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task { @MainActor in
                self.status = path.status == .satisfied ? .localNetworkAvailable : .offline
                if path.status == .satisfied {
                    await self.refreshServerReachability()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    public func refreshServerReachability() async {
        guard monitor.currentPath.status == .satisfied else {
            status = .offline
            return
        }

        do {
            _ = try await apiClient.health()
            status = .backendReachable
        } catch {
            status = .backendUnreachable
        }
    }

    deinit {
        monitor.cancel()
    }
}
