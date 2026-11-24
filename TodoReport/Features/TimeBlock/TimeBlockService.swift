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

        let categories = categoryInfoById()
        return blocks.compactMap { block in
            guard let todo = todoById[block.todoId] else { return nil }
            let category = todo.categoryId.flatMap { categories[$0] }
            return TimeBlockEntry(
                block: block,
                title: todo.title,
                isCompleted: todo.isCompleted,
                categoryColorHex: category?.colorHex,
                categoryIcon: category?.icon
            )
        }
    }

    /// 블록 고르기 창 목록. 이미 넣은 할 일도 포함한다 (여러 블록에 넣을 수 있음).
    func fetchTodoOptions(for day: Date) async -> [TimeBlockTodoOption] {
        let dayStart = Calendar.current.startOfDay(for: day)
        let todos = await TodoService.shared.fetchTodos(for: dayStart)
        var startsByTodo: [String: [Int]] = [:]
        for block in fetchBlocks(day: dayStart) {
            startsByTodo[block.todoId, default: []].append(block.startMinute)
        }
        return todos.map { todo in
            TimeBlockTodoOption(
                id: todo.id,
                title: todo.title,
                isCompleted: todo.isCompleted,
                placedStartMinutes: (startsByTodo[todo.id] ?? []).sorted()
            )
        }
    }

    // MARK: - 블록 쓰기

    func createBlock(todoId: String, day: Date, startMinute: Int, endMinute: Int) throws {
        let dayStart = Calendar.current.startOfDay(for: day)
        try validate(day: dayStart, startMinute: startMinute, endMinute: endMinute, excludingId: nil)
        let item = TimeBlockItem(
            plannerId: currentPlannerId,
            todoId: todoId,
            day: dayStart,
            startMinute: startMinute,
            endMinute: endMinute
        )
        context.insert(item)
        try saveContext()
        if TimeBlockNotificationManager.shared.isGloballyEnabled {
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

    func setAlarmEnabled(id: String, enabled: Bool) throws {
        guard let item = fetchItem(id: id), item.alarmEnabled != enabled else { return }
        item.alarmEnabled = enabled
        try saveContext()
        syncAlarm(for: item)
    }

    func deleteBlock(id: String) throws {
        guard let item = fetchItem(id: id) else { return }
        context.delete(item)
        try saveContext()
        TimeBlockNotificationManager.shared.cancel(blockIds: [id])
    }

    /// 메뉴 「블록 시작 알림」을 바꾼 뒤 오늘 이후 블록 알림을 다시 맞춘다 (모든 플래너).
    func resyncUpcomingAlarms() {
        let todayStart = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<TimeBlockItem>(predicate: #Predicate { $0.day >= todayStart })
        for item in (try? context.fetch(descriptor)) ?? [] {
            syncAlarm(for: item)
        }
    }

    // MARK: - 할 일 (기존 TodoService 경유)

    /// 투두 탭 체크와 같은 경로: 로컬 저장 → 알림 재예약 → SyncQueue(노션) → 위젯
    func toggleCompletion(todoId: String) async throws {
        let id = todoId
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        var todo = item.toTodo()
        todo.isCompleted.toggle()
        todo.completedAt = todo.isCompleted ? .now : nil
        todo.markLocallyModified()
        try await TodoService.shared.updateTodo(todo)
        await refreshWidgetIfToday(todo.date)
        // 완료하면 그 할 일의 블록 알림은 끄고, 완료를 풀면 다시 켠다
        let blockDescriptor = FetchDescriptor<TimeBlockItem>(predicate: #Predicate { $0.todoId == id })
        for block in (try? context.fetch(blockDescriptor)) ?? [] {
            TimeBlockNotificationManager.shared.sync(block: TimeBlock(item: block), todo: todo)
        }
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

        for block in blocks {
            guard let todo = todoById[block.todoId] else { continue }
            let minutes = max(block.endMinute - block.startMinute, 0)
            let key = todo.categoryId.flatMap { categoryById[$0] != nil ? $0 : nil } ?? TimeBlockUsageSummary.uncategorizedKey
            plannedByCategory[key, default: 0] += minutes
            guard todo.isCompleted else { continue }
            completedByCategory[key, default: 0] += minutes
            if let index = ranges.firstIndex(where: { $0.contains(block.day) }) {
                bucketMinutes[index][key, default: 0] += minutes
            }
        }

        func colorHex(_ key: String) -> String {
            categoryById[key]?.colorHex ?? TimeBlockUsageSummary.uncategorizedColorHex
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
                }
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
            categories: categories
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
        guard startMinute >= 0, endMinute <= TimeBlockLayout.minutesPerDay, endMinute > startMinute else {
            throw TimeBlockError.invalidRange
        }
        let others = fetchBlocks(day: dayStart).filter { $0.id != excludingId }
        if others.contains(where: { $0.overlaps(start: startMinute, end: endMinute) }) {
            throw TimeBlockError.overlap
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
