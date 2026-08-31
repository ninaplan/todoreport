import SwiftData
import OSLog

private let logger = Logger(subsystem: "kr.nock.TodoReport", category: "Persistence")

private enum HealSaveStatus {
    case skipped
    case success
    case failure
}

private struct HealEntityOutcome {
    let inserted: Int
    let skipped: Int
    let saveStatus: HealSaveStatus
}

final class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer
    // nil이면 정상, non-nil이면 영구 저장소 초기화 실패 → 앱이 에러 UI를 표시해야 함
    private(set) var initializationError: Error? = nil

    private init() {
        let schema = Schema([
            PlannerItem.self,
            NotionWorkspaceConnection.self,
            TodoItem.self,
            DailyReportItem.self,
            CategoryItem.self,
            SyncQueueItem.self
        ])

        let config: ModelConfiguration
        if let sharedConfig = AppGroupStore.makeAppConfiguration(allowsSave: true) {
            config = sharedConfig
        } else {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }

        do {
            container = try ModelContainer(for: schema, configurations: config)
            healLegacyStoreIfNeeded(into: container, schema: schema)
        } catch {
            #if DEBUG
            fatalError("""
            [Persistence] ❌ SwiftData 영구 저장소 초기화 실패
            원인: \(error)
            → 스키마 변경 후 경량 마이그레이션 불가 시 발생.
              시뮬레이터: 앱 삭제 후 재설치로 해결.
              실기기: SyncQueueItem.requeueCount 등 @Attribute 기본값 누락 여부 확인.
            """)
            #else
            // 프로덕션: 앱 충돌을 막기 위한 최소 셸만 유지.
            // initializationError가 세팅되면 앱이 에러 UI를 표시하고 정상 플로우는 차단됨.
            logger.fault("[Persistence] ❌ ModelContainer 초기화 실패: \(error, privacy: .public)")
            initializationError = error

            let shellConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            guard let shell = try? ModelContainer(for: schema, configurations: shellConfig) else {
                // 스키마 자체가 깨진 경우 — 앱 기동 자체 불가, crash가 불가피
                fatalError("[Persistence] ❌ 인메모리 셸 생성도 실패 — 스키마 오류: \(error)")
            }
            container = shell
            #endif
        }
    }

    var context: ModelContext {
        container.mainContext
    }

    // MARK: - Legacy heal (idempotent merge by id)

    private func healLegacyStoreIfNeeded(into sharedContainer: ModelContainer, schema: Schema) {
        guard AppGroupStore.legacyStoreExists(),
              let legacyURL = AppGroupStore.privateLegacyStoreURL(),
              let sharedURL = AppGroupStore.appSharedStoreURL(),
              legacyURL.path != sharedURL.path
        else { return }

        let legacyConfig = ModelConfiguration(schema: schema, url: legacyURL, allowsSave: false)
        guard let legacyContainer = try? ModelContainer(for: schema, configurations: legacyConfig) else {
            logger.error("[Persistence] legacy 스토어 읽기 전용 열기 실패")
            return
        }

        let legacyContext = ModelContext(legacyContainer)
        let sharedContext = sharedContainer.mainContext

        let plannerOutcome = saveMergedEntity(
            "planners",
            inserted: mergePlanners(from: legacyContext, into: sharedContext),
            into: sharedContext
        )
        let connectionMerge = mergeNotionConnections(from: legacyContext, into: sharedContext)
        let connectionOutcome = saveMergedEntity(
            "connections",
            inserted: connectionMerge.inserted,
            skipped: connectionMerge.skippedWorkspaceId,
            into: sharedContext
        )
        let todoOutcome = saveMergedEntity(
            "todos",
            inserted: mergeTodos(from: legacyContext, into: sharedContext),
            into: sharedContext
        )
        let categoryOutcome = saveMergedEntity(
            "categories",
            inserted: mergeCategories(from: legacyContext, into: sharedContext),
            into: sharedContext
        )
        let reportOutcome = saveMergedEntity(
            "reports",
            inserted: mergeDailyReports(from: legacyContext, into: sharedContext),
            into: sharedContext
        )
        let queueOutcome = saveMergedEntity(
            "syncQueue",
            inserted: mergeSyncQueueItems(from: legacyContext, into: sharedContext),
            into: sharedContext
        )

        let outcomes = [
            ("planners", plannerOutcome),
            ("connections", connectionOutcome),
            ("todos", todoOutcome),
            ("categories", categoryOutcome),
            ("reports", reportOutcome),
            ("syncQueue", queueOutcome)
        ]

        let anyActivity = outcomes.contains { outcome in
            outcome.1.inserted > 0 || outcome.1.skipped > 0 || outcome.1.saveStatus == .failure
        }
        guard anyActivity else { return }

        let summary = outcomes.map { healOutcomeLabel(entity: $0.0, outcome: $0.1) }.joined(separator: " ")
        logger.info("[Persistence] legacy→shared 치유 병합 완료: \(summary, privacy: .public)")
    }

    private func saveMergedEntity(
        _ entityName: String,
        inserted: Int,
        skipped: Int = 0,
        into shared: ModelContext
    ) -> HealEntityOutcome {
        guard inserted > 0 else {
            return HealEntityOutcome(inserted: 0, skipped: skipped, saveStatus: .skipped)
        }

        do {
            try shared.save()
            return HealEntityOutcome(inserted: inserted, skipped: skipped, saveStatus: .success)
        } catch {
            logger.error(
                "[Persistence] legacy→shared \(entityName) 저장 실패 (\(inserted)건): \(error.localizedDescription, privacy: .public)"
            )
            shared.rollback()
            return HealEntityOutcome(inserted: inserted, skipped: skipped, saveStatus: .failure)
        }
    }

    private func healOutcomeLabel(entity: String, outcome: HealEntityOutcome) -> String {
        let status: String
        switch outcome.saveStatus {
        case .skipped:
            status = "없음"
        case .success:
            status = "성공"
        case .failure:
            status = "실패"
        }

        if outcome.skipped > 0 {
            return "\(entity)=\(outcome.inserted)(\(status), workspaceId스킵=\(outcome.skipped))"
        }
        return "\(entity)=\(outcome.inserted)(\(status))"
    }

    private func mergePlanners(from legacy: ModelContext, into shared: ModelContext) -> Int {
        guard let legacyItems = try? legacy.fetch(FetchDescriptor<PlannerItem>()),
              let sharedItems = try? shared.fetch(FetchDescriptor<PlannerItem>())
        else { return 0 }

        let existingIds = Set(sharedItems.map(\.id))
        var merged = 0

        for source in legacyItems where !existingIds.contains(source.id) {
            let copy = PlannerItem(
                id: source.id,
                name: source.name,
                colorHex: source.colorHex,
                isNotionConnected: source.isNotionConnected,
                notionTodoDBId: source.notionTodoDBId,
                notionReportDBId: source.notionReportDBId,
                notionCategoryDBId: source.notionCategoryDBId,
                notionAccessToken: source.notionAccessToken,
                notionRefreshToken: source.notionRefreshToken,
                notionWorkspaceConnectionId: source.notionWorkspaceConnectionId,
                iconType: source.iconType,
                iconImageData: source.iconImageData,
                createdAt: source.createdAt,
                todoPropsMapping: source.todoPropsMapping,
                reportPropsMapping: source.reportPropsMapping,
                isReadOnly: source.isReadOnly,
                sortOrder: source.sortOrder
            )
            copy.categoryPaletteSetId = source.categoryPaletteSetId
            shared.insert(copy)
            merged += 1
        }
        return merged
    }

    private struct NotionConnectionMergeResult {
        let inserted: Int
        let skippedWorkspaceId: Int
    }

    private func mergeNotionConnections(from legacy: ModelContext, into shared: ModelContext) -> NotionConnectionMergeResult {
        guard let legacyItems = try? legacy.fetch(FetchDescriptor<NotionWorkspaceConnection>()),
              let sharedItems = try? shared.fetch(FetchDescriptor<NotionWorkspaceConnection>())
        else { return NotionConnectionMergeResult(inserted: 0, skippedWorkspaceId: 0) }

        let existingIds = Set(sharedItems.map(\.id))
        let existingWorkspaceIds = Set(sharedItems.map(\.workspaceId))
        var inserted = 0
        var skippedWorkspaceId = 0

        for source in legacyItems where !existingIds.contains(source.id) {
            if existingWorkspaceIds.contains(source.workspaceId) {
                logger.info(
                    """
                    [Persistence] legacy→shared connection workspaceId 충돌로 스킵: \
                    id=\(source.id, privacy: .public), workspaceId=\(source.workspaceId, privacy: .public)
                    """
                )
                skippedWorkspaceId += 1
                continue
            }

            let copy = NotionWorkspaceConnection(
                id: source.id,
                workspaceId: source.workspaceId,
                workspaceName: source.workspaceName,
                accessToken: source.accessToken,
                refreshToken: source.refreshToken,
                botId: source.botId,
                createdAt: source.createdAt,
                updatedAt: source.updatedAt
            )
            shared.insert(copy)
            inserted += 1
        }
        return NotionConnectionMergeResult(inserted: inserted, skippedWorkspaceId: skippedWorkspaceId)
    }

    private func mergeTodos(from legacy: ModelContext, into shared: ModelContext) -> Int {
        guard let legacyItems = try? legacy.fetch(FetchDescriptor<TodoItem>()),
              let sharedItems = try? shared.fetch(FetchDescriptor<TodoItem>())
        else { return 0 }

        let existingIds = Set(sharedItems.map(\.id))
        var merged = 0

        for source in legacyItems where !existingIds.contains(source.id) {
            let copy = TodoItem(
                id: source.id,
                title: source.title,
                memo: source.memo,
                isCompleted: source.isCompleted,
                isPinned: source.isPinned,
                date: source.date,
                completedAt: source.completedAt,
                notionCreatedAt: source.notionCreatedAt,
                notionLastEditedTime: source.notionLastEditedTime,
                categoryId: source.categoryId,
                notionPageId: source.notionPageId,
                plannerId: source.plannerId,
                scheduledTime: source.scheduledTime,
                alarmOffset: source.alarmOffset,
                recurrenceData: source.recurrenceData,
                recurrenceId: source.recurrenceId,
                recurrenceEndDate: source.recurrenceEndDate,
                recurrenceCount: source.recurrenceCount,
                notionRelationLinked: source.notionRelationLinked
            )
            copy.createdAt = source.createdAt
            copy.categoryName = source.categoryName
            copy.localModifiedAt = source.localModifiedAt
            shared.insert(copy)
            merged += 1
        }
        return merged
    }

    private func mergeCategories(from legacy: ModelContext, into shared: ModelContext) -> Int {
        guard let legacyItems = try? legacy.fetch(FetchDescriptor<CategoryItem>()),
              let sharedItems = try? shared.fetch(FetchDescriptor<CategoryItem>())
        else { return 0 }

        let existingIds = Set(sharedItems.map(\.id))
        var merged = 0

        for source in legacyItems where !existingIds.contains(source.id) {
            let copy = CategoryItem(
                id: source.id,
                name: source.name,
                colorHex: source.colorHex,
                icon: source.icon,
                statusRaw: source.statusRaw,
                sortOrder: source.sortOrder,
                plannerId: source.plannerId,
                notionOptionId: source.notionOptionId,
                notionOptionName: source.notionOptionName
            )
            copy.notionPageId = source.notionPageId
            copy.isHidden = source.isHidden
            shared.insert(copy)
            merged += 1
        }
        return merged
    }

    private func mergeDailyReports(from legacy: ModelContext, into shared: ModelContext) -> Int {
        guard let legacyItems = try? legacy.fetch(FetchDescriptor<DailyReportItem>()),
              let sharedItems = try? shared.fetch(FetchDescriptor<DailyReportItem>())
        else { return 0 }

        let existingIds = Set(sharedItems.map(\.id))
        var merged = 0

        for source in legacyItems where !existingIds.contains(source.id) {
            let copy = DailyReportItem(
                id: source.id,
                date: source.date,
                review: source.review,
                completionRate: source.completionRate,
                dayRatingRaw: source.dayRatingRaw,
                photoURLs: source.photoURLs,
                notionPageId: source.notionPageId,
                plannerId: source.plannerId,
                endDate: source.endDate,
                periodCompletionRate: source.periodCompletionRate,
                aiComment: source.aiComment
            )
            shared.insert(copy)
            merged += 1
        }
        return merged
    }

    private func mergeSyncQueueItems(from legacy: ModelContext, into shared: ModelContext) -> Int {
        guard let legacyItems = try? legacy.fetch(FetchDescriptor<SyncQueueItem>()),
              let sharedItems = try? shared.fetch(FetchDescriptor<SyncQueueItem>())
        else { return 0 }

        let existingIds = Set(sharedItems.map(\.id))
        var merged = 0

        for source in legacyItems where !existingIds.contains(source.id) {
            let copy = SyncQueueItem(
                id: source.id,
                action: source.action,
                entityType: source.entityType,
                entityId: source.entityId,
                payload: source.payload,
                retryCount: source.retryCount,
                requeueCount: source.requeueCount,
                status: source.status,
                createdAt: source.createdAt,
                plannerId: source.plannerId
            )
            shared.insert(copy)
            merged += 1
        }
        return merged
    }
}
