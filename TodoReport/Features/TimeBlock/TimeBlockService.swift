import Foundation
import SwiftData

/// 타임라인 데이터 창구.
/// - 블록: SwiftData 로컬 전용(`TimeBlockItem`). 노션에 올리지 않는다.
/// - 할 일 읽기·완료·생성: 기존 `TodoService` 공개 API만 쓴다 → 노션 동기화·알림·위젯 경로가 투두 탭과 같다.
final class TimeBlockService {
    static let shared = TimeBlockService()
    private init() {}

    private var context: ModelContext { PersistenceController.shared.context }

    private var currentPlannerId: String? { PlannerService.shared.selectedPlanner?.id }

    // MARK: - 조회

    /// 그날 타임라인에 그릴 블록. 할 일이 다른 날로 옮겨졌으면 숨기고, 삭제됐으면 블록도 지운다.
    func fetchEntries(for day: Date) async -> [TimeBlockEntry] {
        let dayStart = Calendar.current.startOfDay(for: day)
        let blocks = fetchBlocks(day: dayStart)
        guard !blocks.isEmpty else { return [] }

        let todos = await TodoService.shared.fetchTodos(for: dayStart)
        let todoById = Dictionary(todos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        removeBlocksOfDeletedTodos(blocks.filter { todoById[$0.todoId] == nil })
        let reconciled = clearStaleBlockCompletion(blocks, todoById: todoById)

        let categories = categoryInfoById()
        return reconciled.compactMap { block in
            guard let todo = todoById[block.todoId] else { return nil }
            let category = todo.categoryId.flatMap { categories[$0] }
            return TimeBlockEntry(
                block: block,
                title: todo.title,
                // 할 일이 완료면 모든 블록 완료, 아니면 블록마다 체크한 것만
                isCompleted: todo.isCompleted || block.isCompleted,
                categoryColorHex: category?.colorHex,
                categoryIcon: category?.icon,
                categoryId: todo.categoryId,
                memo: todo.memo,
                recurrenceId: todo.recurrenceId
            )
        }
    }

    /// 블록 고르기 창 목록. 이미 넣은 할 일도 포함한다 (여러 블록에 넣을 수 있음).
    func fetchTodoOptions(for day: Date) async -> [TimeBlockTodoOption] {
        let dayStart = Calendar.current.startOfDay(for: day)
        let todos = await TodoService.shared.fetchTodos(for: dayStart)
        var startsByTodo: [String: [Int]] = [:]
        var minutesByTodo: [String: Int] = [:]
        for block in fetchBlocks(day: dayStart) {
            startsByTodo[block.todoId, default: []].append(block.startMinute)
            minutesByTodo[block.todoId, default: 0] += block.durationMinutes
        }
        return todos.map { todo in
            TimeBlockTodoOption(
                id: todo.id,
                title: todo.title,
                isCompleted: todo.isCompleted,
                placedStartMinutes: (startsByTodo[todo.id] ?? []).sorted(),
                placedTotalMinutes: minutesByTodo[todo.id] ?? 0
            )
        }
    }

    // MARK: - 블록 쓰기

    func createBlock(todoId: String, day: Date, startMinute: Int, endMinute: Int) throws {
        let dayStart = Calendar.current.startOfDay(for: day)
        try validate(day: dayStart, startMinute: startMinute, endMinute: endMinute, excludingId: nil)
        // 알림은 메뉴 「새 블록 기본 알림」 값으로 시작 (블록마다 나중에 바꿀 수 있음)
        let alarms = TimeBlockNotificationManager.shared
        let item = TimeBlockItem(
            plannerId: currentPlannerId,
            todoId: todoId,
            day: dayStart,
            startMinute: startMinute,
            endMinute: endMinute,
            alarmEnabled: alarms.isGloballyEnabled,
            endAlarmEnabled: alarms.isEndGloballyEnabled
        )
        context.insert(item)
        try saveContext()
        if item.alarmEnabled || item.endAlarmEnabled {
            // 이미 허용·거부한 경우엔 다시 묻지 않는다 (시스템 동작)
            TodoNotificationManager.shared.requestPermission()
        }
        syncAlarm(for: item)
    }

    func updateBlockTime(id: String, startMinute: Int, endMinute: Int) throws {
        guard let item = fetchItem(id: id) else { return }
        try validate(day: item.day, startMinute: startMinute, endMinute: endMinute, excludingId: id)
        item.startMinute = startMinute
        item.endMinute = endMinute
        try saveContext()
        syncAlarm(for: item)
    }

    func setAlarms(id: String, startEnabled: Bool, endEnabled: Bool) throws {
        guard let item = fetchItem(id: id) else { return }
        guard item.alarmEnabled != startEnabled || item.endAlarmEnabled != endEnabled else { return }
        item.alarmEnabled = startEnabled
        item.endAlarmEnabled = endEnabled
        try saveContext()
        syncAlarm(for: item)
    }

    /// 할 일까지 삭제. 할 일 삭제는 투두 탭과 같은 경로(`TodoService.deleteTodo` → 노션 삭제 큐·알림 취소),
    /// 「이후 모두」는 투두 탭과 같이 `capSeriesEndDate`(시리즈를 이 날 전에 끝내고 이 날부터 지움).
    /// 이 할 일의 블록은 모든 날짜에서 지운다 (다른 날 블록 알림이 남지 않게)
    func deleteTodo(todoId: String, scope: TimeBlockTodoDeleteScope) async throws {
        if PlannerService.shared.selectedPlanner?.isReadOnly == true {
            throw TimeBlockError.readOnlyPlanner
        }
        guard let todo = fetchTodo(id: todoId) else { return }
        try deleteBlocks(ofTodo: todoId)
        if scope == .allFuture, let seriesId = todo.recurrenceId, let date = todo.date {
            await RecurringTodoManager.shared.capSeriesEndDate(seriesId: seriesId, beforeDate: date)
        } else {
            try await TodoService.shared.deleteTodo(id: todoId)
        }
        await refreshWidgetIfToday(todo.date)
    }

    private func deleteBlocks(ofTodo todoId: String) throws {
        let descriptor = FetchDescriptor<TimeBlockItem>(predicate: #Predicate { $0.todoId == todoId })
        let items = (try? context.fetch(descriptor)) ?? []
        guard !items.isEmpty else { return }
        let ids = items.map(\.id)
        items.forEach { context.delete($0) }
        try saveContext()
        TimeBlockNotificationManager.shared.cancel(blockIds: ids)
    }

    func deleteBlock(id: String) throws {
        guard let item = fetchItem(id: id) else { return }
        context.delete(item)
        try saveContext()
        TimeBlockNotificationManager.shared.cancel(blockIds: [id])
    }

    /// 기존 블록 알림을 한 번 정리하기 전에 쓰던 규칙: 메뉴가 꺼져 있으면 블록 설정과 상관없이 안 울렸다.
    /// 규칙이 바뀌어도 울리던 것만 울리게, 처음 한 번 블록 설정을 그때 메뉴 상태에 맞춘다
    /// (예: 메뉴 종료 알림이 꺼져 있었으면 모든 블록의 종료 알림을 끔). 이후로는 블록 설정만 따른다
    func migrateAlarmFlagsIfNeeded() {
        let key = "timeBlockAlarmFlagsMigratedV1"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: key) else { return }
        let alarms = TimeBlockNotificationManager.shared
        let startOn = alarms.isGloballyEnabled
        let endOn = alarms.isEndGloballyEnabled
        let items = (try? context.fetch(FetchDescriptor<TimeBlockItem>())) ?? []
        for item in items {
            if !startOn { item.alarmEnabled = false }
            if !endOn { item.endAlarmEnabled = false }
        }
        do {
            try saveContext()
        } catch {
            return
        }
        defaults.set(true, forKey: key)
        resyncUpcomingAlarms()
    }

    /// 오늘 이후 블록 알림을 다시 맞춘다 (모든 플래너).
    /// 일과 시간이 새벽까지면 어제 블록이 아직 남았을 수 있어 어제부터 본다 (지난 알림은 예약 단계에서 걸러짐)
    func resyncUpcomingAlarms() {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let fromDay = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        let descriptor = FetchDescriptor<TimeBlockItem>(predicate: #Predicate { $0.day >= fromDay })
        for item in (try? context.fetch(descriptor)) ?? [] {
            syncAlarm(for: item)
        }
    }

    // MARK: - 할 일 (기존 TodoService 경유)

    /// 진행 중 블록을 일찍 끝낸다: 종료를 지금(분 단위)으로 줄이고, 원래 종료는 `plannedEndMinute`에 남긴 뒤 완료.
    /// 이미 줄인 적이 있으면 처음 계획한 종료를 그대로 둔다. 시작한 지 1분이 안 됐으면 1분짜리로
    func finishBlockEarly(blockId: String, now: Date = .now) async throws {
        guard let item = fetchItem(id: blockId) else { return }
        let nowMinute = TimeBlockLayout.minutesSince(day: item.day, until: now)
        let newEnd = max(item.startMinute + 1, nowMinute)
        if newEnd < item.endMinute {
            if item.plannedEndMinute == nil {
                item.plannedEndMinute = item.endMinute
            }
            item.endMinute = newEnd
            try saveContext()
        }
        try await toggleBlockCompletion(blockId: blockId)
    }

    /// 완료를 푼 블록이 일찍 끝내 줄인 블록이면 원래 길이로. 비운 자리에 다른 블록이 들어와 겹치면 줄인 길이 그대로
    /// (그때는 원래 계획 값을 남겨 둔다). 저장은 부르는 쪽에서
    private func restorePlannedEndIfPossible(_ item: TimeBlockItem) {
        guard !item.isCompleted, let planned = item.plannedEndMinute, planned > item.endMinute else { return }
        let others = fetchBlocks(day: item.day).filter { $0.id != item.id }
        guard !others.contains(where: { $0.overlaps(start: item.startMinute, end: planned) }) else { return }
        item.endMinute = planned
        item.plannedEndMinute = nil
    }

    /// 블록 체크 원. 그 블록만 완료/취소하고, 그날 이 할 일의 블록이 모두 완료면 할 일도 완료한다.
    /// 할 일 완료·취소는 투두 탭 체크와 같은 경로: 로컬 저장 → 알림 재예약 → SyncQueue(노션) → 위젯
    func toggleBlockCompletion(blockId: String) async throws {
        guard let item = fetchItem(id: blockId) else { return }
        let todoId = item.todoId
        let day = item.day
        let todoDescriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == todoId })
        guard let todoItem = try context.fetch(todoDescriptor).first else { return }
        var todo = todoItem.toTodo()

        let siblingDescriptor = FetchDescriptor<TimeBlockItem>(
            predicate: #Predicate { $0.todoId == todoId && $0.day == day }
        )
        let siblings = (try? context.fetch(siblingDescriptor)) ?? [item]

        let wasDone = todo.isCompleted || item.isCompleted
        if wasDone {
            // 할 일 전체가 완료였다면 다른 블록은 완료로 남기고 이 블록만 푼다
            if todo.isCompleted {
                siblings.forEach { $0.isCompleted = true }
            }
            item.isCompleted = false
        } else {
            item.isCompleted = true
        }
        restorePlannedEndIfPossible(item)
        try saveContext()

        let allDone = !siblings.isEmpty && siblings.allSatisfy(\.isCompleted)
        if allDone != todo.isCompleted {
            todo.isCompleted = allDone
            todo.completedAt = allDone ? .now : nil
            todo.markLocallyModified()
            try await TodoService.shared.updateTodo(todo)
            await refreshWidgetIfToday(todo.date)
        }
        // 완료한 블록 알림만 끄고, 같은 할 일의 남은 블록 알림은 유지
        for block in siblings {
            TimeBlockNotificationManager.shared.sync(block: TimeBlock(item: block), todo: todo)
        }
    }

