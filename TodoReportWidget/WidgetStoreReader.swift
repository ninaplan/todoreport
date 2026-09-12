import Foundation
import OSLog
import SwiftData

enum WidgetStoreReader {
    private static let logger = Logger(subsystem: "kr.nock.TodoReport", category: "WidgetStoreReader")

    private static let container: ModelContainer? = {
        guard let configuration = AppGroupStore.makeWidgetConfiguration(allowsSave: false) else {
            logger.error("container nil: shared store file missing")
            return nil
        }
        do {
            return try ModelContainer(for: AppGroupStore.schema, configurations: configuration)
        } catch {
            logger.error("container nil: ModelContainer init failed — \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }()

    static func loadTodaySnapshot() -> WidgetSnapshotData? {
        guard let container else {
            logger.error("loadTodaySnapshot aborted: container nil")
            return nil
        }

        let calendar = Calendar.current
        let now = Date.now
        let startOfDay = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let context = ModelContext(container)
        let plannerId = AppGroupUserDefaults.selectedPlannerId() ?? ""
        guard !plannerId.isEmpty else { return nil }

        // Optional date의 flatMap/#Predicate는 SwiftData에서 조용히 잘못된 결과를 낼 수 있어
        // plannerId만 fetch한 뒤 Swift에서 오늘 범위로 필터한다 (인박스 date==nil 제외).
        let items: [TodoItem]
        do {
            let predicate = #Predicate<TodoItem> { item in
                item.plannerId == plannerId
            }
            let fetched = try context.fetch(FetchDescriptor<TodoItem>(predicate: predicate))
            let hiddenCategoryIds = try fetchHiddenCategoryIds(plannerId: plannerId, context: context)
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

        let completedCount = items.filter(\.isCompleted).count
        let totalCount = items.count
        let widgetTodos = listItems.prefix(10).map {
            WidgetTodoItem(
                id: $0.id,
                title: $0.title,
                isCompleted: $0.isCompleted,
                isPinned: $0.isPinned
            )
        }

        return WidgetSnapshotData(
            date: now,
            plannerName: plannerName,
            completionRate: totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount),
            completedCount: completedCount,
            totalCount: totalCount,
            todos: Array(widgetTodos)
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
        func sortDate(_ item: TodoItem) -> Date { item.notionCreatedAt ?? item.createdAt }

        let pinned = items
            .filter { $0.isPinned && !$0.isCompleted }
            .sorted { sortDate($0) < sortDate($1) }
        let normal = items
            .filter { !$0.isPinned && !$0.isCompleted }
            .sorted { sortDate($0) < sortDate($1) }
        let completed: [TodoItem] = hideCompleted ? [] :
            items.filter(\.isCompleted)
                .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
        return pinned + normal + completed
    }
}
