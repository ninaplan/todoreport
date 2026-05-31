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

    // Paywall
    var showPaywall: Bool = false
    private(set) var paywallMessage: String = ""

    private(set) var isSyncing: Bool = false
    private(set) var isSavingToNotion: Bool = false
    var notionSaveSuccess: Bool = false

    // Save editor
    var showSaveEditor: Bool = false
    private(set) var pendingPeriod: DateInterval?
    private(set) var pendingPeriodTitle: String = ""
    private(set) var pendingNotionTitle: String = ""
    private(set) var pendingAvgRating: Double = 0
    private(set) var pendingCompletionRate: Double = 0
    var notionSaveError: String?

    #if DEBUG
    private var isPro: Bool { UserDefaults.standard.bool(forKey: "debugIsPro") }
    #else
    private let isPro = false
    #endif

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
        guard isPro else {
            paywallMessage = "이전 기간 조회는 Pro 기능이에요"
            showPaywall = true
            return
        }
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

    func dismissPaywall() {
        showPaywall = false
        paywallMessage = ""
        if selectedPeriod == .monthly { selectedPeriod = .weekly }
    }

    func prepareSave() {
        guard isPro else {
            paywallMessage = "노션에 저장하기는 Pro 기능이에요"
            showPaywall = true
            return
        }
        guard PlannerService.shared.selectedPlanner?.isNotionConnected == true else { return }

        switch selectedPeriod {
        case .weekly:
            guard let report = weeklyReport else { return }
            pendingPeriod = report.period
            pendingPeriodTitle = periodTitle
            pendingNotionTitle = notionTitle(for: report.period, type: .weekly)
            pendingAvgRating = report.averageRating
            pendingCompletionRate = report.completionRate
        case .monthly:
            guard let report = monthlyReport else { return }
            pendingPeriod = report.period
            pendingPeriodTitle = periodTitle
            pendingNotionTitle = notionTitle(for: report.period, type: .monthly)
            pendingAvgRating = report.averageRating
            pendingCompletionRate = report.completionRate
        }
        showSaveEditor = true
    }

    func confirmSave(comment: String) async {
        guard let period = pendingPeriod else { return }
        isSavingToNotion = true
        showSaveEditor = false
        defer { isSavingToNotion = false }
        do {
            try await service.savePeriodReport(
                period: period,
                title: pendingNotionTitle,
                comment: comment,
                completionRate: pendingCompletionRate,
                avgRating: pendingAvgRating
            )
            notionSaveSuccess = true
        } catch {
            print("[ReportVM] ❌ 저장 실패 - \(error)")
            notionSaveError = error.localizedDescription
        }
        pendingPeriod = nil
    }

    func dismissSaveError() {
        notionSaveError = nil
    }

    func cancelSave() {
        showSaveEditor = false
        pendingPeriod = nil
    }

    func dismissNotionSaveSuccess() {
        notionSaveSuccess = false
    }

    // MARK: - Data

    func fetchReport() async {
        isLoading = true
        defer { isLoading = false }

        switch selectedPeriod {
        case .weekly:
            let weekStart = startOfCurrentWeek(offset: periodOffset)
            await syncMissingDays(from: weekStart, count: 7)
            weeklyReport = await service.fetchWeeklyReport(startingFrom: weekStart)
        case .monthly:
            guard isPro else {
                paywallMessage = "월간 리포트는 Pro 기능이에요"
                showPaywall = true
                return
            }
            let (year, month) = yearMonthOfCurrent(offset: periodOffset)
            let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now
            let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
            await syncMissingDays(from: monthStart, count: daysInMonth)
            monthlyReport = await service.fetchMonthlyReport(year: year, month: month)
        }
    }

    // MARK: - Notion Sync (없는 날짜만)

    private func syncMissingDays(from start: Date, count: Int) async {
        let planner = PlannerService.shared.selectedPlanner
        guard planner?.isNotionConnected == true else { return }

        isSyncing = true
        defer { isSyncing = false }

        let todoService = TodoService.shared
        let reportService = DailyReportService()

        for i in 0..<count {
            guard let dayStart = calendar.date(byAdding: .day, value: i, to: start),
                  let dayEnd   = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            // 해당 날이 오늘 이후면 스킵
            if dayStart > calendar.startOfDay(for: .now) { continue }

            let hasTodos = await self.service.hasTodos(in: dayStart..<dayEnd)
            if !hasTodos {
                await todoService.syncTodosFromNotion(for: dayStart)
                await reportService.syncReportFromNotion(for: dayStart)
            }
        }
    }

    // MARK: - Helpers

    private func startOfCurrentWeek(offset: Int) -> Date {
        let startWeekday = UserDefaults.standard.string(forKey: "startWeekday") ?? "월"
        let firstWeekdayNum = startWeekday == "일" ? 1 : 2  // 일=Sunday=1, 월=Monday=2
        let today = calendar.startOfDay(for: .now)
        let todayWeekday = calendar.component(.weekday, from: today)  // 1=Sun...7=Sat
        let daysBack = (todayWeekday - firstWeekdayNum + 7) % 7
        let weekStart = calendar.date(byAdding: .day, value: -daysBack, to: today) ?? today
        return calendar.date(byAdding: .weekOfYear, value: offset, to: weekStart) ?? weekStart
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
        let startComps = calendar.dateComponents([.year, .month, .day], from: interval.start)
        let endDate    = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let endComps   = calendar.dateComponents([.year, .month, .day], from: endDate)

        let year = startComps.year ?? 0
        let sm   = startComps.month ?? 0
        let sd   = startComps.day ?? 0
        let em   = endComps.month ?? 0
        let ed   = endComps.day ?? 0

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

    private func notionTitle(for period: DateInterval, type: ReportPeriod) -> String {
        switch type {
        case .weekly:
            let startComps = calendar.dateComponents([.year, .month, .day], from: period.start)
            let lastDay    = calendar.date(byAdding: .day, value: -1, to: period.end) ?? period.end
            let endComps   = calendar.dateComponents([.month, .day], from: lastDay)
            let y  = startComps.year  ?? 0
            let sm = startComps.month ?? 0
            let sd = startComps.day   ?? 0
            let em = endComps.month   ?? 0
            let ed = endComps.day     ?? 0
            return "주간 리포트 (\(y)년 \(sm)월 \(sd)일 - \(em)월 \(ed)일)"
        case .monthly:
            let comps = calendar.dateComponents([.year, .month], from: period.start)
            return "월간 리포트 (\(comps.year ?? 2026)년 \(comps.month ?? 1)월)"
        }
    }
}
