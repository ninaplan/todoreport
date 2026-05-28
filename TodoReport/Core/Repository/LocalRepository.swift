import SwiftData
import Foundation

final class LocalRepository: DataRepository {
    private let context: ModelContext

    init(context: ModelContext = PersistenceController.shared.context) {
        self.context = context
    }

    // MARK: - Todo

    func fetchTodos(for date: Date) async throws -> [Todo] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor).map { $0.toTodo() }
    }

    func saveTodo(_ todo: Todo) async throws {
        let id = todo.id
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        guard (try context.fetch(descriptor)).isEmpty else { return }
        context.insert(TodoItem.from(todo))
        try context.save()
    }

    func updateTodo(_ todo: Todo) async throws {
        let id = todo.id
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        item.update(from: todo)
        try context.save()
    }

    func deleteTodo(id: String) async throws {
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        context.delete(item)
        try context.save()
    }

    // MARK: - DailyReport

    func fetchDailyReport(for date: Date) async throws -> DailyReport? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }
        let descriptor = FetchDescriptor<DailyReportItem>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        return try context.fetch(descriptor).first?.toReport()
    }

    func saveDailyReport(_ report: DailyReport) async throws {
        let startOfDay = Calendar.current.startOfDay(for: report.date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        let descriptor = FetchDescriptor<DailyReportItem>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: report)
        } else {
            context.insert(DailyReportItem.from(report))
        }
        try context.save()
    }

    // MARK: - Category

    func fetchCategories() async throws -> [Category] {
        let statusRaw = CategoryStatus.active.rawValue
        let descriptor = FetchDescriptor<CategoryItem>(
            predicate: #Predicate { $0.statusRaw == statusRaw },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try context.fetch(descriptor).map { $0.toCategory() }
    }

    func fetchArchivedCategories() async throws -> [Category] {
        let statusRaw = CategoryStatus.archived.rawValue
        let descriptor = FetchDescriptor<CategoryItem>(
            predicate: #Predicate { $0.statusRaw == statusRaw },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try context.fetch(descriptor).map { $0.toCategory() }
    }

    func saveCategory(_ category: Category) async throws {
        let id = category.id
        let descriptor = FetchDescriptor<CategoryItem>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: category)
        } else {
            let allDescriptor = FetchDescriptor<CategoryItem>()
            let count = (try? context.fetch(allDescriptor))?.count ?? 0
            context.insert(CategoryItem.from(category, sortOrder: count))
        }
        try context.save()
    }

    func archiveCategory(id: String) async throws {
        let descriptor = FetchDescriptor<CategoryItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        item.statusRaw = CategoryStatus.archived.rawValue
        try context.save()
    }

    func restoreCategory(id: String) async throws {
        let descriptor = FetchDescriptor<CategoryItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        item.statusRaw = CategoryStatus.active.rawValue
        try context.save()
    }

    func reorderCategories(_ ordered: [Category]) async throws {
        for (index, category) in ordered.enumerated() {
            let id = category.id
            let descriptor = FetchDescriptor<CategoryItem>(predicate: #Predicate { $0.id == id })
            if let item = try context.fetch(descriptor).first {
                item.sortOrder = index
            }
        }
        try context.save()
    }
}
