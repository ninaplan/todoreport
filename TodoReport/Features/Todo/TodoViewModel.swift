import Foundation
import SwiftUI

@Observable
final class TodoViewModel {
    private(set) var todos: [Todo] = []
    private(set) var isLoading: Bool = false

    var plannerName: String { PlannerService.shared.selectedPlanner?.name ?? "내 플래너" }
    var isViewOptionsVisible: Bool = false
    var hideCompleted: Bool = UserDefaults.standard.bool(forKey: "todoHideCompleted") {
        didSet {
            UserDefaults.standard.set(hideCompleted, forKey: "todoHideCompleted")
            updateWidget()
        }
    }
    var showMemo: Bool = UserDefaults.standard.bool(forKey: "todoShowMemo") {
        didSet { UserDefaults.standard.set(showMemo, forKey: "todoShowMemo") }
    }
    var selectedCategoryFilter: String? = nil  // nil = 전체

    var selectedDate: Date = .now {
        didSet {
            Task { await fetchLocalTodos() }
            Task { @MainActor in await RecurringTodoManager.shared.generateUpcoming() }
        }
    }

    private let service = TodoService.shared
    private let categoryService = CategoryService.shared
    @ObservationIgnored private var localFetchTask: Task<Void, Never>?
    @ObservationIgnored private var notionSyncTask: Task<Void, Never>?
    @ObservationIgnored private var dateSyncDebounceTask: Task<Void, Never>?
    @ObservationIgnored private var isHandlingForegroundRefresh = false
    @ObservationIgnored private var isFirstLaunch: Bool = true
    @ObservationIgnored private static let dateSyncDebounceNanoseconds: UInt64 = 350_000_000

    private var isPro: Bool { SubscriptionManager.shared.isPro }

    var isCurrentPlannerReadOnly: Bool {
        PlannerService.shared.selectedPlanner?.isReadOnly ?? false
    }

    var showReadOnlyAlert: Bool = false

    var showDatePicker: Bool = false
    private(set) var isNotionSyncing: Bool = false
    private(set) var isAwaitingInitialNotionLoad: Bool = false

    var showDeleteAlert: Bool = false
    var showSingleDeleteAlert: Bool = false
    private(set) var pendingDeleteTodo: Todo? = nil

    var showRecurringEditAlert: Bool = false
    private(set) var pendingRecurringEdit: RecurringEditPendingInfo? = nil

    var showsTodoListLoading: Bool {
        filteredTodos.isEmpty && (isLoading || isAwaitingInitialNotionLoad)
    }

    // MARK: - Computed

    var activeCategories: [Category] { categoryService.activeCategories }

    var completionRate: Double {
        let dated = todosForSelectedDate
        guard !dated.isEmpty else { return 0 }
        return Double(dated.filter(\.isCompleted).count) / Double(dated.count)
    }

    private var todosForRate: [Todo] {
        let dated = todosForSelectedDate
        guard let filterId = selectedCategoryFilter else { return dated }
        return dated.filter { $0.categoryId == filterId }
    }

