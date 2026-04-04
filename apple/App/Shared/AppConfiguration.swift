import Foundation
import SaveCore

enum AppConfiguration {
    static func apiBaseURL() -> URL {
        SharedAppConfiguration.apiBaseURL()
    }

    static func appGroupID() -> String {
        SharedAppConfiguration.appGroupID()
    }
}
