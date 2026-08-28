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
    var notionCategoryDBId: String?
    var notionAccessToken: String?
    var notionRefreshToken: String?
    var notionWorkspaceConnectionId: String?
    var iconType: String?
    @Attribute(.externalStorage) var iconImageData: Data?
    var createdAt: Date
    var todoPropsMapping: String?
    var reportPropsMapping: String?
    var isReadOnly: Bool = false
    var sortOrder: Double = 0
    var categoryPaletteSetId: String = "basic"

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String = "#FD6845",
        isNotionConnected: Bool = false,
        notionTodoDBId: String? = nil,
        notionReportDBId: String? = nil,
        notionCategoryDBId: String? = nil,
        notionAccessToken: String? = nil,
        notionRefreshToken: String? = nil,
        notionWorkspaceConnectionId: String? = nil,
        iconType: String? = nil,
        iconImageData: Data? = nil,
        createdAt: Date = .now,
        todoPropsMapping: String? = nil,
        reportPropsMapping: String? = nil,
        isReadOnly: Bool = false,
        sortOrder: Double = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isNotionConnected = isNotionConnected
        self.notionTodoDBId = notionTodoDBId
        self.notionReportDBId = notionReportDBId
        self.notionCategoryDBId = notionCategoryDBId
        self.notionAccessToken = notionAccessToken
        self.notionRefreshToken = notionRefreshToken
        self.notionWorkspaceConnectionId = notionWorkspaceConnectionId
        self.iconType = iconType
        self.iconImageData = iconImageData
        self.createdAt = createdAt
        self.todoPropsMapping = todoPropsMapping
        self.reportPropsMapping = reportPropsMapping
        self.isReadOnly = isReadOnly
        self.sortOrder = sortOrder
    }
}
