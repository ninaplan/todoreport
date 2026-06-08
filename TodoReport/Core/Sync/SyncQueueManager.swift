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
        guard let payload = encodedTodoCreatePayload(todo) else { return }
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
                guard let payload = encodedTodoCreatePayload(todo) else { return }
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
                guard let payload = encodedTodoUpdatePayload(todo) else { return }
                enqueue(action: "update", entityType: "todo", entityId: current.notionPageId,
                        payload: payload, plannerId: todo.plannerId)
                print("[SyncQueue] ➕ update enqueue (resolved) - \(lid) → \(current.notionPageId)")
                return
            }

            // 3) notionPageId 미확정 → localId로 enqueue, 처리 시점에 Processor가 해소
            guard let payload = encodedTodoUpdatePayload(todo) else { return }
            enqueue(action: "update", entityType: "todo", entityId: lid,
                    payload: payload, plannerId: todo.plannerId)
            print("[SyncQueue] ➕ update enqueue (localId 임시) - \(lid)")
            return
        }
        guard let payload = encodedTodoUpdatePayload(todo) else { return }
        enqueue(action: "update", entityType: "todo", entityId: todo.notionPageId,
                payload: payload, plannerId: todo.plannerId)
        print("[SyncQueue] ➕ update enqueue (notionPageId) - \(todo.notionPageId)")
    }

    /// 데일리 리포트 relation 전용 연결 (일반 update와 분리 — 완료 체크 등이 relation을 덮어쓰지 않음)
    func enqueueTodoRelationLink(_ todo: Todo) {
        guard !todo.notionRelationLinked else {
            print("[SyncQueue] 🚫 relation link 스킵 - 이미 연결됨 \(todo.notionPageId)")
            return
        }
        guard let payload = encodedTodoRelationLinkPayload(todo) else { return }

        let entityId: String
        if !todo.notionPageId.isEmpty {
            entityId = todo.notionPageId
        } else {
            let lid = todo.id
            let todoItemDesc = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == lid })
            if let current = try? context.fetch(todoItemDesc).first,
               !current.notionPageId.isEmpty {
                entityId = current.notionPageId
            } else {
                entityId = lid
            }
        }

        print("[SyncQueue] 🔗 enqueue relation link - \(entityId)")
        enqueue(action: "update", entityType: "todo", entityId: entityId,
                payload: payload, plannerId: todo.plannerId)
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
                existing.payload = mergeUpdatePayload(existing: existing.payload, incoming: payload) ?? payload
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

    private struct TodoPayloadContext {
        let planner: Planner
        let mapping: TodoPropsMapping
        let reportMapping: ReportPropsMapping
        let legacyTodo: TodoPropsMapping?
        let legacyReport: ReportPropsMapping?
        let legacyTodoDBId: String?
        let legacyReportDBId: String?

        init?(todo: Todo) {
            guard let planner = PlannerService.shared.store.first(where: { $0.id == todo.plannerId }) else {
                print("[SyncQueue] ❌ payload: planner not found - todoId:\(todo.id) plannerId:\(todo.plannerId ?? "nil")")
                return nil
            }
            self.planner = planner
            self.mapping = planner.decodedTodoPropsMapping
            self.reportMapping = planner.decodedReportPropsMapping

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
            self.legacyTodo = legacyMapping("todoPropsMapping", as: TodoPropsMapping.self)
            self.legacyReport = legacyMapping("reportPropsMapping", as: ReportPropsMapping.self)
            self.legacyTodoDBId = legacyString("todoDBId")
            self.legacyReportDBId = legacyString("reportDBId")
        }
    }

    private func encodedTodoCreatePayload(_ todo: Todo) -> Data? {
        guard let body = encodedTodoBaseBody(todo: todo, includeReportFields: true) else { return nil }
        print("[Payload:create] plannerId:\(todo.plannerId ?? "nil") date:\(body["date"] ?? "")")
        return try? JSONSerialization.data(withJSONObject: body)
    }

    private func encodedTodoUpdatePayload(_ todo: Todo) -> Data? {
        guard let body = encodedTodoBaseBody(todo: todo, includeReportFields: false) else { return nil }
        print("[Payload:update] plannerId:\(todo.plannerId ?? "nil") date:\(body["date"] ?? "")")
        return try? JSONSerialization.data(withJSONObject: body)
    }

    private func encodedTodoRelationLinkPayload(_ todo: Todo) -> Data? {
        guard let ctx = TodoPayloadContext(todo: todo) else { return nil }
        var body: [String: Any] = [
            "linkDailyReport": true,
            "date": seoulDateString(from: todo.date),
        ]
        if let v = ctx.planner.notionTodoDBId ?? ctx.legacyTodoDBId { body["dbId"] = v }
        if let v = ctx.planner.notionReportDBId ?? ctx.legacyReportDBId { body["reportDBId"] = v }
        if let v = ctx.mapping.reportRelation ?? ctx.legacyTodo?.reportRelation { body["reportRelationProp"] = v }
        if let v = ctx.reportMapping.date ?? ctx.legacyReport?.date { body["reportDateProp"] = v }
        print("[Payload:relation] plannerId:\(ctx.planner.id) date:\(body["date"] ?? "")")
        return try? JSONSerialization.data(withJSONObject: body)
    }

    private func encodedTodoBaseBody(todo: Todo, includeReportFields: Bool) -> [String: Any]? {
        guard let ctx = TodoPayloadContext(todo: todo) else { return nil }
        let planner = ctx.planner
        let mapping = ctx.mapping

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
        if let ao = todo.alarmOffset { body["alarmOffset"] = ao }
        if let memo = todo.memo { body["memo"] = memo }
        if let v = planner.notionTodoDBId ?? ctx.legacyTodoDBId { body["dbId"] = v }
        if let v = mapping.completed ?? ctx.legacyTodo?.completed { body["completedProp"] = v }
        if let v = mapping.date ?? ctx.legacyTodo?.date { body["dateProp"] = v }
        if let v = mapping.memo ?? ctx.legacyTodo?.memo { body["memoProp"] = v }
        if let v = mapping.isPinned ?? ctx.legacyTodo?.isPinned { body["isPinnedProp"] = v }
        if includeReportFields {
            if let v = planner.notionReportDBId ?? ctx.legacyReportDBId { body["reportDBId"] = v }
            if let v = mapping.reportRelation ?? ctx.legacyTodo?.reportRelation { body["reportRelationProp"] = v }
            if let v = ctx.reportMapping.date ?? ctx.legacyReport?.date { body["reportDateProp"] = v }
        }
        CategoryNotionSync.shared.appendToPayload(&body, todo: todo, planner: planner)
        return body
    }

    private static let reportPayloadKeys: Set<String> = [
        "linkDailyReport", "reportDBId", "reportRelationProp", "reportDateProp"
    ]

    private func mergeUpdatePayload(existing: Data, incoming: Data) -> Data? {
        guard var merged = decodePayloadDict(existing),
              let incomingDict = decodePayloadDict(incoming) else { return nil }

        let incomingWantsLink = incomingDict["linkDailyReport"] as? Bool == true
        let existingWantsLink = merged["linkDailyReport"] as? Bool == true

        for (key, value) in incomingDict where !Self.reportPayloadKeys.contains(key) {
            merged[key] = value
        }

        if incomingWantsLink {
            for key in Self.reportPayloadKeys {
                if let value = incomingDict[key] { merged[key] = value }
            }
        } else if !existingWantsLink {
            for key in Self.reportPayloadKeys { merged.removeValue(forKey: key) }
        }

        return try? JSONSerialization.data(withJSONObject: merged)
    }

    private func decodePayloadDict(_ data: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func seoulDateString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Asia/Seoul")
        return fmt.string(from: date)
    }
}
