import Foundation

// MARK: - ViewModel
// 온보딩(OnboardingViewModel)과 독립적으로 동작합니다.
// API 호출 코드가 일부 중복되어 있으며, 온보딩 로직 변경 시 이 파일도 함께 확인하세요.

@Observable
final class PlannerNotionSettingsViewModel {

    private(set) var isLoading: Bool = false
    private(set) var isLoadingDatabases: Bool = false
    private(set) var alertMessage: String?

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

    private let planner: Planner
    private let backendBase = "https://todoreport-backend.vercel.app"
    @ObservationIgnored private var databasesFetchTask: Task<Void, Never>?

    init(planner: Planner) {
        self.planner = planner
        selectedTodoDBId   = planner.notionTodoDBId
        selectedReportDBId = planner.notionReportDBId
        loadPlannerMappings(plannerId: planner.id)
    }

    // MARK: - 플래너별 매핑 불러오기

    private func loadPlannerMappings(plannerId: String) {
        let todo = planner.decodedTodoPropsMapping
        todoPropsMapping = todo
        if todo.memo != nil || todo.memoPropId != nil           { memoMode = .existing }
        if todo.isPinned != nil || todo.isPinnedPropId != nil   { isPinnedMode = .existing }
        if todo.reportRelation != nil || todo.reportRelationPropId != nil { reportRelationMode = .existing }
        if todo.category != nil || todo.categoryPropId != nil { categoryMode = .existing }

        let report = planner.decodedReportPropsMapping
        reportPropsMapping = report
        if report.review != nil { reviewMode = .existing }
        if report.rating != nil { ratingMode = .existing }
    }

    // MARK: - DB 목록

    func fetchDatabases() async {
        if let existing = databasesFetchTask {
            await existing.value
            return
        }
        let task = Task { @MainActor in
            defer { databasesFetchTask = nil }
            isLoadingDatabases = true
            defer { isLoadingDatabases = false }

            guard let token = planner.resolvedNotionToken else {
                alertMessage = "노션 인증 정보가 없어요. 다시 로그인해주세요."
                return
            }
            let outcome = await NotionDatabasesFetcher.fetch(
                token: token,
                mergeWith: databases,
                retryIfEmpty: databases.isEmpty
            )
            switch outcome {
            case .success(let list):
                databases = list
            case .failure(let message):
                alertMessage = message
            }
        }
        databasesFetchTask = task
        await task.value
    }

    // MARK: - 투두 속성

    func selectTodoDB(_ id: String) {
        selectedTodoDBId = id
        Task { await fetchTodoProperties(policy: .initialSetup) }
    }

