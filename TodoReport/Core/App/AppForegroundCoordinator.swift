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
        defer { backgroundEnteredAt = nil }
        guard let entered = backgroundEnteredAt else { return }
        let elapsed = Date().timeIntervalSince(entered)
        guard elapsed >= Self.longBackgroundThreshold else { return }
        MainTabCoordinator.shared.requestTodoRootReset()
        MainTabCoordinator.shared.triggerForegroundRefresh()
    }
}
