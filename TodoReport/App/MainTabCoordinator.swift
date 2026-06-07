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

    private init() {}

    func openTodo(on date: Date) {
        pendingTodoDate = Calendar.current.startOfDay(for: date)
        selectedTab = .todo
    }

    func clearPendingTodoDate() {
        pendingTodoDate = nil
    }
}
