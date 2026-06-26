import Foundation
import Combine

// MARK: - Models

struct NotionDatabase: Identifiable {
    let id: String
    let title: String
    let icon: String?
}

struct NotionProperty: Identifiable {
    let id: String
    let name: String
    let type: String
    var options: [String]? = nil
}

struct TodoPropsMapping: Codable {
    var completed: String? = nil
    var completedPropId: String? = nil
    var date: String? = nil
    var datePropId: String? = nil
    var memo: String? = nil
    var memoPropId: String? = nil
    var isPinned: String? = nil
    var isPinnedPropId: String? = nil
    var reportRelation: String? = nil  // 투두DB → 데일리리포트DB relation 속성명
    var reportRelationPropId: String? = nil
    var category: String? = nil
    var categoryPropId: String? = nil
    var categoryPropType: String? = nil  // v1: "select" 고정
}

struct ReportPropsMapping: Codable {
    var date: String? = nil
    var datePropId: String? = nil
    var review: String? = nil
    var reviewPropId: String? = nil
    var rating: String? = nil
    var ratingPropId: String? = nil
    var periodCompletionRate: String? = nil
    var periodCompletionRatePropId: String? = nil
    var dayRatingOptions: [String] = []
    var ratingPropType: String? = nil
}

enum PropMappingMode: Equatable {
    case appOnly
    case existing
}

// MARK: - ViewModel

@Observable
final class OnboardingViewModel {

    enum Step: Equatable {
        case welcome
        case plannerName
        case selectTodoDB
        case mapTodoProps
        case selectReportDB
        case mapReportProps
    }

    private(set) var step: Step = .welcome
    private(set) var welcomePageIndex: Int = 0
    private(set) var isLoading: Bool = false
    private(set) var isComplete: Bool = false
    private(set) var alertMessage: String?

    var plannerName: String = ""
    private(set) var databases: [NotionDatabase] = []
    var selectedTodoDBId: String?
    var selectedReportDBId: String?
    private(set) var todoProperties: [NotionProperty] = []
    private(set) var reportProperties: [NotionProperty] = []
    var todoPropsMapping = TodoPropsMapping()
    var reportPropsMapping = ReportPropsMapping()
    private(set) var isLoadingDatabases: Bool = false
    private(set) var isLoadingDBs: Bool = false

    // 선택 속성 매핑 모드
    var memoMode: PropMappingMode = .appOnly
    var isPinnedMode: PropMappingMode = .appOnly
    var reportRelationMode: PropMappingMode = .appOnly
    var categoryMode: PropMappingMode = .appOnly
    var reviewMode: PropMappingMode = .appOnly
    var ratingMode: PropMappingMode = .appOnly

    // 온보딩 완료 후 초기 fetch
    private(set) var isFetchingInitialData: Bool = false
    private(set) var fetchProgress: Double = 0

    // 필수 속성 validation
    var canProceedFromTodoProps: Bool {
        todoPropsMapping.completed != nil && todoPropsMapping.date != nil
    }
    var canProceedFromReportProps: Bool {
        reportPropsMapping.date != nil
    }

    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var databasesFetchTask: Task<Void, Never>?
    @ObservationIgnored private(set) var capturedToken: String?
    @ObservationIgnored private(set) var capturedRefreshToken: String?

