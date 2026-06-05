import Foundation

// MARK: - ViewModel
// 온보딩(OnboardingViewModel)과 독립적으로 동작합니다.
// API 호출 코드가 일부 중복되어 있으며, 온보딩 로직 변경 시 이 파일도 함께 확인하세요.

@Observable
final class PlannerNotionSettingsViewModel {

    private(set) var isLoading: Bool = false
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
    var reviewMode: PropMappingMode = .appOnly
    var ratingMode: PropMappingMode = .appOnly

    private let planner: Planner
    private let backendBase = "https://todoreport-backend.vercel.app"

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
        if todo.memo != nil           { memoMode = .existing }
        if todo.isPinned != nil       { isPinnedMode = .existing }
        if todo.reportRelation != nil { reportRelationMode = .existing }

        let report = planner.decodedReportPropsMapping
        reportPropsMapping = report
        if report.review != nil { reviewMode = .existing }
        if report.rating != nil { ratingMode = .existing }
    }

    // MARK: - DB 목록

    func fetchDatabases() async {
        isLoading = true
        defer { isLoading = false }

        guard let token = planner.resolvedNotionToken,
              let url = URL(string: "\(backendBase)/api/notion/databases") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(DatabasesResponse.self, from: data)
            databases = decoded.databases.map {
                NotionDatabase(id: $0.id, title: $0.title, icon: $0.icon?.emoji)
            }
        } catch {
            alertMessage = "DB 목록을 불러오지 못했어요"
        }
    }

    // MARK: - 투두 속성

    func selectTodoDB(_ id: String) {
        selectedTodoDBId = id
        Task { await fetchTodoProperties() }
    }

    func fetchTodoProperties() async {
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
            autoMapTodoProps()
        } catch {
            alertMessage = "투두 속성을 불러오지 못했어요"
        }
    }

    private func autoMapTodoProps() {
        func best(type: String, default name: String) -> String? {
            let typed = todoProperties.filter { $0.type == type }
            return typed.first(where: { $0.name == name })?.name ?? typed.first?.name
        }
        todoPropsMapping.completed      = best(type: "checkbox",  default: "완료")
        todoPropsMapping.date           = best(type: "date",      default: "날짜")
        todoPropsMapping.memo           = best(type: "rich_text", default: "메모")
        todoPropsMapping.isPinned       = best(type: "checkbox",  default: "중요")
        todoPropsMapping.reportRelation = best(type: "relation",  default: "데일리 리포트")

        memoMode           = todoPropsMapping.memo != nil ? .existing : .appOnly
        isPinnedMode       = todoPropsMapping.isPinned != nil ? .existing : .appOnly
        reportRelationMode = todoPropsMapping.reportRelation != nil ? .existing : .appOnly
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
            if autoMap { autoMapReportProps() }
        } catch {
            alertMessage = "리포트 속성을 불러오지 못했어요"
        }
    }

    private func autoMapReportProps() {
        func best(type: String, default name: String) -> NotionProperty? {
            let typed = reportProperties.filter { $0.type == type }
            return typed.first(where: { $0.name == name }) ?? typed.first
        }
        reportPropsMapping.date = best(type: "date", default: "날짜")?.name
        if let reviewProp = best(type: "rich_text", default: "하루 리뷰") {
            reportPropsMapping.review = reviewProp.name
            reviewMode = .existing
        }
        if let ratingProp = best(type: "select", default: "별점") ?? best(type: "status", default: "별점") {
            selectRating(ratingProp.name)
        }
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

    // MARK: - 속성 생성

    func createMemoProperty() async {
        isLoading = true
        defer { isLoading = false }
        guard let dbId = selectedTodoDBId,
              let name = await addNotionProperty(dbId: dbId, name: "메모", type: "rich_text") else { return }
        todoPropsMapping.memo = name
        memoMode = .existing
    }

    func createPinnedProperty() async {
        isLoading = true
        defer { isLoading = false }
        guard let dbId = selectedTodoDBId,
              let name = await addNotionProperty(dbId: dbId, name: "상단고정", type: "checkbox") else { return }
        todoPropsMapping.isPinned = name
        isPinnedMode = .existing
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
        if !options.isEmpty { body["options"] = options }
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

    func save() {
        var updated = planner
        updated.notionTodoDBId   = selectedTodoDBId
        updated.notionReportDBId = selectedReportDBId
        if let data = try? JSONEncoder().encode(todoPropsMapping),
           let json = String(data: data, encoding: .utf8) {
            updated.todoPropsMapping = json
        }
        if let data = try? JSONEncoder().encode(reportPropsMapping),
           let json = String(data: data, encoding: .utf8) {
            updated.reportPropsMapping = json
        }
        Task { try? await PlannerService.shared.savePlanner(updated) }
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
