import Foundation
import OSLog
import SwiftData

enum WidgetStoreReader {
    private static let logger = Logger(subsystem: "kr.nock.TodoReport", category: "WidgetStoreReader")

    /// 한 번 열리면 계속 쓴다. **실패는 저장하지 않는다** — 예전엔 `static let`이라 한 번 실패하면
    /// 위젯 프로세스가 살아 있는 동안 계속 빈 화면이었다. 앱 업데이트로 저장소 모양이 바뀌면(새 칸 추가)
    /// 앱이 먼저 열어 고쳐 놓기 전까지 위젯(읽기 전용)은 열지 못하므로, 다음 갱신 때 다시 시도해야 한다
    private static var cachedContainer: ModelContainer?

    private static var container: ModelContainer? {
        if let cachedContainer { return cachedContainer }
        guard let configuration = AppGroupStore.makeWidgetConfiguration(allowsSave: false) else {
            logger.error("container nil: shared store file missing")
            return nil
        }
        do {
            let opened = try ModelContainer(for: AppGroupStore.schema, configurations: configuration)
            cachedContainer = opened
            return opened
        } catch {
            logger.error("container nil: ModelContainer init failed — \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func loadTodaySnapshot(for referenceDate: Date = .now) -> WidgetSnapshotData? {
        guard let container else {
            logger.error("loadTodaySnapshot aborted: container nil")
            return nil
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let context = ModelContext(container)
        let plannerId = AppGroupUserDefaults.selectedPlannerId() ?? ""
        guard !plannerId.isEmpty else { return nil }

        // Optional date의 flatMap/#Predicate는 SwiftData에서 조용히 잘못된 결과를 낼 수 있어
        // plannerId만 fetch한 뒤 Swift에서 오늘 범위로 필터한다 (인박스 date==nil 제외).
        let fetched: [TodoItem]
        let hiddenCategoryIds: Set<String>
        let items: [TodoItem]
        do {
            let predicate = #Predicate<TodoItem> { item in
                item.plannerId == plannerId
            }
            fetched = try context.fetch(FetchDescriptor<TodoItem>(predicate: predicate))
            hiddenCategoryIds = try fetchHiddenCategoryIds(plannerId: plannerId, context: context)
            items = fetched.filter { item in
                guard let date = item.date else { return false }
                guard date >= startOfDay && date < startOfTomorrow else { return false }
                guard let categoryId = item.categoryId else { return true }
                return !hiddenCategoryIds.contains(categoryId)
            }
        } catch {
            logger.error("fetch throw (plannerId): \(error.localizedDescription, privacy: .public)")
            return nil
        }

        let hideCompleted = AppGroupUserDefaults.todoHideCompleted()
        let listItems = widgetListItems(from: items, hideCompleted: hideCompleted)
        let plannerName = fetchPlannerName(id: plannerId, context: context) ?? String(localized: "내 플래너")
        let previews = recurringPreviews(
            plannerId: plannerId,
            startOfDay: startOfDay,
            fetchedTodos: fetched,
            hiddenCategoryIds: hiddenCategoryIds,
            context: context
        )

        let completedCount = items.filter(\.isCompleted).count
        let totalCount = items.count + previews.count
        var widgetTodos = listItems.map {
            WidgetTodoItem(
                id: $0.id,
                title: $0.title,
                isCompleted: $0.isCompleted,
                isPinned: $0.isPinned
            )
        }
        let insertAt = widgetTodos.firstIndex(where: \.isCompleted) ?? widgetTodos.endIndex
        widgetTodos.insert(contentsOf: previews, at: insertAt)

        return WidgetSnapshotData(
            date: referenceDate,
            plannerName: plannerName,
            completionRate: totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount),
            completedCount: completedCount,
            totalCount: totalCount,
            todos: Array(widgetTodos.prefix(10))
        )
    }

    private static func fetchPlannerName(id: String, context: ModelContext) -> String? {
        let predicate = #Predicate<PlannerItem> { $0.id == id }
        let descriptor = FetchDescriptor<PlannerItem>(predicate: predicate)
        return try? context.fetch(descriptor).first?.name
    }

    /// 앱 `TodoViewModel.excludingHiddenCategoryTodos`와 동일 — 숨긴 카테고리 할일 제외용 id 집합.
    private static func fetchHiddenCategoryIds(plannerId: String, context: ModelContext) throws -> Set<String> {
        let predicate = #Predicate<CategoryItem> { item in
            item.plannerId == plannerId
        }
        let categories = try context.fetch(FetchDescriptor<CategoryItem>(predicate: predicate))
        return Set(categories.filter(\.isHidden).map(\.id))
    }

    private static func widgetListItems(from items: [TodoItem], hideCompleted: Bool) -> [TodoItem] {
        // 앱 투두 탭과 같은 순서 — 손으로 정한 순서 키, 없으면 만든 시각 (같은 척도)
        func sortKey(_ item: TodoItem) -> Double {
            item.manualSortOrder ?? (item.notionCreatedAt ?? item.createdAt).timeIntervalSinceReferenceDate
        }

        let pinned = items
            .filter { $0.isPinned && !$0.isCompleted }
            .sorted { sortKey($0) < sortKey($1) }
        let normal = items
            .filter { !$0.isPinned && !$0.isCompleted }
            .sorted { sortKey($0) < sortKey($1) }
        let completed: [TodoItem] = hideCompleted ? [] :
            items.filter(\.isCompleted)
                .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
        return pinned + normal + completed
    }

    /// 오늘 발생분이 아직 없을 때만 읽기 전용 미리보기. SwiftData에 쓰지 않는다.
    private static func recurringPreviews(
        plannerId: String,
        startOfDay: Date,
        fetchedTodos: [TodoItem],
        hiddenCategoryIds: Set<String>,
        context: ModelContext
    ) -> [WidgetTodoItem] {
        if isPlannerReadOnly(id: plannerId, context: context) { return [] }

        let seriesList: [RecurringSeries]
        do {
            seriesList = try context.fetch(FetchDescriptor<RecurringSeries>())
        } catch {
            logger.error("recurring series fetch: \(error.localizedDescription, privacy: .public)")
            return []
        }

        var previews: [(createdAt: Date, item: WidgetTodoItem)] = []
        for series in seriesList where series.isActive {
            if let seriesPlanner = series.plannerId, seriesPlanner != plannerId { continue }
            if let categoryId = series.categoryId, hiddenCategoryIds.contains(categoryId) { continue }
            let existing = existingOccurrenceDates(from: fetchedTodos, seriesId: series.id)
            guard series.shouldPreviewOccurrence(on: startOfDay, existingOccurrenceDates: existing) else {
                continue
            }
            previews.append((
                series.createdAt,
                WidgetTodoItem(
                    id: "recurring-preview-\(series.id)",
                    title: series.title,
                    isCompleted: false,
                    isPinned: false
                )
            ))
        }
        return previews.sorted { $0.createdAt < $1.createdAt }.map(\.item)
    }

    private static func existingOccurrenceDates(from items: [TodoItem], seriesId: String) -> Set<Date> {
        let cal = Calendar.current
        return Set(
            items.compactMap { item -> Date? in
                guard item.recurrenceId == seriesId, let date = item.date else { return nil }
                return cal.startOfDay(for: date)
            }
        )
    }

    private static func isPlannerReadOnly(id: String, context: ModelContext) -> Bool {
        let predicate = #Predicate<PlannerItem> { $0.id == id }
        return (try? context.fetch(FetchDescriptor<PlannerItem>(predicate: predicate)).first)?.isReadOnly == true
    }
}
