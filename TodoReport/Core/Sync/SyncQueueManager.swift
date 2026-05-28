import Foundation
import SwiftData

@MainActor
final class SyncQueueManager {
    static let shared = SyncQueueManager()
    private init() {}

    private var context: ModelContext { PersistenceController.shared.context }

    private var isNotionConnected: Bool {
        UserDefaults.standard.bool(forKey: "isNotionConnected")
    }

    // MARK: - Enqueue

    func enqueueTodoCreate(_ todo: Todo) {
        enqueue(action: "create", entityType: "todo", entityId: todo.id,
                payload: encoded(todo))
    }

    func enqueueTodoUpdate(_ todo: Todo) {
        enqueue(action: "update", entityType: "todo", entityId: todo.id,
                payload: encoded(todo))
    }

    func enqueueTodoDelete(id: String) {
        enqueue(action: "delete", entityType: "todo", entityId: id, payload: Data())
    }

    // MARK: - Notion 연결 완료 시 호출

    func onNotionConnected() {
        processIfConnected()
    }

    // MARK: - Private

    private func enqueue(action: String, entityType: String, entityId: String, payload: Data) {
        // update 중복 방지: 동일 entityId의 pending update 항목이 있으면 payload를 최신으로 교체
        if action == "update" {
            let eid = entityId
            let descriptor = FetchDescriptor<SyncQueueItem>(
                predicate: #Predicate<SyncQueueItem> { item in
                    item.entityId == eid &&
                    item.action == "update" &&
                    item.status == "pending"
                }
            )
            if let existing = try? context.fetch(descriptor).first {
                existing.payload = payload
                existing.createdAt = .now
                try? context.save()
                processIfConnected()
                return
            }
        }

        let item = SyncQueueItem(
            action: action,
            entityType: entityType,
            entityId: entityId,
            payload: payload
        )
        context.insert(item)
        try? context.save()
        processIfConnected()
    }

    func processIfConnected() {
        guard isNotionConnected else { return }
        Task { await SyncQueueProcessor.shared.process() }
    }

    private func encoded<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }
}
