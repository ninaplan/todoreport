import Foundation

@Observable
final class MainTabCoordinator {
    static let shared = MainTabCoordinator()

    enum Tab: Hashable {
        case todo
        case report
        case settings
        case search
    }

    var selectedTab: Tab = .todo
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
    /// 포그라운드 복귀 시 데이터 갱신 트리거
    private(set) var foregroundRefreshToken: Int = 0

    private init() {}

    func openTodo(on date: Date, highlightTodoId: String? = nil) {
        pendingHighlightTodoId = highlightTodoId
        pendingTodoDate = Calendar.current.startOfDay(for: date)
        selectedTab = .todo
    }

    func openTodoTab() {
        selectedTab = .todo
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
