import Foundation
import SwiftUI

enum InboxSegment: String, CaseIterable, Identifiable {
    case now
    case snoozed
    case completed

    var id: String { rawValue }
}

/// 지금·완료됨 탭 공통 날짜 버킷 (최근은 헤더 없음·항상 전체 표시).
enum InboxAgeBucket: String, CaseIterable, Identifiable {
    case recent
    case weekPlus
    case monthPlus
    case halfYearPlus

    var id: String { rawValue }

    /// 접을 수 있는 버킷만 (최근 제외).
    static var collapsibleCases: [InboxAgeBucket] {
        [.weekPlus, .monthPlus, .halfYearPlus]
    }

    var headerTitle: String {
        switch self {
        case .recent: return ""
        case .weekPlus: return String(localized: "7일 이전")
        case .monthPlus: return String(localized: "30일 이전")
        case .halfYearPlus: return String(localized: "6개월 이전")
        }
    }
}

@Observable
final class InboxViewModel {
    private static let pageSize = 10
    private static let maxNavigationLoadMoreRounds = 40

    var segment: InboxSegment = .now
    private(set) var allInbox: [Todo] = []
    private(set) var categories: [Category] = []
    var isLoading = false

    /// 접힌 버킷은 Set에 없음. 최근은 항상 펼침으로 취급.
    private(set) var expandedNowBuckets: Set<InboxAgeBucket> = []
    private(set) var expandedCompletedBuckets: Set<InboxAgeBucket> = []
    /// 펼친 버킷의 현재 표시 상한 (접으면 제거 → 다시 펼치면 10부터).
    private(set) var visibleLimitNow: [InboxAgeBucket: Int] = [:]
    private(set) var visibleLimitCompleted: [InboxAgeBucket: Int] = [:]

    var showDeleteAlert = false
    private(set) var pendingDeleteTodo: Todo? = nil

    var showReadOnlyAlert = false
    var showSnoozeSheet = false
    private(set) var pendingSnoozeTodo: Todo? = nil
    var showCustomSnoozePicker = false
    var customSnoozeDate: Date = Calendar.current.startOfDay(for: .now)

    private let service = TodoService.shared
    private let categoryService = CategoryService.shared

    private var isCurrentPlannerReadOnly: Bool {
        PlannerService.shared.selectedPlanner?.isReadOnly == true
    }

    // MARK: - Lists

    /// 완료 > 스누즈 > 지금 우선순위로 분류.
    var nowTodos: [Todo] {
        allInbox
            .filter { !$0.isCompleted && !$0.isSnoozeActive }
            .sorted { nowRecencyDate(for: $0) > nowRecencyDate(for: $1) }
    }

    var snoozedTodos: [Todo] {
        allInbox
            .filter { !$0.isCompleted && $0.isSnoozeActive }
            .sorted { ($0.snoozedUntil ?? .distantPast) < ($1.snoozedUntil ?? .distantPast) }
    }

    var completedTodos: [Todo] {
        allInbox
            .filter(\.isCompleted)
            .sorted { completedRecencyDate(for: $0) > completedRecencyDate(for: $1) }
    }

    var snoozedCount: Int { snoozedTodos.count }
    var completedCount: Int { completedTodos.count }

    func nowTodos(in bucket: InboxAgeBucket) -> [Todo] {
        nowTodos.filter { nowAgeBucket(for: $0) == bucket }
    }

    func completedTodos(in bucket: InboxAgeBucket) -> [Todo] {
        completedTodos.filter { completedAgeBucket(for: $0) == bucket }
    }

    func isBucketExpanded(_ bucket: InboxAgeBucket, segment: InboxSegment) -> Bool {
        guard bucket != .recent else { return true }
        switch segment {
        case .now: return expandedNowBuckets.contains(bucket)
        case .completed: return expandedCompletedBuckets.contains(bucket)
        case .snoozed: return false
        }
    }

