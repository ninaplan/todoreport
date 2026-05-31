import Foundation

// MARK: - UserDefaults 키 목록

enum UserDefaultsKeys {
    static let prefix = "kr.nock.TodoReport."

    static let plannerName        = "\(prefix)plannerName"
    static let notionConnected    = "notionConnected"
    static let isNotionConnected  = "isNotionConnected"
    static let onboardingCompleted = "onboardingCompleted"
    static let plannerColorHex    = "plannerColorHex"
}
