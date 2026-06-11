import Foundation

@Observable
final class MainTabCoordinator {
    static let shared = MainTabCoordinator()

    enum Tab: Hashable {
        case todo
        case report
        case settings
    }

    var selectedTab: Tab = .todo
    var pendingTodoDate: Date?
    /// 설정 탭 NavigationStack 초기화 트리거 (위젯 진입 등)
    private(set) var settingsStackResetToken: Int = 0

    private init() {}

    func openTodo(on date: Date) {
        pendingTodoDate = Calendar.current.startOfDay(for: date)
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
}
