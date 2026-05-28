import Foundation

enum ReportPeriod: String, CaseIterable {
    case weekly  = "주간"
    case monthly = "월간"
}

@Observable
final class ReportViewModel {
    var selectedPeriod: ReportPeriod = .weekly
    var isLoading: Bool = false

    private(set) var weeklyReport: WeeklyReportData?
    private(set) var monthlyReport: MonthlyReportData?

    // 현재 보여주는 기간의 오프셋 (0 = 이번 주/월)
    private(set) var periodOffset: Int = 0

    private let service = ReportService.shared
    private let calendar = Calendar.current

    // MARK: - Computed

    var periodTitle: String {
        switch selectedPeriod {
        case .weekly:
            guard let report = weeklyReport else { return "" }
            return formatWeeklyPeriod(report.period)
        case .monthly:
            guard let report = monthlyReport else { return "" }
            return formatMonthlyPeriod(report.period)
        }
    }

    var canGoNext: Bool { periodOffset < 0 }

    // MARK: - Actions

    func goToPreviousPeriod() {
        periodOffset -= 1
        Task { await fetchReport() }
    }

    func goToNextPeriod() {
        guard canGoNext else { return }
        periodOffset += 1
        Task { await fetchReport() }
    }

    func onPeriodChanged() {
        periodOffset = 0
        Task { await fetchReport() }
    }

    // MARK: - Data

    func fetchReport() async {
        isLoading = true
        defer { isLoading = false }

        switch selectedPeriod {
        case .weekly:
            let monday = mondayOfCurrentWeek(offset: periodOffset)
            weeklyReport = await service.fetchWeeklyReport(startingFrom: monday)
        case .monthly:
            let (year, month) = yearMonthOfCurrent(offset: periodOffset)
            monthlyReport = await service.fetchMonthlyReport(year: year, month: month)
        }
    }

    // MARK: - Helpers

    private func mondayOfCurrentWeek(offset: Int) -> Date {
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        components.weekday = 2  // 월요일
        let thisMonday = calendar.date(from: components) ?? .now
        return calendar.date(byAdding: .weekOfYear, value: offset, to: thisMonday) ?? thisMonday
    }

    private func yearMonthOfCurrent(offset: Int) -> (Int, Int) {
        guard let shifted = calendar.date(byAdding: .month, value: offset, to: .now) else {
            let comps = calendar.dateComponents([.year, .month], from: .now)
            return (comps.year ?? 2026, comps.month ?? 1)
        }
        let comps = calendar.dateComponents([.year, .month], from: shifted)
        return (comps.year ?? 2026, comps.month ?? 1)
    }

    private func formatWeeklyPeriod(_ interval: DateInterval) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")

        let startComps = calendar.dateComponents([.year, .month, .day], from: interval.start)
        let endComps   = calendar.dateComponents([.year, .month, .day], from: interval.end)

        let year  = startComps.year ?? 0
        let sm    = startComps.month ?? 0
        let sd    = startComps.day ?? 0
        let em    = endComps.month ?? 0
        let ed    = endComps.day ?? 0

        if sm == em {
            return "\(year)년 \(sm)월 \(sd)일 — \(ed)일"
        } else {
            return "\(year)년 \(sm)월 \(sd)일 — \(em)월 \(ed)일"
        }
    }

    private func formatMonthlyPeriod(_ interval: DateInterval) -> String {
        let comps = calendar.dateComponents([.year, .month], from: interval.start)
        return "\(comps.year ?? 2026)년 \(comps.month ?? 1)월"
    }
}
