import Foundation

public actor AuthSessionStore {
    private var currentSession: AuthSession?

    public init() {}

    public func session() -> AuthSession? {
        currentSession
    }

    public func update(_ session: AuthSession?) {
        currentSession = session
    }
}
