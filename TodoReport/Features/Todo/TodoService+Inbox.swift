import Foundation
import SwiftData

// MARK: - Inbox Notion Response (date always null)

/// 인박스 GET 전용. 기존 `NotionTodoResponse`(date: String 필수)와 분리.
private struct NotionInboxTodoResponse: Decodable {
    let id: String
    let title: String
    let isCompleted: Bool
    let date: String?
    let memo: String?
    let isPinned: Bool
    let categoryName: String?
    let notionPageId: String
    let createdAt: String?
    let lastEditedTime: String?
}

// MARK: - TodoService Inbox

extension TodoService {
    private var inboxContext: ModelContext { PersistenceController.shared.context }

    /// 로컬 SwiftData에서 date == nil 인박스 목록. 노션 연결 시 백그라운드 GET /inbox 동기화.
    func fetchInboxTodos() async -> [Todo] {
        let local = loadLocalInboxTodos()
        let planner = PlannerService.shared.selectedPlanner
        if planner?.isNotionConnected == true {
            Task {
                await syncInboxFromNotion()
            }
        }
        return local
    }

    /// 「지금」 탭에 해당하는 인박스 개수 (완료·스누즈 유효 항목 제외). 배지용 동기 조회.
    func inboxNowCount() -> Int {
        loadLocalInboxTodos().filter { !$0.isCompleted && !$0.isSnoozeActive }.count
    }

    /// 인박스 스누즈만 로컬 저장. SyncQueue/노션에 올리지 않음.
    func setInboxSnooze(id: String, until: Date?) throws {
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        guard let item = try inboxContext.fetch(descriptor).first else { return }
        item.snoozedUntil = until
        item.localModifiedAt = .now
        try inboxContext.save()
    }

