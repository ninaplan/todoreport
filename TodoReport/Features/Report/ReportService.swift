import Foundation
import SwiftData

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

    private var context: ModelContext { PersistenceController.shared.context }

    func fetchWeeklyReport(startingFrom monday: Date) async -> WeeklyReportData {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: monday)
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else {
            return emptyWeekly(start: start)
        }

        let plannerId = PlannerService.shared.selectedPlanner?.id
        let todos = fetchTodos(in: start..<end, plannerId: plannerId)
        let reports = fetchReports(in: start..<end, plannerId: plannerId)
        let categories = fetchCategories(plannerId: plannerId)

        let weekdays = ["월", "화", "수", "목", "금", "토", "일"]
        var dailyRates: [DailyRate] = []
        var dailyRatings: [DailyRatingPoint] = []

        for i in 0..<7 {
            guard let dayStart = calendar.date(byAdding: .day, value: i, to: start),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let dayTodos = todos.filter { $0.date >= dayStart && $0.date < dayEnd }
            let rate = dayTodos.isEmpty ? 0 : Double(dayTodos.filter { $0.isCompleted }.count) / Double(dayTodos.count)
            dailyRates.append(DailyRate(weekday: weekdays[i], rate: rate))

            let report = reports.first { $0.date >= dayStart && $0.date < dayEnd }
            let ratingValue = ratingDouble(report?.dayRatingRaw)
            dailyRatings.append(DailyRatingPoint(weekday: weekdays[i], rating: ratingValue))
        }

        let avgRate = dailyRates.map(\.rate).reduce(0, +) / max(1, Double(dailyRates.count))
        let ratedDays = dailyRatings.filter { $0.rating > 0 }
        let avgRating = ratedDays.isEmpty ? 0 : ratedDays.map(\.rating).reduce(0, +) / Double(ratedDays.count)
        let streak = calculateStreak(reports: reports, endingAt: start, calendar: calendar)

        return WeeklyReportData(
            period: DateInterval(start: start, end: end),
            completionRate: avgRate,
            averageRating: avgRating,
            streakDays: streak,
            dailyCompletionRates: dailyRates,
            dailyRatings: dailyRatings,
            categoryStats: buildCategoryStats(todos: todos, categories: categories)
        )
    }

    func fetchMonthlyReport(year: Int, month: Int) async -> MonthlyReportData {
        let calendar = Calendar.current
        guard let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            return emptyMonthly(start: .now)
        }

        let plannerId = PlannerService.shared.selectedPlanner?.id
        let todos = fetchTodos(in: start..<end, plannerId: plannerId)
        let reports = fetchReports(in: start..<end, plannerId: plannerId)
        let categories = fetchCategories(plannerId: plannerId)

        // 주차별 집계
        var weeklyRates: [WeeklyRate] = []
        var weeklyRatings: [WeeklyRatingPoint] = []
        var weekStart = start
        var weekIndex = 1

        while weekStart < end {
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            let actualEnd = min(weekEnd, end)
            let label = "\(weekIndex)주차"

            let weekTodos = todos.filter { $0.date >= weekStart && $0.date < actualEnd }
            let rate = weekTodos.isEmpty ? 0 : Double(weekTodos.filter { $0.isCompleted }.count) / Double(weekTodos.count)
            weeklyRates.append(WeeklyRate(label: label, rate: rate))

            let weekReports = reports.filter { $0.date >= weekStart && $0.date < actualEnd }
            let ratedReports = weekReports.filter { $0.dayRatingRaw != nil }
            let avgRating = ratedReports.isEmpty
                ? 0
                : ratedReports.map { ratingDouble($0.dayRatingRaw) }.reduce(0, +) / Double(ratedReports.count)
            weeklyRatings.append(WeeklyRatingPoint(label: label, rating: avgRating))

            weekStart = weekEnd
            weekIndex += 1
        }

        let avgRate = weeklyRates.map(\.rate).reduce(0, +) / max(1, Double(weeklyRates.count))
        let ratedWeeks = weeklyRatings.filter { $0.rating > 0 }
        let avgRating = ratedWeeks.isEmpty ? 0 : ratedWeeks.map(\.rating).reduce(0, +) / Double(ratedWeeks.count)
        let streak = calculateStreak(reports: reports, endingAt: start, calendar: calendar)

        return MonthlyReportData(
            period: DateInterval(start: start, end: end),
            completionRate: avgRate,
            averageRating: avgRating,
            streakDays: streak,
            weeklyCompletionRates: weeklyRates,
            weeklyRatings: weeklyRatings,
            categoryStats: buildCategoryStats(todos: todos, categories: categories)
        )
    }

    // MARK: - 노션 저장

    func syncWeeklyToNotion(period: DateInterval) async {
        let plannerId = PlannerService.shared.selectedPlanner?.id
        let reports = fetchReports(in: period.start..<period.end, plannerId: plannerId)
        let dailyService = DailyReportService()
        for item in reports {
            await dailyService.syncToNotion(item.toReport())
        }
    }

    // MARK: - SwiftData Fetch

    func hasTodos(in range: Range<Date>) async -> Bool {
        let plannerId = PlannerService.shared.selectedPlanner?.id
        return !fetchTodos(in: range, plannerId: plannerId).isEmpty
    }

    private func fetchTodos(in range: Range<Date>, plannerId: String?) -> [TodoItem] {
        let start = range.lowerBound
        let end = range.upperBound
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        let all = (try? context.fetch(descriptor)) ?? []
        guard let pid = plannerId else { return all }
        return all.filter { $0.plannerId == pid || $0.plannerId == nil }
    }

    private func fetchReports(in range: Range<Date>, plannerId: String?) -> [DailyReportItem] {
        let start = range.lowerBound
        let end = range.upperBound
        let descriptor = FetchDescriptor<DailyReportItem>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        let all = (try? context.fetch(descriptor)) ?? []
        guard let pid = plannerId else { return all }
        return all.filter { $0.plannerId == pid }
    }

    private func fetchCategories(plannerId: String?) -> [CategoryItem] {
        let descriptor = FetchDescriptor<CategoryItem>()
        let all = (try? context.fetch(descriptor)) ?? []
        let pid = plannerId
        return all.filter { $0.statusRaw != "archived" && ($0.plannerId == pid || $0.plannerId == nil) }
    }

    // MARK: - 집계 헬퍼

    private func buildCategoryStats(todos: [TodoItem], categories: [CategoryItem]) -> [CategoryStat] {
        // 카테고리 없는 투두도 "미분류"로 포함
        var stats: [CategoryStat] = categories.compactMap { category in
            let catTodos = todos.filter { $0.categoryId == category.id }
            guard !catTodos.isEmpty else { return nil }
            let completed = catTodos.filter { $0.isCompleted }.count
            let total = catTodos.count
            return CategoryStat(
                name: category.name,
                colorHex: category.colorHex,
                rate: Double(completed) / Double(total),
                completed: completed,
                total: total
            )
        }
        // 완료율 내림차순 정렬
        stats.sort { $0.rate > $1.rate }
        return stats
    }

    private func ratingDouble(_ raw: String?) -> Double {
        guard let raw else { return 0 }
        return Double(raw.filter { $0 == "⭐" }.count)
    }

    // 연속 달성: 오늘 기준으로 completionRate > 0인 연속 날 수
    private func calculateStreak(reports: [DailyReportItem], endingAt: Date, calendar: Calendar) -> Int {
        // 전체 기간 포함 추가 조회 (streak은 기간과 무관하게 오늘 기준)
        let today = calendar.startOfDay(for: .now)
        var streak = 0
        var checkDate = today
        let allReportDesc = FetchDescriptor<DailyReportItem>()
        let allReports = (try? context.fetch(allReportDesc)) ?? []
        let plannerId = PlannerService.shared.selectedPlanner?.id

        for _ in 0..<365 {
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: checkDate) else { break }
            let dayReports = allReports.filter {
                $0.date >= checkDate && $0.date < nextDate &&
                ($0.plannerId == plannerId || plannerId == nil)
            }
            guard let report = dayReports.first, report.completionRate > 0 else { break }
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return streak
    }

    // MARK: - 빈 데이터

    private func emptyWeekly(start: Date) -> WeeklyReportData {
        WeeklyReportData(
            period: DateInterval(start: start, end: start),
            completionRate: 0, averageRating: 0, streakDays: 0,
            dailyCompletionRates: [], dailyRatings: [], categoryStats: []
        )
    }

    private func emptyMonthly(start: Date) -> MonthlyReportData {
        MonthlyReportData(
            period: DateInterval(start: start, end: start),
            completionRate: 0, averageRating: 0, streakDays: 0,
            weeklyCompletionRates: [], weeklyRatings: [], categoryStats: []
        )
    }
}
