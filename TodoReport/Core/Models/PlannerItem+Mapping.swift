import Foundation

extension PlannerItem {
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
        let item = PlannerItem(
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
        // 새 플래너의 카테고리 색 세트는 앱 기본(노션)
        item.categoryPaletteSetId = CategoryColorSet.defaultId
        return item
    }
}
