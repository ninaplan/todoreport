import Foundation
import Network

@MainActor
final class NetworkMonitor: @unchecked Sendable {
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

        monitor.pathUpdateHandler = { path in
            let isConnected = path.status == .satisfied
            Task { @MainActor in
                NetworkMonitor.shared.handleConnectivityChange(isConnected)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private func handleConnectivityChange(_ isConnected: Bool) {
        if isConnected, !wasConnected {
            SyncQueueManager.shared.processIfConnected()
        }
        wasConnected = isConnected
    }
}
