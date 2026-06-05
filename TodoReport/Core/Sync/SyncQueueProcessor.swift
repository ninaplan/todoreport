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
                // 아이템에 저장된 plannerId로만 플래너 조회 (selectedPlanner fallback 없음)
                guard let planner = PlannerService.shared.store.first(where: { $0.id == item.plannerId }),
                      planner.isNotionConnected else {
                    print("[Processor] ⚠️ 플래너 없음 또는 미연결 - 스킵 \(item.entityId) plannerId:\(item.plannerId ?? "nil")")
                    continue
                }

                // update todo: entityId가 localId인 경우 notionPageId로 해소
                if item.action == "update", item.entityType == "todo" {
                    let eid = item.entityId
                    let byNotionPageId = FetchDescriptor<TodoItem>(
                        predicate: #Predicate { $0.notionPageId == eid }
                    )
                    if (try? context.fetch(byNotionPageId).first) == nil {
                        // notionPageId로 찾지 못함 → localId로 TodoItem 조회 시도
                        let byLocalId = FetchDescriptor<TodoItem>(
                            predicate: #Predicate { $0.id == eid }
                        )
                        if let todoItem = try? context.fetch(byLocalId).first {
                            if todoItem.notionPageId.isEmpty {
                                // create 아직 미완료 → 재배치 상한선 체크
                                item.requeueCount += 1
                                if item.requeueCount > 5 {
                                    item.status = "failed"
                                    try? context.save()
                                    print("[Processor] ❌ update 재배치 한도 초과 → failed localId:\(eid) requeueCount:\(item.requeueCount)")
                                    AppLogger.shared.error("Processor", "update 재배치 한도 초과 → failed localId:\(eid) requeueCount:\(item.requeueCount)")
                                } else {
                                    item.createdAt = Date()
                                    try? context.save()
                                    print("[Processor] ⏳ update 보류 - create 미완료, 재배치 localId:\(eid) requeueCount:\(item.requeueCount)")
                                }
                                continue
                            }
                            // notionPageId 확정됨 → entityId 업데이트 후 계속 진행
                            item.entityId = todoItem.notionPageId
                            try? context.save()
                            print("[Processor] 🔗 update entityId 해소 \(eid) → \(todoItem.notionPageId)")
                        }
                        // localId로도 찾지 못하면 (삭제된 todo) → 그대로 진행, Notion API가 404 반환하면 실패 처리
                    }
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
                        enqueueTodoUpdateForRelation(localId: item.entityId)
                    }
                    if item.action == "update", item.entityType == "todo" {
                        setRelationLinked(notionPageId: item.entityId)
                    }
                    context.delete(item)
                    try? context.save()
                    print("[Processor] ✅ 성공 - \(item.entityId)")
                } catch {
                    item.retryCount += 1
                    let isFinalFailure = item.retryCount > 3
                    item.status = isFinalFailure ? "failed" : "pending"
                    try? context.save()
                    print("[Processor] ❌ 실패 - \(item.entityId) retryCount:\(item.retryCount)")
                    AppLogger.shared.error("Processor", "동기화 실패 - \(item.entityId) retryCount:\(item.retryCount) isFinalFailure:\(isFinalFailure) error:\(error.localizedDescription)")

                    // create 최종 실패 시 같은 localId의 update 아이템도 함께 failed 처리
                    if isFinalFailure, item.action == "create", item.entityType == "todo" {
                        failRelatedUpdates(localId: item.entityId)
                    }
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

    private func failRelatedUpdates(localId: String) {
        let lid = localId
        let descriptor = FetchDescriptor<SyncQueueItem>(
            predicate: #Predicate<SyncQueueItem> { item in
                item.entityId == lid &&
                item.action == "update" &&
                (item.status == "pending" || item.status == "processing")
            }
        )
        guard let updates = try? context.fetch(descriptor), !updates.isEmpty else { return }
        updates.forEach { $0.status = "failed" }
        try? context.save()
        print("[Processor] ❌ create 실패 → 연관 update \(updates.count)개 failed 처리 localId:\(localId)")
        AppLogger.shared.error("Processor", "create 최종 실패 → 연관 update \(updates.count)개 failed 처리 localId:\(localId)")
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

    private func enqueueTodoUpdateForRelation(localId: String) {
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == localId })
        guard let item = try? context.fetch(descriptor).first,
              !item.notionPageId.isEmpty else { return }
        SyncQueueManager.shared.enqueueTodoUpdate(item.toTodo())
        print("[Processor] 🔗 create 완료 → relation enqueue - \(localId)")
    }

    private func setRelationLinked(notionPageId: String) {
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.notionPageId == notionPageId }
        )
        guard let item = try? context.fetch(descriptor).first else { return }
        item.notionRelationLinked = true
        try? context.save()
        print("[Processor] 🔗 notionRelationLinked = true - \(notionPageId)")
    }
}
