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
        self.categoryId = categoryId
        self.notionPageId = notionPageId
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
        do {
            let descriptor = FetchDescriptor<TodoItem>(
                predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            return try context.fetch(descriptor).map { $0.toTodo() }
        } catch {
            return []
        }
    }

    func incompleteTodoCount(for categoryId: String) async -> Int {
        let todos = await fetchTodos(for: .now)
        return todos.filter { $0.categoryId == categoryId && !$0.isCompleted }.count
    }

    func saveTodo(_ todo: Todo) async throws {
        // 중복 삽입 방지
        let id = todo.id
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        guard (try context.fetch(descriptor)).isEmpty else { return }
        context.insert(TodoItem.from(todo))
        try context.save()
        ensureDailyReport(for: todo.date)
        let captured = todo
        Task { @MainActor in SyncQueueManager.shared.enqueueTodoCreate(captured) }
    }

    func updateTodo(_ todo: Todo) async throws {
        let id = todo.id
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        item.update(from: todo)
        try context.save()
        ensureDailyReport(for: todo.date)
        let captured = todo
        Task { @MainActor in SyncQueueManager.shared.enqueueTodoUpdate(captured) }
    }

    func deleteTodo(id: String) async throws {
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        context.delete(item)
        try context.save()
        let captured = id
        Task { @MainActor in SyncQueueManager.shared.enqueueTodoDelete(id: captured) }
    }

    // MARK: - Private

    // 투두가 속한 날짜의 DailyReportItem이 없으면 자동 생성
    private func ensureDailyReport(for date: Date) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        let descriptor = FetchDescriptor<DailyReportItem>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        guard let existing = try? context.fetch(descriptor), existing.isEmpty else { return }
        let item = DailyReportItem(date: startOfDay)
        context.insert(item)
        try? context.save()
    }
}
