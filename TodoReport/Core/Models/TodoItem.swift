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

    init(
        id: String = UUID().uuidString,
        title: String,
        memo: String? = nil,
        isCompleted: Bool = false,
        isPinned: Bool = false,
        date: Date = .now,
        categoryId: String? = nil,
        notionPageId: String = ""
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
    }

    func toTodo() -> Todo {
        Todo(
            id: id,
            title: title,
            memo: memo,
            isCompleted: isCompleted,
            isPinned: isPinned,
            date: date,
            categoryId: categoryId,
            notionPageId: notionPageId
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
    }

    static func from(_ todo: Todo) -> TodoItem {
        TodoItem(
            id: todo.id,
            title: todo.title,
            memo: todo.memo,
            isCompleted: todo.isCompleted,
            isPinned: todo.isPinned,
            date: todo.date,
            categoryId: todo.categoryId,
            notionPageId: todo.notionPageId
        )
    }
}
