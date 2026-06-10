import Foundation

@Observable
final class PlannerAddViewModel {

    enum Step: Equatable {
        case chooseMode
        case notionOAuth        // OAuth 진행 중 (Notion 카드에 로딩 표시)
        case selectTodoDB
        case mapTodoProps
        case selectReportDB
        case mapReportProps
    }

    private(set) var step: Step = .chooseMode
    private(set) var isLoading: Bool = false
    private(set) var isLoadingDatabases: Bool = false
    var alertMessage: String?

    var plannerName: String = ""
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

    private(set) var capturedAccessToken: String?
    private(set) var createdLocalPlanner: Planner?

    @ObservationIgnored private var databasesFetchTask: Task<Void, Never>?

    private let backendBase = "https://todoreport-backend.vercel.app"

    // MARK: - 로컬 모드

    func selectLocalMode() async {
        let trimmed = plannerName.trimmingCharacters(in: .whitespaces)
        let name = trimmed.isEmpty ? defaultPlannerName() : trimmed
        let planner = Planner(name: name)
        try? await PlannerService.shared.savePlanner(planner)
        PlannerService.shared.selectPlanner(planner)
        createdLocalPlanner = planner
    }

    var showNotionWorkspaceInfo: Bool {
        PlannerService.shared.store.contains(where: { $0.isNotionConnected })
    }

    // MARK: - 노션 모드

    func selectNotionMode() {
        databases = []
        capturedAccessToken = nil
        step = .notionOAuth
        isLoading = true
        NotionAuthManager.shared.secondaryOAuthCompletion = { [weak self] token in
            guard let self else { return }
            self.capturedAccessToken = token
            self.isLoading = false
            Task { await self.fetchDatabases() }
        }
        NotionAuthManager.shared.startOAuth()
    }

    // MARK: - DB / 속성 선택

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

    func proceedFromMapReportProps() async {
        await savePlanner()
    }

    func skipReportDB() async {
        selectedReportDBId = nil
        reportPropsMapping = ReportPropsMapping()
        await savePlanner()
    }

    // MARK: - 저장

    private func savePlanner() async {
        let trimmed = plannerName.trimmingCharacters(in: .whitespaces)
        var planner = Planner(name: trimmed.isEmpty ? defaultPlannerName() : trimmed)
        planner.isNotionConnected = true
        planner.notionTodoDBId    = selectedTodoDBId
        planner.notionReportDBId  = selectedReportDBId
        planner.notionAccessToken = capturedAccessToken
        if let data = try? JSONEncoder().encode(todoPropsMapping),
           let json = String(data: data, encoding: .utf8) {
            planner.todoPropsMapping = json
        }
        if let data = try? JSONEncoder().encode(reportPropsMapping),
           let json = String(data: data, encoding: .utf8) {
            planner.reportPropsMapping = json
        }
        try? await PlannerService.shared.savePlanner(planner)
        PlannerService.shared.selectPlanner(planner)
        CategoryNotionSync.shared.onCategoryMappingEnabled(
            plannerId: planner.id,
            previousCategoryProp: nil,
            newCategoryProp: todoPropsMapping.category
        )
    }

    // MARK: - 뒤로가기

    func goBack() {
        switch step {
        case .notionOAuth:
            NotionAuthManager.shared.secondaryOAuthCompletion = nil
            isLoading = false
            step = .chooseMode
        case .selectTodoDB:
            databases = []
            capturedAccessToken = nil
            step = .chooseMode
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

    // MARK: - 디폴트 이름

    private func defaultPlannerName() -> String {
        PlannerService.shared.generateDefaultName()
    }

    // MARK: - API

    func fetchDatabases() async {
        if let existing = databasesFetchTask {
            await existing.value
            return
        }
        let task = Task { @MainActor in
            defer { databasesFetchTask = nil }
            isLoadingDatabases = true
            defer { isLoadingDatabases = false }

            let outcome = await NotionDatabasesFetcher.fetch(
                token: capturedAccessToken ?? "",
                mergeWith: databases,
                retryIfEmpty: databases.isEmpty
            )
            switch outcome {
            case .success(let list):
                databases = list
                if step == .notionOAuth { step = .selectTodoDB }
            case .failure(let message):
                alertMessage = message
            }
        }
        databasesFetchTask = task
        await task.value
    }

    func fetchTodoProperties() async {
        guard let dbId = selectedTodoDBId else { return }
        isLoading = true
        defer { isLoading = false }
        let token = capturedAccessToken ?? ""
        guard let url = URL(string: "\(backendBase)/api/notion/databases/\(dbId)/properties") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(PropertiesResponse.self, from: data)
            todoProperties = decoded.properties.map { NotionProperty(id: $0.id, name: $0.name, type: $0.type, options: $0.options) }
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
        guard let url = URL(string: "\(backendBase)/api/notion/databases/\(dbId)/properties") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(PropertiesResponse.self, from: data)
            reportProperties = decoded.properties.map { NotionProperty(id: $0.id, name: $0.name, type: $0.type, options: $0.options) }
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
        guard let url = URL(string: "\(backendBase)/api/notion/databases/\(dbId)/add-property") else { return nil }
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
