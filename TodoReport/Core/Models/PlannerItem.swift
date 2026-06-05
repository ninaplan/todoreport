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
    // 플래너별 Notion 토큰 (온보딩 플래너는 nil → NotionAuthManager Keychain 사용)
    var notionAccessToken: String?
    // 아이콘: SF Symbol 이름 또는 "photo"
    var iconType: String?
    @Attribute(.externalStorage) var iconImageData: Data?
    var createdAt: Date
    // Notion 속성 매핑 (JSON 문자열)
    var todoPropsMapping: String?
    var reportPropsMapping: String?
    // Pro 해지 후 읽기 전용 전환 여부
    var isReadOnly: Bool = false

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String = "#FD6845",
        isNotionConnected: Bool = false,
        notionTodoDBId: String? = nil,
        notionReportDBId: String? = nil,
        notionAccessToken: String? = nil,
        iconType: String? = nil,
        iconImageData: Data? = nil,
        createdAt: Date = .now,
        todoPropsMapping: String? = nil,
        reportPropsMapping: String? = nil,
        isReadOnly: Bool = false
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isNotionConnected = isNotionConnected
        self.notionTodoDBId = notionTodoDBId
        self.notionReportDBId = notionReportDBId
        self.notionAccessToken = notionAccessToken
        self.iconType = iconType
        self.iconImageData = iconImageData
        self.createdAt = createdAt
        self.todoPropsMapping = todoPropsMapping
        self.reportPropsMapping = reportPropsMapping
        self.isReadOnly = isReadOnly
    }

    func toPlanner() -> Planner {
        Planner(
            id: id, name: name, colorHex: colorHex,
            isNotionConnected: isNotionConnected,
            notionTodoDBId: notionTodoDBId,
            notionReportDBId: notionReportDBId,
            notionAccessToken: notionAccessToken,
            iconType: iconType,
            iconImageData: iconImageData,
            createdAt: createdAt,
            todoPropsMapping: todoPropsMapping,
            reportPropsMapping: reportPropsMapping,
            isReadOnly: isReadOnly
        )
    }

    func update(from planner: Planner) {
        name = planner.name
        colorHex = planner.colorHex
        isNotionConnected = planner.isNotionConnected
        notionTodoDBId = planner.notionTodoDBId
        notionReportDBId = planner.notionReportDBId
        notionAccessToken = planner.notionAccessToken
        iconType = planner.iconType
        iconImageData = planner.iconImageData
        todoPropsMapping = planner.todoPropsMapping
        reportPropsMapping = planner.reportPropsMapping
        isReadOnly = planner.isReadOnly
    }

    static func from(_ planner: Planner) -> PlannerItem {
        PlannerItem(
            id: planner.id, name: planner.name, colorHex: planner.colorHex,
            isNotionConnected: planner.isNotionConnected,
            notionTodoDBId: planner.notionTodoDBId,
            notionReportDBId: planner.notionReportDBId,
            notionAccessToken: planner.notionAccessToken,
            iconType: planner.iconType,
            iconImageData: planner.iconImageData,
            createdAt: planner.createdAt,
            todoPropsMapping: planner.todoPropsMapping,
            reportPropsMapping: planner.reportPropsMapping,
            isReadOnly: planner.isReadOnly
        )
    }
}
