import SwiftData
import Foundation

@Model
final class CategoryItem {
    @Attribute(.unique) var id: String
    var name: String
    var colorHex: String
    var icon: String
    var statusRaw: String
    var sortOrder: Int
    var plannerId: String?
    var notionPageId: String? = nil  // v2 Pro: 카테고리 DB 페이지 ID
    var notionOptionId: String? = nil
    var notionOptionName: String? = nil
    var isHidden: Bool = false

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String,
        icon: String,
        status: CategoryStatus = .active,
        sortOrder: Int = 0,
        plannerId: String? = nil,
        notionOptionId: String? = nil,
        notionOptionName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.statusRaw = status.rawValue
        self.sortOrder = sortOrder
        self.plannerId = plannerId
        self.notionOptionId = notionOptionId
        self.notionOptionName = notionOptionName
    }

    var status: CategoryStatus {
        CategoryStatus(rawValue: statusRaw) ?? .active
    }

    var isLinkedToNotion: Bool {
        notionOptionId != nil || notionOptionName != nil
    }

    func toCategory() -> Category {
        Category(
            id: id, name: name, colorHex: colorHex, icon: icon,
            status: status, plannerId: plannerId,
            notionOptionId: notionOptionId, notionOptionName: notionOptionName,
            isHidden: isHidden
        )
    }

    func update(from category: Category) {
        name = category.name
        colorHex = category.colorHex
        icon = category.icon
        statusRaw = category.status.rawValue
        notionOptionId = category.notionOptionId
        notionOptionName = category.notionOptionName
        isHidden = category.isHidden
    }

    static func from(_ category: Category, sortOrder: Int = 0) -> CategoryItem {
        let item = CategoryItem(
            id: category.id, name: category.name,
            colorHex: category.colorHex, icon: category.icon,
            status: category.status, sortOrder: sortOrder,
            plannerId: category.plannerId,
            notionOptionId: category.notionOptionId,
            notionOptionName: category.notionOptionName
        )
        item.isHidden = category.isHidden
        return item
    }
}
