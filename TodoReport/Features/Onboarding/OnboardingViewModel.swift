import Foundation
import AuthenticationServices
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
    var date: String? = nil
    var memo: String? = nil
    var isPinned: String? = nil
    var reportRelation: String? = nil  // 투두DB → 데일리리포트DB relation 속성명
}

struct ReportPropsMapping: Codable {
    var date: String? = nil
    var review: String? = nil
    var rating: String? = nil
    var periodCompletionRate: String? = nil
}

enum PropMappingMode: Equatable {
    case appOnly
    case existing
}

// MARK: - ViewModel

@Observable
final class OnboardingViewModel {

    enum Step: Equatable {
        case signIn
        case connectionChoice
        case notionOAuth
        case localModeInfo
        case plannerName
        case selectTodoDB
        case mapTodoProps
        case selectReportDB
        case mapReportProps
    }

    private(set) var step: Step = .signIn
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
    private(set) var isLoadingDBs: Bool = false

    // 선택 속성 매핑 모드
    var memoMode: PropMappingMode = .appOnly
    var isPinnedMode: PropMappingMode = .appOnly
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
    @ObservationIgnored private(set) var capturedToken: String?

    private let backendBase = "https://todoreport-backend.vercel.app"

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

    // MARK: - Step 1: Sign in with Apple

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success:
            step = .connectionChoice
        case .failure(let error):
            guard (error as? ASAuthorizationError)?.code != .canceled else { return }
            alertMessage = error.localizedDescription
        }
    }

    // MARK: - Step 2: Connection Choice

    func selectNotionConnection() {
        step = .notionOAuth
    }

    func selectLocalMode() {
        step = .localModeInfo
    }

    // MARK: - Step 3: Notion OAuth

    func startNotionOAuth() async {
        isLoading = true
        NotionAuthManager.shared.secondaryOAuthCompletion = { [weak self] token in
            Task { @MainActor [weak self] in
                self?.capturedToken = token
                self?.isLoading = false
                self?.proceedFromNotionOAuth()
            }
        }
        NotionAuthManager.shared.startOAuth()
    }

    func proceedFromNotionOAuth() {
        step = .plannerName
        Task { await fetchDatabases() }
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
        planner.isNotionConnected = true
        if let data = try? JSONEncoder().encode(todoPropsMapping),
           let json = String(data: data, encoding: .utf8) {
            planner.todoPropsMapping = json
        }
        if let data = try? JSONEncoder().encode(reportPropsMapping),
           let json = String(data: data, encoding: .utf8) {
            planner.reportPropsMapping = json
        }
        try? await PlannerService.shared.savePlanner(planner)
        SyncQueueManager.shared.onNotionConnected()
    }

    // MARK: - Navigation

    func goBack() {
        switch step {
        case .plannerName:
            step = .connectionChoice
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

    // TODO: 배포 전 제거 — 개발 테스트용
    func devLogin() {
        step = .connectionChoice
    }

    // MARK: - API

    func fetchDatabases() async {
        isLoadingDBs = true
        defer { isLoadingDBs = false }

        guard let url = URL(string: "\(backendBase)/api/notion/databases") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(capturedToken ?? "")", forHTTPHeaderField: "Authorization")

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

    func fetchTodoProperties() async {
        guard let dbId = selectedTodoDBId else { return }
        isLoadingDBs = true
        defer { isLoadingDBs = false }

        guard let url = URL(string: "\(backendBase)/api/notion/databases/\(dbId)/properties") else { return }
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

        guard let url = URL(string: "\(backendBase)/api/notion/databases/\(dbId)/properties") else { return }
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
        func best(props: [NotionProperty], type: String, default name: String) -> String? {
            let typed = props.filter { $0.type == type }
            return typed.first(where: { $0.name == name })?.name ?? typed.first?.name
        }
        todoPropsMapping.completed = best(props: todoProperties, type: "checkbox",  default: "완료")
        todoPropsMapping.date      = best(props: todoProperties, type: "date",      default: "날짜")
        todoPropsMapping.memo      = best(props: todoProperties, type: "rich_text", default: "메모")
        todoPropsMapping.isPinned  = best(props: todoProperties, type: "checkbox",  default: "중요")
    }

    // MARK: - 속성 생성

    func createMemoProperty() async {
        isLoadingDBs = true
        defer { isLoadingDBs = false }
        guard let dbId = selectedTodoDBId,
              let name = await addNotionProperty(dbId: dbId, name: "메모", type: "rich_text") else { return }
        todoPropsMapping.memo = name
        memoMode = .existing
    }

    func createPinnedProperty() async {
        isLoadingDBs = true
        defer { isLoadingDBs = false }
        guard let dbId = selectedTodoDBId,
              let name = await addNotionProperty(dbId: dbId, name: "상단고정", type: "checkbox") else { return }
        todoPropsMapping.isPinned = name
        isPinnedMode = .existing
    }

    func createRatingProperty() async {
        isLoadingDBs = true
        defer { isLoadingDBs = false }
        let options = DayRating.allCases.map { $0.rawValue }
        guard let dbId = selectedReportDBId,
              let name = await addNotionProperty(dbId: dbId, name: "별점", type: "select", options: options) else { return }
        reportPropsMapping.rating = name
        ratingMode = .existing
    }

    private func addNotionProperty(dbId: String, name: String, type: String, options: [String] = []) async -> String? {
        guard let token = capturedToken,
              let url = URL(string: "\(backendBase)/api/notion/databases/\(dbId)/add-property") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["propertyName": name, "type": type]
        if !options.isEmpty { body["options"] = options }
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
        func best(props: [NotionProperty], type: String, default name: String) -> NotionProperty? {
            let typed = props.filter { $0.type == type }
            return typed.first(where: { $0.name == name }) ?? typed.first
        }
        reportPropsMapping.date = best(props: reportProperties, type: "date", default: "날짜")?.name
        if let reviewProp = best(props: reportProperties, type: "rich_text", default: "하루 리뷰") {
            reportPropsMapping.review = reviewProp.name
            reviewMode = .existing
        }
        if let ratingProp = best(props: reportProperties, type: "select", default: "별점") {
            reportPropsMapping.rating = ratingProp.name
            ratingMode = .existing
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
