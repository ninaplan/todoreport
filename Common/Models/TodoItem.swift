import SwiftData
import Foundation

@Model
final class TodoItem {
    @Attribute(.unique) var id: String
    var title: String
    var memo: String?
    var isCompleted: Bool
    var isPinned: Bool
    var date: Date?
    var createdAt: Date
    var completedAt: Date?
    var notionCreatedAt: Date?
    var notionLastEditedTime: Date?
    var categoryId: String?
    var categoryName: String?
    var notionPageId: String
    var plannerId: String?
    var scheduledTime: Date?
    var alarmOffset: Int?
    var recurrenceData: Data?
    var recurrenceId: String?
    var recurrenceEndDate: Date?
    var recurrenceCount: Int?
    var notionRelationLinked: Bool = false
    var localModifiedAt: Date?

    init(
        id: String = UUID().uuidString,
        title: String,
        memo: String? = nil,
        isCompleted: Bool = false,
        isPinned: Bool = false,
        date: Date? = .now,
        completedAt: Date? = nil,
        notionCreatedAt: Date? = nil,
        notionLastEditedTime: Date? = nil,
        categoryId: String? = nil,
        notionPageId: String = "",
        plannerId: String? = nil,
        scheduledTime: Date? = nil,
        alarmOffset: Int? = nil,
        recurrenceData: Data? = nil,
        recurrenceId: String? = nil,
        recurrenceEndDate: Date? = nil,
        recurrenceCount: Int? = nil,
        notionRelationLinked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.memo = memo
        self.isCompleted = isCompleted
        self.isPinned = isPinned
        self.date = date
        self.createdAt = .now
        self.completedAt = completedAt
        self.notionCreatedAt = notionCreatedAt
        self.notionLastEditedTime = notionLastEditedTime
        self.categoryId = categoryId
        self.notionPageId = notionPageId
        self.plannerId = plannerId
        self.scheduledTime = scheduledTime
        self.alarmOffset = alarmOffset
        self.recurrenceData = recurrenceData
        self.recurrenceId = recurrenceId
        self.recurrenceEndDate = recurrenceEndDate
        self.recurrenceCount = recurrenceCount
        self.notionRelationLinked = notionRelationLinked
    }
}
