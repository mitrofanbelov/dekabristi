import Foundation

public actor AuthSessionStore {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var currentSession: AuthSession?

    public init(userDefaults: UserDefaults = SharedAppConfiguration.sharedUserDefaults()) {
        self.userDefaults = userDefaults
        if
            let savedData = userDefaults.data(forKey: SharedAppConfiguration.sessionDefaultsKey),
            let savedSession = try? decoder.decode(AuthSession.self, from: savedData)
        {
            currentSession = savedSession
        }
    }

    public func session() -> AuthSession? {
        currentSession
    }

    public func update(_ session: AuthSession?) {
        currentSession = session

        if let session, let encodedSession = try? encoder.encode(session) {
            userDefaults.set(encodedSession, forKey: SharedAppConfiguration.sessionDefaultsKey)
        } else {
            userDefaults.removeObject(forKey: SharedAppConfiguration.sessionDefaultsKey)
        }
    }

    public func clear() {
        currentSession = nil
        userDefaults.removeObject(forKey: SharedAppConfiguration.sessionDefaultsKey)
    }
}
