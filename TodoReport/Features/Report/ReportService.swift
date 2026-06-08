import Foundation
import SwiftData

struct ReportTodoEntry: Identifiable {
    let id: String
    let title: String
    let date: Date
    let isCompleted: Bool
}

struct ReviewTimelineEntry: Identifiable {
    let id: String
    let date: Date
    let rating: Double
    let review: String
}

struct WeeklyReportData {
    let period: DateInterval
    let completionRate: Double
    let averageRating: Double
    let streakDays: Int
    let dailyCompletionRates: [DailyRate]
    let dailyRatings: [DailyRatingPoint]
    let categoryStats: [CategoryStat]
    let todos: [ReportTodoEntry]
    let reviewTimeline: [ReviewTimelineEntry]
}

struct MonthlyReportData {
    let period: DateInterval
    let completionRate: Double
    let averageRating: Double
    let streakDays: Int
    let weeklyCompletionRates: [WeeklyRate]
    let weeklyRatings: [WeeklyRatingPoint]
    let dailyRatings: [DailyRatingPoint]
    let categoryStats: [CategoryStat]
    let todos: [ReportTodoEntry]
    let reviewTimeline: [ReviewTimelineEntry]
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

struct PeriodReportChartData {
    struct Entry { let label: String; let rate: Double }
    struct RatingEntry { let label: String; let rating: Double }
    struct CategoryEntry { let name: String; let rate: Double; let completed: Int; let total: Int }
    struct ReviewEntry { let date: String; let review: String; let rating: Double }
    let rates: [Entry]
    let ratings: [RatingEntry]
    let categories: [CategoryEntry]
    let reviews: [ReviewEntry]
}

final class ReportService {
    static let shared = ReportService()
    private init() {}

    private var context: ModelContext { PersistenceController.shared.context }
    private let calendar = Calendar.current

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
        let today = calendar.startOfDay(for: .now)
        var dailyRates: [DailyRate] = []
        var dailyRatings: [DailyRatingPoint] = []
        var elapsedCount = 0

        for i in 0..<7 {
            guard let dayStart = calendar.date(byAdding: .day, value: i, to: start),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let dayTodos = todos.filter { $0.date >= dayStart && $0.date < dayEnd }
            let rate = dayTodos.isEmpty ? 0 : Double(dayTodos.filter { $0.isCompleted }.count) / Double(dayTodos.count)
            dailyRates.append(DailyRate(weekday: weekdays[i], rate: rate))

            let report = reports.first { $0.date >= dayStart && $0.date < dayEnd }
            let ratingValue = ratingDouble(report?.dayRatingRaw)
            dailyRatings.append(DailyRatingPoint(weekday: weekdays[i], rating: ratingValue))

            if dayStart <= today { elapsedCount += 1 }
        }

        let avgRate = elapsedCount == 0 ? 0 : dailyRates.prefix(elapsedCount).map(\.rate).reduce(0, +) / Double(elapsedCount)
        let ratedDays = dailyRatings.filter { $0.rating > 0 }
        let avgRating = ratedDays.isEmpty ? 0 : ratedDays.map(\.rating).reduce(0, +) / Double(ratedDays.count)
        let streak = calculateStreak(plannerId: plannerId, calendar: calendar)

        let todoEntries = todos
            .sorted { $0.date < $1.date }
            .map { ReportTodoEntry(id: $0.id, title: $0.title, date: $0.date, isCompleted: $0.isCompleted) }

        let reviewTimeline = reports
            .filter { !$0.review.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.date < $1.date }
            .map { ReviewTimelineEntry(id: $0.id, date: $0.date, rating: ratingDouble($0.dayRatingRaw), review: $0.review) }

