import Foundation
import SwiftData

@Model
final class MoodOptionItem {
    @Attribute(.unique) var id: String
    var plannerId: String
    var name: String
    var colorHex: String
    var sortOrder: Int
    var notionOptionId: String? = nil
    var notionOptionName: String? = nil

    init(
        id: String = UUID().uuidString,
        plannerId: String,
        name: String,
        colorHex: String,
        sortOrder: Int,
        notionOptionId: String? = nil,
        notionOptionName: String? = nil
    ) {
        self.id = id
        self.plannerId = plannerId
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.notionOptionId = notionOptionId
        self.notionOptionName = notionOptionName
    }
}
