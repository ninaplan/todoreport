import Foundation

enum TodoSortOrder: String, CaseIterable {
    case addedOrder    = "추가한 순서"
    case categoryOrder = "카테고리순"
    case completedFirst = "완료 먼저"
}

@Observable
final class TodoViewModel {
    private(set) var todos: [Todo] = []
    private(set) var isLoading: Bool = false

    var plannerName: String { PlannerService.shared.selectedPlanner?.name ?? "내 플래너" }
    var isViewOptionsVisible: Bool = false
    var hideCompleted: Bool = false
    var showMemo: Bool = false
    var sortOrder: TodoSortOrder = .addedOrder
    var selectedCategoryFilter: String? = nil  // nil = 전체

    var selectedDate: Date = .now {
        didSet { Task { await fetchTodos() } }
    }

    private let service = TodoService.shared
    private let categoryService = CategoryService.shared

    // MARK: - Computed

    // CategoryService.shared(@Observable)를 직접 참조 → store 변경 시 뷰 자동 갱신
    var activeCategories: [Category] { categoryService.activeCategories }

    var completionRate: Double {
        guard !todos.isEmpty else { return 0 }
        return Double(todos.filter(\.isCompleted).count) / Double(todos.count)
    }

    private var todosForRate: [Todo] {
        guard let filterId = selectedCategoryFilter else { return todos }
        return todos.filter { $0.categoryId == filterId }
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
        result.sort { $0.isPinned && !$1.isPinned }
        return result
    }

    var filteredTodos: [Todo] {
        guard let filterId = selectedCategoryFilter else { return displayedTodos }
        return displayedTodos.filter { $0.categoryId == filterId }
    }

    var filteredCompletionRate: Double {
        guard !todosForRate.isEmpty else { return 0 }
        return Double(todosForRate.filter(\.isCompleted).count) / Double(todosForRate.count)
    }

    var filteredCompletedCount: Int { todosForRate.filter(\.isCompleted).count }
    var filteredTotalCount: Int { todosForRate.count }

    func category(for id: String?) -> Category? {
        guard let id else { return nil }
        return categoryService.activeCategories.first(where: { $0.id == id })
    }

    // MARK: - Data

    func fetchTodos() async {
        isLoading = true
        todos = await service.fetchTodos(for: selectedDate)
        isLoading = false
        validateCategoryFilter()
    }

    private func validateCategoryFilter() {
        guard let filterId = selectedCategoryFilter else { return }
        if !categoryService.activeCategories.contains(where: { $0.id == filterId }) {
            selectedCategoryFilter = nil
        }
    }

    // MARK: - Actions

    func toggleTodo(_ todo: Todo) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index].isCompleted.toggle()
        let updated = todos[index]
        Task { try? await service.updateTodo(updated) }
    }

    func pinTodo(_ todo: Todo) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index].isPinned.toggle()
        let updated = todos[index]
        Task { try? await service.updateTodo(updated) }
    }

    func addTodo(title: String, memo: String? = nil, categoryId: String? = nil, date: Date? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let todo = Todo(title: trimmed, memo: memo, date: date ?? selectedDate, categoryId: categoryId)
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

    func changeTodoDate(_ todo: Todo, to newDate: Date) {
        var updated = todo
        updated.date = newDate
        if Calendar.current.isDate(newDate, inSameDayAs: selectedDate) {
            if let index = todos.firstIndex(where: { $0.id == todo.id }) {
                todos[index].date = newDate
            }
        } else {
            todos.removeAll { $0.id == todo.id }
        }
        Task { try? await service.updateTodo(updated) }
    }

    func saveTodoEdit(_ updated: Todo) {
        let isSameDay = Calendar.current.isDate(updated.date, inSameDayAs: selectedDate)
        if isSameDay {
            if let index = todos.firstIndex(where: { $0.id == updated.id }) {
                todos[index] = updated
            }
        } else {
            todos.removeAll { $0.id == updated.id }
        }
        Task { try? await service.updateTodo(updated) }
    }

    func selectPlanner(_ planner: Planner) {
        PlannerService.shared.selectPlanner(planner)
    }

    func goToPreviousDay() {
        guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = prev
    }

    func goToNextDay() {
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectedDate = next
    }
}
