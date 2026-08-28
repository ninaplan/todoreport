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
            DailyReportItem.self,
            CategoryItem.self,
            SyncQueueItem.self
        ])
    }

    static func resolvedStoreURL() -> URL? {
        migrateStoreIfNeeded()
    }

    static func makeConfiguration(allowsSave: Bool) -> ModelConfiguration? {
        guard let url = resolvedStoreURL() else { return nil }
        return ModelConfiguration(schema: schema, url: url, allowsSave: allowsSave)
    }

    // MARK: - Migration

    private static func migrateStoreIfNeeded() -> URL? {
        guard let groupContainer = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConstants.suiteName
        ) else {
            logger.error("App Group 컨테이너 URL을 가져오지 못함")
            return privateLegacyStoreURL()
        }

        let sharedStoreURL = groupContainer.appendingPathComponent(AppGroupConstants.storeFileName)

        if fileExists(at: sharedStoreURL) {
            return sharedStoreURL
        }

        guard let legacyURL = privateLegacyStoreURL(), fileExists(at: legacyURL) else {
            return sharedStoreURL
        }

        do {
            try copyStoreFiles(from: legacyURL, to: sharedStoreURL)
            logger.info("SwiftData 스토어를 App Group으로 마이그레이션 완료")
            return sharedStoreURL
        } catch {
            logger.error("App Group 스토어 복사 실패, 앱 전용 스토어로 폴백: \(error.localizedDescription, privacy: .public)")
            return legacyURL
        }
    }

    private static func privateLegacyStoreURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(AppGroupConstants.legacyStoreFileName)
    }

    private static func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private static func copyStoreFiles(from sourceStoreURL: URL, to destinationStoreURL: URL) throws {
        let fileManager = FileManager.default
        let destinationDirectory = destinationStoreURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let sourceFileName = sourceStoreURL.lastPathComponent
        let destinationFileName = destinationStoreURL.lastPathComponent
        let sourceDirectory = sourceStoreURL.deletingLastPathComponent()

        for suffix in ["", "-shm", "-wal"] {
            let sourceURL = sourceDirectory.appendingPathComponent(sourceFileName + suffix)
            guard fileManager.fileExists(atPath: sourceURL.path) else { continue }

            let destinationURL = destinationDirectory.appendingPathComponent(destinationFileName + suffix)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
    }
}