        return WeeklyReportData(
            period: DateInterval(start: start, end: end),
            completionRate: avgRate,
            averageRating: avgRating,
            streakDays: streak,
            dailyCompletionRates: dailyRates,
            dailyRatings: dailyRatings,
            categoryStats: buildCategoryStats(todos: todos, categories: categories),
            todos: todoEntries,
            reviewTimeline: reviewTimeline
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
        let today = calendar.startOfDay(for: .now)
        var weeklyRates: [WeeklyRate] = []
        var weeklyRatings: [WeeklyRatingPoint] = []
        var weekStart = start
        var weekIndex = 1
        var elapsedWeekCount = 0

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

            if weekStart <= today { elapsedWeekCount += 1 }

            weekStart = weekEnd
            weekIndex += 1
        }

        let avgRate = elapsedWeekCount == 0 ? 0 : weeklyRates.prefix(elapsedWeekCount).map(\.rate).reduce(0, +) / Double(elapsedWeekCount)
        let ratedWeeks = weeklyRatings.filter { $0.rating > 0 }
        let avgRating = ratedWeeks.isEmpty ? 0 : ratedWeeks.map(\.rating).reduce(0, +) / Double(ratedWeeks.count)
        let streak = calculateStreak(plannerId: plannerId, calendar: calendar)

        // 일별 별점 집계 (꺾은선 그래프용)
        let daysInMonth = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        var dailyRatings: [DailyRatingPoint] = []
        for i in 0..<daysInMonth {
            guard let dayStart = calendar.date(byAdding: .day, value: i, to: start),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let report = reports.first { $0.date >= dayStart && $0.date < dayEnd }
            dailyRatings.append(DailyRatingPoint(weekday: "\(i + 1)", rating: ratingDouble(report?.dayRatingRaw)))
        }

        let todoEntries = todos
            .sorted { $0.date < $1.date }
            .map { ReportTodoEntry(id: $0.id, title: $0.title, date: $0.date, isCompleted: $0.isCompleted) }

        let reviewTimeline = reports
            .filter { !$0.review.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.date < $1.date }
            .map { ReviewTimelineEntry(id: $0.id, date: $0.date, rating: ratingDouble($0.dayRatingRaw), review: $0.review) }

        return MonthlyReportData(
            period: DateInterval(start: start, end: end),
            completionRate: avgRate,
            averageRating: avgRating,
            streakDays: streak,
            weeklyCompletionRates: weeklyRates,
            weeklyRatings: weeklyRatings,
            dailyRatings: dailyRatings,
            categoryStats: buildCategoryStats(todos: todos, categories: categories),
            todos: todoEntries,
            reviewTimeline: reviewTimeline
        )
    }

    // MARK: - 기간 리포트 저장 (주간/월간)