    func visibleCount(for bucket: InboxAgeBucket, segment: InboxSegment) -> Int {
        guard bucket != .recent else { return Int.max }
        switch segment {
        case .now: return visibleLimitNow[bucket] ?? Self.pageSize
        case .completed: return visibleLimitCompleted[bucket] ?? Self.pageSize
        case .snoozed: return Self.pageSize
        }
    }

    func displayedTodos(in bucket: InboxAgeBucket, segment: InboxSegment) -> [Todo] {
        let all: [Todo]
        switch segment {
        case .now: all = nowTodos(in: bucket)
        case .completed: all = completedTodos(in: bucket)
        case .snoozed: return []
        }
        if bucket == .recent { return all }
        guard isBucketExpanded(bucket, segment: segment) else { return [] }
        let limit = visibleCount(for: bucket, segment: segment)
        return Array(all.prefix(limit))
    }

    func remainingCount(in bucket: InboxAgeBucket, segment: InboxSegment) -> Int {
        let total: Int
        switch segment {
        case .now: total = nowTodos(in: bucket).count
        case .completed: total = completedTodos(in: bucket).count
        case .snoozed: return 0
        }
        if bucket == .recent { return 0 }
        guard isBucketExpanded(bucket, segment: segment) else { return 0 }
        return max(0, total - visibleCount(for: bucket, segment: segment))
    }

    // MARK: - Bucket UI actions

    func toggleBucket(_ bucket: InboxAgeBucket, segment: InboxSegment) {
        guard bucket != .recent else { return }
        switch segment {
        case .now:
            if expandedNowBuckets.contains(bucket) {
                expandedNowBuckets.remove(bucket)
                visibleLimitNow[bucket] = nil
            } else {
                expandedNowBuckets.insert(bucket)
                visibleLimitNow[bucket] = Self.pageSize
            }
        case .completed:
            if expandedCompletedBuckets.contains(bucket) {
                expandedCompletedBuckets.remove(bucket)
                visibleLimitCompleted[bucket] = nil
            } else {
                expandedCompletedBuckets.insert(bucket)
                visibleLimitCompleted[bucket] = Self.pageSize
            }
        case .snoozed:
            break
        }
    }

    func loadMore(in bucket: InboxAgeBucket, segment: InboxSegment) {
        guard bucket != .recent else { return }
        guard isBucketExpanded(bucket, segment: segment) else { return }
        switch segment {
        case .now:
            let current = visibleLimitNow[bucket] ?? Self.pageSize
            visibleLimitNow[bucket] = current + Self.pageSize
        case .completed:
            let current = visibleLimitCompleted[bucket] ?? Self.pageSize
            visibleLimitCompleted[bucket] = current + Self.pageSize
        case .snoozed:
            break
        }
    }

    /// 검색 진입용 — 해당 항목의 세그먼트·버킷을 열고 표시 목록에 들어갈 때까지 loadMore.
    @discardableResult
    func revealTodoForNavigation(_ todoId: String) -> Bool {
        guard let todo = allInbox.first(where: { $0.id == todoId }) else { return false }
        if todo.isCompleted {
            segment = .completed
            expandUntilVisible(todoId, in: completedAgeBucket(for: todo), segment: .completed)
        } else if todo.isSnoozeActive {
            segment = .snoozed
        } else {
            segment = .now
            expandUntilVisible(todoId, in: nowAgeBucket(for: todo), segment: .now)
        }
        return true
    }

    func isTodoVisibleInCurrentList(_ todoId: String) -> Bool {
        switch segment {
        case .now:
            return InboxAgeBucket.allCases.contains { bucket in
                displayedTodos(in: bucket, segment: .now).contains { $0.id == todoId }
            }
        case .snoozed:
            return snoozedTodos.contains { $0.id == todoId }
        case .completed:
            return InboxAgeBucket.allCases.contains { bucket in
                displayedTodos(in: bucket, segment: .completed).contains { $0.id == todoId }
            }
        }
    }

