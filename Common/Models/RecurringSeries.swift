import SwiftData
import Foundation

/// 반복 규칙의 유일한 진실 공급원. 로컬 전용 — Notion에 올리지 않는다.
@Model
final class RecurringSeries {
    @Attribute(.unique) var id: String
    var plannerId: String?
    var title: String
    var memo: String?
    var categoryId: String?
    var scheduledTime: Date?
    var alarmOffset: Int?
    var ruleData: Data
    var originDate: Date
    var endDate: Date?
    var occurrenceLimit: Int?
    var isActive: Bool
    /// 이 날짜까지 생성 여부를 검사했다. 삭제된 발생분을 다시 만들지 않기 위해 사용.
    var lastMaterializedThrough: Date?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        plannerId: String? = nil,
        title: String,
        memo: String? = nil,
        categoryId: String? = nil,
        scheduledTime: Date? = nil,
        alarmOffset: Int? = nil,
        ruleData: Data,
        originDate: Date,
        endDate: Date? = nil,
        occurrenceLimit: Int? = nil,
        isActive: Bool = true,
        lastMaterializedThrough: Date? = nil
    ) {
        self.id = id
        self.plannerId = plannerId
        self.title = title
        self.memo = memo
        self.categoryId = categoryId
        self.scheduledTime = scheduledTime
        self.alarmOffset = alarmOffset
        self.ruleData = ruleData
        self.originDate = originDate
        self.endDate = endDate
        self.occurrenceLimit = occurrenceLimit
        self.isActive = isActive
        self.lastMaterializedThrough = lastMaterializedThrough
        self.createdAt = .now
    }
}