    init() {
        NotionAuthManager.shared.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.isLoading = false
                self?.alertMessage = message
            }
            .store(in: &cancellables)
    }

    // MARK: - Welcome

    func advanceWelcomePage() {
        let lastIndex = OnboardingWelcomePage.allCases.count - 1
        guard welcomePageIndex < lastIndex else { return }
        welcomePageIndex += 1
    }

    func goToWelcomePage(_ index: Int) {
        let lastIndex = OnboardingWelcomePage.allCases.count - 1
        welcomePageIndex = min(max(index, 0), lastIndex)
    }

    func selectNotionConnection() {
        Task { await startNotionOAuth() }
    }

    func selectLocalMode() {
        completeWithLocalMode()
    }

    // MARK: - Notion OAuth

    private func startNotionOAuth() async {
        isLoading = true
        NotionAuthManager.shared.secondaryOAuthCompletion = { [weak self] token, refreshToken in
            Task { @MainActor [weak self] in
                self?.capturedToken = token
                self?.capturedRefreshToken = refreshToken
                self?.isLoading = false
                self?.proceedFromNotionOAuth()
            }
        }
        NotionAuthManager.shared.oAuthCancelledCompletion = { [weak self] in
            Task { @MainActor [weak self] in
                self?.isLoading = false
            }
        }
        NotionAuthManager.shared.startOAuth()
    }

    func proceedFromNotionOAuth() {
        step = .plannerName
    }

    // MARK: - Step 4: Planner Name

    func proceedFromPlannerName() {
        guard !plannerName.trimmingCharacters(in: .whitespaces).isEmpty else {
            alertMessage = "플래너 이름을 입력해주세요"
            return
        }
        step = .selectTodoDB
    }

    // MARK: - Step 5: Select Todo DB

    func selectTodoDB(_ id: String) {
        selectedTodoDBId = id
        Task { await fetchTodoProperties() }
    }

    // MARK: - Step 6: Map Todo Props

    func proceedFromMapTodoProps() {
        step = .selectReportDB
    }

    // MARK: - Step 7: Select Report DB

    func selectReportDB(_ id: String) {
        selectedReportDBId = id
        Task { await fetchReportProperties() }
    }

    func skipReportDB() {
        selectedReportDBId = nil
        Task { await performInitialFetch() }
    }

    // MARK: - Step 8: Map Report Props

    func proceedFromMapReportProps() {
        Task { await performInitialFetch() }
    }

    @MainActor
    private func performInitialFetch() async {
        await saveOnboardingData()
        guard PlannerService.shared.selectedPlanner?.isNotionConnected == true else {
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
            isComplete = true
            return
        }
        if let planner = PlannerService.shared.selectedPlanner {
            await CategoryNotionSync.shared.syncCategoriesByName(plannerId: planner.id)
        }
        await runInitialNotionFetch()
    }

    @MainActor
    private func runInitialNotionFetch() async {
        isFetchingInitialData = true
        fetchProgress = 0
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days: [Date] = (0..<7).compactMap { i in
            calendar.date(byAdding: .day, value: -i, to: today)
        }
        let total = Double(days.count)
        var completed = 0.0
        await withTaskGroup(of: Void.self) { group in
            for day in days {
                group.addTask {
                    await TodoService.shared.syncTodosFromNotion(for: day)
                    await DailyReportService().syncReportFromNotion(for: day)
                }
            }
            for await _ in group {
                completed += 1
                fetchProgress = completed / total
            }
        }
        isFetchingInitialData = false
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        isComplete = true
    }

    private func saveOnboardingData() async {
        guard var planner = PlannerService.shared.selectedPlanner else { return }
        planner.name = plannerName
        planner.notionTodoDBId = selectedTodoDBId
        planner.notionReportDBId = selectedReportDBId
        planner.notionAccessToken = capturedToken
        planner.notionRefreshToken = capturedRefreshToken
        planner.isNotionConnected = true
        TodoPropsMappingAutoFill.backfillIds(mapping: &todoPropsMapping, properties: todoProperties)
        ReportPropsMappingAutoFill.backfillIds(mapping: &reportPropsMapping, properties: reportProperties)
        if let data = try? JSONEncoder().encode(todoPropsMapping),
           let json = String(data: data, encoding: .utf8) {
            planner.todoPropsMapping = json
        }
        if let data = try? JSONEncoder().encode(reportPropsMapping),
           let json = String(data: data, encoding: .utf8) {
            planner.reportPropsMapping = json
        }
        try? await PlannerService.shared.savePlanner(planner)
        CategoryNotionSync.shared.onCategoryMappingEnabled(
            plannerId: planner.id,
            previousCategoryProp: nil,
            newCategoryProp: todoPropsMapping.category
        )
        SyncQueueManager.shared.onNotionConnected()
    }

    // MARK: - Navigation

    func goBack() {
        switch step {
        case .plannerName:
            step = .welcome
            welcomePageIndex = OnboardingWelcomePage.allCases.count - 1
        case .selectTodoDB:
            selectedTodoDBId = nil
            step = .plannerName
        case .mapTodoProps:
            selectedTodoDBId = nil
            step = .selectTodoDB
        case .selectReportDB:
            selectedReportDBId = nil
            step = .mapTodoProps
        case .mapReportProps:
            selectedReportDBId = nil
            step = .selectReportDB
        default:
            break
        }
    }

    // MARK: - Step 4 (Local): Local Mode

    func completeWithLocalMode() {
        UserDefaults.standard.set(false, forKey: "notionConnected")
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        isComplete = true
    }

    // MARK: - Utility

    func clearAlert() {
        alertMessage = nil
        NotionAuthManager.shared.errorMessage = nil
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
                token: capturedToken ?? "",
                mergeWith: databases,
                retryIfEmpty: databases.isEmpty
            )
            guard !Task.isCancelled else { return }

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

    func refreshDatabases() async {
        await fetchDatabases(forceRefresh: true)
    }

    func fetchTodoProperties() async {
        guard let dbId = selectedTodoDBId else { return }
        isLoadingDBs = true
        defer { isLoadingDBs = false }

        guard let url = URL(string: "\(BackendBaseURL.resolved)/api/notion/databases/\(dbId)/properties") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(capturedToken ?? "")", forHTTPHeaderField: "Authorization")

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
        isLoadingDBs = true
        defer { isLoadingDBs = false }

        guard let url = URL(string: "\(BackendBaseURL.resolved)/api/notion/databases/\(dbId)/properties") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(capturedToken ?? "")", forHTTPHeaderField: "Authorization")

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

    func selectCategory(_ name: String?) {
        TodoPropsMappingAutoFill.applyCategorySelection(
            mapping: &todoPropsMapping,
            name: name,
            properties: todoProperties,
            categoryMode: &categoryMode
        )
    }

    // MARK: - 속성 생성

    func createMemoProperty() async {
        isLoadingDBs = true
        defer { isLoadingDBs = false }
        guard let dbId = selectedTodoDBId,
              let name = await addNotionProperty(dbId: dbId, name: "메모", type: "rich_text") else { return }
        todoPropsMapping.memo = name
        memoMode = .existing
        await refreshTodoPropertiesList()
        TodoPropsMappingAutoFill.backfillIds(mapping: &todoPropsMapping, properties: todoProperties)
    }

    func createPinnedProperty() async {
        isLoadingDBs = true
        defer { isLoadingDBs = false }
        guard let dbId = selectedTodoDBId,
              let name = await addNotionProperty(dbId: dbId, name: "상단고정", type: "checkbox") else { return }
        todoPropsMapping.isPinned = name
        isPinnedMode = .existing
        await refreshTodoPropertiesList()
        TodoPropsMappingAutoFill.backfillIds(mapping: &todoPropsMapping, properties: todoProperties)
    }

    func createCategoryProperty() async {
        isLoadingDBs = true
        defer { isLoadingDBs = false }
        guard let dbId = selectedTodoDBId,
              let name = await addNotionProperty(dbId: dbId, name: "카테고리", type: "select", options: []) else { return }
        todoPropsMapping.category = name
        todoPropsMapping.categoryPropType = "select"
        categoryMode = .existing
        await refreshTodoPropertiesList()
        TodoPropsMappingAutoFill.backfillIds(mapping: &todoPropsMapping, properties: todoProperties)
    }

    func createRatingProperty() async {
        isLoadingDBs = true
        defer { isLoadingDBs = false }
        let options = DayRating.allCases.map { $0.rawValue }
        guard let dbId = selectedReportDBId,
              let name = await addNotionProperty(dbId: dbId, name: "별점", type: "select", options: options) else { return }
        reportPropsMapping.dayRatingOptions = options
        reportPropsMapping.ratingPropType = "select"
        reportPropsMapping.rating = name
        ratingMode = .existing
        await refreshReportPropertiesList()
        ReportPropsMappingAutoFill.backfillIds(mapping: &reportPropsMapping, properties: reportProperties)
    }

    private func addNotionProperty(dbId: String, name: String, type: String, options: [String] = []) async -> String? {
        guard let token = capturedToken,
              let url = URL(string: "\(BackendBaseURL.resolved)/api/notion/databases/\(dbId)/add-property") else { return nil }

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

    private func refreshTodoPropertiesList() async {
        guard let dbId = selectedTodoDBId,
              let url = URL(string: "\(BackendBaseURL.resolved)/api/notion/databases/\(dbId)/properties") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(capturedToken ?? "")", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let decoded = try? JSONDecoder().decode(PropertiesResponse.self, from: data) else { return }
        todoProperties = decoded.properties.map {
            NotionProperty(id: $0.id, name: $0.name, type: $0.type, options: $0.options)
        }
    }

    private func refreshReportPropertiesList() async {
        guard let dbId = selectedReportDBId,
              let url = URL(string: "\(BackendBaseURL.resolved)/api/notion/databases/\(dbId)/properties") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(capturedToken ?? "")", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let decoded = try? JSONDecoder().decode(PropertiesResponse.self, from: data) else { return }
        reportProperties = decoded.properties.map {
            NotionProperty(id: $0.id, name: $0.name, type: $0.type, options: $0.options)
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
