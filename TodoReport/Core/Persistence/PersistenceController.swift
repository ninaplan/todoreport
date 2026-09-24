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

private struct PlannerMergeResult {
    let count: Int
    let ids: [String]
}

private struct ReassignOutcome {
    let count: Int
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
            RecurringSeries.self,
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
        let legacyExists = AppGroupStore.legacyStoreExists()
        logger.info("[Persistence] heal 진입: legacyStoreExists=\(legacyExists)")
        AppLogger.shared.info("Persistence", "heal 진입: legacyStoreExists=\(legacyExists)")

        // 진단: legacy 경로에 파일이 없을 때 실제 저장 위치 확인용 (오류신고 첨부)
        logStoreDirectoryDiagnostics()

        guard legacyExists,
              let legacyURL = AppGroupStore.privateLegacyStoreURL(),
              let sharedURL = AppGroupStore.appSharedStoreURL(),
              legacyURL.path != sharedURL.path
        else { return }

        let legacyConfig = ModelConfiguration(schema: schema, url: legacyURL, allowsSave: false)
        guard let legacyContainer = try? ModelContainer(for: schema, configurations: legacyConfig) else {
            logger.error("[Persistence] legacy 스토어 읽기 전용 열기 실패")
            AppLogger.shared.error("Persistence", "legacy 스토어 읽기 전용 열기 실패")
            return
        }

        let legacyContext = ModelContext(legacyContainer)
        let sharedContext = sharedContainer.mainContext

        let plannerMerge = mergePlanners(from: legacyContext, into: sharedContext)
        let plannerOutcome = saveMergedEntity(
            "planners",
            inserted: plannerMerge.count,
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
        let summary = outcomes.map { healOutcomeLabel(entity: $0.0, outcome: $0.1) }.joined(separator: " ")
        if anyActivity {
            logger.info("[Persistence] legacy→shared 치유 병합 완료: \(summary, privacy: .public)")
        }
        // 오류신고용: 병합 0건이어도 summary를 남겨 heal이 돌았는지 확인 가능하게 함
        AppLogger.shared.info("Persistence", "legacy→shared 치유 병합 완료: \(summary)")

        // 이번 실행 병합 여부와 무관 — legacy가 있으면 항상 가짜 플래너 정리 시도 (멱등)
        reconcileFakePlannersIfNeeded(from: legacyContext, into: sharedContext)
    }

    /// Application Support / App Group 컨테이너 내용을 1단계 깊이까지 나열 (경로 진단용)
    private func logStoreDirectoryDiagnostics() {
        let fm = FileManager.default

        if let appSupportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            logDirectoryContents(label: "Application Support", at: appSupportURL)
        } else {
            AppLogger.shared.error("Persistence", "Application Support 경로를 가져오지 못함")
            logger.error("[Persistence] Application Support 경로를 가져오지 못함")
        }

