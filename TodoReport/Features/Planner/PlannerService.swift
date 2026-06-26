import Foundation
import SwiftData
import Observation

// MARK: - Planner 모델

struct Planner: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var colorHex: String
    var isNotionConnected: Bool
    var notionTodoDBId: String?
    var notionReportDBId: String?
    var notionCategoryDBId: String?  // v2 Pro: 카테고리 전용 DB
    // 플래너별 Notion 토큰 (nil이면 NotionAuthManager Keychain 토큰 fallback)
    var notionAccessToken: String?
    var notionRefreshToken: String?
    // 아이콘: SF Symbol 이름 또는 "photo"
    var iconType: String?
    var iconImageData: Data?
    var createdAt: Date
    // Notion 속성 매핑 (JSON 문자열로 저장)
    var todoPropsMapping: String?
    var reportPropsMapping: String?
    // Pro 해지 후 읽기 전용 전환 여부
    var isReadOnly: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String = "#FD6845",
        isNotionConnected: Bool = false,
        notionTodoDBId: String? = nil,
        notionReportDBId: String? = nil,
        notionCategoryDBId: String? = nil,
        notionAccessToken: String? = nil,
        notionRefreshToken: String? = nil,
        iconType: String? = nil,
        iconImageData: Data? = nil,
        createdAt: Date = .now,
        todoPropsMapping: String? = nil,
        reportPropsMapping: String? = nil,
        isReadOnly: Bool = false
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isNotionConnected = isNotionConnected
        self.notionTodoDBId = notionTodoDBId
        self.notionReportDBId = notionReportDBId
        self.notionCategoryDBId = notionCategoryDBId
        self.notionAccessToken = notionAccessToken
        self.notionRefreshToken = notionRefreshToken
        self.iconType = iconType
        self.iconImageData = iconImageData
        self.createdAt = createdAt
        self.todoPropsMapping = todoPropsMapping
        self.reportPropsMapping = reportPropsMapping
        self.isReadOnly = isReadOnly
    }

    // 이 플래너에서 사용할 Notion 액세스 토큰
    // 마이그레이션 전 기존 플래너: Keychain fallback 유지
    var resolvedNotionToken: String? {
        notionAccessToken ?? NotionAuthManager.shared.accessToken
    }

    var decodedTodoPropsMapping: TodoPropsMapping {
        guard let json = todoPropsMapping,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(TodoPropsMapping.self, from: data) else {
            return TodoPropsMapping()
        }
        return decoded
    }

    var decodedReportPropsMapping: ReportPropsMapping {
        guard let json = reportPropsMapping,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ReportPropsMapping.self, from: data) else {
            return ReportPropsMapping()
        }
        return decoded
    }
}

// MARK: - PlannerService

@Observable
final class PlannerService {
    static let shared = PlannerService()

    private init() {
        setup()
    }

    private(set) var store: [Planner] = []
    private(set) var selectedPlannerId: String = ""

    var selectedPlanner: Planner? {
        store.first(where: { $0.id == selectedPlannerId }) ?? store.first
    }

    private var context: ModelContext { PersistenceController.shared.context }

    // MARK: - 디폴트 이름 생성

    func generateDefaultName() -> String {
        let adjectives = ["귀여운", "작은", "용감한", "졸린", "배고픈", "신나는", "따뜻한", "차가운", "빠른", "느린", "똑똑한", "엉뚱한", "수줍은", "씩씩한", "행복한"]
        let animals = ["사자", "호랑이", "토끼", "펭귄", "곰", "여우", "돌고래", "판다", "코알라", "햄스터", "고슴도치", "미어캣", "카피바라", "라마", "알파카"]
        let existing = Set(store.map { $0.name })
        let candidates = adjectives.flatMap { adj in animals.map { "\(adj) \($0)" } }
            .filter { !existing.contains($0) }
        return candidates.randomElement() ?? "내 플래너 \(store.count + 1)"
    }

    // MARK: - Setup (앱 최초 실행 시 기본 플래너 생성 + 기존 데이터 backfill)

    private func setup() {
        refreshStore()

        if store.isEmpty {
            let item = PlannerItem.from(Planner(name: generateDefaultName()))
            context.insert(item)
            try? context.save()
            refreshStore()
        }

        migrateGlobalNotionContextIfNeeded()
        let savedId = UserDefaults.standard.string(forKey: "selectedPlannerId")
        if let savedId, store.contains(where: { $0.id == savedId }) {
            selectedPlannerId = savedId
        } else {
            selectedPlannerId = store.first?.id ?? ""
        }
        backfillPlannerId(selectedPlannerId)
    }

