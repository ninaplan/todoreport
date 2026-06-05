import Foundation
import SwiftData

@MainActor
final class NotionRelationLinker {
    static let shared = NotionRelationLinker()
    private init() {}

    private var context: ModelContext { PersistenceController.shared.context }

    /// 최근 14일 투두 중 notionRelationLinked == false인 항목의 relation 연결 시도 (최대 10개)
    /// Notion 연결된 플래너 항목만 처리 (selectedPlanner 무관)
    func linkMissing() {
        let connectedPlannerIds = Set(
            PlannerService.shared.store
                .filter { $0.isNotionConnected }
                .map { $0.id }
        )
        guard !connectedPlannerIds.isEmpty else { return }

        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let allItems = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        let pending = allItems.filter {
            !$0.notionRelationLinked &&
            !$0.notionPageId.isEmpty &&
            $0.date >= cutoff &&
            connectedPlannerIds.contains($0.plannerId ?? "")
        }
        .prefix(10)

        guard !pending.isEmpty else { return }
        print("[RelationLinker] 🔗 \(pending.count)개 relation 연결 시도")

        for item in pending {
            Task { @MainActor in
                SyncQueueManager.shared.enqueueTodoUpdate(item.toTodo())
            }
        }
        // notionRelationLinked = true 는 SyncQueueProcessor 성공 후에만 세팅
    }
}
