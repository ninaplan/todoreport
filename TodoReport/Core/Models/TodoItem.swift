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
    var categoryId: String?
    var notionPageId: String
    var plannerId: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        memo: String? = nil,
        isCompleted: Bool = false,
        isPinned: Bool = false,
        date: Date = .now,
        categoryId: String? = nil,
        notionPageId: String = "",
        plannerId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.memo = memo
        self.isCompleted = isCompleted
        self.isPinned = isPinned
        self.date = date
        self.createdAt = .now
        self.categoryId = categoryId
        self.notionPageId = notionPageId
        self.plannerId = plannerId
    }

    func toTodo() -> Todo {
        Todo(
            id: id, title: title, memo: memo,
            isCompleted: isCompleted, isPinned: isPinned,
            date: date, categoryId: categoryId,
            notionPageId: notionPageId, plannerId: plannerId
        )
    }

    func update(from todo: Todo) {
        title = todo.title
        memo = todo.memo
        isCompleted = todo.isCompleted
        isPinned = todo.isPinned
        date = todo.date
        categoryId = todo.categoryId
        notionPageId = todo.notionPageId
        // plannerId는 생성 시 고정 — 플래너 이동 기능 구현 시 별도 메서드로 처리
    }

    static func from(_ todo: Todo) -> TodoItem {
        TodoItem(
            id: todo.id, title: todo.title, memo: todo.memo,
            isCompleted: todo.isCompleted, isPinned: todo.isPinned,
            date: todo.date, categoryId: todo.categoryId,
            notionPageId: todo.notionPageId, plannerId: todo.plannerId
        )
    }
}
