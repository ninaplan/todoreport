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
        self.categoryId = categoryId
        self.notionPageId = notionPageId
        self.plannerId = plannerId
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
        let captured = t
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