    private var todosForSelectedDate: [Todo] {
        todos.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var displayedTodos: [Todo] {
        let dated = todosForSelectedDate
        let pinned   = dated.filter {  $0.isPinned && !$0.isCompleted }
                            .sorted { sortDate($0) < sortDate($1) }
        let normal   = dated.filter { !$0.isPinned && !$0.isCompleted }
                            .sorted { sortDate($0) < sortDate($1) }
        let completed = hideCompleted ? [] :
                        dated.filter { $0.isCompleted }
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

    func onAppear() async {
        await fetchLocalTodos()
        if todosForSelectedDate.isEmpty {
            await syncFromNotion(immediate: true, initialLoad: true)
        } else {
            scheduleDebouncedNotionSync()
        }
        if isFirstLaunch {
            isFirstLaunch = false
        }
    }

    func switchPlanner() async {
        cancelInFlightFetches()
        todos = []
        await categoryService.refresh()
        await syncFromNotion(immediate: true)
    }

    func handleForegroundRefresh() async {
        guard !isHandlingForegroundRefresh else { return }
        isHandlingForegroundRefresh = true
        defer { isHandlingForegroundRefresh = false }

        let timeout = Date.now.addingTimeInterval(5)
        while SyncQueueManager.shared.hasPendingItems && Date.now < timeout {
            try? await Task.sleep(for: .milliseconds(200))
        }
        let hadLocalData = !todosForSelectedDate.isEmpty
        await syncFromNotion(immediate: true, quiet: hadLocalData)
    }

    func refreshFromNotion() async {
        await syncFromNotion(immediate: true)
    }

    func fetchLocalTodos(for date: Date? = nil) async {
        localFetchTask?.cancel()
        let targetDate = date ?? selectedDate
        let task = Task { @MainActor in
            defer { localFetchTask = nil }
            await performFetchLocalTodos(for: targetDate)
        }
        localFetchTask = task
        await task.value
    }

    func scheduleDebouncedNotionSync(for date: Date? = nil) {
        dateSyncDebounceTask?.cancel()
        let targetDate = date ?? selectedDate
        dateSyncDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.dateSyncDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            guard Calendar.current.isDate(selectedDate, inSameDayAs: targetDate) else { return }
            // push 큐가 처리 중이면 pull을 미룸 — stale 응답 유발 창을 좁힘
            let timeout = Date.now.addingTimeInterval(5)
            while SyncQueueManager.shared.hasPendingItems && Date.now < timeout {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                guard Calendar.current.isDate(selectedDate, inSameDayAs: targetDate) else { return }
            }
            let hadLocalData = !todosForSelectedDate.isEmpty
            await syncFromNotion(for: targetDate, immediate: true, quiet: hadLocalData)
        }
    }

    func syncFromNotion(
        for date: Date? = nil,
        immediate: Bool = false,
        quiet: Bool = false,
        initialLoad: Bool = false
    ) async {
        if !immediate {
            scheduleDebouncedNotionSync(for: date)
            return
        }

        dateSyncDebounceTask?.cancel()
        dateSyncDebounceTask = nil

        let targetDate = date ?? selectedDate
        await fetchLocalTodos(for: targetDate)

        guard PlannerService.shared.selectedPlanner?.isNotionConnected == true else { return }

        notionSyncTask?.cancel()
        notionSyncTask = nil

        let task = Task { @MainActor in
            defer {
                isNotionSyncing = false
                isAwaitingInitialNotionLoad = false
                notionSyncTask = nil
            }
            if initialLoad {
                isAwaitingInitialNotionLoad = true
            } else if !quiet {
                isNotionSyncing = true
            }
            await syncNotionCategoriesIfNeeded()
            await service.syncTodosFromNotion(for: targetDate)
            guard !Task.isCancelled else { return }
            guard Calendar.current.isDate(selectedDate, inSameDayAs: targetDate) else { return }
            let fetched = await service.fetchTodos(for: targetDate)
            applyTodosUpdate(fetched, animated: quiet || initialLoad)
        }
        notionSyncTask = task
        await task.value
    }

    @MainActor
    private func performFetchLocalTodos(for date: Date) async {
        let shouldShowLoading = todosForSelectedDate.isEmpty
            && Calendar.current.isDate(date, inSameDayAs: selectedDate)
        if shouldShowLoading { isLoading = true }
        defer { isLoading = false }

        let fetched = await service.fetchTodos(for: date)
        guard !Task.isCancelled else { return }
        guard Calendar.current.isDate(selectedDate, inSameDayAs: date) else { return }
        applyTodosUpdate(fetched, animated: false)
    }

    @MainActor
    private func applyTodosUpdate(_ incoming: [Todo], animated: Bool) {
        var filtered = incoming
        let hiddenCategoryIds = CategoryService.shared.store
            .filter { $0.isHidden }
            .map(\.id)
        filtered = filtered.filter { todo in
            guard let categoryId = todo.categoryId else { return true }
            return !hiddenCategoryIds.contains(categoryId)
        }

        guard TodoListDiff.hasChanges(current: todos, incoming: filtered) else {
            validateCategoryFilter()
            return
        }

        let merged = TodoListDiff.merged(current: todos, incoming: filtered)
        let apply = {
            self.todos = merged
            self.validateCategoryFilter()
            self.updateWidget()
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.3)) { apply() }
        } else {
            apply()
        }
    }

    private func filterHiddenCategoryTodos() {
        let hiddenCategoryIds = CategoryService.shared.store
            .filter { $0.isHidden }
            .map(\.id)
        todos = todos.filter { todo in
            guard let categoryId = todo.categoryId else { return true }
            return !hiddenCategoryIds.contains(categoryId)
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
        todos[index].markLocallyModified()
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
            todos[index].markLocallyModified()
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
            recurrenceCount: recurrenceCount,
            localModifiedAt: .now
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
        pendingDeleteTodo = todo
        if todo.recurrenceId != nil {
            showDeleteAlert = true
        } else {
            showSingleDeleteAlert = true
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

    func confirmSingleDelete() {
        guard let todo = pendingDeleteTodo else { return }
        pendingDeleteTodo = nil
        deleteTodo(todo)
    }

    func cancelSingleDelete() {
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

    private func cancelInFlightFetches() {
        localFetchTask?.cancel()
        localFetchTask = nil
        dateSyncDebounceTask?.cancel()
        dateSyncDebounceTask = nil
        notionSyncTask?.cancel()
        notionSyncTask = nil
    }

    @MainActor
    private func replaceTodosFromStore() async {
        todos = await service.fetchTodos(for: selectedDate)
        validateCategoryFilter()
        updateWidget()
    }

    func moveToTomorrow(_ todo: Todo) {
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        var moved = todo
        moved.date = nextDay
        todos.removeAll { $0.id == todo.id }
        cancelInFlightFetches()
        Task {
            try? await service.updateTodo(moved)
            await replaceTodosFromStore()
        }
    }

    func changeTodoDate(_ todo: Todo, to newDate: Date) {
        var updated = todo
        updated.date = newDate
        updated.markLocallyModified()
        if Calendar.current.isDate(newDate, inSameDayAs: selectedDate) {
            if let index = todos.firstIndex(where: { $0.id == todo.id }) {
                todos[index] = updated
            }
        } else {
            todos.removeAll { $0.id == todo.id }
        }
        cancelInFlightFetches()
        Task {
            try? await service.updateTodo(updated)
            await replaceTodosFromStore()
        }
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
        var touched = updated
        touched.markLocallyModified()
        let isSameDay = Calendar.current.isDate(touched.date, inSameDayAs: selectedDate)
        if isSameDay {
            if let index = todos.firstIndex(where: { $0.id == touched.id }) {
                todos[index] = touched
            }
        } else {
            todos.removeAll { $0.id == touched.id }
        }
        // 사용자가 시간을 명시적으로 제거한 경우 알림 직접 취소
        if touched.scheduledTime == nil {
            TodoNotificationManager.shared.cancel(for: touched.id)
        }
        cancelInFlightFetches()
        Task {
            try? await service.updateTodo(touched)
            await replaceTodosFromStore()
        }
    }

    func selectPlanner(_ planner: Planner) {
        PlannerService.shared.selectPlanner(planner)
    }

    func requestDatePicker() {
        showDatePicker = true
    }

    var canGoNextDay: Bool {
        !Calendar.current.isDateInToday(selectedDate)
    }

    func requestPreviousDay() {
        goToPreviousDay()
    }

    func goToPreviousDay() {
        guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = prev
    }

    func requestNextDay() {
        let cal = Calendar.current
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
        selectedDate = target
    }
}
