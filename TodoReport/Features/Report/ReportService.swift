import Foundation

struct WeeklyReportData {
    let period: DateInterval
    let completionRate: Double
    let averageRating: Double
    let streakDays: Int
    let dailyCompletionRates: [DailyRate]
    let dailyRatings: [DailyRatingPoint]
    let categoryStats: [CategoryStat]
}

struct MonthlyReportData {
    let period: DateInterval
    let completionRate: Double
    let averageRating: Double
    let streakDays: Int
    let weeklyCompletionRates: [WeeklyRate]
    let weeklyRatings: [WeeklyRatingPoint]
    let categoryStats: [CategoryStat]
}

struct DailyRate: Identifiable {
    let id = UUID()
    let weekday: String
    let rate: Double
}

struct DailyRatingPoint: Identifiable {
    let id = UUID()
    let weekday: String
    let rating: Double
}

struct WeeklyRate: Identifiable {
    let id = UUID()
    let label: String
    let rate: Double
}

struct WeeklyRatingPoint: Identifiable {
    let id = UUID()
    let label: String
    let rating: Double
}

struct CategoryStat: Identifiable {
    let id = UUID()
    let name: String
    let colorHex: String
    let rate: Double
    let completed: Int
    let total: Int
}

final class ReportService {
    static let shared = ReportService()
    private init() {}

    func fetchWeeklyReport(startingFrom monday: Date) async -> WeeklyReportData {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: monday)
        guard let end = calendar.date(byAdding: .day, value: 6, to: start) else {
            return Self.dummyWeekly(start: start)
        }
        return Self.dummyWeekly(start: start)
    }

    func fetchMonthlyReport(year: Int, month: Int) async -> MonthlyReportData {
        var components = DateComponents(year: year, month: month, day: 1)
        let calendar = Calendar.current
        let start = calendar.date(from: components) ?? .now
        components.month = month + 1
        components.day = 0
        let end = calendar.date(from: components) ?? .now
        return Self.dummyMonthly(start: start, end: end)
    }

    // MARK: - 더미 데이터

    private static func dummyWeekly(start: Date) -> WeeklyReportData {
        let calendar = Calendar.current
        guard let end = calendar.date(byAdding: .day, value: 6, to: start) else {
            return WeeklyReportData(
                period: DateInterval(start: start, end: start),
                completionRate: 0, averageRating: 0, streakDays: 0,
                dailyCompletionRates: [], dailyRatings: [], categoryStats: []
            )
        }

        let dailyRates: [DailyRate] = [
            DailyRate(weekday: "월", rate: 0.85),
            DailyRate(weekday: "화", rate: 0.60),
            DailyRate(weekday: "수", rate: 1.00),
            DailyRate(weekday: "목", rate: 0.75),
            DailyRate(weekday: "금", rate: 0.50),
            DailyRate(weekday: "토", rate: 0.90),
            DailyRate(weekday: "일", rate: 0.70),
        ]

        let dailyRatings: [DailyRatingPoint] = [
            DailyRatingPoint(weekday: "월", rating: 4.0),
            DailyRatingPoint(weekday: "화", rating: 3.0),
            DailyRatingPoint(weekday: "수", rating: 5.0),
            DailyRatingPoint(weekday: "목", rating: 4.0),
            DailyRatingPoint(weekday: "금", rating: 3.0),
            DailyRatingPoint(weekday: "토", rating: 5.0),
            DailyRatingPoint(weekday: "일", rating: 4.0),
        ]

        let avgRate = dailyRates.map(\.rate).reduce(0, +) / Double(dailyRates.count)
        let avgRating = dailyRatings.map(\.rating).reduce(0, +) / Double(dailyRatings.count)

        return WeeklyReportData(
            period: DateInterval(start: start, end: end),
            completionRate: avgRate,
            averageRating: avgRating,
            streakDays: 5,
            dailyCompletionRates: dailyRates,
            dailyRatings: dailyRatings,
            categoryStats: dummyCategoryStats()
        )
    }

    private static func dummyMonthly(start: Date, end: Date) -> MonthlyReportData {
        let weeklyRates: [WeeklyRate] = [
            WeeklyRate(label: "1주차", rate: 0.72),
            WeeklyRate(label: "2주차", rate: 0.85),
            WeeklyRate(label: "3주차", rate: 0.68),
            WeeklyRate(label: "4주차", rate: 0.91),
            WeeklyRate(label: "5주차", rate: 0.80),
        ]

        let weeklyRatings: [WeeklyRatingPoint] = [
            WeeklyRatingPoint(label: "1주차", rating: 3.5),
            WeeklyRatingPoint(label: "2주차", rating: 4.2),
            WeeklyRatingPoint(label: "3주차", rating: 3.8),
            WeeklyRatingPoint(label: "4주차", rating: 4.6),
            WeeklyRatingPoint(label: "5주차", rating: 4.0),
        ]

        let avgRate = weeklyRates.map(\.rate).reduce(0, +) / Double(weeklyRates.count)
        let avgRating = weeklyRatings.map(\.rating).reduce(0, +) / Double(weeklyRatings.count)

        return MonthlyReportData(
            period: DateInterval(start: start, end: end),
            completionRate: avgRate,
            averageRating: avgRating,
            streakDays: 14,
            weeklyCompletionRates: weeklyRates,
            weeklyRatings: weeklyRatings,
            categoryStats: dummyCategoryStats()
        )
    }

    private static func dummyCategoryStats() -> [CategoryStat] {
        [
            CategoryStat(name: "공부",  colorHex: "4A90D9", rate: 0.83, completed: 10, total: 12),
            CategoryStat(name: "운동",  colorHex: "E8794A", rate: 0.60, completed:  6, total: 10),
            CategoryStat(name: "독서",  colorHex: "5BAD72", rate: 0.75, completed:  9, total: 12),
            CategoryStat(name: "생활",  colorHex: "9B71C8", rate: 0.50, completed:  4, total:  8),
        ]
    }
}
