import Foundation
import SwiftData

enum WidgetStoreReader {
    private static let container: ModelContainer? = {
        guard let configuration = AppGroupStore.makeWidgetConfiguration(allowsSave: false) else { return nil }
        return try? ModelContainer(for: AppGroupStore.schema, configurations: configuration)
    }()

    static func loadTodaySnapshot() -> WidgetSnapshotData? {
        guard let container else { return nil }

        let calendar = Calendar.current
        let now = Date.now
        let startOfDay = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let context = ModelContext(container)
        let plannerId = AppGroupUserDefaults.selectedPlannerId() ?? ""
        guard !plannerId.isEmpty else { return nil }

        let predicate = #Predicate<TodoItem> { item in
            item.date >= startOfDay
                && item.date < startOfTomorrow
                && item.plannerId == plannerId
        }
        let descriptor = FetchDescriptor<TodoItem>(predicate: predicate)

        guard let items = try? context.fetch(descriptor) else { return nil }

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
