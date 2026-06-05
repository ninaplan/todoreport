import Foundation
import SwiftData

// MARK: - Todo 모델

struct Todo: Identifiable, Codable {
    let id: String
    var title: String
    var memo: String?
    var isCompleted: Bool
    var isPinned: Bool
    var date: Date
    var createdAt: Date
    var completedAt: Date?
    var notionCreatedAt: Date?
    var categoryId: String?
    var notionPageId: String
    var plannerId: String?
    var scheduledTime: Date?
    var alarmOffset: Int?
    var recurrenceRule: RecurrenceRule?
    var recurrenceId: String?
    var recurrenceEndDate: Date?
    var recurrenceCount: Int?
    var notionRelationLinked: Bool

    init(
        id: String = UUID().uuidString,
        title: String,
        memo: String? = nil,
        isCompleted: Bool = false,
        isPinned: Bool = false,
        date: Date = .now,
        createdAt: Date = .now,
        completedAt: Date? = nil,
        notionCreatedAt: Date? = nil,
        categoryId: String? = nil,
        notionPageId: String = "",
        plannerId: String? = nil,
        scheduledTime: Date? = nil,
        alarmOffset: Int? = nil,
        recurrenceRule: RecurrenceRule? = nil,
        recurrenceId: String? = nil,
        recurrenceEndDate: Date? = nil,
        recurrenceCount: Int? = nil,
        notionRelationLinked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.memo = memo
        self.isCompleted = isCompleted
        self.isPinned = isPinned
        self.date = date
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.notionCreatedAt = notionCreatedAt
        self.categoryId = categoryId
        self.notionPageId = notionPageId
        self.plannerId = plannerId
        self.scheduledTime = scheduledTime
        self.alarmOffset = alarmOffset
        self.recurrenceRule = recurrenceRule
        self.recurrenceId = recurrenceId
        self.recurrenceEndDate = recurrenceEndDate
        self.recurrenceCount = recurrenceCount
        self.notionRelationLinked = notionRelationLinked
    }
}

// MARK: - TodoService

final class TodoService {
    static let shared = TodoService()
    private init() {}

    private var context: ModelContext { PersistenceController.shared.context }

    func fetchTodos(for date: Date) async -> [Todo] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        let plannerId = PlannerService.shared.selectedPlanner?.id
        do {
            let descriptor = FetchDescriptor<TodoItem>(
                predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            let items = try context.fetch(descriptor).map { $0.toTodo() }
            guard let pid = plannerId else { return items }
            return items.filter { $0.plannerId == pid || $0.plannerId == nil }
        } catch {
            return []
        }
    }

    func incompleteTodoCount(for categoryId: String) async -> Int {
        let todos = await fetchTodos(for: .now)
        return todos.filter { $0.categoryId == categoryId && !$0.isCompleted }.count
    }

    func saveTodo(_ todo: Todo) async throws {
        var t = todo
        if t.plannerId == nil {
            t.plannerId = PlannerService.shared.selectedPlanner?.id
        }
        let id = t.id
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        guard (try context.fetch(descriptor)).isEmpty else { return }
        context.insert(TodoItem.from(t))
        try context.save()
        ensureDailyReport(for: t.date)
        print("[TodoService] 💾 saveTodo - id:\(t.id) scheduledTime:\(String(describing: t.scheduledTime)) alarmOffset:\(String(describing: t.alarmOffset))")
        TodoNotificationManager.shared.schedule(for: t)
        let captured = t
        Task { @MainActor in SyncQueueManager.shared.enqueueTodoCreate(captured) }
    }

    func updateTodo(_ todo: Todo) async throws {
        let id = todo.id
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        let dateChanged = !Calendar.current.isDate(item.date, inSameDayAs: todo.date)
        item.update(from: todo)
        if dateChanged {
            item.notionRelationLinked = false
            removeFromLinkedIds(notionPageId: item.notionPageId)
        }
        try context.save()
        ensureDailyReport(for: todo.date)
        print("[TodoService] ✏️ updateTodo - id:\(todo.id) scheduledTime:\(String(describing: todo.scheduledTime)) alarmOffset:\(String(describing: todo.alarmOffset))")
        TodoNotificationManager.shared.schedule(for: todo)
        let captured = item.toTodo()
        Task { @MainActor in SyncQueueManager.shared.enqueueTodoUpdate(captured) }
    }