        if let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: AppGroupConstants.suiteName) {
            logDirectoryContents(label: "App Group", at: groupURL)
        } else {
            AppLogger.shared.error("Persistence", "App Group 컨테이너 경로를 가져오지 못함")
            logger.error("[Persistence] App Group 컨테이너 경로를 가져오지 못함")
        }
    }

    private func logDirectoryContents(label: String, at url: URL) {
        let pathMessage = "\(label) 경로: \(url.path)"
        AppLogger.shared.info("Persistence", pathMessage)
        logger.info("[Persistence] \(pathMessage, privacy: .public)")

        let fm = FileManager.default
        let entries: [URL]
        do {
            entries = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
        } catch {
            let errorMessage = "\(label) 내용물 조회 실패: \(error.localizedDescription)"
            AppLogger.shared.error("Persistence", errorMessage)
            logger.error("[Persistence] \(errorMessage, privacy: .public)")
            return
        }

        let names = entries.map(\.lastPathComponent).sorted()
        let listMessage = "\(label) 내용물: \(names.isEmpty ? "(비어 있음)" : names.joined(separator: ", "))"
        AppLogger.shared.info("Persistence", listMessage)
        logger.info("[Persistence] \(listMessage, privacy: .public)")

        for entry in entries {
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDirectory else { continue }

            do {
                let children = try fm.contentsOfDirectory(
                    at: entry,
                    includingPropertiesForKeys: nil,
                    options: []
                )
                let childNames = children.map(\.lastPathComponent).sorted()
                let childMessage = "\(label)/\(entry.lastPathComponent): \(childNames.isEmpty ? "(비어 있음)" : childNames.joined(separator: ", "))"
                AppLogger.shared.info("Persistence", childMessage)
                logger.info("[Persistence] \(childMessage, privacy: .public)")
            } catch {
                let childError = "\(label)/\(entry.lastPathComponent) 조회 실패: \(error.localizedDescription)"
                AppLogger.shared.error("Persistence", childError)
                logger.error("[Persistence] \(childError, privacy: .public)")
            }
        }
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
            let message = "legacy→shared \(entityName) 저장 실패 (\(inserted)건): \(error.localizedDescription)"
            logger.error("[Persistence] \(message, privacy: .public)")
            AppLogger.shared.error("Persistence", message)
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

    private func mergePlanners(from legacy: ModelContext, into shared: ModelContext) -> PlannerMergeResult {
        guard let legacyItems = try? legacy.fetch(FetchDescriptor<PlannerItem>()),
              let sharedItems = try? shared.fetch(FetchDescriptor<PlannerItem>())
        else { return PlannerMergeResult(count: 0, ids: []) }

        let existingIds = Set(sharedItems.map(\.id))
        var mergedIds: [String] = []

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
            mergedIds.append(source.id)
        }
        return PlannerMergeResult(count: mergedIds.count, ids: mergedIds)
    }

    // MARK: - Fake planner reconciliation (v1.10 bug cleanup)

    /// legacy∩shared 플래너 id로 원본을 판별한다.
    /// 이번 실행 병합 여부와 무관 — 1.11에서 이미 복구된 기기에서도 동작한다.
    private func reconcileFakePlannersIfNeeded(from legacy: ModelContext, into shared: ModelContext) {
        guard let legacyPlanners = try? legacy.fetch(FetchDescriptor<PlannerItem>()),
              let sharedPlanners = try? shared.fetch(FetchDescriptor<PlannerItem>())
        else {
            logger.error("[Persistence] 가짜 플래너 정리 실패: PlannerItem 조회 실패")
            AppLogger.shared.error("Persistence", "가짜 플래너 정리 실패: PlannerItem 조회 실패")
            return
        }

        let legacyIds = Set(legacyPlanners.map(\.id))
        let sharedIds = Set(sharedPlanners.map(\.id))
        let originalIds = legacyIds.intersection(sharedIds)

        logger.info("[Persistence] 가짜 플래너 정리: legacy∩shared=\(originalIds.count)")
        AppLogger.shared.info("Persistence", "가짜 플래너 정리: legacy∩shared=\(originalIds.count)")

        let originalId: String
        switch originalIds.count {
        case 0:
            logger.info("[Persistence] 가짜 플래너 정리 스킵: legacy∩shared 플래너 0개")
            AppLogger.shared.info("Persistence", "가짜 플래너 정리 스킵: legacy∩shared 플래너 0개")
            return
        case 1:
            guard let id = originalIds.first else { return }
            originalId = id
        default:
            let skipMessage = "가짜 플래너 정리 스킵: legacy∩shared 플래너 \(originalIds.count)개 (2개 이상, 애매한 케이스)"
            logger.info("[Persistence] \(skipMessage, privacy: .public)")
            AppLogger.shared.info("Persistence", skipMessage)
            return
        }

        let fakePlanners = sharedPlanners.filter { $0.id != originalId }
        guard !fakePlanners.isEmpty else {
            let message = "가짜 플래너 정리: 후보 없음 (originalId=\(originalId))"
            logger.info("[Persistence] \(message, privacy: .public)")
            AppLogger.shared.info("Persistence", message)
            return
        }

        let foundMessage = "가짜 플래너 후보 \(fakePlanners.count)개 발견 (originalId=\(originalId))"
        logger.info("[Persistence] \(foundMessage, privacy: .public)")
        AppLogger.shared.info("Persistence", foundMessage)

        for fakePlanner in fakePlanners {
            let fakeId = fakePlanner.id
            let todoOutcome = reassignTodos(from: fakeId, to: originalId, in: shared)
            let reportOutcome = reassignDailyReports(from: fakeId, to: originalId, in: shared)
            let categoryOutcome = reassignCategories(from: fakeId, to: originalId, in: shared)
            let queueOutcome = reassignSyncQueueItems(from: fakeId, to: originalId, in: shared)

            let reassignMessage = """
            가짜 플래너 재할당 완료 fakeId=\(fakeId): \
            todos=\(todoOutcome.count)(\(reassignStatusLabel(todoOutcome.saveStatus))), \
            reports=\(reportOutcome.count)(\(reassignStatusLabel(reportOutcome.saveStatus))), \
            categories=\(categoryOutcome.count)(\(reassignStatusLabel(categoryOutcome.saveStatus))), \
            syncQueue=\(queueOutcome.count)(\(reassignStatusLabel(queueOutcome.saveStatus)))
            """
            logger.info("[Persistence] \(reassignMessage, privacy: .public)")
            AppLogger.shared.info("Persistence", reassignMessage)
        }

        let currentSelected = AppGroupUserDefaults.selectedPlannerId()
        if currentSelected != originalId {
            AppGroupUserDefaults.setSelectedPlannerId(originalId)
            let message = "selectedPlannerId 변경: \(currentSelected ?? "nil") → \(originalId)"
            logger.info("[Persistence] \(message, privacy: .public)")
            AppLogger.shared.info("Persistence", message)
        } else {
            let message = "selectedPlannerId 유지 (이미 originalId=\(originalId))"
            logger.info("[Persistence] \(message, privacy: .public)")
            AppLogger.shared.info("Persistence", message)
        }
    }

    private func reassignStatusLabel(_ status: HealSaveStatus) -> String {
        switch status {
        case .skipped: return "없음"
        case .success: return "성공"
        case .failure: return "실패"
        }
    }

    private func reassignTodos(from fakePlannerId: String, to originalId: String, in shared: ModelContext) -> ReassignOutcome {
        guard let allItems = try? shared.fetch(FetchDescriptor<TodoItem>()) else {
            let message = "TodoItem 재할당 실패: 조회 실패 (fakeId=\(fakePlannerId))"
            logger.error("[Persistence] \(message, privacy: .public)")
            AppLogger.shared.error("Persistence", message)
            return ReassignOutcome(count: 0, saveStatus: .failure)
        }

        let toReassign = allItems.filter { $0.plannerId == fakePlannerId }
        guard !toReassign.isEmpty else {
            return ReassignOutcome(count: 0, saveStatus: .skipped)
        }

        for item in toReassign {
            item.plannerId = originalId
        }

        do {
            try shared.save()
            return ReassignOutcome(count: toReassign.count, saveStatus: .success)
        } catch {
            let message = "TodoItem 재할당 저장 실패 (\(toReassign.count)건, fakeId=\(fakePlannerId)): \(error.localizedDescription)"
            logger.error("[Persistence] \(message, privacy: .public)")
            AppLogger.shared.error("Persistence", message)
            shared.rollback()
            return ReassignOutcome(count: toReassign.count, saveStatus: .failure)
        }
    }

    private func reassignDailyReports(from fakePlannerId: String, to originalId: String, in shared: ModelContext) -> ReassignOutcome {
        guard let allItems = try? shared.fetch(FetchDescriptor<DailyReportItem>()) else {
            let message = "DailyReportItem 재할당 실패: 조회 실패 (fakeId=\(fakePlannerId))"
            logger.error("[Persistence] \(message, privacy: .public)")
            AppLogger.shared.error("Persistence", message)
            return ReassignOutcome(count: 0, saveStatus: .failure)
        }

        let toReassign = allItems.filter { $0.plannerId == fakePlannerId }
        guard !toReassign.isEmpty else {
            return ReassignOutcome(count: 0, saveStatus: .skipped)
        }

        for item in toReassign {
            item.plannerId = originalId
        }

        do {
            try shared.save()
            return ReassignOutcome(count: toReassign.count, saveStatus: .success)
        } catch {
            let message = "DailyReportItem 재할당 저장 실패 (\(toReassign.count)건, fakeId=\(fakePlannerId)): \(error.localizedDescription)"
            logger.error("[Persistence] \(message, privacy: .public)")
            AppLogger.shared.error("Persistence", message)
            shared.rollback()
            return ReassignOutcome(count: toReassign.count, saveStatus: .failure)
        }
    }

    private func reassignCategories(from fakePlannerId: String, to originalId: String, in shared: ModelContext) -> ReassignOutcome {
        guard let allItems = try? shared.fetch(FetchDescriptor<CategoryItem>()) else {
            let message = "CategoryItem 재할당 실패: 조회 실패 (fakeId=\(fakePlannerId))"
            logger.error("[Persistence] \(message, privacy: .public)")
            AppLogger.shared.error("Persistence", message)
            return ReassignOutcome(count: 0, saveStatus: .failure)
        }

        let toReassign = allItems.filter { $0.plannerId == fakePlannerId }
        guard !toReassign.isEmpty else {
            return ReassignOutcome(count: 0, saveStatus: .skipped)
        }

        for item in toReassign {
            item.plannerId = originalId
        }

        do {
            try shared.save()
            return ReassignOutcome(count: toReassign.count, saveStatus: .success)
        } catch {
            let message = "CategoryItem 재할당 저장 실패 (\(toReassign.count)건, fakeId=\(fakePlannerId)): \(error.localizedDescription)"
            logger.error("[Persistence] \(message, privacy: .public)")
            AppLogger.shared.error("Persistence", message)
            shared.rollback()
            return ReassignOutcome(count: toReassign.count, saveStatus: .failure)
        }
    }

    private func reassignSyncQueueItems(from fakePlannerId: String, to originalId: String, in shared: ModelContext) -> ReassignOutcome {
        guard let allItems = try? shared.fetch(FetchDescriptor<SyncQueueItem>()) else {
            let message = "SyncQueueItem 재할당 실패: 조회 실패 (fakeId=\(fakePlannerId))"
            logger.error("[Persistence] \(message, privacy: .public)")
            AppLogger.shared.error("Persistence", message)
            return ReassignOutcome(count: 0, saveStatus: .failure)
        }

        let toReassign = allItems.filter { $0.plannerId == fakePlannerId }
        guard !toReassign.isEmpty else {
            return ReassignOutcome(count: 0, saveStatus: .skipped)
        }

        for item in toReassign {
            item.plannerId = originalId
        }

        do {
            try shared.save()
            return ReassignOutcome(count: toReassign.count, saveStatus: .success)
        } catch {
            let message = "SyncQueueItem 재할당 저장 실패 (\(toReassign.count)건, fakeId=\(fakePlannerId)): \(error.localizedDescription)"
            logger.error("[Persistence] \(message, privacy: .public)")
            AppLogger.shared.error("Persistence", message)
            shared.rollback()
            return ReassignOutcome(count: toReassign.count, saveStatus: .failure)
        }
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
                aiComment: source.aiComment,
                notionSyncPendingAt: source.notionSyncPendingAt
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
