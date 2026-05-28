import SwiftData
import Foundation

@Model
final class PlannerItem {
    @Attribute(.unique) var id: String
    var name: String
    var colorHex: String
    var isNotionConnected: Bool
    var notionTodoDBId: String?
    var notionReportDBId: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String = "#FD6845",
        isNotionConnected: Bool = false,
        notionTodoDBId: String? = nil,
        notionReportDBId: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isNotionConnected = isNotionConnected
        self.notionTodoDBId = notionTodoDBId
        self.notionReportDBId = notionReportDBId
        self.createdAt = createdAt
    }

    func toPlanner() -> Planner {
        Planner(
            id: id, name: name, colorHex: colorHex,
            isNotionConnected: isNotionConnected,
            notionTodoDBId: notionTodoDBId,
            notionReportDBId: notionReportDBId,
            createdAt: createdAt
        )
    }

    func update(from planner: Planner) {
        name = planner.name
        colorHex = planner.colorHex
        isNotionConnected = planner.isNotionConnected
        notionTodoDBId = planner.notionTodoDBId
        notionReportDBId = planner.notionReportDBId
    }

    static func from(_ planner: Planner) -> PlannerItem {
        PlannerItem(
            id: planner.id, name: planner.name, colorHex: planner.colorHex,
            isNotionConnected: planner.isNotionConnected,
            notionTodoDBId: planner.notionTodoDBId,
            notionReportDBId: planner.notionReportDBId,
            createdAt: planner.createdAt
        )
    }
}
