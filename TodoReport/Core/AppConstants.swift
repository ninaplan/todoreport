import Foundation

// MARK: - UserDefaults 키 목록

enum UserDefaultsKeys {
    static let prefix = "kr.nock.TodoReport."

    static let plannerName        = "\(prefix)plannerName"
    static let notionConnected    = "notionConnected"
    static let isNotionConnected  = "isNotionConnected"
    static let onboardingCompleted = "onboardingCompleted"
    static let plannerColorHex    = "plannerColorHex"

    /// 계정 삭제 시 제거할 UserDefaults 키 (접두사 스캔 없음 — 플래너별 레거시 키는 AccountDeletionService에서 별도 처리)
    static let accountDeletionKeys: [String] = [
        onboardingCompleted,
        "selectedPlannerId",
        "startWeekday",
        StreakCriteria.storageKey,
        "todoHideCompleted",
        "todoShowMemo",
        notionConnected,
        isNotionConnected,
        "notionContextMigrated",
        ReportNotificationSettings.weeklyEnabledKey,
        ReportNotificationSettings.monthlyEnabledKey,
        ReportNotificationSettings.hourKey,
        ReportNotificationSettings.minuteKey,
        ReportNotificationSettings.weeklyWeekdayKey,
        ReportNotificationSettings.monthlyTimingKey,
        plannerName,
        plannerColorHex,
        "\(prefix)todoDBId",
        "\(prefix)reportDBId",
        "\(prefix)todoPropsMapping",
        "\(prefix)reportPropsMapping",
    ]
}
