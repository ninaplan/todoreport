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
    var notionCategoryDBId: String?  // v2 Pro: 카테고리 전용 DB
    // 플래너별 Notion 토큰 (온보딩 플래너는 nil → NotionAuthManager Keychain 사용)
    var notionAccessToken: String?
    // [참고] 토큰 끊김의 실제 원인은 시간 만료가 아니라 같은 워크스페이스의
    // 중복 OAuth 재인증임 (2026-06-24 조사 확정). 자세한 내용은 백엔드
    // lib/notion-auth.ts 주석과 V2-IDEAS.md 참고.
    var notionRefreshToken: String?
    // 워크스페이스 단위 Notion 연결 참조 (nil이면 레거시 플래너별 토큰 사용)
    var notionWorkspaceConnectionId: String?
    // 아이콘: SF Symbol 이름 또는 "photo"
    var iconType: String?
    @Attribute(.externalStorage) var iconImageData: Data?
    var createdAt: Date
    // Notion 속성 매핑 (JSON 문자열)
    var todoPropsMapping: String?
    var reportPropsMapping: String?
    // Pro 해지 후 읽기 전용 전환 여부
    var isReadOnly: Bool = false
    var sortOrder: Double = 0

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

    func toPlanner() -> Planner {
        Planner(
            id: id, name: name, colorHex: colorHex,
            isNotionConnected: isNotionConnected,
            notionTodoDBId: notionTodoDBId,
            notionReportDBId: notionReportDBId,
            notionCategoryDBId: notionCategoryDBId,
            notionAccessToken: notionAccessToken,
            notionRefreshToken: notionRefreshToken,
            notionWorkspaceConnectionId: notionWorkspaceConnectionId,
            iconType: iconType,
            iconImageData: iconImageData,
            createdAt: createdAt,
            todoPropsMapping: todoPropsMapping,
            reportPropsMapping: reportPropsMapping,
            isReadOnly: isReadOnly,
            sortOrder: sortOrder
        )
    }

    func update(from planner: Planner) {
        name = planner.name
        colorHex = planner.colorHex
        isNotionConnected = planner.isNotionConnected
        notionTodoDBId = planner.notionTodoDBId
        notionReportDBId = planner.notionReportDBId
        notionCategoryDBId = planner.notionCategoryDBId
        notionAccessToken = planner.notionAccessToken
        notionRefreshToken = planner.notionRefreshToken
        notionWorkspaceConnectionId = planner.notionWorkspaceConnectionId
        iconType = planner.iconType
        iconImageData = planner.iconImageData
        todoPropsMapping = planner.todoPropsMapping
        reportPropsMapping = planner.reportPropsMapping
        isReadOnly = planner.isReadOnly
        sortOrder = planner.sortOrder
    }

    static func from(_ planner: Planner) -> PlannerItem {
        PlannerItem(
            id: planner.id, name: planner.name, colorHex: planner.colorHex,
            isNotionConnected: planner.isNotionConnected,
            notionTodoDBId: planner.notionTodoDBId,
            notionReportDBId: planner.notionReportDBId,
            notionCategoryDBId: planner.notionCategoryDBId,
            notionAccessToken: planner.notionAccessToken,
            notionRefreshToken: planner.notionRefreshToken,
            notionWorkspaceConnectionId: planner.notionWorkspaceConnectionId,
            iconType: planner.iconType,
            iconImageData: planner.iconImageData,
            createdAt: planner.createdAt,
            todoPropsMapping: planner.todoPropsMapping,
            reportPropsMapping: planner.reportPropsMapping,
            isReadOnly: planner.isReadOnly,
            sortOrder: planner.sortOrder
        )
    }
}
