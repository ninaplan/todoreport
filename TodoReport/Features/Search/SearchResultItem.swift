import Foundation

enum SearchResultItem: Identifiable {
    case todo(Todo)
    case review(id: String, date: Date, text: String, plannerId: String?)

    var id: String {
        switch self {
        case .todo(let todo):
            return "todo-\(todo.id)"
        case .review(let id, _, _, _):
            return "review-\(id)"
        }
    }

    var plannerId: String? {
        switch self {
        case .todo(let todo):
            return todo.plannerId
        case .review(_, _, _, let plannerId):
            return plannerId
        }
    }

    var sortDate: Date {
        switch self {
        case .todo(let todo):
            return todo.date ?? todo.createdAt
        case .review(_, let date, _, _):
            return date
        }
    }
}
