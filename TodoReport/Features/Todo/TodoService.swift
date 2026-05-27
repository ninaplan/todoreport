import Foundation

// 1파일 1타입 원칙상 별도 모델 파일이 맞으나 MVP 단계에서 TodoService와 함께 관리
struct Todo: Identifiable, Codable {
    let id: String
    var title: String
    var memo: String?
    var isCompleted: Bool
    var date: Date
    var categoryId: String?
    var notionPageId: String

    init(
        id: String = UUID().uuidString,
        title: String,
        memo: String? = nil,
        isCompleted: Bool = false,
        date: Date = .now,
        categoryId: String? = nil,
        notionPageId: String = ""
    ) {
        self.id = id
        self.title = title
        self.memo = memo
        self.isCompleted = isCompleted
        self.date = date
        self.categoryId = categoryId
        self.notionPageId = notionPageId
    }
}

final class TodoService {
    static let shared = TodoService()
    private init() {}

    private let apiClient = APIClient.shared

    func fetchTodos(for date: Date) async -> [Todo] {
        // TODO: APIClient로 백엔드 호출 → SwiftData 캐싱
        return Self.dummyTodos(for: date)
    }

    func incompleteTodoCount(for categoryId: String) async -> Int {
        let todos = await fetchTodos(for: .now)
        return todos.filter { $0.categoryId == categoryId && !$0.isCompleted }.count
    }

    func saveTodo(_ todo: Todo) async throws {
        // Offline-First:
        // 1. SwiftData 즉시 저장 (TODO)
        // 2. SyncManager.shared.enqueue(.createTodo(todo))
    }

    func updateTodo(_ todo: Todo) async throws {
        // 1. SwiftData 즉시 업데이트 (TODO)
        // 2. SyncManager.shared.enqueue(.updateTodo(todo))
    }

    func deleteTodo(id: String) async throws {
        // 1. SwiftData 즉시 삭제 (TODO)
        // 2. SyncManager.shared.enqueue(.deleteTodo(id))
    }

    private static func dummyTodos(for date: Date) -> [Todo] {
        [
            Todo(id: "1", title: "수학 문제 풀기", isCompleted: true,  date: date, categoryId: "cat-1"),
            Todo(id: "2", title: "영어 단어 30개", isCompleted: true,  date: date, categoryId: "cat-2"),
            Todo(id: "3", title: "독서 30분",      isCompleted: false, date: date, categoryId: "cat-3"),
            Todo(id: "4", title: "운동하기",        isCompleted: false, date: date, categoryId: "cat-4"),
            Todo(id: "5", title: "장보기",          isCompleted: false, date: date),
        ]
    }
}
