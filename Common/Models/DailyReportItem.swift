import SwiftData
import Foundation

@Model
final class DailyReportItem {
    @Attribute(.unique) var id: String
    var date: Date
    var review: String
    var completionRate: Double
    var dayRatingRaw: String?
    var photoURLs: [String]
    var notionPageId: String
    var plannerId: String?
    var endDate: Date?
    var periodCompletionRate: Double?
    var aiComment: String?
    /// 노션 저장이 끝날 때까지 남김. nil이면 대기 아님. 값 자체가 대기 시작 시각.
    var notionSyncPendingAt: Date? = nil

    init(
        id: String = UUID().uuidString,
        date: Date = .now,
        review: String = "",
        completionRate: Double = 0,
        dayRatingRaw: String? = nil,
        photoURLs: [String] = [],
        notionPageId: String = "",
        plannerId: String? = nil,
        endDate: Date? = nil,
        periodCompletionRate: Double? = nil,
        aiComment: String? = nil,
        notionSyncPendingAt: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.review = review
        self.completionRate = completionRate
        self.dayRatingRaw = dayRatingRaw
        self.photoURLs = photoURLs
        self.notionPageId = notionPageId
        self.plannerId = plannerId
        self.endDate = endDate
        self.periodCompletionRate = periodCompletionRate
        self.aiComment = aiComment
        self.notionSyncPendingAt = notionSyncPendingAt
    }
}
