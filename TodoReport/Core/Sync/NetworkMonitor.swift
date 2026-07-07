import Foundation
import Network

@MainActor
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    private init() {}

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "kr.nock.TodoReport.NetworkMonitor")
    private var wasConnected = false
    private var hasStarted = false

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        wasConnected = monitor.currentPath.status == .satisfied

        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                if isConnected, !self.wasConnected {
                    SyncQueueManager.shared.processIfConnected()
                }
                self.wasConnected = isConnected
            }
        }
        monitor.start(queue: monitorQueue)
    }
}
