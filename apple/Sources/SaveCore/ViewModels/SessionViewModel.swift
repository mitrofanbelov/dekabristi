import Combine
import Foundation

@MainActor
public final class SessionViewModel: ObservableObject {
    @Published public private(set) var currentUser: UserProfile?
    @Published public private(set) var isBusy = false
    @Published public private(set) var errorMessage: String?

    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func register(email: String, password: String) async {
        await perform {
            let session = try await apiClient.register(email: email, password: password)
            currentUser = session.user
        }
    }

    public func login(email: String, password: String) async {
        await perform {
            let session = try await apiClient.login(email: email, password: password)
            currentUser = session.user
        }
    }

    private func perform(_ work: @escaping () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            try await work()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