    // MARK: - 레거시 마이그레이션 (한 번만 실행)

    private func migrateGlobalNotionContextIfNeeded() {
        let flag = "notionContextMigrated"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        defer { UserDefaults.standard.set(true, forKey: flag) }

        let allItems = (try? context.fetch(FetchDescriptor<PlannerItem>())) ?? []
        guard let connectedItem = allItems.first(where: { $0.isNotionConnected }) else {
            return
        }

        let pid = connectedItem.id
        let prefix = "kr.nock.TodoReport."
        let scopedPrefix = "\(prefix)\(pid)."
        let defaults = UserDefaults.standard

        if connectedItem.notionAccessToken == nil {
            connectedItem.notionAccessToken = NotionAuthManager.shared.readLegacyAccessToken()
        }
        if connectedItem.notionTodoDBId == nil {
            connectedItem.notionTodoDBId = defaults.string(forKey: "\(scopedPrefix)todoDBId")
                ?? defaults.string(forKey: "\(prefix)todoDBId")
        }
        if connectedItem.notionReportDBId == nil {
            connectedItem.notionReportDBId = defaults.string(forKey: "\(scopedPrefix)reportDBId")
                ?? defaults.string(forKey: "\(prefix)reportDBId")
        }
        if connectedItem.todoPropsMapping == nil {
            if let data = defaults.data(forKey: "\(scopedPrefix)todoPropsMapping")
                ?? defaults.data(forKey: "\(prefix)todoPropsMapping"),
               let json = String(data: data, encoding: .utf8) {
                connectedItem.todoPropsMapping = json
            }
        }
        if connectedItem.reportPropsMapping == nil {
            if let data = defaults.data(forKey: "\(scopedPrefix)reportPropsMapping")
                ?? defaults.data(forKey: "\(prefix)reportPropsMapping"),
               let json = String(data: data, encoding: .utf8) {
                connectedItem.reportPropsMapping = json
            }
        }

        try? context.save()
        refreshStore()
        print("[Migration] ✅ 노션 컨텍스트 마이그레이션 완료 - plannerId:\(pid)")
    }

    private func refreshStore() {
        let descriptor = FetchDescriptor<PlannerItem>(sortBy: [SortDescriptor(\.createdAt)])
        store = (try? context.fetch(descriptor))?.map { $0.toPlanner() } ?? []
    }

    /// store 변경 후 SwiftData 최신 상태 반영 (설정 저장 직후 등)
    func reloadFromStore() {
        refreshStore()
    }

    /// 계정 삭제 후 온보딩 재진입용 — store 비우기·기본 로컬 플래너 1개 생성
    func resetStoreAfterAccountDeletion() {
        selectedPlannerId = ""
        refreshStore()
        guard store.isEmpty else {
            if let first = store.first {
                selectPlanner(first)
            }
            return
        }
        let planner = Planner(name: generateDefaultName())
        context.insert(PlannerItem.from(planner))
        try? context.save()
        refreshStore()
        if let first = store.first {
            selectPlanner(first)
        }
    }

    // 기존 데이터(plannerId가 nil 또는 빈 문자열)를 기본 플래너 ID로 설정
    private func backfillPlannerId(_ defaultId: String) {
        guard !defaultId.isEmpty else { return }
        var changed = false

        if let items = try? context.fetch(FetchDescriptor<TodoItem>()) {
            for item in items where item.plannerId == nil || item.plannerId == "" {
                item.plannerId = defaultId
                changed = true
            }
        }
        if let items = try? context.fetch(FetchDescriptor<DailyReportItem>()) {
            for item in items where item.plannerId == nil || item.plannerId == "" {
                item.plannerId = defaultId
                changed = true
            }
        }
        if let items = try? context.fetch(FetchDescriptor<CategoryItem>()) {
            for item in items where item.plannerId == nil || item.plannerId == "" {
                item.plannerId = defaultId
                changed = true
            }
        }

        if changed { try? context.save() }
    }

    // MARK: - CRUD

    func selectPlanner(_ planner: Planner) {
        selectedPlannerId = planner.id
        UserDefaults.standard.set(planner.id, forKey: "selectedPlannerId")
    }

