import Foundation
import SwiftData

@MainActor
final class SyncQueueManager {
    static let shared = SyncQueueManager()
    private init() {
        clearFailedItems()
        clearOldItems()
    }

    private var context: ModelContext { PersistenceController.shared.context }

    private var hasNotionConnectedPlanner: Bool {
        PlannerService.shared.store.contains { $0.isNotionConnected }
    }

    // MARK: - Enqueue

    func enqueueTodoCreate(_ todo: Todo) {
        guard let payload = encodedTodoPayload(todo) else { return }
        print("[SyncQueue] ➕ enqueue create - \(todo.title)")
        enqueue(action: "create", entityType: "todo", entityId: todo.id,
                payload: payload, plannerId: todo.plannerId)
    }

    func enqueueTodoUpdate(_ todo: Todo) {
        guard !todo.notionPageId.isEmpty else {
            let lid = todo.id

            // 1) pending/processing create가 있으면 페이로드를 최신 상태로 갱신
            //    "processing" 포함: create가 전송 중일 때도 payload를 최신으로 유지
            let pendingCreateDesc = FetchDescriptor<SyncQueueItem>(
                predicate: #Predicate<SyncQueueItem> { item in
                    item.entityId == lid &&
                    item.action == "create" &&
                    (item.status == "pending" || item.status == "processing")
                }
            )
            if let existing = try? context.fetch(pendingCreateDesc).first {
                guard let payload = encodedTodoPayload(todo) else { return }
                existing.payload = payload
                existing.createdAt = .now
                try? context.save()
                print("[SyncQueue] 🔄 pending create 페이로드 갱신 - \(lid) status:\(existing.status)")
                return
            }

            // 2) create가 완료됐다면 SwiftData에 notionPageId가 세팅돼 있을 수 있음
            let todoItemDesc = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == lid })
            if let current = try? context.fetch(todoItemDesc).first,
               !current.notionPageId.isEmpty {
                guard let payload = encodedTodoPayload(todo) else { return }
                enqueue(action: "update", entityType: "todo", entityId: current.notionPageId,
                        payload: payload, plannerId: todo.plannerId)
                print("[SyncQueue] ➕ update enqueue (resolved) - \(lid) → \(current.notionPageId)")
                return
            }

            // 3) notionPageId 미확정 → localId로 enqueue, 처리 시점에 Processor가 해소
            guard let payload = encodedTodoPayload(todo) else { return }
            enqueue(action: "update", entityType: "todo", entityId: lid,
                    payload: payload, plannerId: todo.plannerId)
            print("[SyncQueue] ➕ update enqueue (localId 임시) - \(lid)")
            return
        }
        guard let payload = encodedTodoPayload(todo) else { return }
        enqueue(action: "update", entityType: "todo", entityId: todo.notionPageId,
                payload: payload, plannerId: todo.plannerId)
        print("[SyncQueue] ➕ update enqueue (notionPageId) - \(todo.notionPageId)")
    }

    func enqueueTodoDelete(notionPageId: String, plannerId: String?) {
        guard !notionPageId.isEmpty else {
            print("[SyncQueue] 🚫 delete 스킵 - notionPageId 없음")
            return
        }
        enqueue(action: "delete", entityType: "todo", entityId: notionPageId,
                payload: Data(), plannerId: plannerId)
    }

    // MARK: - Notion 연결 완료 시 호출

    func onNotionConnected() {
        print("[SyncQueue] 🔔 onNotionConnected 호출")
        processIfConnected()
    }

    // MARK: - Private

    private func enqueue(action: String, entityType: String, entityId: String, payload: Data, plannerId: String?) {
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
            payload: payload,
            plannerId: plannerId
        )
        context.insert(item)
        try? context.save()
        processIfConnected()
    }

    func hasPendingCreate(for localId: String) -> Bool {
        let descriptor = FetchDescriptor<SyncQueueItem>(
            predicate: #Predicate<SyncQueueItem> { item in
                item.entityId == localId &&
                item.action == "create" &&
                item.status == "pending"
            }
        )
        return (try? context.fetch(descriptor))?.isEmpty == false
    }

    func hasPendingUpdate(for entityId: String) -> Bool {
        let descriptor = FetchDescriptor<SyncQueueItem>(
            predicate: #Predicate<SyncQueueItem> { item in
                item.entityId == entityId &&
                item.action == "update" &&
                (item.status == "pending" || item.status == "processing")
            }
        )
        return (try? context.fetch(descriptor))?.isEmpty == false
    }

    func hasPendingDelete(for entityId: String) -> Bool {
        let descriptor = FetchDescriptor<SyncQueueItem>(
            predicate: #Predicate<SyncQueueItem> { item in
                item.entityId == entityId &&
                item.action == "delete" &&
                (item.status == "pending" || item.status == "processing")
            }
        )
        return (try? context.fetch(descriptor))?.isEmpty == false
    }

    func hasPendingOperation(for pageId: String) -> Bool {
        hasPendingCreate(for: pageId) || hasPendingUpdate(for: pageId) || hasPendingDelete(for: pageId)
    }

    var hasPendingItems: Bool {
        let descriptor = FetchDescriptor<SyncQueueItem>(
            predicate: #Predicate<SyncQueueItem> { $0.status == "pending" || $0.status == "processing" }
        )
        return (try? context.fetch(descriptor))?.isEmpty == false
    }

    func processIfConnected() {
        guard hasNotionConnectedPlanner else {
            print("[SyncQueue] ⚠️ Notion 연결된 플래너 없음 - 스킵")
            return
        }
        print("[SyncQueue] ▶️ 처리 시작")
        Task { await SyncQueueProcessor.shared.process() }
    }

    // MARK: - Cleanup

    private func clearFailedItems() {
        let descriptor = FetchDescriptor<SyncQueueItem>(
            predicate: #Predicate<SyncQueueItem> { $0.status == "failed" || $0.retryCount >= 4 }
        )
        guard let items = try? context.fetch(descriptor), !items.isEmpty else { return }
        items.forEach { context.delete($0) }
        try? context.save()
        print("[SyncQueue] 🗑️ failed 항목 \(items.count)개 삭제")
    }

    private func clearOldItems() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let descriptor = FetchDescriptor<SyncQueueItem>(
            predicate: #Predicate<SyncQueueItem> { $0.createdAt < cutoff }
        )
        guard let items = try? context.fetch(descriptor), !items.isEmpty else { return }
        items.forEach { context.delete($0) }
        try? context.save()
        print("[SyncQueue] 🗑️ 오래된 항목 \(items.count)개 삭제 (7일 초과)")
    }

    #if DEBUG
    @discardableResult
    func clearAllReturningCount() -> Int {
        let descriptor = FetchDescriptor<SyncQueueItem>()
        let items = (try? context.fetch(descriptor)) ?? []
        guard !items.isEmpty else { return 0 }
        items.forEach { context.delete($0) }
        try? context.save()
        print("[SyncQueue] 🗑️ 전체 큐 초기화 (\(items.count)개)")
        return items.count
    }
    #endif

    // MARK: - Todo Payload

    private func encodedTodoPayload(_ todo: Todo) -> Data? {
        guard let planner = PlannerService.shared.store.first(where: { $0.id == todo.plannerId }) else {
            print("[SyncQueue] ❌ encodedTodoPayload: planner not found - todoId:\(todo.id) plannerId:\(todo.plannerId ?? "nil")")
            return nil
        }
        let mapping = planner.decodedTodoPropsMapping
        let reportMapping = planner.decodedReportPropsMapping

        // 마이그레이션 전 항목 대비 UserDefaults 레거시 폴백
        let prefix = "kr.nock.TodoReport."
        let pid = planner.id
        let defaults = UserDefaults.standard
        func legacyString(_ key: String) -> String? {
            defaults.string(forKey: "\(prefix)\(pid).\(key)") ?? defaults.string(forKey: "\(prefix)\(key)")
        }
        func legacyMapping<T: Decodable>(_ key: String, as type: T.Type) -> T? {
            let data = defaults.data(forKey: "\(prefix)\(pid).\(key)") ?? defaults.data(forKey: "\(prefix)\(key)")
            return data.flatMap { try? JSONDecoder().decode(type, from: $0) }
        }
        let legacyTodo   = legacyMapping("todoPropsMapping",   as: TodoPropsMapping.self)
        let legacyReport = legacyMapping("reportPropsMapping", as: ReportPropsMapping.self)

        var body: [String: Any] = [
            "title": todo.title,
            "date": seoulDateString(from: todo.date),
            "isCompleted": todo.isCompleted,
            "isPinned": todo.isPinned,
        ]
        if let st = todo.scheduledTime {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
            fmt.timeZone = TimeZone(identifier: "Asia/Seoul")
            body["scheduledTime"] = fmt.string(from: st)
        }
        if let ao = todo.alarmOffset                                               { body["alarmOffset"] = ao }
        if let memo = todo.memo                                                    { body["memo"] = memo }
        if let v = planner.notionTodoDBId   ?? legacyString("todoDBId")            { body["dbId"] = v }
        if let v = mapping.completed        ?? legacyTodo?.completed               { body["completedProp"] = v }
        if let v = mapping.date             ?? legacyTodo?.date                    { body["dateProp"] = v }
        if let v = mapping.memo             ?? legacyTodo?.memo                    { body["memoProp"] = v }
        if let v = mapping.isPinned         ?? legacyTodo?.isPinned                { body["isPinnedProp"] = v }
        if let v = planner.notionReportDBId ?? legacyString("reportDBId")          { body["reportDBId"] = v }
        if let v = mapping.reportRelation   ?? legacyTodo?.reportRelation          { body["reportRelationProp"] = v }
        if let v = reportMapping.date       ?? legacyReport?.date                  { body["reportDateProp"] = v }

        print("[Payload] plannerId:\(pid) todoDBId:\(planner.notionTodoDBId ?? "nil") reportDBId:\(planner.notionReportDBId ?? "nil") reportRelation:\(mapping.reportRelation ?? "nil")")

        return try? JSONSerialization.data(withJSONObject: body)
    }

    private func seoulDateString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Asia/Seoul")
        return fmt.string(from: date)
    }
}
