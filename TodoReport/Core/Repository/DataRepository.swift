import Foundation

protocol DataRepository {
    // MARK: - Todo
    func fetchTodos(for date: Date) async throws -> [Todo]
    func saveTodo(_ todo: Todo) async throws
    func updateTodo(_ todo: Todo) async throws
    func deleteTodo(id: String) async throws

    // MARK: - DailyReport
    func fetchDailyReport(for date: Date) async throws -> DailyReport?
    func saveDailyReport(_ report: DailyReport) async throws

    // MARK: - Category
    func fetchCategories() async throws -> [Category]
    func fetchArchivedCategories() async throws -> [Category]
    func saveCategory(_ category: Category) async throws
    func archiveCategory(id: String) async throws
    func restoreCategory(id: String) async throws
    func reorderCategories(_ ordered: [Category]) async throws
}
