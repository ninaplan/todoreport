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

        let colors = categoryColorHexById()
        return blocks.compactMap { block in
            guard let todo = todoById[block.todoId] else { return nil }
            let colorHex = todo.categoryId.flatMap { colors[$0] }
            return TimeBlockEntry(
                block: block,
                title: todo.title,
                isCompleted: todo.isCompleted,
                categoryColorHex: colorHex
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
        context.insert(TimeBlockItem(
            plannerId: currentPlannerId,
            todoId: todoId,
            day: dayStart,
            startMinute: startMinute,
            endMinute: endMinute
        ))
        try saveContext()
    }

    func updateBlockTime(id: String, startMinute: Int, endMinute: Int) throws {
        guard let item = fetchItem(id: id) else { return }
        try validate(day: item.day, startMinute: startMinute, endMinute: endMinute, excludingId: id)
        item.startMinute = startMinute
        item.endMinute = endMinute
        try saveContext()
    }

    func deleteBlock(id: String) throws {
        guard let item = fetchItem(id: id) else { return }
        context.delete(item)
        try saveContext()
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
            removed = true
        }
        if removed {
            try? context.save()
        }
    }

    private func categoryColorHexById() -> [String: String] {
        let plannerId = currentPlannerId
        let items = (try? context.fetch(FetchDescriptor<CategoryItem>())) ?? []
        var map: [String: String] = [:]
        for item in items where plannerId == nil || item.plannerId == plannerId || item.plannerId == nil {
            map[item.id] = item.colorHex
        }
        return map
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