    private func removeFromLinkedIds(notionPageId: String) {
        guard !notionPageId.isEmpty else { return }
        let key = "reportLinkedNotionIds"
        var ids = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        ids.remove(notionPageId)
        UserDefaults.standard.set(Array(ids), forKey: key)
    }

    func deleteTodo(id: String) async throws {
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        let notionPageId = item.notionPageId
        let plannerId = item.plannerId
        context.delete(item)
        try context.save()
        TodoNotificationManager.shared.cancel(for: id)
        Task { @MainActor in SyncQueueManager.shared.enqueueTodoDelete(notionPageId: notionPageId, plannerId: plannerId) }
    }

    func deleteFutureItems(recurrenceId: String, from date: Date) async throws {
        let fromDate = Calendar.current.startOfDay(for: date)
        let allItems = try context.fetch(FetchDescriptor<TodoItem>())
        let toDelete = allItems.filter {
            $0.recurrenceId == recurrenceId &&
            Calendar.current.startOfDay(for: $0.date) >= fromDate
        }
        let deletions: [(notionPageId: String, plannerId: String?)] = toDelete.compactMap {
            guard !$0.notionPageId.isEmpty else { return nil }
            return ($0.notionPageId, $0.plannerId)
        }
        let todoIds = toDelete.map { $0.id }
        toDelete.forEach { context.delete($0) }
        try context.save()
        todoIds.forEach { TodoNotificationManager.shared.cancel(for: $0) }
        Task { @MainActor in
            deletions.forEach {
                SyncQueueManager.shared.enqueueTodoDelete(notionPageId: $0.notionPageId, plannerId: $0.plannerId)
            }
        }
    }

    // MARK: - Notion Sync

    func syncTodosFromNotion(for date: Date) async {
        let planner = PlannerService.shared.selectedPlanner
        guard planner?.isNotionConnected == true,
              let dbId = planner?.notionTodoDBId else { return }
        let pid = planner?.id
        let mapping = planner?.decodedTodoPropsMapping ?? TodoPropsMapping()
        let token = planner?.resolvedNotionToken

        var params: [String: String] = ["date": seoulDateString(from: date), "dbId": dbId]
        if let v = mapping.completed { params["completedProp"] = v }
        if let v = mapping.date      { params["dateProp"] = v }
        if let v = mapping.isPinned  { params["isPinnedProp"] = v }

        do {
            let notionTodos: [NotionTodoResponse] = try await APIClient.shared.get(
                "/api/notion/todo", params: params, token: token
            )
            guard !Task.isCancelled else { return }
            print("[TodoService] 🔄 Notion fetch - \(seoulDateString(from: date)) \(notionTodos.count)개")
            upsertFromNotion(notionTodos, for: date, plannerId: pid)
        } catch {
            print("[TodoService] ⚠️ Notion sync 실패 - \(error.localizedDescription)")
        }
    }

