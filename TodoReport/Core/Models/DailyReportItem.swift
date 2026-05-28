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

    init(
        id: String = UUID().uuidString,
        date: Date = .now,
        review: String = "",
        completionRate: Double = 0,
        dayRatingRaw: String? = nil,
        photoURLs: [String] = [],
        notionPageId: String = ""
    ) {
        self.id = id
        self.date = date
        self.review = review
        self.completionRate = completionRate
        self.dayRatingRaw = dayRatingRaw
        self.photoURLs = photoURLs
        self.notionPageId = notionPageId
    }

    var dayRating: DayRating? {
        dayRatingRaw.flatMap { DayRating(rawValue: $0) }
    }

    func toReport() -> DailyReport {
        DailyReport(
            id: id,
            date: date,
            review: review,
            completionRate: completionRate,
            dayRating: dayRating,
            photoURLs: photoURLs,
            notionPageId: notionPageId
        )
    }

    func update(from report: DailyReport) {
        review = report.review
        completionRate = report.completionRate
        dayRatingRaw = report.dayRating?.rawValue
        photoURLs = report.photoURLs
        notionPageId = report.notionPageId
    }

    static func from(_ report: DailyReport) -> DailyReportItem {
        DailyReportItem(
            id: report.id,
            date: report.date,
            review: report.review,
            completionRate: report.completionRate,
            dayRatingRaw: report.dayRating?.rawValue,
            photoURLs: report.photoURLs,
            notionPageId: report.notionPageId
        )
    }
}