    /// 인박스 항목 생성 — Offline-First (date nil, 선택 플래너 배정) → SyncQueue createInbox.
    func saveInboxTodo(title: String, memo: String? = nil, categoryId: String? = nil) async throws -> Todo {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw InboxTodoError.emptyTitle
        }
        var todo = Todo(
            title: trimmed,
            memo: memo,
            date: nil,
            categoryId: categoryId,
            plannerId: PlannerService.shared.selectedPlanner?.id,
            localModifiedAt: .now
        )
        if todo.plannerId == nil {
            todo.plannerId = PlannerService.shared.selectedPlanner?.id
        }
        let id = todo.id
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        guard (try inboxContext.fetch(descriptor)).isEmpty else { return todo }
        inboxContext.insert(TodoItem.from(todo))
        try inboxContext.save()
        print("[TodoService] 📥 saveInboxTodo - id:\(todo.id) plannerId:\(todo.plannerId ?? "nil")")
        let captured = todo
        Task { @MainActor in SyncQueueManager.shared.enqueueInboxTodoCreate(captured) }
        return todo
    }

    /// 노션 인박스 pull → 로컬 upsert (date는 항상 nil 유지).
    @discardableResult
    func syncInboxFromNotion() async -> Bool? {
        let planner = PlannerService.shared.selectedPlanner
        guard planner?.isNotionConnected == true,
              let dbId = planner?.notionTodoDBId else { return nil }
        let pid = planner?.id
        let mapping = planner?.decodedTodoPropsMapping ?? TodoPropsMapping()
        let token = planner?.resolvedNotionToken

        var params: [String: String] = ["dbId": dbId]
        if let pid { params["plannerId"] = pid }
        if let v = mapping.completed { params["completedProp"] = v }
        if let v = mapping.date { params["dateProp"] = v }
        if let v = mapping.isPinned { params["isPinnedProp"] = v }
        if let planner {
            params.merge(CategoryNotionSync.shared.todoFetchParams(from: planner)) { _, new in new }
        }

        do {
            let notionTodos: [NotionInboxTodoResponse] = try await APIClient.shared.get(
                "/api/notion/todo/inbox", params: params, token: token
            )
            guard !Task.isCancelled else { return nil }
            print("[TodoService] 📥 Notion inbox fetch - \(notionTodos.count)개")
            upsertInboxFromNotion(notionTodos, plannerId: pid)
            return true
        } catch {
            print("[TodoService] ⚠️ Notion inbox sync 실패 - \(error.localizedDescription)")
            AppLogger.shared.warn("TodoService", "Notion inbox sync 실패 - \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private

    private func loadLocalInboxTodos() -> [Todo] {
        let plannerId = PlannerService.shared.selectedPlanner?.id
        do {
            let descriptor = FetchDescriptor<TodoItem>(
                predicate: #Predicate { $0.date == nil },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let items = try inboxContext.fetch(descriptor).map { $0.toTodo() }
            guard let pid = plannerId else { return items }
            return items.filter { $0.plannerId == pid || $0.plannerId == nil }
        } catch {
            return []
        }
    }

    private func upsertInboxFromNotion(
        _ notionTodos: [NotionInboxTodoResponse],
        plannerId: String?
    ) {
        let iso8601: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }()

        for nt in notionTodos {
            let parsedNotionCreatedAt: Date? = nt.createdAt.flatMap { iso8601.date(from: $0) }
            let pageId = nt.notionPageId

            if let existing = findExistingByNotionPageIdForInbox(pageId, plannerId: plannerId) {
                applyInboxNotionResponse(nt, to: existing, plannerId: plannerId, parsedNotionCreatedAt: parsedNotionCreatedAt)
                continue
            }

            let title = nt.title
            let byTitle = FetchDescriptor<TodoItem>(
                predicate: #Predicate {
                    $0.title == title &&
                    $0.date == nil &&
                    $0.notionPageId == ""
                }
            )
            if let candidates = try? inboxContext.fetch(byTitle),
               let existing = candidates.first(where: { itemBelongsToInboxPlanner($0, plannerId: plannerId) }) {
                existing.notionPageId = pageId
                if !isLocallyProtectedFromInboxOverwrite(existing) {
                    applyInboxNotionResponse(nt, to: existing, plannerId: plannerId, parsedNotionCreatedAt: parsedNotionCreatedAt)
                }
                continue
            }

            if let existing = findExistingByNotionPageIdForInbox(pageId, plannerId: plannerId) {
                applyInboxNotionResponse(nt, to: existing, plannerId: plannerId, parsedNotionCreatedAt: parsedNotionCreatedAt)
                continue
            }

            let categoryId = CategoryNotionSync.shared.applyCategoryFromNotion(
                name: nt.categoryName, plannerId: plannerId
            )
            let todo = Todo(
                title: nt.title,
                memo: nt.memo,
                isCompleted: nt.isCompleted,
                isPinned: nt.isPinned,
                date: nil,
                notionCreatedAt: parsedNotionCreatedAt,
                notionLastEditedTime: parseInboxLastEditedTime(nt.lastEditedTime),
                categoryId: categoryId,
                notionPageId: pageId,
                plannerId: plannerId
            )
            inboxContext.insert(TodoItem.from(todo))
        }

        try? inboxContext.save()
    }

    private func findExistingByNotionPageIdForInbox(_ pageId: String, plannerId: String?) -> TodoItem? {
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.notionPageId == pageId }
        )
        guard let items = try? inboxContext.fetch(descriptor) else { return nil }
        return items.first { itemBelongsToInboxPlanner($0, plannerId: plannerId) }
    }

    private func itemBelongsToInboxPlanner(_ item: TodoItem, plannerId: String?) -> Bool {
        guard let plannerId else { return item.plannerId == nil }
        return item.plannerId == plannerId || item.plannerId == nil
    }

    private func isLocallyProtectedFromInboxOverwrite(_ item: TodoItem, now: Date = .now) -> Bool {
        if !item.notionPageId.isEmpty,
           SyncQueueManager.shared.hasPendingOperation(for: item.notionPageId) {
            return true
        }
        if SyncQueueManager.shared.hasPendingCreate(for: item.id)
            || SyncQueueManager.shared.hasPendingUpdate(for: item.id) {
            return true
        }
        if let localModifiedAt = item.localModifiedAt,
           now.timeIntervalSince(localModifiedAt) < 60 {
            return true
        }
        return false
    }

    private func applyInboxNotionResponse(
        _ nt: NotionInboxTodoResponse,
        to existing: TodoItem,
        plannerId: String?,
        parsedNotionCreatedAt: Date?
    ) {
        guard !isLocallyProtectedFromInboxOverwrite(existing) else { return }

        let incomingLastEditedTime = parseInboxLastEditedTime(nt.lastEditedTime)
        if let incoming = incomingLastEditedTime,
           let existingLastEditedTime = existing.notionLastEditedTime,
           incoming < existingLastEditedTime {
            print("[TodoService] ⏭️ inbox stale skip - pageId:\(nt.notionPageId)")
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
        // 인박스: 날짜·시간·리포트 relation 없음
        existing.date = nil
        existing.scheduledTime = nil
        if let incoming = incomingLastEditedTime {
            existing.notionLastEditedTime = incoming
        }
        if existing.plannerId == nil, let plannerId {
            existing.plannerId = plannerId
        }
    }

    private func parseInboxLastEditedTime(_ string: String?) -> Date? {
        guard let string else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: string) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: string)
    }
}

enum InboxTodoError: Error {
    case emptyTitle
}
