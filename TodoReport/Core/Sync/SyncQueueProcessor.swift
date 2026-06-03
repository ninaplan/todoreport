import Foundation
import SwiftData

@MainActor
final class SyncQueueProcessor {
    static let shared = SyncQueueProcessor()
    private init() {}

    private var isProcessing = false
    private var context: ModelContext { PersistenceController.shared.context }

    func process() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let descriptor = FetchDescriptor<SyncQueueItem>(
                predicate: #Predicate<SyncQueueItem> { $0.status == "pending" },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            let fetched = try context.fetch(descriptor)
            // update(완료 체크)를 create/delete보다 먼저 처리
            let items = fetched.filter { $0.action == "update" } + fetched.filter { $0.action != "update" }
            print("[Processor] 🔄 처리 시작 - \(items.count)개")

            for item in items {
                // 아이템의 plannerId로 플래너 조회 (없으면 현재 선택 플래너 사용)
                let planner = PlannerService.shared.store.first(where: { $0.id == item.plannerId })
                    ?? PlannerService.shared.selectedPlanner
                guard let planner, planner.isNotionConnected else {
                    print("[Processor] ⚠️ 플래너 미연결 - 스킵 \(item.entityId)")
                    continue
                }

                item.status = "processing"
                try? context.save()

                do {
                    let notionPageId = try await NotionAPIClient.shared.sync(
                        action: item.action,
                        entityType: item.entityType,
                        entityId: item.entityId,
                        payload: item.payload,
                        planner: planner
                    )
                    if item.action == "create", item.entityType == "todo",
                       let pageId = notionPageId {
                        updateNotionPageId(localId: item.entityId, notionPageId: pageId)
                    }
                    context.delete(item)
                    try? context.save()
                    print("[Processor] ✅ 성공 - \(item.entityId)")
                } catch {
                    item.retryCount += 1
                    item.status = item.retryCount > 3 ? "failed" : "pending"
                    try? context.save()
                    print("[Processor] ❌ 실패 - \(item.entityId) retryCount:\(item.retryCount)")
                }
            }

            // 루프 실행 중 새로 enqueue된 아이템 처리
            let remainingDesc = FetchDescriptor<SyncQueueItem>(
                predicate: #Predicate<SyncQueueItem> { $0.status == "pending" }
            )
            if let remaining = try? context.fetch(remainingDesc), !remaining.isEmpty {
                Task { await self.process() }
            }
        } catch {
            // fetch 실패 — 다음 실행 시 재시도
        }
    }

    private func updateNotionPageId(localId: String, notionPageId: String) {
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.id == localId }
        )
        guard let item = try? context.fetch(descriptor).first else { return }
        item.notionPageId = notionPageId
        try? context.save()
        print("[Processor] 🔗 notionPageId 업데이트 - \(localId) → \(notionPageId)")
    }
}