    func savePlanner(_ planner: Planner) async throws {
        let id = planner.id
        let descriptor = FetchDescriptor<PlannerItem>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: planner)
        } else {
            context.insert(PlannerItem.from(planner))
        }
        try context.save()
        refreshStore()
    }

    func resetNotionConnection(for planner: Planner) async {
        let id = planner.id
        let tokenToRevoke = planner.notionAccessToken
        let wasNotionConnected = planner.isNotionConnected
        let shouldClearGlobalSession = wasNotionConnected
            && countOtherNotionConnectedPlanners(excluding: id) == 0

        await revokePlannerNotionTokenBestEffort(tokenToRevoke)

        let todoDesc = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.plannerId == id })
        for item in (try? context.fetch(todoDesc)) ?? [] { context.delete(item) }

        let reportDesc = FetchDescriptor<DailyReportItem>(predicate: #Predicate { $0.plannerId == id })
        for item in (try? context.fetch(reportDesc)) ?? [] { context.delete(item) }

        let queueDesc = FetchDescriptor<SyncQueueItem>(predicate: #Predicate { $0.plannerId == id })
        for item in (try? context.fetch(queueDesc)) ?? [] { context.delete(item) }

        let plannerDesc = FetchDescriptor<PlannerItem>(predicate: #Predicate { $0.id == id })
        if let item = try? context.fetch(plannerDesc).first {
            item.isNotionConnected  = false
            item.notionAccessToken  = nil
            item.notionTodoDBId     = nil
            item.notionReportDBId   = nil
            item.todoPropsMapping   = nil
            item.reportPropsMapping = nil
        }

        try? context.save()
        refreshStore()

        if shouldClearGlobalSession {
            clearNotionGlobalSession()
        }

        print("[PlannerService] 🔄 연동 초기화 완료 - plannerId:\(id)")
    }

    // MARK: - Pro 해지 다운그레이드

    func downgradeToFree(keepPlannerId: String) {
        guard let items = try? context.fetch(FetchDescriptor<PlannerItem>()) else { return }
        for item in items {
            item.isReadOnly = (item.id != keepPlannerId)
        }
        try? context.save()
        refreshStore()
        if selectedPlannerId != keepPlannerId {
            selectedPlannerId = keepPlannerId
            UserDefaults.standard.set(keepPlannerId, forKey: "selectedPlannerId")
        }
    }

    func restoreAllPlanners() {
        guard let items = try? context.fetch(FetchDescriptor<PlannerItem>()) else { return }
        for item in items {
            item.isReadOnly = false
        }
        try? context.save()
        refreshStore()
    }

    func deletePlanner(_ planner: Planner) async throws {
        guard store.count > 1 else { return }
        let id = planner.id
        let tokenToRevoke = planner.notionAccessToken
        let wasNotionConnected = planner.isNotionConnected
        let shouldClearGlobalSession = wasNotionConnected
            && countOtherNotionConnectedPlanners(excluding: id) == 0

        await revokePlannerNotionTokenBestEffort(tokenToRevoke)

        let todoDesc = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.plannerId == id })
        for item in (try? context.fetch(todoDesc)) ?? [] { context.delete(item) }

        let reportDesc = FetchDescriptor<DailyReportItem>(predicate: #Predicate { $0.plannerId == id })
        for item in (try? context.fetch(reportDesc)) ?? [] { context.delete(item) }

        let categoryDesc = FetchDescriptor<CategoryItem>(predicate: #Predicate { $0.plannerId == id })
        for item in (try? context.fetch(categoryDesc)) ?? [] { context.delete(item) }

        let queueDesc = FetchDescriptor<SyncQueueItem>(predicate: #Predicate { $0.plannerId == id })
        for item in (try? context.fetch(queueDesc)) ?? [] { context.delete(item) }

        let plannerDesc = FetchDescriptor<PlannerItem>(predicate: #Predicate { $0.id == id })
        guard let plannerItem = try context.fetch(plannerDesc).first else { return }
        context.delete(plannerItem)

        try context.save()
        refreshStore()
        if selectedPlannerId == planner.id {
            selectedPlannerId = store.first?.id ?? ""
        }

        if shouldClearGlobalSession {
            clearNotionGlobalSession()
        }
    }

    // MARK: - Notion 세션 정리

    private func countOtherNotionConnectedPlanners(excluding plannerId: String) -> Int {
        store.filter { $0.id != plannerId && $0.isNotionConnected }.count
    }

    private func revokePlannerNotionTokenBestEffort(_ token: String?) async {
        guard let token, !token.isEmpty else { return }
        do {
            try await APIClient.shared.revokeNotionToken(token)
        } catch {
            AppLogger.shared.error(
                "PlannerService",
                "Notion 토큰 revoke 실패 (계속 진행): \(error.localizedDescription)"
            )
        }
    }

    @MainActor
    private func clearNotionGlobalSession() {
        NotionAuthManager.shared.signOut()
    }
}
