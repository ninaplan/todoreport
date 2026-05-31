import Foundation
import SwiftData

@MainActor
final class SyncQueueManager {
    static let shared = SyncQueueManager()
    private init() {
        clearFailedItems()
    }

    private var context: ModelContext { PersistenceController.shared.context }

    private var isNotionConnected: Bool {
        PlannerService.shared.selectedPlanner?.isNotionConnected == true
    }

    // MARK: - Enqueue

    func enqueueTodoCreate(_ todo: Todo) {
        print("[SyncQueue] ➕ enqueue create - \(todo.title)")
        enqueue(action: "create", entityType: "todo", entityId: todo.id,
                payload: encodedTodoPayload(todo))
    }

    func enqueueTodoUpdate(_ todo: Todo) {
        guard !todo.notionPageId.isEmpty else {
            // notionPageId 없음 → pending create 페이로드를 최신 상태(isCompleted 포함)로 갱신
            let lid = todo.id
            let descriptor = FetchDescriptor<SyncQueueItem>(
                predicate: #Predicate<SyncQueueItem> { item in
                    item.entityId == lid &&
                    item.action == "create" &&
                    item.status == "pending"
                }
            )
            if let existing = try? context.fetch(descriptor).first {
                existing.payload = encodedTodoPayload(todo)
                existing.createdAt = .now
                try? context.save()
                print("[SyncQueue] 🔄 pending create 페이로드 갱신 - \(todo.id)")
            }
            return
        }
        enqueue(action: "update", entityType: "todo", entityId: todo.notionPageId,
                payload: encodedTodoPayload(todo))
    }

    func enqueueTodoDelete(notionPageId: String) {
        guard !notionPageId.isEmpty else {
            print("[SyncQueue] 🚫 delete 스킵 - notionPageId 없음")
            return
        }
        enqueue(action: "delete", entityType: "todo", entityId: notionPageId, payload: Data())
    }

    // MARK: - Notion 연결 완료 시 호출

    func onNotionConnected() {
        print("[SyncQueue] 🔔 onNotionConnected 호출")
        processIfConnected()
    }

    // MARK: - Private

    private func enqueue(action: String, entityType: String, entityId: String, payload: Data) {
        let plannerId = PlannerService.shared.selectedPlanner?.id

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

    func processIfConnected() {
        guard isNotionConnected else {
            print("[SyncQueue] ⚠️ Notion 미연결 - 스킵")
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

    // MARK: - Todo Payload

    private func encodedTodoPayload(_ todo: Todo) -> Data {
        let planner = PlannerService.shared.store.first(where: { $0.id == todo.plannerId })
            ?? PlannerService.shared.selectedPlanner
        let mapping = planner?.decodedTodoPropsMapping ?? TodoPropsMapping()
        let reportMapping = planner?.decodedReportPropsMapping ?? ReportPropsMapping()

        // 마이그레이션 실패 시 폴백: UserDefaults 레거시 키에서 직접 읽기
        let prefix = "kr.nock.TodoReport."
        let pid = planner?.id ?? ""
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
        if let memo = todo.memo                                                          { body["memo"] = memo }
        if let v = planner?.notionTodoDBId   ?? legacyString("todoDBId")                { body["dbId"] = v }
        if let v = mapping.completed         ?? legacyTodo?.completed                   { body["completedProp"] = v }
        if let v = mapping.date              ?? legacyTodo?.date                        { body["dateProp"] = v }
        if let v = mapping.memo              ?? legacyTodo?.memo                        { body["memoProp"] = v }
        if let v = mapping.isPinned          ?? legacyTodo?.isPinned                    { body["isPinnedProp"] = v }
        if let v = planner?.notionReportDBId ?? legacyString("reportDBId")              { body["reportDBId"] = v }
        if let v = mapping.reportRelation    ?? legacyTodo?.reportRelation              { body["reportRelationProp"] = v }
        if let v = reportMapping.date        ?? legacyReport?.date                      { body["reportDateProp"] = v }

        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    private func seoulDateString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Asia/Seoul")
        return fmt.string(from: date)
    }
}