    private func expandUntilVisible(_ todoId: String, in bucket: InboxAgeBucket, segment: InboxSegment) {
        expandBucketForNavigation(bucket, segment: segment)
        var rounds = 0
        while !displayedTodos(in: bucket, segment: segment).contains(where: { $0.id == todoId }),
              remainingCount(in: bucket, segment: segment) > 0,
              rounds < Self.maxNavigationLoadMoreRounds {
            loadMore(in: bucket, segment: segment)
            rounds += 1
        }
    }

    private func expandBucketForNavigation(_ bucket: InboxAgeBucket, segment: InboxSegment) {
        guard bucket != .recent else { return }
        switch segment {
        case .now:
            if !expandedNowBuckets.contains(bucket) {
                expandedNowBuckets.insert(bucket)
                visibleLimitNow[bucket] = Self.pageSize
            }
        case .completed:
            if !expandedCompletedBuckets.contains(bucket) {
                expandedCompletedBuckets.insert(bucket)
                visibleLimitCompleted[bucket] = Self.pageSize
            }
        case .snoozed:
            break
        }
    }

    // MARK: - Load / CRUD

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        allInbox = await service.fetchInboxTodos()
        categories = await categoryService.fetchCategories()
    }

    @MainActor
    func refreshLocal() async {
        allInbox = await service.fetchInboxTodos()
    }

    func addInboxTodo(title: String) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { @MainActor in
            _ = try? await service.saveInboxTodo(title: trimmed)
            await refreshLocal()
        }
    }

    func toggleTodo(_ todo: Todo) {
        guard let index = allInbox.firstIndex(where: { $0.id == todo.id }) else { return }
        allInbox[index].isCompleted.toggle()
        allInbox[index].completedAt = allInbox[index].isCompleted ? .now : nil
        allInbox[index].markLocallyModified()
        let updated = allInbox[index]
        Task { try? await service.updateTodo(updated) }
    }

    /// 완료됨 탭 「되돌리기」— 미완료로 돌려 지금(또는 미뤄둠)으로 분류.
    func uncompleteTodo(_ todo: Todo) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        guard todo.isCompleted else { return }
        guard let index = allInbox.firstIndex(where: { $0.id == todo.id }) else { return }
        allInbox[index].isCompleted = false
        allInbox[index].completedAt = nil
        allInbox[index].markLocallyModified()
        let updated = allInbox[index]
        Task { try? await service.updateTodo(updated) }
    }

    func updateTodoTitle(_ todo: Todo, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed != todo.title else { return }
        var updated = todo
        updated.title = trimmed
        updated.markLocallyModified()
        applyLocal(updated)
        Task { try? await service.updateTodo(updated) }
    }

    func saveTodoEdit(_ updated: Todo) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        var saved = updated
        saved.markLocallyModified()
        if saved.date != nil {
            saved.snoozedUntil = nil
        }
        Task { @MainActor in
            try? await service.updateTodo(saved)
            await refreshLocal()
        }
    }

    func moveToToday(_ todo: Todo) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        assignDate(todo, to: Calendar.current.startOfDay(for: .now))
    }

    func assignDate(_ todo: Todo, to newDate: Date) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        var updated = todo
        TodoScheduledTime.applyingDateChange(to: &updated, newDate: newDate)
        updated.snoozedUntil = nil
        updated.markLocallyModified()
        allInbox.removeAll { $0.id == todo.id }
        Task { try? await service.updateTodo(updated) }
    }

    func requestSnooze(_ todo: Todo) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        pendingSnoozeTodo = todo
        showSnoozeSheet = true
    }

    func cancelSnoozeSheet() {
        showSnoozeSheet = false
        pendingSnoozeTodo = nil
        showCustomSnoozePicker = false
    }

    func confirmSnoozeNextWeek() {
        guard let todo = pendingSnoozeTodo else { return }
        let cal = Calendar.current
        let base = cal.startOfDay(for: .now)
        let until = cal.date(byAdding: .weekOfYear, value: 1, to: base) ?? base
        applySnooze(todo, until: until)
        cancelSnoozeSheet()
    }

    func confirmSnoozeNextMonth() {
        guard let todo = pendingSnoozeTodo else { return }
        let cal = Calendar.current
        let base = cal.startOfDay(for: .now)
        let until = cal.date(byAdding: .month, value: 1, to: base) ?? base
        applySnooze(todo, until: until)
        cancelSnoozeSheet()
    }

    func openCustomSnoozePicker() {
        customSnoozeDate = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        )
        showSnoozeSheet = false
        showCustomSnoozePicker = true
    }

    func confirmCustomSnooze() {
        guard let todo = pendingSnoozeTodo else { return }
        let until = Calendar.current.startOfDay(for: customSnoozeDate)
        applySnooze(todo, until: until)
        cancelSnoozeSheet()
    }

    /// 지금으로 복귀 — `snoozedUntil`을 현재 시각으로 두어 「최근」버킷에 들어가게 함.
    func clearSnooze(_ todo: Todo) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        applySnooze(todo, until: .now)
    }

    /// 오래된 할일을 「최근」버킷으로. `now` 직전이면 `isSnoozeActive`에 안 걸림.
    func bumpToRecent(_ todo: Todo) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        guard canBumpToRecent(todo) else { return }
        applySnooze(todo, until: Date.now.addingTimeInterval(-1))
    }

    func canBumpToRecent(_ todo: Todo) -> Bool {
        nowAgeBucket(for: todo) != .recent
    }

    func requestDelete(_ todo: Todo) {
        guard !isCurrentPlannerReadOnly else { showReadOnlyAlert = true; return }
        pendingDeleteTodo = todo
        showDeleteAlert = true
    }

    func confirmDelete() {
        guard let todo = pendingDeleteTodo else { return }
        pendingDeleteTodo = nil
        allInbox.removeAll { $0.id == todo.id }
        Task { try? await service.deleteTodo(id: todo.id) }
    }

    func cancelDelete() {
        pendingDeleteTodo = nil
    }

    func cancelReadOnlyAlert() {
        showReadOnlyAlert = false
    }

    // MARK: - Private

    /// 지금 탭 버킷·정렬 — 스누즈 복귀값 우선, 없으면 노션 생성일.
    private func nowRecencyDate(for todo: Todo) -> Date {
        if let snoozedUntil = todo.snoozedUntil {
            return snoozedUntil
        }
        return todo.notionCreatedAt ?? todo.createdAt
    }

    /// 완료됨 탭 버킷·정렬 — 완료일 우선, 없으면 노션 시각 폴백.
    private func completedRecencyDate(for todo: Todo) -> Date {
        todo.completedAt
            ?? todo.notionLastEditedTime
            ?? todo.notionCreatedAt
            ?? todo.createdAt
    }

    private func nowAgeBucket(for todo: Todo) -> InboxAgeBucket {
        ageBucket(for: nowRecencyDate(for: todo))
    }

    private func completedAgeBucket(for todo: Todo) -> InboxAgeBucket {
        ageBucket(for: completedRecencyDate(for: todo))
    }

    private func ageBucket(for date: Date) -> InboxAgeBucket {
        let cal = Calendar.current
        let now = Date.now
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let thirtyDaysAgo = cal.date(byAdding: .day, value: -30, to: now) ?? now
        let sixMonthsAgo = cal.date(byAdding: .month, value: -6, to: now) ?? now

        if date >= sevenDaysAgo { return .recent }
        if date >= thirtyDaysAgo { return .weekPlus }
        if date >= sixMonthsAgo { return .monthPlus }
        return .halfYearPlus
    }

    private func applySnooze(_ todo: Todo, until: Date?) {
        var updated = todo
        updated.snoozedUntil = until
        updated.markLocallyModified()
        applyLocal(updated)
        do {
            try service.setInboxSnooze(id: todo.id, until: until)
        } catch {
            AppLogger.shared.warn("InboxViewModel", "스누즈 저장 실패 - \(error.localizedDescription)")
        }
    }

    private func applyLocal(_ updated: Todo) {
        if let index = allInbox.firstIndex(where: { $0.id == updated.id }) {
            allInbox[index] = updated
        }
    }
}
