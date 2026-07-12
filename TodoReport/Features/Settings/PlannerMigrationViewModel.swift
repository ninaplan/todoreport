import Foundation
import SwiftData

@Observable
final class PlannerMigrationViewModel {

    enum Step: Equatable {
        case idle
        case oauthRequired
        case selectTodoDB
        case mapTodoProps
        case selectReportDB
        case mapReportProps
        case running
        case completed
        case failed(String)
    }

    enum SyncMode {
        case uploadToNotion
        case importFromNotion
    }

    // MARK: - OAuth / DB / 속성 상태

    private(set) var step: Step = .idle
    private(set) var isLoading: Bool = false
    private(set) var isLoadingDatabases: Bool = false
    var alertMessage: String?

    private(set) var capturedAccessToken: String?
    private(set) var capturedRefreshToken: String?
    private(set) var capturedWorkspaceId: String?
    private(set) var capturedWorkspaceName: String?
    private(set) var capturedBotId: String?
    private(set) var databases: [NotionDatabase] = []
    var selectedTodoDBId: String?
    var selectedReportDBId: String?
    private(set) var todoProperties: [NotionProperty] = []
    private(set) var reportProperties: [NotionProperty] = []
    var todoPropsMapping = TodoPropsMapping()
    var reportPropsMapping = ReportPropsMapping()

    var memoMode: PropMappingMode = .appOnly
    var isPinnedMode: PropMappingMode = .appOnly
    var reportRelationMode: PropMappingMode = .appOnly
    var categoryMode: PropMappingMode = .appOnly
    var reviewMode: PropMappingMode = .appOnly
    var ratingMode: PropMappingMode = .appOnly

    var canProceedFromTodoProps: Bool {
        todoPropsMapping.completed != nil && todoPropsMapping.date != nil
    }
    var canProceedFromReportProps: Bool {
        reportPropsMapping.date != nil
    }

    // MARK: - 마이그레이션 진행 상태

    private(set) var totalCount: Int = 0
    private(set) var completedCount: Int = 0
    private(set) var completionMessage: String = ""
    private(set) var mode: SyncMode

