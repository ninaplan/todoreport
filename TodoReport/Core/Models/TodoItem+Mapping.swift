import Foundation

extension TodoItem {
    convenience init(
        id: String = UUID().uuidString,
        title: String,
        memo: String? = nil,
        isCompleted: Bool = false,
        isPinned: Bool = false,
        date: Date = .now,
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
        notionRelationLinked: Bool = false
    ) {
        self.init(
            id: id,
            title: title,
            memo: memo,
            isCompleted: isCompleted,
            isPinned: isPinned,
            date: date,
            completedAt: completedAt,
            notionCreatedAt: notionCreatedAt,
            notionLastEditedTime: notionLastEditedTime,
            categoryId: categoryId,
            notionPageId: notionPageId,
            plannerId: plannerId,
            scheduledTime: scheduledTime,
            alarmOffset: alarmOffset,
            recurrenceData: recurrenceRule.flatMap { try? JSONEncoder().encode($0) },
            recurrenceId: recurrenceId,
            recurrenceEndDate: recurrenceEndDate,
            recurrenceCount: recurrenceCount,
            notionRelationLinked: notionRelationLinked
        )
    }

    var decodedRecurrence: RecurrenceRule? {
        guard let data = recurrenceData else { return nil }
        return try? JSONDecoder().decode(RecurrenceRule.self, from: data)
    }

    func toTodo() -> Todo {
        Todo(
            id: id, title: title, memo: memo,
            isCompleted: isCompleted, isPinned: isPinned,
            date: date, createdAt: createdAt,
            completedAt: completedAt, notionCreatedAt: notionCreatedAt,
            notionLastEditedTime: notionLastEditedTime,
            categoryId: categoryId, notionPageId: notionPageId,
            plannerId: plannerId, scheduledTime: scheduledTime,
            alarmOffset: alarmOffset,
            recurrenceRule: decodedRecurrence,
            recurrenceId: recurrenceId,
            recurrenceEndDate: recurrenceEndDate,
            recurrenceCount: recurrenceCount,
            notionRelationLinked: notionRelationLinked
        )
    }

    func update(from todo: Todo) {
        title = todo.title
        memo = todo.memo
        isCompleted = todo.isCompleted
        isPinned = todo.isPinned
        date = todo.date
        completedAt = todo.completedAt
        categoryId = todo.categoryId
        scheduledTime = todo.scheduledTime
        alarmOffset = todo.alarmOffset
        recurrenceData = todo.recurrenceRule.flatMap { try? JSONEncoder().encode($0) }
        recurrenceId = todo.recurrenceId
        recurrenceEndDate = todo.recurrenceEndDate
        recurrenceCount = todo.recurrenceCount
        // sync 관련 필드는 호출자 객체를 신뢰하지 않음 — SyncQueue/Notion이 단독 관리
        // notionPageId: SyncQueueProcessor.updateNotionPageId() 가 세팅
        // notionRelationLinked: updateTodo(dateChanged) / NotionRelationLinker 가 관리
        // notionCreatedAt: Notion에서 내려온 값만 신뢰 (upsertFromNotion에서 직접 세팅)
        // notionLastEditedTime: SyncQueueProcessor의 push 성공 시 / upsertFromNotion의 pull 시에만 세팅
        // plannerId: 생성 시 고정 — 플래너 이동 기능 구현 시 별도 메서드로 처리
    }

    static func from(_ todo: Todo) -> TodoItem {
        TodoItem(
            id: todo.id, title: todo.title, memo: todo.memo,
            isCompleted: todo.isCompleted, isPinned: todo.isPinned,
            date: todo.date, completedAt: todo.completedAt,
            notionCreatedAt: todo.notionCreatedAt,
            notionLastEditedTime: todo.notionLastEditedTime,
            categoryId: todo.categoryId,
            notionPageId: todo.notionPageId, plannerId: todo.plannerId,
            scheduledTime: todo.scheduledTime, alarmOffset: todo.alarmOffset,
            recurrenceData: todo.recurrenceRule.flatMap { try? JSONEncoder().encode($0) },
            recurrenceId: todo.recurrenceId,
            recurrenceEndDate: todo.recurrenceEndDate,
            recurrenceCount: todo.recurrenceCount,
            notionRelationLinked: todo.notionRelationLinked
        )
    }
}
