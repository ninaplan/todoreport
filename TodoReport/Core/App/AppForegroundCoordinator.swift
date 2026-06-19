import Foundation

@Observable
final class AppForegroundCoordinator {
    static let shared = AppForegroundCoordinator()

    static let longBackgroundThreshold: TimeInterval = 5 * 60

    private(set) var backgroundEnteredAt: Date?

    private init() {}

    func recordBackgroundEntry() {
        backgroundEnteredAt = Date()
    }

    @MainActor
    func handleBecomeActive() {
        if let entered = backgroundEnteredAt {
            let elapsed = Date().timeIntervalSince(entered)
            if elapsed >= Self.longBackgroundThreshold {
                MainTabCoordinator.shared.requestTodoRootReset()
            }
        }
        backgroundEnteredAt = nil
        MainTabCoordinator.shared.triggerForegroundRefresh()
    }
}
