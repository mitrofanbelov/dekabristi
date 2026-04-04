import Foundation

enum AppConfiguration {
    static let fallbackBaseURL = "http://127.0.0.1:8000/api/v1"

    static func apiBaseURL() -> URL {
        let environmentValue = ProcessInfo.processInfo.environment["DEKABRISTI_API_BASE_URL"]
        let plistValue = Bundle.main.object(forInfoDictionaryKey: "DEKABRISTI_API_BASE_URL") as? String
        let rawValue = environmentValue ?? plistValue ?? fallbackBaseURL

        guard let url = URL(string: rawValue) else {
            return URL(string: fallbackBaseURL)!
        }

        return url
    }
}
