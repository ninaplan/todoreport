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
            AppGroupUserDefaults.setTodoHideCompleted(hideCompleted)
            updateWidget()
        }
    }
    var showMemo: Bool = UserDefaults.standard.bool(forKey: "todoShowMemo") {
        didSet { UserDefaults.standard.set(showMemo, forKey: "todoShowMemo") }
    }
    var showScheduledTime: Bool = {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "todoShowScheduledTime") == nil {
            return true
        }
        return defaults.bool(forKey: "todoShowScheduledTime")
    }() {
        didSet { UserDefaults.standard.set(showScheduledTime, forKey: "todoShowScheduledTime") }
    }
    var selectedCategoryFilter: String? = nil  // nil = 전체
    /// 검색에서 들어온 항목이 숨김(완료/카테고리 필터)이어도 잠깐 목록에 보이게 한다.
    private(set) var navigationRevealTodoId: String?

    var selectedDate: Date = .now {
        didSet {
            Task {
                await RecurringTodoManager.shared.materializeThrough(date: selectedDate)
                await fetchLocalTodos()
            }
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

    var isCurrentPlannerReadOnly: Bool {
        PlannerService.shared.selectedPlanner?.isReadOnly ?? false
    }

    var showReadOnlyAlert: Bool = false

    var showDatePicker: Bool = false
    private(set) var isNotionSyncing: Bool = false
    private(set) var isAwaitingInitialNotionLoad: Bool = false
    /// 마지막 Notion 일별 pull 결과. `nil`이면 아직 기록된 pull 없음, `false`면 실패.
    private(set) var lastNotionPullSucceeded: Bool?

    var showDeleteAlert: Bool = false
    var showSingleDeleteAlert: Bool = false
    private(set) var pendingDeleteTodo: Todo? = nil

    var showRecurringEditAlert: Bool = false
    private(set) var pendingRecurringEdit: RecurringEditPendingInfo? = nil

    var showsTodoListLoading: Bool {
        filteredTodos.isEmpty && (isLoading || isAwaitingInitialNotionLoad)
    }

    /// 빈 목록 UI 분기. View는 이 값으로만 표시를 가른다.
    var emptyStateKind: TodoEmptyStateKind {
        guard filteredTodos.isEmpty else { return .notEmpty }

        // 완료 숨김·카테고리 필터로만 비는 경우
        if !todosForSelectedDate.isEmpty { return .plain }

        guard PlannerService.shared.selectedPlanner?.isNotionConnected == true else {
            return .plain
        }

        // quiet 포함 진행 중 — 안내 숨김 (로딩 UI는 showsTodoListLoading이 별도 담당)
        if notionSyncTask != nil { return .plain }

        // 명시적 pull 실패만 새로고침 안내
        if lastNotionPullSucceeded == false { return .notionPullHint }

        return .plain
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
        todos.filter {
            guard let date = $0.date else { return false }
            return Calendar.current.isDate(date, inSameDayAs: selectedDate)
        }
    }

    var displayedTodos: [Todo] {
        let dated = todosForSelectedDate
        let pinned   = dated.filter {  $0.isPinned && !$0.isCompleted }
                            .sorted { sortDate($0) < sortDate($1) }
        let normal   = dated.filter { !$0.isPinned && !$0.isCompleted }
                            .sorted { sortDate($0) < sortDate($1) }
        let completed: [Todo]
        if hideCompleted {
            if let revealId = navigationRevealTodoId {
                completed = dated.filter { $0.isCompleted && $0.id == revealId }
                    .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
            } else {
                completed = []
            }
        } else {
            completed = dated.filter { $0.isCompleted }
                .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
        }
        return pinned + normal + completed
    }

    var filteredTodos: [Todo] {
        guard let filterId = selectedCategoryFilter else { return displayedTodos }
        return displayedTodos.filter { $0.categoryId == filterId || $0.id == navigationRevealTodoId }
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
            if let succeeded = await service.syncTodosFromNotion(for: targetDate) {
                recordNotionPull(succeeded: succeeded)
            }
            guard !Task.isCancelled else { return }
            guard Calendar.current.isDate(selectedDate, inSameDayAs: targetDate) else { return }
            await loadTodosFromStore(for: targetDate, animated: quiet || initialLoad)
        }
        notionSyncTask = task
        await task.value
    }

    @MainActor
    private func recordNotionPull(succeeded: Bool) {
        lastNotionPullSucceeded = succeeded
    }

    @MainActor
    private func performFetchLocalTodos(for date: Date) async {
        let shouldShowLoading = todosForSelectedDate.isEmpty
            && Calendar.current.isDate(date, inSameDayAs: selectedDate)
        if shouldShowLoading { isLoading = true }
        defer { isLoading = false }

        guard !Task.isCancelled else { return }
        guard Calendar.current.isDate(selectedDate, inSameDayAs: date) else { return }
        await loadTodosFromStore(for: date, animated: false)
    }

    /// 저장소 → `todos` 반영의 단일 진입점. `fetchTodos` 결과를 직접 대입하지 않는다.
    @MainActor
    private func loadTodosFromStore(for date: Date, animated: Bool) async {
        let fetched = RecurringTodoManager.shared.attachingSeries(
            to: await service.fetchTodos(for: date)
        )
        guard !Task.isCancelled else { return }
        guard Calendar.current.isDate(selectedDate, inSameDayAs: date) else { return }
        applyTodosUpdate(fetched, animated: animated)
    }

    @MainActor
    private func applyTodosUpdate(_ incoming: [Todo], animated: Bool) {
        let filtered = excludingHiddenCategoryTodos(incoming)

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

    /// 숨긴 카테고리 할일 제외 — 목록 반영 시 유일한 필터.
    private func excludingHiddenCategoryTodos(_ todos: [Todo]) -> [Todo] {
        let hiddenCategoryIds = Set(
            CategoryService.shared.store
                .filter(\.isHidden)
                .map(\.id)
        )
        return todos.filter { todo in
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
            withAnimation(.easeInOut(duration: 0.3)) {
                todos[index].isPinned.toggle()
            }
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
        if let recurrenceRule {
            Task {
                do {
                    _ = try await RecurringTodoManager.shared.createSeries(
                        title: trimmed,
                        memo: memo,
                        categoryId: categoryId,
                        plannerId: PlannerService.shared.selectedPlanner?.id,
                        originDate: date ?? selectedDate,
                        scheduledTime: scheduledTime,
                        alarmOffset: alarmOffset,
                        rule: recurrenceRule,
                        endDate: recurrenceEndDate,
                        occurrenceLimit: recurrenceCount
                    )
                    await replaceTodosFromStore()
                    updateWidget()
                } catch {
                    showTodoSaveFailedAlert = true
                }
            }
            return
        }
        let todo = Todo(
            title: trimmed, memo: memo,
            date: date ?? selectedDate,
            categoryId: categoryId,
            plannerId: PlannerService.shared.selectedPlanner?.id,
            scheduledTime: scheduledTime, alarmOffset: alarmOffset,
            localModifiedAt: .now
        )
        todos.append(todo)
        updateWidget()
        Task { try? await service.saveTodo(todo) }
    }

    /// 날짜 없는 인박스 항목 생성. 오늘 목록에는 넣지 않음.
    func addInboxTodo(title: String, memo: String? = nil, categoryId: String? = nil) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task { try? await service.saveInboxTodo(title: trimmed, memo: memo, categoryId: categoryId) }
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
        todos.removeAll {
            guard $0.recurrenceId == rid, let left = $0.date, let right = todo.date else { return false }
            return left >= right
        }
        guard let fromDate = todo.date else { return }
        Task {
            try? await service.deleteFutureItems(recurrenceId: rid, from: fromDate)
            await RecurringTodoManager.shared.capSeriesEndDate(seriesId: rid, beforeDate: fromDate)
        }
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
        pendingRecurringEdit?.changeType.alertTitle ?? String(localized: "반복 투두 편집")
    }

    var recurringEditAlertMessage: String {
        pendingRecurringEdit?.changeType.alertMessage ?? String(localized: "어떻게 변경할까요?")
    }

    var recurringEditSingleLabel: String {
        pendingRecurringEdit?.changeType.singleLabel ?? String(localized: "이 항목만 변경")
    }

    var recurringEditFutureLabel: String {
        pendingRecurringEdit?.changeType.futureLabel ?? String(localized: "이후 항목 모두 변경")
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
            await replaceTodosFromStore()
        }
    }

    func confirmRecurringEditFuture() {
        guard let info = pendingRecurringEdit else { return }
        pendingRecurringEdit = nil
        Task {
            try? await RecurringTodoEditHandler.applyFromNowOn(
                original: info.original, updated: info.updated, changeType: info.changeType
            )
            await replaceTodosFromStore()
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
        await loadTodosFromStore(for: selectedDate, animated: false)
    }

    func moveToTomorrow(_ todo: Todo) {
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        var moved = todo
        TodoScheduledTime.applyingDateChange(to: &moved, newDate: nextDay)
        todos.removeAll { $0.id == todo.id }
        cancelInFlightFetches()
        Task {
            try? await service.updateTodo(moved)
            await replaceTodosFromStore()
        }
    }

    func changeTodoDate(_ todo: Todo, to newDate: Date) {
        var updated = todo
        TodoScheduledTime.applyingDateChange(to: &updated, newDate: newDate)
        updated.markLocallyModified()
        if let updatedDate = updated.date,
           Calendar.current.isDate(updatedDate, inSameDayAs: selectedDate) {
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

    func sendToInbox(_ todo: Todo) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        guard todo.recurrenceId == nil else { return }
        var updated = todo
        let hadAlarm = updated.alarmOffset != nil
        updated.date = nil
        updated.scheduledTime = nil
        updated.alarmOffset = nil
        updated.snoozedUntil = Date.now.addingTimeInterval(-1)
        updated.markLocallyModified()
        todos.removeAll { $0.id == todo.id }
        if hadAlarm {
            TodoNotificationManager.shared.cancel(for: todo.id)
        }
        cancelInFlightFetches()
        Task {
            try? await service.updateTodo(updated)
            await replaceTodosFromStore()
        }
    }

    func saveTodoEdit(_ updated: Todo) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        let original: Todo
        if let listed = todos.first(where: { $0.id == updated.id }) {
            original = RecurringTodoManager.shared.attachingSeries(to: listed)
        } else {
            original = RecurringTodoManager.shared.attachingSeries(to: updated)
        }

        if original.recurrenceId == nil, updated.recurrenceRule != nil {
            Task {
                var adopted = updated
                adopted.recurrenceId = adopted.recurrenceId ?? UUID().uuidString
                do {
                    try RecurringTodoManager.shared.adoptExistingTodoAsSeriesOrigin(adopted)
                    try await service.updateTodo(adopted)
                    await RecurringTodoManager.shared.materializeDue()
                    await replaceTodosFromStore()
                } catch {
                    await replaceTodosFromStore()
                    showTodoSaveFailedAlert = true
                }
            }
            return
        }

        if let changeType = RecurringTodoEditHandler.detectChange(original: original, updated: updated) {
            if changeType == .changeEndCondition {
                // 종료 조건 변경은 alert 없이 시리즈 전체에 적용
                Task {
                    try? await RecurringTodoEditHandler.applyFromNowOn(
                        original: original, updated: updated, changeType: changeType
                    )
                    await replaceTodosFromStore()
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

    /// 인라인 제목 수정 — 기존 `saveTodoEdit` Offline-First 경로 재사용.
    func updateTodoTitle(_ todo: Todo, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed != todo.title else { return }
        var updated = todo
        updated.title = trimmed
        saveTodoEdit(updated)
    }

    func cancelReadOnlyAlert() {
        showReadOnlyAlert = false
    }

    var showTodoSaveFailedAlert: Bool = false

    func cancelTodoSaveFailedAlert() {
        showTodoSaveFailedAlert = false
    }

    private func performSaveTodoEdit(_ updated: Todo) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        var touched = updated
        if let date = touched.date {
            TodoScheduledTime.applyingDateChange(to: &touched, newDate: date)
        }
        touched.markLocallyModified()
        let isSameDay = touched.date.map { Calendar.current.isDate($0, inSameDayAs: selectedDate) } ?? false
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
        // 낙관적 UI → SwiftData 쓰기 → 스토어 재조회 (CacheManager 경로 없음)
        Task {
            do {
                try await service.updateTodo(touched)
                await replaceTodosFromStore()
            } catch {
                await replaceTodosFromStore()
                showTodoSaveFailedAlert = true
            }
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

    func prepareRevealForNavigation(todoId: String) {
        navigationRevealTodoId = todoId
    }

    func clearNavigationReveal() {
        navigationRevealTodoId = nil
    }
}
