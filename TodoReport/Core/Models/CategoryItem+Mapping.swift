import Foundation

extension CategoryItem {
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
            statusRaw: category.status.rawValue, sortOrder: sortOrder,
            plannerId: category.plannerId,
            notionOptionId: category.notionOptionId,
            notionOptionName: category.notionOptionName
        )
        item.isHidden = category.isHidden
        return item
    }
}
