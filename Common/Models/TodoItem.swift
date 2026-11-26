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
    /// 시리즈 소속만 표시. 규칙 본체는 `RecurringSeries`. 아래 세 필드는 스키마 호환용으로만 남김.
    var recurrenceData: Data?
    var recurrenceId: String?
    var recurrenceEndDate: Date?
    var recurrenceCount: Int?
    var notionRelationLinked: Bool = false
    var localModifiedAt: Date?
    /// 인박스 「나중에 보기」. 로컬 전용 — 노션 payload에 포함하지 않음.
    var snoozedUntil: Date? = nil
    /// 투두 탭에서 손으로 바꾼 순서 키. nil이면 만든 시각 순. 로컬 전용 — 노션에 올리지 않음.
    /// 값은 「만든 시각(기준일부터 초)」과 같은 척도라 정하지 않은 할 일과 섞여도 순서가 맞는다.
    var manualSortOrder: Double? = nil

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
        notionRelationLinked: Bool = false,
        snoozedUntil: Date? = nil
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
        self.snoozedUntil = snoozedUntil
    }
}
