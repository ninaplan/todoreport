import Foundation
import SwiftUI

@Observable
final class TodoViewModel {
    private(set) var todos: [Todo] = []
    private(set) var isLoading: Bool = false

    var plannerName: String { PlannerService.shared.selectedPlanner?.name ?? "내 플래너" }
    var isViewOptionsVisible: Bool = false
    var hideCompleted: Bool = UserDefaults.standard.bool(forKey: "todoHideCompleted") {
        didSet { UserDefaults.standard.set(hideCompleted, forKey: "todoHideCompleted") }
    }
    var showMemo: Bool = UserDefaults.standard.bool(forKey: "todoShowMemo") {
        didSet { UserDefaults.standard.set(showMemo, forKey: "todoShowMemo") }
    }
    var selectedCategoryFilter: String? = nil  // nil = 전체

    var selectedDate: Date = .now {
        didSet { Task { await fetchTodos() } }
    }

    private let service = TodoService.shared
    private let categoryService = CategoryService.shared
    private var notionSyncTask: Task<Void, Never>?

    #if DEBUG
    private var isPro: Bool { UserDefaults.standard.bool(forKey: "debugIsPro") }
    #else
    private let isPro = false
    #endif

    var showDatePaywall: Bool = false
    private(set) var datePaywallMessage: String = ""
    var showDatePicker: Bool = false
    private(set) var isNotionSyncing: Bool = false

    // MARK: - Computed

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
        let pinned   = todos.filter {  $0.isPinned && !$0.isCompleted }
                            .sorted { sortDate($0) < sortDate($1) }
        let normal   = todos.filter { !$0.isPinned && !$0.isCompleted }
                            .sorted { sortDate($0) < sortDate($1) }
        let completed = hideCompleted ? [] :
                        todos.filter { $0.isCompleted }
                             .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
        return pinned + normal + completed
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

    private func sortDate(_ todo: Todo) -> Date {
        todo.notionCreatedAt ?? todo.createdAt
    }

    func category(for id: String?) -> Category? {
        guard let id else { return nil }
        return categoryService.activeCategories.first(where: { $0.id == id })
    }

    // MARK: - Data

    func switchPlanner() async {
        notionSyncTask?.cancel()
        notionSyncTask = nil
        todos = []
        await fetchTodos()
    }

    func fetchTodos() async {
        isLoading = true
        todos = await service.fetchTodos(for: selectedDate)
        isLoading = false
        validateCategoryFilter()
        updateWidget()
        notionSyncTask?.cancel()
        let date = selectedDate
        notionSyncTask = Task {
            isNotionSyncing = true
            defer { isNotionSyncing = false }
            await service.syncTodosFromNotion(for: date)
            guard !Task.isCancelled else { return }
            todos = await service.fetchTodos(for: date)
            validateCategoryFilter()
            updateWidget()
        }
    }

    private func updateWidget() {
        guard Calendar.current.isDateInToday(selectedDate) else { return }
        WidgetDataProvider.shared.update(todos: displayedTodos, plannerName: plannerName)
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
        todos[index].completedAt = todos[index].isCompleted ? .now : nil
        let updated = todos[index]
        notionSyncTask?.cancel()
        notionSyncTask = nil
        Task { try? await service.updateTodo(updated) }
    }

    func pinTodo(_ todo: Todo) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index].isPinned.toggle()
        let updated = todos[index]
        notionSyncTask?.cancel()
        notionSyncTask = nil
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

    func requestDatePicker() {
        guard isPro else {
            datePaywallMessage = "다른 날 투두 확인은 Pro 기능이에요"
            showDatePaywall = true
            return
        }
        showDatePicker = true
    }

    func dismissDatePaywall() {
        showDatePaywall = false
        datePaywallMessage = ""
    }

    func goToPreviousDay() {
        guard isPro else {
            datePaywallMessage = "다른 날 투두 확인은 Pro 기능이에요"
            showDatePaywall = true
            return
        }
        guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = prev
    }

    func goToNextDay() {
        guard isPro else {
            datePaywallMessage = "다른 날 투두 확인은 Pro 기능이에요"
            showDatePaywall = true
            return
        }
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectedDate = next
    }
}
