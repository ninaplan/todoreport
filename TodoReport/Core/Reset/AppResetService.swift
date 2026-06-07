import Foundation
import SwiftData

@MainActor
enum AppResetService {

    /// 앱 로컬 데이터를 처음 설치 상태로 되돌린다. (구독·노션 서버 데이터는 유지)
    static func resetAllLocalData() throws {
        cancelAllNotifications()
        try deleteAllSwiftData()
        clearUserDefaults()
        NotionAuthManager.shared.signOut()
        WidgetDataProvider.shared.clear()
        PlannerService.shared.prepareForFreshOnboarding()
        AppLogger.shared.info("AppResetService", "로컬 데이터 초기화 완료")
    }

    // MARK: - SwiftData

    private static func deleteAllSwiftData() throws {
        let context = PersistenceController.shared.context
        try deleteAll(PlannerItem.self, in: context)
        try deleteAll(TodoItem.self, in: context)
        try deleteAll(DailyReportItem.self, in: context)
        try deleteAll(CategoryItem.self, in: context)
        try deleteAll(SyncQueueItem.self, in: context)
        try context.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<T>())
        items.forEach { context.delete($0) }
    }

    // MARK: - UserDefaults

    private static func clearUserDefaults() {
        let defaults = UserDefaults.standard
        let explicitKeys = [
            "selectedPlannerId",
            "startWeekday",
            StreakCriteria.storageKey,
            ReportNotificationSettings.weeklyEnabledKey,
            ReportNotificationSettings.monthlyEnabledKey,
            ReportNotificationSettings.hourKey,
            ReportNotificationSettings.minuteKey,
            ReportNotificationSettings.weeklyWeekdayKey,
            ReportNotificationSettings.monthlyTimingKey,
            "todoHideCompleted",
            "todoShowMemo",
            "notionConnected",
            "isNotionConnected",
            "notionContextMigrated",
            "reportLinkedNotionIds",
            UserDefaultsKeys.plannerName,
            UserDefaultsKeys.plannerColorHex,
        ]
        explicitKeys.forEach { defaults.removeObject(forKey: $0) }

        let legacyPrefix = UserDefaultsKeys.prefix
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(legacyPrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
    }

    // MARK: - Notifications

    private static func cancelAllNotifications() {
        TodoNotificationManager.shared.cancelAll()
    }
}
