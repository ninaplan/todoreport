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

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String,
        icon: String,
        status: CategoryStatus = .active,
        sortOrder: Int = 0,
        plannerId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.statusRaw = status.rawValue
        self.sortOrder = sortOrder
        self.plannerId = plannerId
    }

    var status: CategoryStatus {
        CategoryStatus(rawValue: statusRaw) ?? .active
    }

    func toCategory() -> Category {
        Category(id: id, name: name, colorHex: colorHex, icon: icon, status: status, plannerId: plannerId)
    }

    func update(from category: Category) {
        name = category.name
        colorHex = category.colorHex
        icon = category.icon
        statusRaw = category.status.rawValue
        // plannerId 고정
    }

    static func from(_ category: Category, sortOrder: Int = 0) -> CategoryItem {
        CategoryItem(
            id: category.id, name: category.name,
            colorHex: category.colorHex, icon: category.icon,
            status: category.status, sortOrder: sortOrder,
            plannerId: category.plannerId
        )
    }
}