    private func upsertFromNotion(_ notionTodos: [NotionTodoResponse], for date: Date, plannerId: String?) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let iso8601: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }()

        for nt in notionTodos {
            let parsedNotionCreatedAt: Date? = nt.createdAt.flatMap { iso8601.date(from: $0) }

            // 1순위: notionPageId 기준 매칭
            let pageId = nt.notionPageId
            let byPageId = FetchDescriptor<TodoItem>(
                predicate: #Predicate { $0.notionPageId == pageId }
            )
            if let existing = try? context.fetch(byPageId).first {
                // pending 작업 중인 항목은 어떤 필드도 노션 결과로 덮어쓰지 않음
                guard !SyncQueueManager.shared.hasPendingOperation(for: pageId) else { continue }
                existing.title = nt.title
                existing.memo = nt.memo
                if let nc = parsedNotionCreatedAt { existing.notionCreatedAt = nc }
                existing.isCompleted = nt.isCompleted
                existing.isPinned = nt.isPinned
                continue
            }

            // 2순위: notionPageId 없는 로컬 항목 중 title + date 기준 매칭
            let title = nt.title
            let byTitleDate = FetchDescriptor<TodoItem>(
                predicate: #Predicate {
                    $0.title == title &&
                    $0.date >= startOfDay &&
                    $0.date < endOfDay &&
                    $0.notionPageId == ""
                }
            )
            if let existing = try? context.fetch(byTitleDate).first {
                // notionPageId는 항상 연결
                existing.notionPageId = nt.notionPageId
                // pending 작업 중인 항목의 나머지 필드는 덮어쓰지 않음
                if !SyncQueueManager.shared.hasPendingOperation(for: nt.notionPageId) {
                    existing.memo = nt.memo
                    if let nc = parsedNotionCreatedAt { existing.notionCreatedAt = nc }
                    existing.isCompleted = nt.isCompleted
                    existing.isPinned = nt.isPinned
                }
                continue
            }

            // 신규 insert
            let todo = Todo(
                title: nt.title,
                memo: nt.memo,
                isCompleted: nt.isCompleted,
                isPinned: nt.isPinned,
                date: startOfDay,
                notionCreatedAt: parsedNotionCreatedAt,
                notionPageId: nt.notionPageId,
                plannerId: plannerId
            )
            context.insert(TodoItem.from(todo))
        }

        // Notion 응답에 없는 항목 삭제 (notionPageId 있는 항목만 — pending 항목은 제외)
        let notionPageIds = Set(notionTodos.map { $0.notionPageId })
        let allDescriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate {
                $0.date >= startOfDay && $0.date < endOfDay && $0.notionPageId != ""
            }
        )
        if let allItems = try? context.fetch(allDescriptor) {
            let gracePeriodCutoff = Date().addingTimeInterval(-300)  // Notion 전파 지연 대비 5분 유예
            let toDelete = allItems.filter {
                !notionPageIds.contains($0.notionPageId) &&
                $0.createdAt < gracePeriodCutoff &&
                !SyncQueueManager.shared.hasPendingOperation(for: $0.notionPageId)
            }
            toDelete.forEach { context.delete($0) }
            if !toDelete.isEmpty {
                print("[TodoService] 🗑️ Notion에 없는 항목 \(toDelete.count)개 삭제")
            }
        }

        try? context.save()

        // relation 미연결 항목 update 시도
        // UserDefaults로 "이미 연결됨" 추적 → 한 번 연결 후 재시도 안 함
        let linkedKey = "reportLinkedNotionIds"
        let linkedIds = Set(UserDefaults.standard.stringArray(forKey: linkedKey) ?? [])
        let unlinked = notionTodos.filter { !linkedIds.contains($0.notionPageId) }
        guard !unlinked.isEmpty else { return }

        let itemsToLink: [Todo] = unlinked.compactMap { nt in
            let pid = nt.notionPageId
            let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.notionPageId == pid })
            guard let item = try? context.fetch(descriptor).first else { return nil }
            return item.toTodo()
        }

        guard !itemsToLink.isEmpty else { return }
        var newLinkedIds = linkedIds
        for nt in unlinked { newLinkedIds.insert(nt.notionPageId) }
        Task { @MainActor in
            for todo in itemsToLink {
                SyncQueueManager.shared.enqueueTodoUpdate(todo)
            }
            print("[TodoService] 🔗 relation 연결 enqueue \(itemsToLink.count)개")
            UserDefaults.standard.set(Array(newLinkedIds), forKey: linkedKey)
        }
    }

    private func seoulDateString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Asia/Seoul")
        return fmt.string(from: date)
    }

    // MARK: - Private

    private func ensureDailyReport(for date: Date) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        let plannerId = PlannerService.shared.selectedPlanner?.id
        let descriptor = FetchDescriptor<DailyReportItem>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        guard let existing = try? context.fetch(descriptor) else { return }
        let hasReport = existing.contains { $0.plannerId == plannerId }
        guard !hasReport else { return }
        let item = DailyReportItem(date: startOfDay, plannerId: plannerId)
        context.insert(item)
        try? context.save()
    }
}

// MARK: - Notion Response

private struct NotionTodoResponse: Decodable {
    let id: String
    let title: String
    let isCompleted: Bool
    let date: String
    let memo: String?
    let isPinned: Bool
    let notionPageId: String
    let createdAt: String?
}
