import Foundation
import OSLog
import SwiftData

enum AppGroupStore {
    private static let logger = Logger(subsystem: "kr.nock.TodoReport", category: "AppGroupStore")

    static var schema: Schema {
        Schema([
            PlannerItem.self,
            NotionWorkspaceConnection.self,
            TodoItem.self,
            RecurringSeries.self,
            DailyReportItem.self,
            CategoryItem.self,
            MoodOptionItem.self,
            SyncQueueItem.self
        ])
    }

    // MARK: - Widget (read-only, never creates store files)

    /// 위젯 전용: 공유 스토어 파일이 이미 있을 때만 구성을 반환한다. 없으면 nil.
    static func makeWidgetConfiguration(allowsSave: Bool = false) -> ModelConfiguration? {
        guard let url = existingSharedStoreURL() else { return nil }
        return ModelConfiguration(schema: schema, url: url, allowsSave: allowsSave)
    }

    // MARK: - Main app (may create empty shared store; never copies legacy files)

    /// 메인 앱 전용: App Group 공유 스토어 URL로 구성을 반환한다. 파일이 없으면 ModelContainer가 빈 스토어를 생성한다.
    static func makeAppConfiguration(allowsSave: Bool = true) -> ModelConfiguration? {
        guard let url = appSharedStoreURL() else {
            logger.error("App Group 컨테이너 URL을 가져오지 못함")
            guard let legacyURL = privateLegacyStoreURL() else { return nil }
            return ModelConfiguration(schema: schema, url: legacyURL, allowsSave: allowsSave)
        }
        return ModelConfiguration(schema: schema, url: url, allowsSave: allowsSave)
    }

    // MARK: - Store URLs

    /// App Group에 이미 존재하는 공유 스토어 URL. 없으면 nil (파일 생성 안 함).
    static func existingSharedStoreURL() -> URL? {
        guard let url = appGroupSharedStoreURL(), fileExists(at: url) else { return nil }
        return url
    }

    /// 메인 앱이 사용할 공유 스토어 URL. App Group 불가 시 legacy private URL을 반환한다.
    static func appSharedStoreURL() -> URL? {
        appGroupSharedStoreURL() ?? privateLegacyStoreURL()
    }

    static func privateLegacyStoreURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(AppGroupConstants.legacyStoreFileName)
    }

    static func legacyStoreExists() -> Bool {
        guard let url = privateLegacyStoreURL() else { return false }
        return fileExists(at: url)
    }

    static func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private static func appGroupSharedStoreURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupConstants.suiteName)?
            .appendingPathComponent(AppGroupConstants.storeFileName)
    }
}
