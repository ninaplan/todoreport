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
    // 기간 리포트(주간/월간) 전용 필드. nil이면 데일리 리포트.
    var endDate: Date?
    var periodCompletionRate: Double?
    var aiComment: String?

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
        aiComment: String? = nil
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
    }

    var dayRating: DayRating? {
        dayRatingRaw.flatMap { DayRating(rawValue: $0) }
    }

    func toReport() -> DailyReport {
        DailyReport(
            id: id, date: date, review: review,
            completionRate: completionRate, dayRating: dayRating,
            photoURLs: photoURLs, notionPageId: notionPageId,
            plannerId: plannerId,
            endDate: endDate,
            periodCompletionRate: periodCompletionRate,
            aiComment: aiComment
        )
    }

    func update(from report: DailyReport) {
        review = report.review
        completionRate = report.completionRate
        dayRatingRaw = report.dayRating?.rawValue
        photoURLs = report.photoURLs
        notionPageId = report.notionPageId
        endDate = report.endDate
        periodCompletionRate = report.periodCompletionRate
        aiComment = report.aiComment
        // plannerId 고정
    }

    static func from(_ report: DailyReport) -> DailyReportItem {
        DailyReportItem(
            id: report.id, date: report.date, review: report.review,
            completionRate: report.completionRate,
            dayRatingRaw: report.dayRating?.rawValue,
            photoURLs: report.photoURLs, notionPageId: report.notionPageId,
            plannerId: report.plannerId,
            endDate: report.endDate,
            periodCompletionRate: report.periodCompletionRate,
            aiComment: report.aiComment
        )
    }
}
