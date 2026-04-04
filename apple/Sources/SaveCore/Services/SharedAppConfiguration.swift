import Foundation

public enum SharedAppConfiguration {
    public static let fallbackBaseURL = "http://127.0.0.1:8000/api/v1"
    public static let fallbackAppGroupID = "group.com.dekabristi.shared"
    public static let sessionDefaultsKey = "dekabristi.auth.session"
    public static let pendingSharedLinksKey = "dekabristi.shared.pendingLinks"

    public static func apiBaseURL(bundle: Bundle = .main) -> URL {
        let environmentValue = ProcessInfo.processInfo.environment["DEKABRISTI_API_BASE_URL"]
        let plistValue = bundle.object(forInfoDictionaryKey: "DEKABRISTI_API_BASE_URL") as? String
        let rawValue = environmentValue ?? plistValue ?? fallbackBaseURL

        guard let url = URL(string: rawValue) else {
            return URL(string: fallbackBaseURL)!
        }

        return url
    }

    public static func appGroupID(bundle: Bundle = .main) -> String {
        let environmentValue = ProcessInfo.processInfo.environment["DEKABRISTI_APP_GROUP_ID"]
        let plistValue = bundle.object(forInfoDictionaryKey: "DEKABRISTI_APP_GROUP_ID") as? String
        let rawValue = environmentValue ?? plistValue ?? fallbackAppGroupID
        return rawValue.isEmpty ? fallbackAppGroupID : rawValue
    }

    public static func sharedUserDefaults(bundle: Bundle = .main) -> UserDefaults {
        let suiteName = appGroupID(bundle: bundle)
        return UserDefaults(suiteName: suiteName) ?? .standard
    }
}