    func fetchTodoProperties(policy: TodoPropsMappingPolicy = .preserveUser) async {
        guard let dbId = selectedTodoDBId else { return }
        isLoading = true
        defer { isLoading = false }

        guard let token = planner.resolvedNotionToken,
              let url = URL(string: "\(backendBase)/api/notion/databases/\(dbId)/properties") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(PropertiesResponse.self, from: data)
            todoProperties = decoded.properties.map {
                NotionProperty(id: $0.id, name: $0.name, type: $0.type, options: $0.options)
            }
            TodoPropsMappingAutoFill.apply(
                mapping: &todoPropsMapping,
                properties: todoProperties,
                policy: policy
            )
            TodoPropsMappingAutoFill.backfillIds(mapping: &todoPropsMapping, properties: todoProperties)
            TodoPropsMappingAutoFill.syncOptionalModes(
                mapping: todoPropsMapping,
                memoMode: &memoMode,
                isPinnedMode: &isPinnedMode,
                reportRelationMode: &reportRelationMode,
                categoryMode: &categoryMode
            )
        } catch {
            alertMessage = "투두 속성을 불러오지 못했어요"
        }
    }

    // MARK: - 리포트 속성

    func selectReportDB(_ id: String) {
        selectedReportDBId = id
        Task { await fetchReportProperties(autoMap: true) }
    }

    func fetchReportProperties(autoMap: Bool = false) async {
        guard let dbId = selectedReportDBId else { return }
        isLoading = true
        defer { isLoading = false }

        guard let token = planner.resolvedNotionToken,
              let url = URL(string: "\(backendBase)/api/notion/databases/\(dbId)/properties") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(PropertiesResponse.self, from: data)
            reportProperties = decoded.properties.map {
                NotionProperty(id: $0.id, name: $0.name, type: $0.type, options: $0.options)
            }
            if autoMap {
                autoMapReportProps()
            } else {
                ReportPropsMappingAutoFill.syncFromProperties(
                    mapping: &reportPropsMapping,
                    properties: reportProperties
                )
                if reportPropsMapping.review != nil { reviewMode = .existing }
                if reportPropsMapping.rating != nil { ratingMode = .existing }
            }
        } catch {
            alertMessage = "리포트 속성을 불러오지 못했어요"
        }
    }

    private func autoMapReportProps() {
        ReportPropsMappingAutoFill.applyInitialSetup(
            mapping: &reportPropsMapping,
            properties: reportProperties,
            reviewMode: &reviewMode,
            ratingMode: &ratingMode
        )
    }

    func selectRating(_ name: String?) {
        ReportPropsMappingAutoFill.applyRatingSelection(
            mapping: &reportPropsMapping,
            name: name,
            properties: reportProperties,
            ratingMode: &ratingMode
        )
    }

    // MARK: - 속성 생성

    func createMemoProperty() async {
        isLoading = true
        defer { isLoading = false }
        guard let dbId = selectedTodoDBId,
              let name = await addNotionProperty(dbId: dbId, name: "메모", type: "rich_text") else { return }
        todoPropsMapping.memo = name
        memoMode = .existing
        await fetchTodoProperties(policy: .preserveUser)
    }

    func createPinnedProperty() async {
        isLoading = true
        defer { isLoading = false }
        guard let dbId = selectedTodoDBId,
              let name = await addNotionProperty(dbId: dbId, name: "상단고정", type: "checkbox") else { return }
        todoPropsMapping.isPinned = name
        isPinnedMode = .existing
        await fetchTodoProperties(policy: .preserveUser)
    }

    func createCategoryProperty() async {
        isLoading = true
        defer { isLoading = false }
        guard let dbId = selectedTodoDBId,
              let name = await addNotionProperty(dbId: dbId, name: "카테고리", type: "select", options: []) else { return }
        todoPropsMapping.category = name
        todoPropsMapping.categoryPropType = "select"
        categoryMode = .existing
        await fetchTodoProperties(policy: .preserveUser)
    }

    func selectCategory(_ name: String?) {
        TodoPropsMappingAutoFill.applyCategorySelection(
            mapping: &todoPropsMapping,
            name: name,
            properties: todoProperties,
            categoryMode: &categoryMode
        )
    }

    func selectCompletedProperty(id: String?, name: String?) {
        TodoPropsMappingAutoFill.applyCompletedSelection(
            mapping: &todoPropsMapping,
            propertyId: id,
            name: name,
            properties: todoProperties
        )
    }

    func selectIsPinnedProperty(id: String?, name: String?) {
        TodoPropsMappingAutoFill.applyIsPinnedSelection(
            mapping: &todoPropsMapping,
            propertyId: id,
            name: name,
            properties: todoProperties,
            isPinnedMode: &isPinnedMode
        )
    }

    func createRatingProperty() async {
        isLoading = true
        defer { isLoading = false }
        let options = DayRating.allCases.map { $0.rawValue }
        guard let dbId = selectedReportDBId,
              let name = await addNotionProperty(dbId: dbId, name: "별점", type: "select", options: options) else { return }
        reportPropsMapping.dayRatingOptions = options
        reportPropsMapping.ratingPropType = "select"
        reportPropsMapping.rating = name
        ratingMode = .existing
        await fetchReportProperties(autoMap: false)
        selectRating(name)
    }

    private func addNotionProperty(
        dbId: String, name: String, type: String, options: [String] = [], format: String? = nil
    ) async -> String? {
        guard let token = planner.resolvedNotionToken,
              let url = URL(string: "\(backendBase)/api/notion/databases/\(dbId)/add-property") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["propertyName": name, "type": type]
        if type == "select" || !options.isEmpty { body["options"] = options }
        if let format { body["format"] = format }
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

    // MARK: - 저장

    func save() async {
        TodoPropsMappingAutoFill.backfillIds(mapping: &todoPropsMapping, properties: todoProperties)
        ReportPropsMappingAutoFill.backfillIds(mapping: &reportPropsMapping, properties: reportProperties)
        let previousCategoryProp = planner.decodedTodoPropsMapping.category
        var updated = PlannerService.shared.store.first(where: { $0.id == planner.id }) ?? planner
        updated.notionTodoDBId   = selectedTodoDBId
        updated.notionReportDBId = selectedReportDBId
        if selectedTodoDBId != nil, updated.resolvedNotionToken != nil {
            updated.isNotionConnected = true
        }
        if let data = try? JSONEncoder().encode(todoPropsMapping),
           let json = String(data: data, encoding: .utf8) {
            updated.todoPropsMapping = json
        }
        if let data = try? JSONEncoder().encode(reportPropsMapping),
           let json = String(data: data, encoding: .utf8) {
            updated.reportPropsMapping = json
        }
        try? await PlannerService.shared.savePlanner(updated)
        CategoryNotionSync.shared.onCategoryMappingEnabled(
            plannerId: planner.id,
            previousCategoryProp: previousCategoryProp,
            newCategoryProp: todoPropsMapping.category
        )
    }

    func clearAlert() {
        alertMessage = nil
    }
}

// MARK: - Decodable Helpers (온보딩과 동일 구조, B안 독립 복사본)

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