    /// 블록 팝업에서 할 일 이름·카테고리·메모를 고친다. 투두 탭과 같은 `TodoService.updateTodo` 경로(노션 반영).
    /// 반복 할 일은 이 날 할 일만 바뀐다 (투두 탭 「이 항목만」과 같음). 빈 메모는 메모 없음
    func updateTodoDetails(todoId: String, title: String, categoryId: String?, memo: String) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let trimmedMemo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        let newMemo: String? = trimmedMemo.isEmpty ? nil : trimmedMemo
        try await updateTodo(id: todoId) { todo in
            guard todo.title != trimmed
                || todo.categoryId != categoryId
                || (todo.memo ?? "") != (newMemo ?? "") else { return false }
            todo.title = trimmed
            todo.categoryId = categoryId
            todo.memo = newMemo
            return true
        }
    }

    /// 할 일 하나를 읽어 고친 뒤 `TodoService.updateTodo`로 저장. change가 false면 저장하지 않음
    private func updateTodo(id: String, change: (inout Todo) -> Bool) async throws {
        if PlannerService.shared.selectedPlanner?.isReadOnly == true {
            throw TimeBlockError.readOnlyPlanner
        }
        guard var todo = fetchTodo(id: id) else { return }
        guard change(&todo) else { return }
        todo.markLocallyModified()
        try await TodoService.shared.updateTodo(todo)
        await refreshWidgetIfToday(todo.date)
    }

    /// 새 할 일을 만들고 바로 블록에 넣는다. 할 일 생성은 투두 탭과 같은 `TodoService.saveTodo` 경로.
    func createTodoAndBlock(title: String, day: Date, startMinute: Int, endMinute: Int) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if PlannerService.shared.selectedPlanner?.isReadOnly == true {
            throw TimeBlockError.readOnlyPlanner
        }
        let dayStart = Calendar.current.startOfDay(for: day)
        try validate(day: dayStart, startMinute: startMinute, endMinute: endMinute, excludingId: nil)
        let todo = Todo(
            title: trimmed,
            date: dayStart,
            plannerId: currentPlannerId,
            localModifiedAt: .now
        )
        try await TodoService.shared.saveTodo(todo)
        try createBlock(todoId: todo.id, day: dayStart, startMinute: startMinute, endMinute: endMinute)
        await refreshWidgetIfToday(dayStart)
    }

    // MARK: - 리포트용 집계

    /// 그날 완료한 블록 시간 합(분). 투두 탭 하루 리포트 카드용 — 현재 플래너만
    func completedMinutes(on day: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return usageSummary(ranges: [start..<end], labels: [""]).completedMinutes
    }

    /// 리포트 막대 구간(주간 = 하루씩, 월간 = 7일씩)별 시간 사용. 현재 플래너만.
    func usageSummary(ranges: [Range<Date>], labels: [String]) -> TimeBlockUsageSummary {
        guard let periodStart = ranges.first?.lowerBound, let periodEnd = ranges.last?.upperBound else {
            return .empty
        }
        let plannerId = currentPlannerId
        let descriptor = FetchDescriptor<TimeBlockItem>(
            predicate: #Predicate { $0.day >= periodStart && $0.day < periodEnd }
        )
        let blocks = ((try? context.fetch(descriptor)) ?? [])
            .filter { plannerId == nil || $0.plannerId == plannerId || $0.plannerId == nil }
        guard !blocks.isEmpty else { return .empty }

        let todoIds = Array(Set(blocks.map(\.todoId)))
        let todoDescriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { todoIds.contains($0.id) })
        let todoById = Dictionary(
            ((try? context.fetch(todoDescriptor)) ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let categoryItems = (try? context.fetch(FetchDescriptor<CategoryItem>())) ?? []
        let categoryById = Dictionary(categoryItems.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var completedByCategory: [String: Int] = [:]
        var plannedByCategory: [String: Int] = [:]
        var bucketMinutes: [[String: Int]] = Array(repeating: [:], count: ranges.count)
        var bucketPlanned: [[String: Int]] = Array(repeating: [:], count: ranges.count)
        var placed: [TimeBlockUsageSummary.PlacedBlock] = []

        func colorHex(_ key: String) -> String {
            categoryById[key]?.colorHex ?? TimeBlockUsageSummary.uncategorizedColorHex
        }

        for block in blocks {
            guard let todo = todoById[block.todoId] else { continue }
            let minutes = max(block.endMinute - block.startMinute, 0)
            let key = todo.categoryId.flatMap { categoryById[$0] != nil ? $0 : nil } ?? TimeBlockUsageSummary.uncategorizedKey
            plannedByCategory[key, default: 0] += minutes
            let bucketIndex = ranges.firstIndex(where: { $0.contains(block.day) })
            let isDone = todo.isCompleted || block.isCompleted
            if let bucketIndex {
                bucketPlanned[bucketIndex][key, default: 0] += minutes
                placed.append(.init(
                    id: block.id,
                    bucketIndex: bucketIndex,
                    startMinute: block.startMinute,
                    endMinute: block.endMinute,
                    colorHex: colorHex(key),
                    isCompleted: isDone
                ))
            }
            // 집중 시간 = 완료한 블록 시간 (같은 할 일의 블록 중 체크한 것만)
            guard isDone else { continue }
            completedByCategory[key, default: 0] += minutes
            if let bucketIndex {
                bucketMinutes[bucketIndex][key, default: 0] += minutes
            }
        }

        func name(_ key: String) -> String {
            categoryById[key]?.name ?? String(localized: "미분류")
        }
        /// 카테고리 정렬: 쓴 시간 많은 순, 미분류는 맨 뒤
        func sortKeys(_ keys: [String]) -> [String] {
            keys.sorted { lhs, rhs in
                if lhs == TimeBlockUsageSummary.uncategorizedKey { return false }
                if rhs == TimeBlockUsageSummary.uncategorizedKey { return true }
                return (completedByCategory[lhs] ?? 0, plannedByCategory[lhs] ?? 0)
                    > (completedByCategory[rhs] ?? 0, plannedByCategory[rhs] ?? 0)
            }
        }

        let orderedKeys = sortKeys(Array(plannedByCategory.keys))
        let buckets = ranges.indices.map { index in
            TimeBlockUsageSummary.Bucket(
                id: index,
                label: index < labels.count ? labels[index] : "",
                segments: orderedKeys.compactMap { key in
                    guard let minutes = bucketMinutes[index][key], minutes > 0 else { return nil }
                    return .init(id: key, colorHex: colorHex(key), minutes: minutes)
                },
                plannedMinutesByCategory: bucketPlanned[index]
            )
        }
        let categories = orderedKeys.map { key in
            TimeBlockUsageSummary.CategoryUsage(
                id: key,
                name: name(key),
                colorHex: colorHex(key),
                completedMinutes: completedByCategory[key] ?? 0,
                plannedMinutes: plannedByCategory[key] ?? 0
            )
        }
        return TimeBlockUsageSummary(
            completedMinutes: completedByCategory.values.reduce(0, +),
            plannedMinutes: plannedByCategory.values.reduce(0, +),
            buckets: buckets,
            categories: categories,
            blocks: placed
        )
    }

    // MARK: - Private

    private func fetchBlocks(day dayStart: Date) -> [TimeBlock] {
        let plannerId = currentPlannerId
        let descriptor = FetchDescriptor<TimeBlockItem>(
            predicate: #Predicate { $0.day == dayStart },
            sortBy: [SortDescriptor(\.startMinute)]
        )
        let items = (try? context.fetch(descriptor)) ?? []
        return items
            .filter { plannerId == nil || $0.plannerId == plannerId || $0.plannerId == nil }
            .map { TimeBlock(item: $0) }
    }

    private func fetchItem(id: String) -> TimeBlockItem? {
        let descriptor = FetchDescriptor<TimeBlockItem>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    /// 겹침 금지·범위 검사
    private func validate(day dayStart: Date, startMinute: Int, endMinute: Int, excludingId: String?) throws {
        // 끝은 다음 날 새벽까지 허용 (일과 시간이 자정을 넘는 경우). 블록 길이는 24시간 이하
        guard startMinute >= 0,
              endMinute <= TimeBlockDayRange.latestEndMinute,
              endMinute > startMinute,
              endMinute - startMinute <= TimeBlockLayout.minutesPerDay else {
            throw TimeBlockError.invalidRange
        }
        let others = fetchBlocks(day: dayStart).filter { $0.id != excludingId }
        if others.contains(where: { $0.overlaps(start: startMinute, end: endMinute) }) {
            throw TimeBlockError.overlap
        }
    }

    /// 투두 탭에서 할 일 완료를 풀었는데 블록 체크가 모두 남아 있으면(= 블록으로 완료했던 할 일) 블록 체크도 푼다.
    /// 그래야 두 화면이 어긋나지 않는다. 일부만 체크된 블록은 그대로 둔다.
    private func clearStaleBlockCompletion(_ blocks: [TimeBlock], todoById: [String: Todo]) -> [TimeBlock] {
        let staleTodoIds = Dictionary(grouping: blocks, by: \.todoId).compactMap { todoId, group -> String? in
            guard let todo = todoById[todoId], !todo.isCompleted,
                  group.allSatisfy(\.isCompleted) else { return nil }
            return todoId
        }
        guard !staleTodoIds.isEmpty else { return blocks }
        let stale = Set(staleTodoIds)
        var updatedById: [String: TimeBlock] = [:]
        for block in blocks where stale.contains(block.todoId) {
            guard let item = fetchItem(id: block.id) else { continue }
            item.isCompleted = false
            // 투두 탭에서 완료를 풀었을 때도 일찍 끝내 줄인 블록은 원래 길이로
            restorePlannedEndIfPossible(item)
            updatedById[block.id] = TimeBlock(item: item)
        }
        try? context.save()
        // 완료가 풀린 블록은 알림을 다시 맞춘다 (원래 길이로 돌아왔으면 종료 알림도 그 시각으로)
        for id in updatedById.keys {
            if let item = fetchItem(id: id) { syncAlarm(for: item) }
        }
        return blocks.map { block in
            guard stale.contains(block.todoId) else { return block }
            if let updated = updatedById[block.id] { return updated }
            var cleared = block
            cleared.isCompleted = false
            return cleared
        }
    }

    /// 다른 날로 옮겨진 할 일의 블록은 남기고(다시 돌아오면 보임), 삭제된 할 일의 블록만 지운다.
    private func removeBlocksOfDeletedTodos(_ candidates: [TimeBlock]) {
        var removed = false
        for block in candidates {
            let todoId = block.todoId
            let todoDescriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == todoId })
            let exists = ((try? context.fetchCount(todoDescriptor)) ?? 1) > 0
            guard !exists, let item = fetchItem(id: block.id) else { continue }
            context.delete(item)
            TimeBlockNotificationManager.shared.cancel(blockIds: [block.id])
            removed = true
        }
        if removed {
            try? context.save()
        }
    }

    private func categoryInfoById() -> [String: (colorHex: String, icon: String)] {
        let plannerId = currentPlannerId
        let items = (try? context.fetch(FetchDescriptor<CategoryItem>())) ?? []
        var map: [String: (colorHex: String, icon: String)] = [:]
        for item in items where plannerId == nil || item.plannerId == plannerId || item.plannerId == nil {
            map[item.id] = (item.colorHex, item.icon)
        }
        return map
    }

    private func fetchTodo(id: String) -> Todo? {
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor).first)?.toTodo()
    }

    private func syncAlarm(for item: TimeBlockItem) {
        TimeBlockNotificationManager.shared.sync(block: TimeBlock(item: item), todo: fetchTodo(id: item.todoId))
    }

    private func saveContext() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw TimeBlockError.saveFailed
        }
    }

    private func refreshWidgetIfToday(_ date: Date?) async {
        guard let date, Calendar.current.isDateInToday(date) else { return }
        await WidgetDataProvider.shared.refreshTodayFromStore()
    }
}
