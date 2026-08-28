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
    var notionPageId: String? = nil
    var notionOptionId: String? = nil
    var notionOptionName: String? = nil
    var isHidden: Bool = false

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String,
        icon: String,
        statusRaw: String = CategoryStatus.active.rawValue,
        sortOrder: Int = 0,
        plannerId: String? = nil,
        notionOptionId: String? = nil,
        notionOptionName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.statusRaw = statusRaw
        self.sortOrder = sortOrder
        self.plannerId = plannerId
        self.notionOptionId = notionOptionId
        self.notionOptionName = notionOptionName
    }
}
