import Foundation
import SwiftData

@MainActor
final class AccountDeletionService {
    static let shared = AccountDeletionService()
    private init() {}

    private let logModule = "AccountDeletion"

    func deleteAllAccountData(context: ModelContext) async throws {
        let plannerIds = collectPlannerIds(context: context)
        let notionTokens = collectNotionTokens(context: context)

        AppLogger.shared.info(logModule, "계정 삭제 시작")

        AppLogger.shared.info(logModule, "1. SyncQueue 일시정지")
        SyncQueueManager.shared.pauseProcessing()

        try deleteAllEntities(
            SyncQueueItem.self,
            context: context,
            step: "2. SyncQueueItem"
        )
        try deleteAllEntities(
            TodoItem.self,
            context: context,
            step: "3. TodoItem"
        )
        try deleteAllEntities(
            DailyReportItem.self,
            context: context,
            step: "4. DailyReportItem"
        )
        try deleteAllEntities(
            CategoryItem.self,
            context: context,
            step: "5. CategoryItem"
        )
        try deleteAllEntities(
            PlannerItem.self,
            context: context,
            step: "6. PlannerItem"
        )

        AppLogger.shared.info(logModule, "7. context.save()")
        do {
            try context.save()
            AppLogger.shared.info(logModule, "7. context.save() 완료")
        } catch {
            AppLogger.shared.error(logModule, "SwiftData 저장 실패: \(error.localizedDescription)")
            throw error
        }

        AppLogger.shared.info(logModule, "8. Notion 토큰 \(notionTokens.count)개 수집 완료")
        await revokeNotionTokens(notionTokens)

        AppLogger.shared.info(logModule, "10. NotionAuthManager.signOut()")
        let keychainBeforeSignOut = NotionAuthManager.shared.hasLegacyKeychainCredentials()
        let memoryTokenBeforeSignOut = NotionAuthManager.shared.hasInMemoryAccessToken()
        AppLogger.shared.info(
            logModule,
            "10. signOut 전 — Keychain 토큰:\(keychainBeforeSignOut) in-memory:\(memoryTokenBeforeSignOut)"
        )
        NotionAuthManager.shared.signOut()
        let keychainAfterSignOut = NotionAuthManager.shared.hasLegacyKeychainCredentials()
        let memoryTokenAfterSignOut = NotionAuthManager.shared.hasInMemoryAccessToken()
        AppLogger.shared.info(
            logModule,
            "10. signOut 후 Keychain 삭제 확인 — Keychain 잔존:\(keychainAfterSignOut) in-memory:\(memoryTokenAfterSignOut)"
        )
        if keychainAfterSignOut || memoryTokenAfterSignOut {
            AppLogger.shared.error(logModule, "10. Keychain/in-memory 토큰 잔존 — signOut 재시도")
            NotionAuthManager.shared.signOut()
            let retryKeychain = NotionAuthManager.shared.hasLegacyKeychainCredentials()
            let retryMemory = NotionAuthManager.shared.hasInMemoryAccessToken()
            AppLogger.shared.info(
                logModule,
                "10. signOut 재시도 후 — Keychain 잔존:\(retryKeychain) in-memory:\(retryMemory)"
            )
        }

        AppLogger.shared.info(logModule, "11. UserDefaults 삭제")
        clearUserDefaults(plannerIds: plannerIds)

        AppLogger.shared.info(logModule, "12. WidgetDataProvider.clear()")
        WidgetDataProvider.shared.clear()

        AppLogger.shared.info(logModule, "13. TodoNotificationManager.cancelAll()")
        TodoNotificationManager.shared.cancelAll()

        AppLogger.shared.info(logModule, "14. ReportNotificationManager.cancelAll()")
        ReportNotificationManager.shared.cancelAll()

        AppLogger.shared.info(logModule, "15. app_logs.txt 삭제")
        deleteAppLogFile()

        AppLogger.shared.info(logModule, "16. PlannerService store 갱신 (온보딩용 기본 플래너)")
        PlannerService.shared.resetStoreAfterAccountDeletion()

        SyncQueueManager.shared.resumeProcessing()

        AppLogger.shared.info(logModule, "계정 삭제 완료")
    }

    // MARK: - SwiftData

    private func deleteAllEntities<T: PersistentModel>(
        _ type: T.Type,
        context: ModelContext,
        step: String
    ) throws {
        AppLogger.shared.info(logModule, "\(step) 삭제 시작")
        let descriptor = FetchDescriptor<T>()
        let items = try context.fetch(descriptor)
        for item in items {
            context.delete(item)
        }
        AppLogger.shared.info(logModule, "\(step) 삭제 완료 - \(items.count)건")
    }

    // MARK: - Notion 토큰

    private func collectPlannerIds(context: ModelContext) -> [String] {
        let descriptor = FetchDescriptor<PlannerItem>()
        let items = (try? context.fetch(descriptor)) ?? []
        return items.map(\.id)
    }

    private func collectNotionTokens(context: ModelContext) -> [String] {
        var tokens = Set<String>()
        let descriptor = FetchDescriptor<PlannerItem>()
        let items = (try? context.fetch(descriptor)) ?? []

        for item in items {
            if let token = item.notionAccessToken, !token.isEmpty {
                tokens.insert(token)
            }
        }

        if let legacy = NotionAuthManager.shared.readLegacyAccessToken(), !legacy.isEmpty {
            tokens.insert(legacy)
        }

        if let memoryToken = NotionAuthManager.shared.currentAccessToken(), !memoryToken.isEmpty {
            tokens.insert(memoryToken)
        }

        return Array(tokens)
    }

    private func revokeNotionTokens(_ tokens: [String]) async {
        AppLogger.shared.info(logModule, "9. Notion 토큰 revoke 시작 - \(tokens.count)개")
        for token in tokens {
            do {
                try await APIClient.shared.revokeNotionToken(token)
                AppLogger.shared.info(logModule, "9. Notion 토큰 revoke 성공")
            } catch {
                AppLogger.shared.error(logModule, "9. Notion 토큰 revoke 실패 (계속 진행): \(error.localizedDescription)")
            }
        }
        AppLogger.shared.info(logModule, "9. Notion 토큰 revoke 완료")
    }

    // MARK: - UserDefaults

    private func clearUserDefaults(plannerIds: [String]) {
        let defaults = UserDefaults.standard
        var keys = UserDefaultsKeys.accountDeletionKeys
        let prefix = UserDefaultsKeys.prefix
        for plannerId in plannerIds {
            keys.append("\(prefix)\(plannerId).todoDBId")
            keys.append("\(prefix)\(plannerId).reportDBId")
            keys.append("\(prefix)\(plannerId).todoPropsMapping")
            keys.append("\(prefix)\(plannerId).reportPropsMapping")
        }

        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - 로그 파일

    private func deleteAppLogFile() {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let logURL = documentsURL.appendingPathComponent("app_logs.txt")
        guard FileManager.default.fileExists(atPath: logURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: logURL)
            AppLogger.shared.info(logModule, "15. app_logs.txt 삭제 완료")
        } catch {
            AppLogger.shared.error(logModule, "15. app_logs.txt 삭제 실패 (계속 진행): \(error.localizedDescription)")
        }
    }
}