    func savePeriodReport(
        period: DateInterval,
        title: String,
        comment: String,
        completionRate: Double,
        avgRating: Double,
        chartData: PeriodReportChartData? = nil
    ) async throws {
        guard let planner = PlannerService.shared.selectedPlanner,
              planner.isNotionConnected,
              let dbId = planner.notionReportDBId else { return }

        var mapping = planner.decodedReportPropsMapping
        let token = planner.resolvedNotionToken

        // 기간완료율 속성 자동 생성 (없으면)
        if mapping.periodCompletionRate == nil {
            if let propName = await autoCreateAndSavePeriodCompletionRateProp(
                planner: planner, dbId: dbId, token: token
            ) {
                mapping.periodCompletionRate = propName
            }
        }

        let rating = dayRatingFromAverage(avgRating)
        let start = calendar.startOfDay(for: period.start)
        let existing = findPeriodReport(startDate: start, plannerId: planner.id)

        // 로컬 먼저 (offline-first)
        let localItem = saveLocalPeriodReport(
            start: start, end: period.end,
            comment: comment, completionRate: completionRate,
            rating: rating, plannerId: planner.id,
            existing: existing
        )

        // Notion 전송
        let endInclusive = calendar.date(byAdding: .day, value: -1, to: period.end) ?? period.end
        var body: [String: Any] = [
            "dbId": dbId,
            "date": seoulDateString(from: start),
            "endDate": seoulDateString(from: endInclusive),
            "title": title,
            "completionRate": completionRate,
            "review": comment,
        ]
        if !localItem.notionPageId.isEmpty { body["notionPageId"] = localItem.notionPageId }
        if let v = mapping.date   { body["dateProp"] = v }
        if let v = mapping.review { body["reviewProp"] = v }
        if let v = mapping.rating { body["ratingProp"] = v }
        if let r = rating         { body["rating"] = r.rawValue }
        if let prop = mapping.periodCompletionRate {
            body["periodCompletionRateProp"] = prop
            body["periodCompletionRate"] = completionRate
        }
        if let data = chartData {
            body["chartRates"] = data.rates.map { ["label": $0.label, "rate": $0.rate] as [String: Any] }
            if !data.ratings.isEmpty {
                body["chartRatings"] = data.ratings.map { ["label": $0.label, "rating": $0.rating] as [String: Any] }
            }
            if !data.categories.isEmpty {
                body["chartCategories"] = data.categories.map {
                    ["name": $0.name, "rate": $0.rate, "completed": $0.completed, "total": $0.total] as [String: Any]
                }
            }
            if !data.reviews.isEmpty {
                body["chartReviews"] = data.reviews.map {
                    ["date": $0.date, "review": $0.review, "rating": $0.rating] as [String: Any]
                }
            }
        }

        let response: NotionSaveResponse = try await APIClient.shared.post(
            "/api/notion/daily-report", body: AnyEncodableDict(body), token: token
        )

        // notionPageId 로컬 갱신
        let itemId = localItem.id
        let descriptor = FetchDescriptor<DailyReportItem>(
            predicate: #Predicate { $0.id == itemId }
        )
        if let item = try? context.fetch(descriptor).first {
            item.notionPageId = response.id
            try? context.save()
        }
    }

    // MARK: - 기간완료율 속성 자동 생성

    private func autoCreateAndSavePeriodCompletionRateProp(
        planner: Planner, dbId: String, token: String?
    ) async -> String? {
        struct AddPropResponse: Decodable { let propertyName: String }
        struct AddPropBody: Encodable {
            let propertyName: String
            let type: String
            let format: String
        }
        do {
            let response: AddPropResponse = try await APIClient.shared.post(
                "/api/notion/databases/\(dbId)/add-property",
                body: AddPropBody(propertyName: "기간완료율", type: "number", format: "percent"),
                token: token
            )
            var updated = planner
            var mapping = planner.decodedReportPropsMapping
            mapping.periodCompletionRate = response.propertyName
            if let data = try? JSONEncoder().encode(mapping),
               let json = String(data: data, encoding: .utf8) {
                updated.reportPropsMapping = json
            }
            try? await PlannerService.shared.savePlanner(updated)
            return response.propertyName
        } catch {
            print("[ReportService] ⚠️ 기간완료율 속성 생성 실패 - \(error)")
            return nil
        }
    }

    // MARK: - 기간 리포트 로컬 헬퍼

    private func findPeriodReport(startDate: Date, plannerId: String) -> DailyReportItem? {
        let descriptor = FetchDescriptor<DailyReportItem>()
        let all = (try? context.fetch(descriptor)) ?? []
        return all.first {
            calendar.isDate($0.date, inSameDayAs: startDate) &&
            $0.plannerId == plannerId &&
            $0.endDate != nil
        }
    }

    private func saveLocalPeriodReport(
        start: Date, end: Date,
        comment: String, completionRate: Double,
        rating: DayRating?, plannerId: String,
        existing: DailyReportItem?
    ) -> DailyReportItem {
        if let item = existing {
            item.review = comment
            item.completionRate = completionRate
            item.periodCompletionRate = completionRate
            item.dayRatingRaw = rating?.rawValue
            item.endDate = end
            try? context.save()
            return item
        }
        let item = DailyReportItem(
            date: start, review: comment,
            completionRate: completionRate,
            dayRatingRaw: rating?.rawValue,
            plannerId: plannerId,
            endDate: end,
            periodCompletionRate: completionRate
        )
        context.insert(item)
        try? context.save()
        return item
    }

