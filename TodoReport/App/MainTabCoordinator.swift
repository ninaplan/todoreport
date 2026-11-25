import Foundation

@Observable
final class MainTabCoordinator {
    static let shared = MainTabCoordinator()

    enum Tab: Hashable {
        case todo
        case timeline
        case report
        case settings
        case search
    }

    /// 설정 > 시작 화면 (`"todo"` / `"timeline"`)
    static let launchTabKey = "launchTab"
    static let launchTabTimeline = "timeline"

    var selectedTab: Tab = .todo
    /// 시작 화면 설정으로 타임라인에서 시작했는지 (무료 사용자는 구독 확인 후 투두로 돌려보냄)
    private(set) var launchedIntoTimeline = false
    var pendingTodoDate: Date?
    /// 투두 탭에서 해당 행으로 스크롤·하이라이트 (검색 결과 진입용)
    var pendingHighlightTodoId: String?
    /// 인박스 시트에서 해당 행으로 스크롤·하이라이트 (검색 결과 진입용)
    var pendingInboxHighlightTodoId: String?
    /// 루트 업데이트 팝업 시트 표시 중 (투두 안내 말풍선 가드용)
    var isWhatsNewPopupPresented: Bool = false
    /// 설정 탭 NavigationStack 초기화 트리거 (위젯 진입 등)
    private(set) var settingsStackResetToken: Int = 0
    /// 5분+ 백그라운드 복귀 시 투두 탭 루트 리셋 트리거
    private(set) var todoRootResetToken: Int = 0
    /// 검색 등에서 데일리 리포트 카드를 1회 펼칠 때 증가
    private(set) var expandDailyReportToken: Int = 0
    /// 포그라운드 복귀 시 데이터 갱신 트리거
    private(set) var foregroundRefreshToken: Int = 0
    /// 이미 선택된 탭을 다시 탭했을 때 증가 → 각 탭이 「현재로 돌아오기」
    private(set) var todoReselectToken: Int = 0
    private(set) var timelineReselectToken: Int = 0
    private(set) var reportReselectToken: Int = 0
    private(set) var settingsReselectToken: Int = 0

    private init() {
        if UserDefaults.standard.string(forKey: Self.launchTabKey) == Self.launchTabTimeline {
            selectedTab = .timeline
            launchedIntoTimeline = true
        }
    }

    /// 한 번만 true를 돌려준다
    func consumeLaunchedIntoTimeline() -> Bool {
        defer { launchedIntoTimeline = false }
        return launchedIntoTimeline
    }

    func openTodo(on date: Date, highlightTodoId: String? = nil, expandDailyReport: Bool = false) {
        pendingHighlightTodoId = highlightTodoId
        pendingTodoDate = Calendar.current.startOfDay(for: date)
        if expandDailyReport {
            expandDailyReportToken += 1
        }
        selectedTab = .todo
    }

    /// 탭바에서 탭을 눌렀을 때. 이미 선택된 탭이면 다시 탭 동작.
    func select(_ tab: Tab) {
        guard tab == selectedTab else {
            selectedTab = tab
            return
        }
        switch tab {
        case .todo: todoReselectToken += 1
        case .timeline: timelineReselectToken += 1
        case .report: reportReselectToken += 1
        case .settings: settingsReselectToken += 1
        case .search: break
        }
    }

    func openTodoTab() {
        selectedTab = .todo
    }

    /// 오래 쉬었다 돌아왔을 때 등 「처음 화면」으로: 설정 > 시작 화면을 따른다 (타임블록은 Pro일 때만)
    func openLaunchTab() {
        let wantsTimeline = UserDefaults.standard.string(forKey: Self.launchTabKey) == Self.launchTabTimeline
        selectedTab = wantsTimeline && SubscriptionManager.shared.isPro ? .timeline : .todo
    }

    func openInbox(highlightTodoId: String) {
        pendingInboxHighlightTodoId = highlightTodoId
        selectedTab = .todo
    }

    func openTodoTabFromWidget() {
        pendingTodoDate = Calendar.current.startOfDay(for: .now)
        selectedTab = .todo
        settingsStackResetToken += 1
    }

    func clearPendingTodoDate() {
        pendingTodoDate = nil
    }

    func clearPendingHighlightTodoId() {
        pendingHighlightTodoId = nil
    }

    func clearPendingInboxHighlightTodoId() {
        pendingInboxHighlightTodoId = nil
    }

    func requestTodoRootReset() {
        todoRootResetToken += 1
    }

    func triggerForegroundRefresh() {
        foregroundRefreshToken += 1
    }
}