    var progress: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }

    private let planner: Planner
    private var context: ModelContext { PersistenceController.shared.context }
    private let reportService = DailyReportService()
    private let todoService = TodoService.shared
    @ObservationIgnored private var databasesFetchTask: Task<Void, Never>?
    private var migrationTask: Task<Void, Never>?

    init(planner: Planner, mode: SyncMode) {
        self.planner = planner
        self.mode = mode
    }

    var showNotionWorkspaceInfo: Bool {
        PlannerService.shared.store.contains(where: { $0.isNotionConnected && $0.id != planner.id })
    }

    // MARK: - 연결 시작 (OAuth)

    func startConnection() {
        guard step == .idle else { return }
        step = .oauthRequired
        isLoading = true
        NotionAuthManager.shared.secondaryOAuthCompletion = { [weak self] token, refreshToken, workspaceId, workspaceName, botId in
            guard let self else { return }
            self.capturedAccessToken = token
            self.capturedRefreshToken = refreshToken
            self.capturedWorkspaceId = workspaceId
            self.capturedWorkspaceName = workspaceName
            self.capturedBotId = botId
            self.isLoading = false
            Task { await self.fetchDatabases() }
        }
        NotionAuthManager.shared.startOAuth()
    }

    // MARK: - DB 선택

    func selectTodoDB(_ id: String) {
        selectedTodoDBId = id
        Task { await fetchTodoProperties() }
    }

    func proceedFromMapTodoProps() {
        step = .selectReportDB
    }

    func selectReportDB(_ id: String) {
        selectedReportDBId = id
        Task { await fetchReportProperties() }
    }

    func skipReportDB() async {
        selectedReportDBId = nil
        reportPropsMapping = ReportPropsMapping()
        await saveConnectionSettings()
        beginMigrationIfReady()
    }

    func proceedFromMapReportProps() async {
        await saveConnectionSettings()
        beginMigrationIfReady()
    }

    // MARK: - 마이그레이션 제어

    private func startMigration() {
        step = .running
        completedCount = 0
        migrationTask = Task {
            await CategoryNotionSync.shared.syncCategoriesByName(plannerId: planner.id)
            switch mode {
            case .uploadToNotion:   await uploadToNotion()
            case .importFromNotion: await importFromNotion()
            }
        }
    }

    func cancelMigration() {
        migrationTask?.cancel()
        migrationTask = nil
        step = .idle
    }

    func retryMigration() {
        startMigration()
    }

    // MARK: - 뒤로가기

    func goBack() {
        switch step {
        case .oauthRequired:
            NotionAuthManager.shared.secondaryOAuthCompletion = nil
            isLoading = false
            step = .idle
        case .selectTodoDB:
            databases = []
            capturedAccessToken = nil
            capturedRefreshToken = nil
            capturedWorkspaceId = nil
            capturedWorkspaceName = nil
            capturedBotId = nil
            step = .idle
        case .mapTodoProps:
            selectedTodoDBId = nil
            step = .selectTodoDB
        case .selectReportDB:
            step = .mapTodoProps
        case .mapReportProps:
            selectedReportDBId = nil
            step = .selectReportDB
        default: break
        }
    }

    // MARK: - 연결 설정 저장

    private func saveConnectionSettings() async {
        let previousCategoryProp = planner.decodedTodoPropsMapping.category
        var updated = planner
        if let token = capturedAccessToken,
           let workspaceId = capturedWorkspaceId,
           let workspaceName = capturedWorkspaceName,
           let connectionId = try? PlannerService.shared.upsertNotionWorkspaceConnection(
            workspaceId: workspaceId,
            workspaceName: workspaceName,
            accessToken: token,
            refreshToken: capturedRefreshToken,
            botId: capturedBotId
           ) {
            updated.notionWorkspaceConnectionId = connectionId
            updated.notionAccessToken = nil
            updated.notionRefreshToken = nil
        } else {
            updated.notionWorkspaceConnectionId = nil
            updated.notionAccessToken = capturedAccessToken
            updated.notionRefreshToken = capturedRefreshToken
        }
        updated.notionTodoDBId    = selectedTodoDBId
        updated.notionReportDBId  = selectedReportDBId
        updated.isNotionConnected = true
        if let data = try? JSONEncoder().encode(todoPropsMapping),
           let json = String(data: data, encoding: .utf8) {
            updated.todoPropsMapping = json
        }
        if let data = try? JSONEncoder().encode(reportPropsMapping),
           let json = String(data: data, encoding: .utf8) {
            updated.reportPropsMapping = json
        }
        try? await PlannerService.shared.savePlanner(updated)
        PlannerService.shared.selectPlanner(updated)
        CategoryNotionSync.shared.onCategoryMappingEnabled(
            plannerId: updated.id,
            previousCategoryProp: previousCategoryProp,
            newCategoryProp: todoPropsMapping.category
        )
    }

    private func beginMigrationIfReady() {
        startMigration()
    }

    // MARK: - API

    func fetchDatabases(forceRefresh: Bool = false) async {
        if await NotionDatabasesFetchTaskRunner.prepareForFetch(
            existingTask: databasesFetchTask,
            forceRefresh: forceRefresh
        ) == .skip {
            return
        }
        let task = Task { @MainActor in
            defer { databasesFetchTask = nil }
            isLoadingDatabases = true
            defer { isLoadingDatabases = false }

            guard !Task.isCancelled else { return }

            let outcome = await NotionDatabasesFetcher.fetch(
                token: capturedAccessToken ?? "",
                mergeWith: databases,
                retryIfEmpty: databases.isEmpty
            )
            guard !Task.isCancelled else { return }

            switch outcome {
            case .success(let list):
                databases = list
                if step == .oauthRequired { step = .selectTodoDB }
            case .failure(let message):
                alertMessage = message
            }
        }
        databasesFetchTask = task
        await task.value
    }

    func refreshDatabases() async {
        await fetchDatabases(forceRefresh: true)
    }

    func fetchTodoProperties() async {
        guard let dbId = selectedTodoDBId else { return }
        isLoading = true
        defer { isLoading = false }
        let token = capturedAccessToken ?? ""
        guard let url = URL(string: "\(BackendBaseURL.resolved)/api/notion/databases/\(dbId)/properties") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(PropertiesResponse.self, from: data)
            todoProperties = decoded.properties.map {
                NotionProperty(id: $0.id, name: $0.name, type: $0.type, options: $0.options)
            }
            autoMapTodoProps()
            step = .mapTodoProps
        } catch {
            alertMessage = "속성을 불러오지 못했어요"
        }
    }

    func fetchReportProperties() async {
        guard let dbId = selectedReportDBId else { return }
        isLoading = true
        defer { isLoading = false }
        let token = capturedAccessToken ?? ""
        guard let url = URL(string: "\(BackendBaseURL.resolved)/api/notion/databases/\(dbId)/properties") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(PropertiesResponse.self, from: data)
            reportProperties = decoded.properties.map {
                NotionProperty(id: $0.id, name: $0.name, type: $0.type, options: $0.options)
            }
            autoMapReportProps()
            step = .mapReportProps
        } catch {
            alertMessage = "속성을 불러오지 못했어요"
        }
    }

    func createMemoProperty() async {
        let token = capturedAccessToken ?? ""
        guard let dbId = selectedTodoDBId,
              let name = await addNotionProperty(dbId: dbId, name: "메모", type: "rich_text", token: token) else { return }
        todoPropsMapping.memo = name
        memoMode = .existing
    }

    func createPinnedProperty() async {
        let token = capturedAccessToken ?? ""
        guard let dbId = selectedTodoDBId,
              let name = await addNotionProperty(dbId: dbId, name: "상단고정", type: "checkbox", token: token) else { return }
        todoPropsMapping.isPinned = name
        isPinnedMode = .existing
    }

    func createCategoryProperty() async {
        let token = capturedAccessToken ?? ""
        guard let dbId = selectedTodoDBId,
              let name = await addNotionProperty(dbId: dbId, name: "카테고리", type: "select", options: [], token: token) else { return }
        todoPropsMapping.category = name
        todoPropsMapping.categoryPropType = "select"
        categoryMode = .existing
    }

    func selectCategory(_ name: String?) {
        todoPropsMapping.category = name
        if let name,
           let prop = todoProperties.first(where: { $0.name == name && CategoryNotionProperty.supportedTypes.contains($0.type) }) {
            todoPropsMapping.categoryPropType = prop.type
            categoryMode = .existing
        } else {
            todoPropsMapping.categoryPropType = nil
            categoryMode = .appOnly
        }
    }

    func createRatingProperty() async {
        let token = capturedAccessToken ?? ""
        let options = DayRating.allCases.map { $0.rawValue }
        guard let dbId = selectedReportDBId,
              let name = await addNotionProperty(dbId: dbId, name: "별점", type: "select", options: options, token: token) else { return }
        reportPropsMapping.dayRatingOptions = options
        reportPropsMapping.ratingPropType = "select"
        reportPropsMapping.rating = name
        ratingMode = .existing
    }

    private func addNotionProperty(dbId: String, name: String, type: String, options: [String] = [], token: String) async -> String? {
        guard let url = URL(string: "\(BackendBaseURL.resolved)/api/notion/databases/\(dbId)/add-property") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["propertyName": name, "type": type]
        if type == "select" || !options.isEmpty { body["options"] = options }
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = bodyData
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Response: Decodable { let propertyName: String }
            return try JSONDecoder().decode(Response.self, from: data).propertyName
        } catch {
            alertMessage = "\(name) 속성 생성에 실패했어요"
            return nil
        }
    }

    // MARK: - Auto Mapping

    private func autoMapTodoProps() {
        TodoPropsMappingAutoFill.apply(
            mapping: &todoPropsMapping,
            properties: todoProperties,
            policy: .initialSetup
        )
        TodoPropsMappingAutoFill.syncOptionalModes(
            mapping: todoPropsMapping,
            memoMode: &memoMode,
            isPinnedMode: &isPinnedMode,
            reportRelationMode: &reportRelationMode,
            categoryMode: &categoryMode
        )
    }

    private func autoMapReportProps() {
        func best(type: String, default name: String) -> NotionProperty? {
            let typed = reportProperties.filter { $0.type == type }
            return typed.first(where: { $0.name == name }) ?? typed.first
        }
        reportPropsMapping.date = best(type: "date", default: "날짜")?.name
        if let p = best(type: "rich_text", default: "하루 리뷰") { reportPropsMapping.review = p.name; reviewMode = .existing }
        if let p = best(type: "select", default: "별점") ?? best(type: "status", default: "별점") { selectRating(p.name) }
    }

    func selectRating(_ name: String?) {
        reportPropsMapping.rating = name
        if let name, let prop = reportProperties.first(where: { $0.name == name }) {
            reportPropsMapping.dayRatingOptions = prop.options ?? []
            reportPropsMapping.ratingPropType = prop.type
            ratingMode = .existing
        } else {
            reportPropsMapping.dayRatingOptions = []
            reportPropsMapping.ratingPropType = nil
            ratingMode = .appOnly
        }
    }

    // MARK: - 노션 연결 검증

    private func verifyNotionConnection() async -> Bool {
        let token = capturedAccessToken ?? ""
        guard let url = URL(string: "\(BackendBaseURL.resolved)/api/notion/databases") else { return false }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - 앱 → Notion 업로드

    private func uploadToNotion() async {
        let plannerId = planner.id
        let allTodos   = (try? context.fetch(FetchDescriptor<TodoItem>()))   ?? []
        let allReports = (try? context.fetch(FetchDescriptor<DailyReportItem>())) ?? []

        let todoItems   = allTodos.filter   { $0.plannerId == plannerId || $0.plannerId == nil }
        let reportItems = allReports.filter { ($0.plannerId == plannerId || $0.plannerId == nil) && $0.endDate == nil }

        await MainActor.run { totalCount = todoItems.count + reportItems.count }

        if totalCount == 0 {
            guard !Task.isCancelled else { return }
            await MainActor.run { completionMessage = "업로드할 데이터가 없어요"; step = .completed }
            return
        }

        // Todo: SyncQueue enqueue — 네트워크 없어도 항상 로컬 저장 후 자동 재시도
        var backfillChanged = false
        for item in todoItems {
            guard !Task.isCancelled else { return }
            if item.plannerId == nil || item.plannerId == "" {
                item.plannerId = plannerId
                backfillChanged = true
            }
            let todo = item.toTodo()
            await MainActor.run {
                SyncQueueManager.shared.enqueueTodoCreate(todo)
                completedCount += 1
            }
        }
        if backfillChanged { try? context.save() }

        // Report: 직접 API 호출 — 실패 감지
        var reportFailCount = 0
        for item in reportItems {
            guard !Task.isCancelled else { return }
            let report = item.toReport()
            do { try await reportService.saveReport(report) }
            catch { reportFailCount += 1 }
            await MainActor.run { completedCount += 1 }
        }

        guard !Task.isCancelled else { return }

        if !reportItems.isEmpty && reportFailCount == reportItems.count {
            await MainActor.run {
                step = .failed("리포트 업로드에 실패했어요.\n인터넷 연결을 확인해주세요.\n투두는 연결 후 자동으로 업로드됩니다.")
            }
            return
        }
        await MainActor.run { completionMessage = "모든 데이터가 Notion에 업로드됐어요"; step = .completed }
    }

    // MARK: - Notion → 앱 가져오기

    private func importFromNotion() async {
        // 1. 로컬 삭제 전에 먼저 노션 연결 검증 — 실패 시 로컬 데이터 보존
        guard await verifyNotionConnection() else {
            await MainActor.run { step = .failed("노션에 연결할 수 없어요.\n인터넷 연결을 확인해주세요.") }
            return
        }

        guard !Task.isCancelled else { return }

        // 2. 검증 통과 후 로컬 데이터 삭제 (투두·리포트·카테고리)
        let plannerId = planner.id
        let allTodos      = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        let allReports    = (try? context.fetch(FetchDescriptor<DailyReportItem>())) ?? []
        let allCategories = (try? context.fetch(FetchDescriptor<CategoryItem>())) ?? []
        allTodos.filter { $0.plannerId == plannerId || $0.plannerId == nil }
            .forEach { context.delete($0) }
        allReports.filter { ($0.plannerId == plannerId || $0.plannerId == nil) && $0.endDate == nil }
            .forEach { context.delete($0) }
        allCategories.filter { $0.plannerId == plannerId || $0.plannerId == nil }
            .forEach { context.delete($0) }
        try? context.save()
        await CategoryService.shared.refresh()

        // 3. 날짜 범위 계산 (최근 7일)
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -7, to: .now) else {
            await MainActor.run { step = .failed("날짜 범위 계산 실패") }
            return
        }
        let today = calendar.startOfDay(for: .now)

        var days: [Date] = []
        var current = calendar.startOfDay(for: start)
        while current <= today {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        await MainActor.run { totalCount = days.count }

        // 4. fetch 루프 — syncTodosFromNotion/syncReportFromNotion이 non-throwing이므로
        //    매 iteration 전 연결 상태를 직접 확인해 루프 중 네트워크 끊김 감지
        for (i, day) in days.enumerated() {
            guard !Task.isCancelled else { return }
            guard await verifyNotionConnection() else {
                await MainActor.run {
                    step = .failed("노션 연결이 끊겼어요.\n인터넷 연결 후 다시 시도해주세요.")
                }
                return
            }
            await todoService.syncTodosFromNotion(for: day)
            await reportService.syncReportFromNotion(for: day)
            await MainActor.run { completedCount = i + 1 }
        }

        guard !Task.isCancelled else { return }
        await MainActor.run { completionMessage = "Notion 데이터를 앱으로 가져왔어요"; step = .completed }
    }
}

// MARK: - Decodable Helpers

private struct DatabasesResponse: Decodable {
    let databases: [DBItem]
    struct DBItem: Decodable {
        let id: String
        let title: String
        let icon: IconItem?
        struct IconItem: Decodable {
            let type: String
            let emoji: String?
        }
    }
}

private struct PropertiesResponse: Decodable {
    let properties: [PropItem]
    struct PropItem: Decodable {
        let id: String
        let name: String
        let type: String
        let options: [String]?
    }
}
