import Foundation
import SwiftData

@MainActor
final class NotionRelationLinker {
    static let shared = NotionRelationLinker()
    private init() {}

    private var context: ModelContext { PersistenceController.shared.context }

    /// 최근 7일 투두 중 notionRelationLinked == false인 항목의 relation 연결 시도
    func linkMissing() {
        guard PlannerService.shared.selectedPlanner?.isNotionConnected == true else { return }

        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let allItems = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        let pending = allItems.filter {
            !$0.notionRelationLinked &&
            !$0.notionPageId.isEmpty &&
            $0.date >= cutoff
        }

        guard !pending.isEmpty else { return }
        print("[RelationLinker] 🔗 \(pending.count)개 relation 연결 시도")

        for item in pending {
            // relation 연결을 위해 update 재큐잉 (encodedTodoPayload에 reportRelationProp 포함됨)
            Task { @MainActor in
                SyncQueueManager.shared.enqueueTodoUpdate(item.toTodo())
            }
            item.notionRelationLinked = true
        }
        try? context.save()
    }
}
