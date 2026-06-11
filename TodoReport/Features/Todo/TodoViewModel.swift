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
        didSet {
            Task { await fetchTodos() }
            Task { @MainActor in await RecurringTodoManager.shared.generateUpcoming() }
        }
    }

    private let service = TodoService.shared
    private let categoryService = CategoryService.shared
    private var notionSyncTask: Task<Void, Never>?

    private var isPro: Bool { SubscriptionManager.shared.isPro }

    var isCurrentPlannerReadOnly: Bool {
        PlannerService.shared.selectedPlanner?.isReadOnly ?? false
    }

    var showReadOnlyAlert: Bool = false

    var showDatePaywall: Bool = false
    private(set) var datePaywallMessage: String = ""
    var showDatePicker: Bool = false
    private(set) var isNotionSyncing: Bool = false

    var showDeleteAlert: Bool = false
    private(set) var pendingDeleteTodo: Todo? = nil

    var showRecurringEditAlert: Bool = false
    private(set) var pendingRecurringEdit: RecurringEditPendingInfo? = nil

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
        await categoryService.refresh()
        await syncNotionCategoriesIfNeeded()
        await fetchTodos()
    }

    func onForeground() async {
        // pending SyncQueue 항목 push 완료 대기 (최대 5초) 후 fetch
        // → 날짜 변경 등 로컬 변경이 Notion에 반영된 뒤 fetch 하도록 순서 보장
        let timeout = Date.now.addingTimeInterval(5)
        while await MainActor.run(body: { SyncQueueManager.shared.hasPendingItems })
                && Date.now < timeout {
            try? await Task.sleep(for: .milliseconds(200))
        }
        await fetchTodos()
    }

    func fetchTodos() async {
        await syncNotionCategoriesIfNeeded()
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
            await syncNotionCategoriesIfNeeded()
            await service.syncTodosFromNotion(for: date)
            guard !Task.isCancelled else { return }
            todos = await service.fetchTodos(for: date)
            validateCategoryFilter()
            updateWidget()
        }
    }

    private func syncNotionCategoriesIfNeeded() async {
        guard let plannerId = PlannerService.shared.selectedPlanner?.id else { return }
        await CategoryNotionSync.shared.syncCategoriesByName(plannerId: plannerId)
    }

    private func updateWidget() {
        guard Calendar.current.isDateInToday(selectedDate) else { return }
        WidgetDataProvider.shared.update(
            allTodos: todos,
            listTodos: displayedTodos,
            plannerName: plannerName
        )
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
        updateWidget()
    }

    func pinTodo(_ todo: Todo) {
        notionSyncTask?.cancel()
        notionSyncTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
            todos[index].isPinned.toggle()
            let updated = todos[index]
            try? await service.updateTodo(updated)
            updateWidget()
        }
    }

    func addTodo(title: String, memo: String? = nil, categoryId: String? = nil, date: Date? = nil, scheduledTime: Date? = nil, alarmOffset: Int? = nil, recurrenceRule: RecurrenceRule? = nil, recurrenceEndDate: Date? = nil, recurrenceCount: Int? = nil) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let recurrenceId = recurrenceRule != nil ? UUID().uuidString : nil
        let todo = Todo(
            title: trimmed, memo: memo,
            date: date ?? selectedDate,
            categoryId: categoryId,
            plannerId: PlannerService.shared.selectedPlanner?.id,
            scheduledTime: scheduledTime, alarmOffset: alarmOffset,
            recurrenceRule: recurrenceRule,
            recurrenceId: recurrenceId,
            recurrenceEndDate: recurrenceEndDate,
            recurrenceCount: recurrenceCount
        )
        todos.append(todo)
        updateWidget()
        Task { try? await service.saveTodo(todo) }
        if recurrenceRule != nil {
            Task { await RecurringTodoManager.shared.generateUpcoming() }
        }
    }

    func deleteTodo(_ todo: Todo) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        todos.removeAll { $0.id == todo.id }
        updateWidget()
        Task { try? await service.deleteTodo(id: todo.id) }
    }

    func requestDelete(_ todo: Todo) {
        if todo.recurrenceId != nil {
            pendingDeleteTodo = todo
            showDeleteAlert = true
        } else {
            deleteTodo(todo)
        }
    }

    func confirmDeleteSingle() {
        guard let todo = pendingDeleteTodo else { return }
        pendingDeleteTodo = nil
        deleteTodo(todo)
    }

    func confirmDeleteFuture() {
        guard let todo = pendingDeleteTodo else { return }
        guard let rid = todo.recurrenceId else { pendingDeleteTodo = nil; return }
        pendingDeleteTodo = nil
        todos.removeAll { $0.recurrenceId == rid && $0.date >= todo.date }
        Task { try? await service.deleteFutureItems(recurrenceId: rid, from: todo.date) }
    }

    func cancelDelete() {
        pendingDeleteTodo = nil
    }

    // MARK: - Edit Sheet Delete Alert

    var showEditDeleteAlert: Bool = false
    private(set) var pendingEditDeleteTodo: Todo? = nil

    func requestEditDelete(_ todo: Todo) {
        pendingEditDeleteTodo = todo
        showEditDeleteAlert = true
    }

    func cancelEditDelete() {
        pendingEditDeleteTodo = nil
    }

    func confirmEditDelete() {
        guard let todo = pendingEditDeleteTodo else { return }
        pendingEditDeleteTodo = nil
        requestDelete(todo)
    }

    // MARK: - Recurring Edit Alert

    var recurringEditAlertTitle: String {
        switch pendingRecurringEdit?.changeType {
        case .removeRecurrence: return "반복 해제"
        case .changeRule:       return "반복 주기 변경"
        default:                return "반복 투두 편집"
        }
    }

    var recurringEditSingleLabel: String {
        pendingRecurringEdit?.changeType == .removeRecurrence ? "이 항목만 해제" : "이 항목만 변경"
    }

    var recurringEditFutureLabel: String {
        pendingRecurringEdit?.changeType == .removeRecurrence ? "이후 항목 모두 해제" : "이후 항목 모두 변경"
    }

    func cancelRecurringEdit() {
        pendingRecurringEdit = nil
    }

    func confirmRecurringEditSingle() {
        guard let info = pendingRecurringEdit else { return }
        pendingRecurringEdit = nil
        Task {
            try? await RecurringTodoEditHandler.applySingleOnly(
                original: info.original, updated: info.updated, changeType: info.changeType
            )
            todos = await service.fetchTodos(for: selectedDate)
        }
    }

    func confirmRecurringEditFuture() {
        guard let info = pendingRecurringEdit else { return }
        pendingRecurringEdit = nil
        Task {
            try? await RecurringTodoEditHandler.applyFromNowOn(
                original: info.original, updated: info.updated, changeType: info.changeType
            )
            todos = await service.fetchTodos(for: selectedDate)
        }
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
        if let original = todos.first(where: { $0.id == updated.id }),
           let changeType = RecurringTodoEditHandler.detectChange(original: original, updated: updated) {
            if changeType == .changeEndCondition {
                // 종료 조건 변경은 alert 없이 시리즈 전체에 적용
                Task {
                    try? await RecurringTodoEditHandler.applyFromNowOn(
                        original: original, updated: updated, changeType: changeType
                    )
                    todos = await service.fetchTodos(for: selectedDate)
                }
            } else {
                pendingRecurringEdit = RecurringEditPendingInfo(
                    original: original, updated: updated, changeType: changeType
                )
                showRecurringEditAlert = true
            }
            return
        }
        performSaveTodoEdit(updated)
    }

    func cancelReadOnlyAlert() {
        showReadOnlyAlert = false
    }

    private func performSaveTodoEdit(_ updated: Todo) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        let isSameDay = Calendar.current.isDate(updated.date, inSameDayAs: selectedDate)
        if isSameDay {
            if let index = todos.firstIndex(where: { $0.id == updated.id }) {
                todos[index] = updated
            }
        } else {
            todos.removeAll { $0.id == updated.id }
        }
        // 사용자가 시간을 명시적으로 제거한 경우 알림 직접 취소
        if updated.scheduledTime == nil {
            TodoNotificationManager.shared.cancel(for: updated.id)
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

    var canGoNextDay: Bool {
        !Calendar.current.isDateInToday(selectedDate)
    }

    func requestPreviousDay() {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)
        let selectedStart = cal.startOfDay(for: selectedDate)
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        guard isPro || selectedStart > yesterdayStart else {
            datePaywallMessage = "다른 날 투두 확인은 Pro 기능이에요"
            showDatePaywall = true
            return
        }
        goToPreviousDay()
    }

    func goToPreviousDay() {
        guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = prev
    }

    func requestNextDay() {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)
        let selectedStart = cal.startOfDay(for: selectedDate)
        let tomorrowStart = cal.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        guard isPro || selectedStart < tomorrowStart else {
            datePaywallMessage = "다른 날 투두 확인은 Pro 기능이에요"
            showDatePaywall = true
            return
        }
        guard let next = cal.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectedDate = next
    }

    func goToNextDay() {
        guard canGoNextDay else { return }
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectedDate = next
    }

    func goToToday() {
        selectedDate = .now
    }

    func navigateToDate(_ date: Date) {
        let cal = Calendar.current
        let target = cal.startOfDay(for: date)
        guard TodoDateAccess.canView(date: target, isPro: isPro) else {
            datePaywallMessage = "다른 날 투두 확인은 Pro 기능이에요"
            showDatePaywall = true
            return
        }
        selectedDate = target
        Task { await fetchTodos() }
    }
}
