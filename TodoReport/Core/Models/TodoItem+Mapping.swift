import Foundation

extension TodoItem {
    /// 목록·동기화는 `recurrenceId`만 쓴다. 규칙 본체는 caller가 이미 가진 `RecurringSeries`를 넘길 때만 붙인다.
    func toTodo(series: RecurringSeries? = nil) -> Todo {
        let attached = (series?.id == recurrenceId) ? series : nil
        return Todo(
            id: id, title: title, memo: memo,
            isCompleted: isCompleted, isPinned: isPinned,
            date: date, createdAt: createdAt,
            completedAt: completedAt, notionCreatedAt: notionCreatedAt,
            notionLastEditedTime: notionLastEditedTime,
            categoryId: categoryId, notionPageId: notionPageId,
            plannerId: plannerId, scheduledTime: scheduledTime,
            alarmOffset: alarmOffset,
            recurrenceRule: attached?.decodedRule,
            recurrenceId: recurrenceId,
            recurrenceEndDate: attached?.endDate,
            recurrenceCount: attached?.occurrenceLimit,
            notionRelationLinked: notionRelationLinked,
            snoozedUntil: snoozedUntil
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
        recurrenceId = todo.recurrenceId
        recurrenceData = nil
        recurrenceEndDate = nil
        recurrenceCount = nil
        snoozedUntil = todo.snoozedUntil
        // sync 관련 필드는 호출자 객체를 신뢰하지 않음 — SyncQueue/Notion이 단독 관리
        // notionPageId: SyncQueueProcessor.updateNotionPageId() 가 세팅
        // notionRelationLinked: updateTodo(dateChanged) / NotionRelationLinker 가 관리
        // notionCreatedAt: Notion에서 내려온 값만 신뢰 (upsertFromNotion에서 직접 세팅)
        // notionLastEditedTime: SyncQueueProcessor의 push 성공 시 / upsertFromNotion의 pull 시에만 세팅
        // plannerId: 생성 시 고정 — 플래너 이동 기능 구현 시 별도 메서드로 처리
        // snoozedUntil: 로컬 전용. 노션 payload에 넣지 않음
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
            recurrenceId: todo.recurrenceId,
            notionRelationLinked: todo.notionRelationLinked,
            snoozedUntil: todo.snoozedUntil
        )
    }
}
