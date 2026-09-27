import Foundation

extension DailyReportItem {
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
