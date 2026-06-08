import Foundation
import SwiftData

@MainActor
final class NotionRepository: DataRepository {
    private let local: LocalRepository
    private let dateFormatter: DateFormatter

    private var currentPlanner: Planner? {
        PlannerService.shared.selectedPlanner
    }

    private var todoDBId: String? {
        currentPlanner?.notionTodoDBId
    }

    private var reportDBId: String? {
        currentPlanner?.notionReportDBId
    }

    private var todoPropsMapping: TodoPropsMapping {
        currentPlanner?.decodedTodoPropsMapping ?? TodoPropsMapping()
    }

    private var reportPropsMapping: ReportPropsMapping {
        currentPlanner?.decodedReportPropsMapping ?? ReportPropsMapping()
    }

    init() {
        self.local = LocalRepository(context: PersistenceController.shared.context)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        self.dateFormatter = fmt
    }

    // MARK: - Todo

    func fetchTodos(for date: Date) async throws -> [Todo] {
        let dateStr = dateFormatter.string(from: date)
        guard let dbId = todoDBId else {
            return try await local.fetchTodos(for: date)
        }
        return try await APIClient.shared.get("/api/notion/todo", params: [
            "date": dateStr,
            "dbId": dbId
        ])
    }

    func saveTodo(_ todo: Todo) async throws {
        try await local.saveTodo(todo)
        let dbId = todoDBId
        let mapping = todoPropsMapping
        Task {
            guard let dbId else { return }
            let body = TodoBody(todo: todo, dbId: dbId, mapping: mapping)
            _ = try? await APIClient.shared.post("/api/notion/todo", body: body) as NotionEmptyResponse
        }
    }

    func updateTodo(_ todo: Todo) async throws {
        try await local.updateTodo(todo)
        let dbId = todoDBId
        let mapping = todoPropsMapping
        Task {
            guard let dbId else { return }
            let body = TodoBody(todo: todo, dbId: dbId, mapping: mapping)
            _ = try? await APIClient.shared.patch("/api/notion/todo/\(todo.id)", body: body) as NotionEmptyResponse
        }
    }

    func deleteTodo(id: String) async throws {
        try await local.deleteTodo(id: id)
        Task {
            try? await APIClient.shared.delete("/api/notion/todo/\(id)")
        }
    }

    // MARK: - DailyReport

    func fetchDailyReport(for date: Date) async throws -> DailyReport? {
        let dateStr = dateFormatter.string(from: date)
        guard let dbId = reportDBId else {
            return try await local.fetchDailyReport(for: date)
        }
        return try await APIClient.shared.get("/api/notion/daily-report", params: [
            "date": dateStr,
            "dbId": dbId
        ])
    }

    func saveDailyReport(_ report: DailyReport) async throws {
        try await local.saveDailyReport(report)
        let dbId = reportDBId
        let mapping = reportPropsMapping
        Task {
            guard let dbId else { return }
            let body = ReportBody(report: report, dbId: dbId, mapping: mapping)
            _ = try? await APIClient.shared.post("/api/notion/daily-report", body: body) as NotionEmptyResponse
        }
    }

    // MARK: - Category (LocalRepository에 위임)

    func fetchCategories() async throws -> [Category] {
        try await local.fetchCategories()
    }

    func fetchArchivedCategories() async throws -> [Category] {
        try await local.fetchArchivedCategories()
    }

    func saveCategory(_ category: Category) async throws {
        try await local.saveCategory(category)
    }

    func archiveCategory(id: String) async throws {
        try await local.archiveCategory(id: id)
    }

    func restoreCategory(id: String) async throws {
        try await local.restoreCategory(id: id)
    }

    func reorderCategories(_ ordered: [Category]) async throws {
        try await local.reorderCategories(ordered)
    }
}

// MARK: - Request Bodies

private struct TodoBody: Encodable {
    let id: String
    let title: String
    let memo: String?
    let isCompleted: Bool
    let date: String
    let categoryId: String?
    let dbId: String
    let completedProp: String?
    let dateProp: String?
    let memoProp: String?
    let isPinnedProp: String?
    let categoryProp: String?
    let categoryPropType: String?
    let categoryName: String?

    init(todo: Todo, dbId: String, mapping: TodoPropsMapping) {
        self.id = todo.id
        self.title = todo.title
        self.memo = todo.memo
        self.isCompleted = todo.isCompleted
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        self.date = fmt.string(from: todo.date)
        self.categoryId = todo.categoryId
        self.dbId = dbId
        self.completedProp = mapping.completed
        self.dateProp = mapping.date
        self.memoProp = mapping.memo
        self.isPinnedProp = mapping.isPinned
        self.categoryProp = mapping.category
        self.categoryPropType = mapping.categoryPropType
        self.categoryName = CategoryNotionSync.shared.notionSyncName(for: todo.categoryId) ?? ""
    }
}

private struct ReportBody: Encodable {
    let id: String
    let date: String
    let review: String
    let dayRating: String?
    let completionRate: Double
    let dbId: String
    let dateProp: String?
    let reviewProp: String?
    let ratingProp: String?

    init(report: DailyReport, dbId: String, mapping: ReportPropsMapping) {
        self.id = report.id
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        self.date = fmt.string(from: report.date)
        self.review = report.review
        self.dayRating = report.dayRating?.rawValue
        self.completionRate = report.completionRate
        self.dbId = dbId
        self.dateProp = mapping.date
        self.reviewProp = mapping.review
        self.ratingProp = mapping.rating
    }
}

private struct NotionEmptyResponse: Decodable {}
