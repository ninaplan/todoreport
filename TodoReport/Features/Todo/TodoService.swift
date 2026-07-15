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
    var notionLastEditedTime: Date?
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
    /// 로컬에서 마지막으로 생성·수정된 시각 (Notion/캐시 지연 시 merge 보호용)
    var localModifiedAt: Date?

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
        notionLastEditedTime: Date? = nil,
        categoryId: String? = nil,
        notionPageId: String = "",
        plannerId: String? = nil,
        scheduledTime: Date? = nil,
        alarmOffset: Int? = nil,
        recurrenceRule: RecurrenceRule? = nil,
        recurrenceId: String? = nil,
        recurrenceEndDate: Date? = nil,
        recurrenceCount: Int? = nil,
        notionRelationLinked: Bool = false,
        localModifiedAt: Date? = nil
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
        self.notionLastEditedTime = notionLastEditedTime
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
        self.localModifiedAt = localModifiedAt
    }

    mutating func markLocallyModified(at date: Date = .now) {
        localModifiedAt = date
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
        item.localModifiedAt = .now
        if dateChanged {
            item.notionRelationLinked = false
        }
        try context.save()
        ensureDailyReport(for: todo.date)
        print("[TodoService] ✏️ updateTodo - id:\(todo.id) scheduledTime:\(String(describing: todo.scheduledTime)) alarmOffset:\(String(describing: todo.alarmOffset))")
        TodoNotificationManager.shared.schedule(for: todo)
        let captured = item.toTodo()
        Task { @MainActor in
            SyncQueueManager.shared.enqueueTodoUpdate(captured)
            if dateChanged, !captured.notionPageId.isEmpty {
                SyncQueueManager.shared.enqueueTodoRelationLink(captured)
            }
        }
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
        if let pid = pid { params["plannerId"] = pid }
        if let v = mapping.completed { params["completedProp"] = v }
        if let v = mapping.date      { params["dateProp"] = v }
        if let v = mapping.isPinned  { params["isPinnedProp"] = v }
        if let planner {
            params.merge(CategoryNotionSync.shared.todoFetchParams(from: planner)) { _, new in new }
        }

        do {
            let notionTodos: [NotionTodoResponse] = try await APIClient.shared.get(
                "/api/notion/todo", params: params, token: token
            )
            guard !Task.isCancelled else { return }
            print("[TodoService] 🔄 Notion fetch - \(seoulDateString(from: date)) \(notionTodos.count)개")
            upsertFromNotion(notionTodos, for: date, plannerId: pid)
        } catch {
            print("[TodoService] ⚠️ Notion sync 실패 - \(error.localizedDescription)")
            AppLogger.shared.warn("TodoService", "Notion sync 실패 - \(error.localizedDescription)")
        }
    }

    private static let localModificationProtectionInterval: TimeInterval = 60

    private func itemBelongsToSyncPlanner(_ item: TodoItem, plannerId: String?) -> Bool {
        guard let plannerId else { return item.plannerId == nil }
        return item.plannerId == plannerId || item.plannerId == nil
    }

    private func isLocallyProtectedFromNotionOverwrite(_ item: TodoItem, now: Date = .now) -> Bool {
        if !item.notionPageId.isEmpty,
           SyncQueueManager.shared.hasPendingOperation(for: item.notionPageId) {
            return true
        }
        if SyncQueueManager.shared.hasPendingCreate(for: item.id)
            || SyncQueueManager.shared.hasPendingUpdate(for: item.id) {
            return true
        }
        if let localModifiedAt = item.localModifiedAt,
           now.timeIntervalSince(localModifiedAt) < Self.localModificationProtectionInterval {
            return true
        }
        return false
    }

    private func findExistingByNotionPageId(_ pageId: String, plannerId: String?) -> TodoItem? {
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.notionPageId == pageId }
        )
        guard let items = try? context.fetch(descriptor) else { return nil }
        return items.first { itemBelongsToSyncPlanner($0, plannerId: plannerId) }
    }

    private func applyNotionTodoResponse(
        _ nt: NotionTodoResponse,
        to existing: TodoItem,
        plannerId: String?,
        parsedNotionCreatedAt: Date?
    ) {
        let pageId = nt.notionPageId
        guard !isLocallyProtectedFromNotionOverwrite(existing) else { return }

        let incomingLastEditedTime = parseLastEditedTime(nt.lastEditedTime)
        if let incoming = incomingLastEditedTime,
           let existingLastEditedTime = existing.notionLastEditedTime,
           incoming <= existingLastEditedTime {
            print("[TodoService] ⏭️ stale 응답 skip - pageId:\(pageId) incoming:\(incoming) existing:\(existingLastEditedTime)")
            return
        }

        existing.title = nt.title
        existing.memo = nt.memo
        if let nc = parsedNotionCreatedAt { existing.notionCreatedAt = nc }
        existing.isCompleted = nt.isCompleted
        existing.isPinned = nt.isPinned
        existing.categoryId = CategoryNotionSync.shared.applyCategoryFromNotion(
            name: nt.categoryName, plannerId: plannerId
        )
        applyNotionDate(to: existing, from: nt.date)
        if let incoming = incomingLastEditedTime {
            existing.notionLastEditedTime = incoming
        }
        if existing.plannerId == nil, let plannerId {
            existing.plannerId = plannerId
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
            let pageId = nt.notionPageId

            // 1순위: notionPageId + plannerId 기준 매칭
            if let existing = findExistingByNotionPageId(pageId, plannerId: plannerId) {
                applyNotionTodoResponse(nt, to: existing, plannerId: plannerId, parsedNotionCreatedAt: parsedNotionCreatedAt)
                continue
            }

            // 2순위: notionPageId 없는 로컬 항목 중 title + date + plannerId 기준 매칭
            let title = nt.title
            let byTitleDate = FetchDescriptor<TodoItem>(
                predicate: #Predicate {
                    $0.title == title &&
                    $0.date >= startOfDay &&
                    $0.date < endOfDay &&
                    $0.notionPageId == ""
                }
            )
            if let candidates = try? context.fetch(byTitleDate),
               let existing = candidates.first(where: { itemBelongsToSyncPlanner($0, plannerId: plannerId) }) {
                existing.notionPageId = pageId
                if !isLocallyProtectedFromNotionOverwrite(existing) {
                    applyNotionTodoResponse(nt, to: existing, plannerId: plannerId, parsedNotionCreatedAt: parsedNotionCreatedAt)
                }
                continue
            }

            // insert 직전: 같은 pageId 레코드가 있으면 갱신만 (삭제·재생성 방지)
            if let existing = findExistingByNotionPageId(pageId, plannerId: plannerId) {
                applyNotionTodoResponse(nt, to: existing, plannerId: plannerId, parsedNotionCreatedAt: parsedNotionCreatedAt)
                continue
            }

            let categoryId = CategoryNotionSync.shared.applyCategoryFromNotion(
                name: nt.categoryName, plannerId: plannerId
            )
            let parsedDate = parseNotionTodoDate(nt.date, fallback: startOfDay)
            let todo = Todo(
                title: nt.title,
                memo: nt.memo,
                isCompleted: nt.isCompleted,
                isPinned: nt.isPinned,
                date: parsedDate.date,
                notionCreatedAt: parsedNotionCreatedAt,
                notionLastEditedTime: parseLastEditedTime(nt.lastEditedTime),
                categoryId: categoryId,
                notionPageId: pageId,
                plannerId: plannerId,
                scheduledTime: parsedDate.scheduledTime
            )
            context.insert(TodoItem.from(todo))
        }

        try? context.save()

        // relation 미연결 항목 → relation 전용 enqueue (일반 update와 분리)
        let itemsToLink: [Todo] = notionTodos.compactMap { nt in
            guard let item = findExistingByNotionPageId(nt.notionPageId, plannerId: plannerId),
                  !item.notionRelationLinked else { return nil }
            return item.toTodo()
        }

        guard !itemsToLink.isEmpty else { return }
        Task { @MainActor in
            for todo in itemsToLink {
                SyncQueueManager.shared.enqueueTodoRelationLink(todo)
            }
            print("[TodoService] 🔗 relation 연결 enqueue \(itemsToLink.count)개")
        }
    }

    private func seoulDateString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Asia/Seoul")
        return fmt.string(from: date)
    }

    private struct NotionTodoDateFields {
        let date: Date
        let scheduledTime: Date?
    }

    /// Notion date 문자열 → `date`(startOfDay) + `scheduledTime`(ISO8601 시간 포함 시만).
    private func parseNotionTodoDate(_ dateString: String, fallback: Date) -> NotionTodoDateFields {
        let cal = Calendar.current
        let fallbackDay = cal.startOfDay(for: fallback)
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return NotionTodoDateFields(date: fallbackDay, scheduledTime: nil)
        }

        let seoul = TimeZone(identifier: "Asia/Seoul")

        if !trimmed.contains("T"), let dayOnly = parseNotionDayOnlyDate(trimmed, calendar: cal, timeZone: seoul) {
            return NotionTodoDateFields(date: dayOnly, scheduledTime: nil)
        }

        if let parsed = parseNotionDateTime(trimmed, timeZone: seoul) {
            return NotionTodoDateFields(
                date: cal.startOfDay(for: parsed),
                scheduledTime: parsed
            )
        }

        if let dayOnly = parseNotionDayOnlyDate(trimmed, calendar: cal, timeZone: seoul) {
            return NotionTodoDateFields(date: dayOnly, scheduledTime: nil)
        }

        return NotionTodoDateFields(date: fallbackDay, scheduledTime: nil)
    }

    private func parseNotionDayOnlyDate(
        _ string: String,
        calendar: Calendar,
        timeZone: TimeZone?
    ) -> Date? {
        let dayOnly = DateFormatter()
        dayOnly.dateFormat = "yyyy-MM-dd"
        dayOnly.locale = Locale(identifier: "en_US_POSIX")
        dayOnly.timeZone = timeZone
        if let parsed = dayOnly.date(from: string) {
            return calendar.startOfDay(for: parsed)
        }
        if string.count >= 10, let parsed = dayOnly.date(from: String(string.prefix(10))) {
            return calendar.startOfDay(for: parsed)
        }
        return nil
    }

    private func parseNotionDateTime(_ string: String, timeZone: TimeZone?) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.timeZone = timeZone
        let formatSets: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone],
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime, .withColonSeparatorInTimeZone],
            [.withInternetDateTime],
        ]
        for options in formatSets {
            iso.formatOptions = options
            if let parsed = iso.date(from: string) { return parsed }
        }
        return nil
    }

    private func parseLastEditedTime(_ string: String?) -> Date? {
        guard let string else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: string) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: string)
    }

    private func notionScheduledTimesEqual(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (left?, right?):
            let cal = Calendar.current
            let leftComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: left)
            let rightComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: right)
            return leftComponents == rightComponents
        default:
            return false
        }
    }

    /// pageId 매칭 기존 항목 — Notion date·scheduledTime 반영, 날짜 변경 시 relation 리셋
    private func applyNotionDate(to existing: TodoItem, from notionDateString: String) {
        let parsed = parseNotionTodoDate(notionDateString, fallback: existing.date)
        let cal = Calendar.current
        let dateChanged = !cal.isDate(existing.date, inSameDayAs: parsed.date)
        let hadScheduledTime = existing.scheduledTime != nil
        let scheduledTimeChanged = !notionScheduledTimesEqual(existing.scheduledTime, parsed.scheduledTime)

        guard dateChanged || scheduledTimeChanged else { return }

        existing.date = parsed.date
        existing.scheduledTime = parsed.scheduledTime
        if dateChanged {
            existing.notionRelationLinked = false
        }

        if parsed.scheduledTime != nil {
            TodoNotificationManager.shared.schedule(for: existing.toTodo())
        } else if hadScheduledTime {
            TodoNotificationManager.shared.cancel(for: existing.id)
        }
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
    let categoryName: String?
    let notionPageId: String
    let createdAt: String?
    let lastEditedTime: String?
}
