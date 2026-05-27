import Foundation

enum TodoSortOrder: String, CaseIterable {
    case addedOrder   = "추가한 순서"
    case categoryOrder = "카테고리순"
    case completedFirst = "완료 먼저"
}

@Observable
final class TodoViewModel {
    private(set) var todos: [Todo] = []
    private(set) var isLoading: Bool = false

    var plannerName: String = "내 플래너"
    var isViewOptionsVisible: Bool = false
    var hideCompleted: Bool = false
    var groupByCategory: Bool = false
    var sortOrder: TodoSortOrder = .addedOrder

    // selectedDate 변경 시 자동으로 투두 재조회
    var selectedDate: Date = .now {
        didSet { Task { await fetchTodos() } }
    }

    private let service: TodoService

    init(service: TodoService = TodoService()) {
        self.service = service
    }

    // MARK: - Computed

    var completionRate: Double {
        guard !todos.isEmpty else { return 0 }
        return Double(todos.filter(\.isCompleted).count) / Double(todos.count)
    }

    var displayedTodos: [Todo] {
        var result = todos
        if hideCompleted {
            result = result.filter { !$0.isCompleted }
        }
        switch sortOrder {
        case .addedOrder:
            break
        case .categoryOrder:
            result.sort { ($0.categoryId ?? "") < ($1.categoryId ?? "") }
        case .completedFirst:
            result.sort { $0.isCompleted && !$1.isCompleted }
        }
        return result
    }

    // MARK: - Data

    func fetchTodos() async {
        isLoading = true
        todos = await service.fetchTodos(for: selectedDate)
        isLoading = false
    }

    // MARK: - Actions

    func toggleTodo(_ todo: Todo) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        // Offline-First: 로컬 즉시 반영
        todos[index].isCompleted.toggle()
        let updated = todos[index]
        Task { try? await service.updateTodo(updated) }
    }

    func addTodo(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let todo = Todo(title: trimmed, date: selectedDate)
        // Offline-First: 로컬 즉시 추가
        todos.append(todo)
        Task { try? await service.saveTodo(todo) }
    }

    func deleteTodo(_ todo: Todo) {
        todos.removeAll { $0.id == todo.id }
        Task { try? await service.deleteTodo(id: todo.id) }
    }

    func moveToTomorrow(_ todo: Todo) {
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        var moved = todo
        moved.date = nextDay
        todos.removeAll { $0.id == todo.id }
        Task { try? await service.updateTodo(moved) }
    }

    func goToPreviousDay() {
        guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = prev  // didSet이 fetchTodos() 호출
    }

    func goToNextDay() {
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectedDate = next  // didSet이 fetchTodos() 호출
    }
}
