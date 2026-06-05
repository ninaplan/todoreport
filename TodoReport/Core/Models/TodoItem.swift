import SwiftData
import Foundation

@Model
final class TodoItem {
    @Attribute(.unique) var id: String
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
    var recurrenceData: Data?
    var recurrenceId: String?
    var recurrenceEndDate: Date?
    var recurrenceCount: Int?
    var notionRelationLinked: Bool = false

    var decodedRecurrence: RecurrenceRule? {
        guard let data = recurrenceData else { return nil }
        return try? JSONDecoder().decode(RecurrenceRule.self, from: data)
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        memo: String? = nil,
        isCompleted: Bool = false,
        isPinned: Bool = false,
        date: Date = .now,
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
        self.createdAt = .now
        self.completedAt = completedAt
        self.notionCreatedAt = notionCreatedAt
        self.categoryId = categoryId
        self.notionPageId = notionPageId
        self.plannerId = plannerId
        self.scheduledTime = scheduledTime
        self.alarmOffset = alarmOffset
        self.recurrenceData = recurrenceRule.flatMap { try? JSONEncoder().encode($0) }
        self.recurrenceId = recurrenceId
        self.recurrenceEndDate = recurrenceEndDate
        self.recurrenceCount = recurrenceCount
        self.notionRelationLinked = notionRelationLinked
    }

    func toTodo() -> Todo {
        Todo(
            id: id, title: title, memo: memo,
            isCompleted: isCompleted, isPinned: isPinned,
            date: date, createdAt: createdAt,
            completedAt: completedAt, notionCreatedAt: notionCreatedAt,
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
        // plannerId: 생성 시 고정 — 플래너 이동 기능 구현 시 별도 메서드로 처리
    }

    static func from(_ todo: Todo) -> TodoItem {
        TodoItem(
            id: todo.id, title: todo.title, memo: todo.memo,
            isCompleted: todo.isCompleted, isPinned: todo.isPinned,
            date: todo.date, completedAt: todo.completedAt,
            notionCreatedAt: todo.notionCreatedAt,
            categoryId: todo.categoryId,
            notionPageId: todo.notionPageId, plannerId: todo.plannerId,
            scheduledTime: todo.scheduledTime, alarmOffset: todo.alarmOffset,
            recurrenceRule: todo.recurrenceRule,
            recurrenceId: todo.recurrenceId,
            recurrenceEndDate: todo.recurrenceEndDate,
            recurrenceCount: todo.recurrenceCount,
            notionRelationLinked: todo.notionRelationLinked
        )
    }
}
