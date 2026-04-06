import Foundation

public enum SharedAppConfiguration {
    public static let fallbackBaseURL = "http://127.0.0.1:8000/api/v1"
    public static let fallbackAppGroupID = "group.com.dekabristi.shared"
    public static let sessionDefaultsKey = "dekabristi.auth.session"
    public static let pendingSharedLinksKey = "dekabristi.shared.pendingLinks"

    public static func apiBaseURL(bundle: Bundle = .main) -> URL {
        let environmentValue = normalizedConfigValue(
            ProcessInfo.processInfo.environment["DEKABRISTI_API_BASE_URL"]
        )
        let plistValue = normalizedConfigValue(
            bundle.object(forInfoDictionaryKey: "DEKABRISTI_API_BASE_URL") as? String
        )
        let rawValue = preferredConfigValue(
            environmentValue: environmentValue,
            plistValue: plistValue,
            fallbackValue: fallbackBaseURL
        )

        guard let url = URL(string: rawValue) else {
            return URL(string: fallbackBaseURL)!
        }

        return url
    }

    public static func appGroupID(bundle: Bundle = .main) -> String {
        let environmentValue = normalizedConfigValue(
            ProcessInfo.processInfo.environment["DEKABRISTI_APP_GROUP_ID"]
        )
        let plistValue = normalizedConfigValue(
            bundle.object(forInfoDictionaryKey: "DEKABRISTI_APP_GROUP_ID") as? String
        )
        let rawValue = preferredConfigValue(
            environmentValue: environmentValue,
            plistValue: plistValue,
            fallbackValue: fallbackAppGroupID
        )
        return rawValue.isEmpty ? fallbackAppGroupID : rawValue
    }

    public static func sharedUserDefaults(bundle: Bundle = .main) -> UserDefaults {
        let suiteName = appGroupID(bundle: bundle)
        return UserDefaults(suiteName: suiteName) ?? .standard
    }

    private static func normalizedConfigValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func preferredConfigValue(
        environmentValue: String?,
        plistValue: String?,
        fallbackValue: String
    ) -> String {
        #if os(iOS) && !targetEnvironment(simulator)
        // On physical iPhone builds, prefer the embedded Info.plist value so a stale
        // Xcode scheme environment override cannot redirect the app back to localhost.
        return plistValue ?? environmentValue ?? fallbackValue
        #else
        return environmentValue ?? plistValue ?? fallbackValue
        #endif
    }
}