    private func dayRatingFromAverage(_ avg: Double) -> DayRating? {
        guard avg > 0 else { return nil }
        switch avg {
        case ..<1.5: return .one
        case ..<2.5: return .two
        case ..<3.5: return .three
        case ..<4.5: return .four
        default:     return .five
        }
    }

    private func seoulDateString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Asia/Seoul")
        return fmt.string(from: date)
    }

    // MARK: - SwiftData Fetch

    func hasTodos(in range: Range<Date>) async -> Bool {
        let plannerId = PlannerService.shared.selectedPlanner?.id
        return !fetchTodos(in: range, plannerId: plannerId).isEmpty
    }

    func hasDailyReport(in range: Range<Date>) async -> Bool {
        let plannerId = PlannerService.shared.selectedPlanner?.id
        return !fetchReports(in: range, plannerId: plannerId).isEmpty
    }

    func hasNotionDailyReport(in range: Range<Date>) async -> Bool {
        let plannerId = PlannerService.shared.selectedPlanner?.id
        let reports = fetchReports(in: range, plannerId: plannerId)
        return reports.contains { !$0.notionPageId.isEmpty }
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
        // 기간 리포트(endDate != nil) 제외 — 데일리 리포트만 집계에 사용
        let dailyOnly = all.filter { $0.endDate == nil }
        guard let pid = plannerId else { return dailyOnly }
        return dailyOnly.filter { $0.plannerId == pid }
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

    // 연속 달성: 어제까지 기준, 설정된 기준에 따라 투두 데이터로 판정
    private func calculateStreak(plannerId: String?, calendar: Calendar) -> Int {
        let today = calendar.startOfDay(for: .now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let rangeStart = calendar.date(byAdding: .day, value: -365, to: yesterday),
              let rangeEnd = calendar.date(byAdding: .day, value: 2, to: yesterday) else {
            return 0
        }

        let todos = fetchTodos(in: rangeStart..<rangeEnd, plannerId: plannerId)
        let criteria = StreakCriteria.current
        var streak = 0
        var checkDate = yesterday

        for _ in 0..<365 {
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: checkDate) else { break }
            let dayTodos = todos.filter { $0.date >= checkDate && $0.date < nextDate }
            guard criteria.isDaySatisfied(todos: dayTodos) else { break }
            streak += 1
            guard let prevDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prevDate
        }
        return streak
    }

    // MARK: - 빈 데이터

    private func emptyWeekly(start: Date) -> WeeklyReportData {
        WeeklyReportData(
            period: DateInterval(start: start, end: start),
            completionRate: 0, averageRating: 0, streakDays: 0,
            dailyCompletionRates: [], dailyRatings: [], categoryStats: [], todos: [], reviewTimeline: []
        )
    }

    private func emptyMonthly(start: Date) -> MonthlyReportData {
        MonthlyReportData(
            period: DateInterval(start: start, end: start),
            completionRate: 0, averageRating: 0, streakDays: 0,
            weeklyCompletionRates: [], weeklyRatings: [], dailyRatings: [], categoryStats: [], todos: [], reviewTimeline: []
        )
    }
}

// MARK: - Private helpers

private struct NotionSaveResponse: Decodable {
    let id: String
}

private struct AnyEncodableDict: Encodable {
    private let value: [String: Any]
    init(_ value: [String: Any]) { self.value = value }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: RawKey.self)
        for (key, val) in value {
            let k = RawKey(key)
            switch val {
            case let v as String:            try container.encode(v, forKey: k)
            case let v as Bool:              try container.encode(v, forKey: k)
            case let v as Int:               try container.encode(v, forKey: k)
            case let v as Double:            try container.encode(v, forKey: k)
            case let arr as [[String: Any]]:
                var nested = container.nestedUnkeyedContainer(forKey: k)
                for dict in arr { try nested.encode(AnyEncodableDict(dict)) }
            default: break
            }
        }
    }

    private struct RawKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ s: String) { stringValue = s }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
}
