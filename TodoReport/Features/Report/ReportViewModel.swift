import Foundation
import SwiftUI

enum ReportPeriod: String, CaseIterable {
    case weekly  = "주간"
    case monthly = "월간"

    var localizedTitle: LocalizedStringKey {
        LocalizedStringKey(rawValue)
    }
}

@Observable
final class ReportViewModel {
    var selectedPeriod: ReportPeriod = .weekly
    var isLoading: Bool = false

    private(set) var weeklyReport: WeeklyReportData?
    private(set) var monthlyReport: MonthlyReportData?
    /// 「집중 시간」·「시간 사용」 (타임라인 블록 집계). 기간 리포트가 바뀔 때마다 다시 계산
    private(set) var timeUsage: TimeBlockUsageSummary = .empty

    // 현재 보여주는 기간의 오프셋 (0 = 이번 주/월)
    private(set) var periodOffset: Int = 0
    /// 화면에 불러와진 기간. 바뀌는 순간 본문이 좌우로 슬라이드된다
    private(set) var loadedPeriodOffset: Int?

    // Paywall
    var showPaywall: Bool = false
    private(set) var paywallMessage: String = ""

    // 노션 연결 유도
    var showNotionConnectAlert: Bool = false
    var showMigrationSheet: Bool = false

    private(set) var isSyncing: Bool = false
    private(set) var isSavingToNotion: Bool = false
    private(set) var isPreparingSave: Bool = false
    var notionSaveSuccess: Bool = false

    // Save editor
    var showSaveEditor: Bool = false
    private(set) var pendingPeriod: DateInterval?
    private(set) var pendingPeriodTitle: String = ""
    private(set) var pendingNotionTitle: String = ""
    private(set) var pendingAvgRating: Double = 0
    private(set) var pendingCompletionRate: Double = 0
    private var pendingChartData: PeriodReportChartData?
    var pendingInitialReview: String = ""
    var notionSaveError: String?

    private var isPro: Bool { SubscriptionManager.shared.isPro }

    private let service = ReportService.shared
    private let calendar = Calendar.current
    @ObservationIgnored private var isHandlingForegroundRefresh = false
    @ObservationIgnored private var notionSyncTask: Task<Void, Never>?

    // MARK: - Computed

    var isNotionConnected: Bool {
        PlannerService.shared.selectedPlanner?.isNotionConnected == true
    }

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
        clearCurrentPeriodReport()
        Task {
            await fetchReport()
            if !hasLocalReportForCurrentPeriod {
                await fetchReportWithNotionSync()
            } else {
                await performBackgroundNotionSync(quiet: true)
            }
        }
    }

    func goToNextPeriod() {
        guard canGoNext else { return }
        periodOffset += 1
        clearCurrentPeriodReport()
        Task {
            await fetchReport()
            if !hasLocalReportForCurrentPeriod {
                await fetchReportWithNotionSync()
            } else {
                await performBackgroundNotionSync(quiet: true)
            }
        }
    }

    func onPeriodChanged() {
        periodOffset = 0
        clearCurrentPeriodReport()
        Task {
            await fetchReport()
            if !hasLocalReportForCurrentPeriod {
                await fetchReportWithNotionSync()
            } else {
                await performBackgroundNotionSync(quiet: true)
            }
        }
    }

    /// 리포트 탭을 다시 탭 → 이번 주(이번 달)로
    func goToCurrentPeriod() {
        guard periodOffset != 0 else { return }
        onPeriodChanged()
    }

    func onPlannerChanged() {
        weeklyReport = nil
        monthlyReport = nil
        periodOffset = 0
        ReportNotificationManager.shared.rescheduleAll()
        Task { await fetchReportWithNotionSync() }
    }

    private func clearCurrentPeriodReport() {
        switch selectedPeriod {
        case .weekly:
            weeklyReport = nil
        case .monthly:
            monthlyReport = nil
        }
    }

    func cancelNotionConnect() {
        showNotionConnectAlert = false
    }

    func confirmNotionConnect() {
        showNotionConnectAlert = false
        showMigrationSheet = true
    }

    func dismissPaywall() {
        showPaywall = false
        paywallMessage = ""
    }

    func prepareSave() {
        guard isPro else {
            paywallMessage = String(localized: "노션에 리포트 저장하기는 Pro 기능이에요")
            showPaywall = true
            return
        }
        guard isNotionConnected else {
            showNotionConnectAlert = true
            return
        }

        let period: DateInterval
        let notionTitleText: String
        let chartData: PeriodReportChartData

        switch selectedPeriod {
        case .weekly:
            guard let report = weeklyReport else { return }
            period = report.period
            pendingPeriodTitle = periodTitle
            notionTitleText = notionTitle(for: report.period, type: .weekly)
            pendingAvgRating = report.averageRating
            pendingCompletionRate = report.completionRate
            chartData = PeriodReportChartData(
                rates: report.dailyCompletionRates.map { .init(label: $0.weekday, rate: $0.rate) },
                ratings: report.dailyRatings.map { .init(label: $0.weekday, rating: $0.rating) },
                categories: notionCategoryStats(report.categoryStats),
                reviews: reviewEntries(from: report.reviewTimeline)
            )
        case .monthly:
            guard let report = monthlyReport else { return }
            period = report.period
            pendingPeriodTitle = periodTitle
            notionTitleText = notionTitle(for: report.period, type: .monthly)
            pendingAvgRating = report.averageRating
            pendingCompletionRate = report.completionRate
            chartData = PeriodReportChartData(
                rates: report.weeklyCompletionRates.map { .init(label: $0.label, rate: $0.rate) },
                ratings: report.weeklyRatings.map { .init(label: $0.label, rating: $0.rating) },
                categories: notionCategoryStats(report.categoryStats),
                reviews: reviewEntries(from: report.reviewTimeline)
            )
        }

        pendingPeriod = period
        pendingNotionTitle = notionTitleText
        pendingChartData = chartData
        pendingInitialReview = ""
        showSaveEditor = true
        isPreparingSave = true
        Task {
            defer { isPreparingSave = false }
            pendingInitialReview = await service.fetchSavedPeriodReview(for: period)
        }
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
                avgRating: pendingAvgRating,
                chartData: pendingChartData
            )
            notionSaveSuccess = true
        } catch {
            print("[ReportVM] ❌ 저장 실패 - \(error)")
            notionSaveError = error.localizedDescription
        }
        pendingPeriod = nil
        pendingChartData = nil
        pendingInitialReview = ""
    }

    func dismissSaveError() {
        notionSaveError = nil
    }

    func cancelSave() {
        showSaveEditor = false
        isPreparingSave = false
        pendingPeriod = nil
        pendingChartData = nil
        pendingInitialReview = ""
    }

    func dismissNotionSaveSuccess() {
        notionSaveSuccess = false
    }

    // MARK: - Data

    func handleForegroundRefresh() async {
        guard !isHandlingForegroundRefresh else { return }
        isHandlingForegroundRefresh = true
        do {
            defer { isHandlingForegroundRefresh = false }
            await fetchReportWithNotionSync()
        }
    }

    /// 로컬(SwiftData)만 조회 — 기간 이동 시 사용
    func fetchReport() async {
        let hadLocal = hasLocalReportForCurrentPeriod
        if !hadLocal { isLoading = true }
        do {
            defer { isLoading = false }
            guard !Task.isCancelled else { return }
            if !hadLocal { await Task.yield() }
            await loadLocalReport()
        }
    }

    /// 화면 최초 진입·pull-to-refresh·포그라운드 복귀 — 로컬 먼저, 백그라운드 Notion sync
    func fetchReportWithNotionSync() async {
        let hadLocal = hasLocalReportForCurrentPeriod
        await fetchReport()
        await performBackgroundNotionSync(quiet: hadLocal)
    }

    private var hasLocalReportForCurrentPeriod: Bool {
        switch selectedPeriod {
        case .weekly: return weeklyReport != nil
        case .monthly: return monthlyReport != nil
        }
    }

    @MainActor
    private func loadLocalReport() async {
        switch selectedPeriod {
        case .weekly:
            let weekStart = startOfCurrentWeek(offset: periodOffset)
            weeklyReport = await service.fetchWeeklyReport(startingFrom: weekStart)
        case .monthly:
            let (year, month) = yearMonthOfCurrent(offset: periodOffset)
            monthlyReport = await service.fetchMonthlyReport(year: year, month: month)
        }
        refreshTimeUsage()
        loadedPeriodOffset = periodOffset
    }

    /// 막대 구간은 완료율 그래프와 같게: 주간 = 하루씩, 월간 = 7일씩
    private func refreshTimeUsage() {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .weekly:
            guard let report = weeklyReport else { timeUsage = .empty; return }
            let ranges: [Range<Date>] = (0..<7).compactMap { offset in
                guard let start = calendar.date(byAdding: .day, value: offset, to: report.period.start),
                      let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
                return start..<end
            }
            timeUsage = TimeBlockService.shared.usageSummary(
                ranges: ranges,
                labels: report.dailyCompletionRates.map(\.weekday)
            )
        case .monthly:
            guard let report = monthlyReport else { timeUsage = .empty; return }
            var ranges: [Range<Date>] = []
            var weekStart = report.period.start
            while weekStart < report.period.end {
                let weekEnd = min(calendar.date(byAdding: .day, value: 7, to: weekStart) ?? report.period.end, report.period.end)
                ranges.append(weekStart..<weekEnd)
                weekStart = weekEnd
            }
            timeUsage = TimeBlockService.shared.usageSummary(
                ranges: ranges,
                labels: report.weeklyCompletionRates.map(\.label)
            )
        }
    }

    @MainActor
    private func reloadLocalReport(animated: Bool) async {
        switch selectedPeriod {
        case .weekly:
            let weekStart = startOfCurrentWeek(offset: periodOffset)
            let updated = await service.fetchWeeklyReport(startingFrom: weekStart)
            if animated, weeklyReport != nil {
                withAnimation(.easeInOut(duration: 0.3)) { weeklyReport = updated }
            } else {
                weeklyReport = updated
            }
            refreshTimeUsage()
        case .monthly:
            let (year, month) = yearMonthOfCurrent(offset: periodOffset)
            let updated = await service.fetchMonthlyReport(year: year, month: month)
            if animated, monthlyReport != nil {
                withAnimation(.easeInOut(duration: 0.3)) { monthlyReport = updated }
            } else {
                monthlyReport = updated
            }
            refreshTimeUsage()
        }
    }

    @MainActor
    private func performBackgroundNotionSync(quiet: Bool) async {
        notionSyncTask?.cancel()
        let task = Task { @MainActor in
            do {
                defer {
                    isSyncing = false
                    notionSyncTask = nil
                }
                if !quiet { isSyncing = true }

                switch selectedPeriod {
                case .weekly:
                    let weekStart = startOfCurrentWeek(offset: periodOffset)
                    await syncMissingDays(from: weekStart, count: 7, manageSyncingFlag: false)
                case .monthly:
                    let (year, month) = yearMonthOfCurrent(offset: periodOffset)
                    let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now
                    let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
                    await syncMissingDays(from: monthStart, count: daysInMonth, manageSyncingFlag: false)
                }

                await reloadLocalReport(animated: quiet)
            }
        }
        notionSyncTask = task
        await task.value
    }

    // MARK: - Notion Sync (없는 날짜만, 병렬 처리)

    private func syncMissingDays(from start: Date, count: Int, manageSyncingFlag: Bool = true) async {
        let planner = PlannerService.shared.selectedPlanner
        guard planner?.isNotionConnected == true else { return }

        let performSync = {
            let todoService = TodoService.shared
            let calendar = self.calendar

            var daysToSync: [Date] = []
            for i in 0..<count {
                guard let dayStart = calendar.date(byAdding: .day, value: i, to: start),
                      let dayEnd   = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
                if dayStart > calendar.startOfDay(for: .now) { continue }
                let hasTodos        = await self.service.hasTodos(in: dayStart..<dayEnd)
                let hasNotionReport = await self.service.hasNotionDailyReport(in: dayStart..<dayEnd)
                if !hasTodos || !hasNotionReport { daysToSync.append(dayStart) }
            }

            guard !daysToSync.isEmpty else { return }

            await withTaskGroup(of: Void.self) { group in
                for dayStart in daysToSync {
                    group.addTask {
                        await todoService.syncTodosFromNotion(for: dayStart)
                        await DailyReportService().syncReportFromNotion(for: dayStart)
                    }
                }
            }
        }

        if manageSyncingFlag {
            do {
                isSyncing = true
                defer { isSyncing = false }
                await performSync()
            }
        } else {
            await performSync()
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
        let endDate = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let formatter = DateIntervalFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: interval.start, to: endDate)
    }

    private func formatMonthlyPeriod(_ interval: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = DateFormatter.dateFormat(
            fromTemplate: "yMMMM",
            options: 0,
            locale: .autoupdatingCurrent
        )
        return formatter.string(from: interval.start)
    }

    private func reviewEntries(from timeline: [ReviewTimelineEntry]) -> [PeriodReportChartData.ReviewEntry] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Asia/Seoul")
        return timeline.map {
            .init(date: fmt.string(from: $0.date), review: $0.review, rating: $0.rating)
        }
    }

    private func notionTitle(for period: DateInterval, type: ReportPeriod) -> String {
        switch type {
        case .weekly:
            let startComps = calendar.dateComponents([.month, .day], from: period.start)
            let lastDay    = calendar.date(byAdding: .day, value: -1, to: period.end) ?? period.end
            let endComps   = calendar.dateComponents([.month, .day], from: lastDay)
            let sm = startComps.month ?? 0
            let sd = startComps.day   ?? 0
            let em = endComps.month   ?? 0
            let ed = endComps.day     ?? 0
            return "주간 리포트 (\(sm)월 \(sd)일 - \(em)월 \(ed)일)"
        case .monthly:
            let comps = calendar.dateComponents([.year, .month], from: period.start)
            return "월간 리포트 (\(comps.year ?? 2026)년 \(comps.month ?? 1)월)"
        }
    }

    /// 노션 저장용 카테고리 통계는 예전 그대로: 기록 있는 카테고리만, 완료율 높은 순
    /// (화면은 설정 순서 + 기록 없음 회색까지 보이지만, 노션 본문은 바꾸지 않는다)
    private func notionCategoryStats(_ stats: [CategoryStat]) -> [PeriodReportChartData.CategoryEntry] {
        stats
            .filter(\.hasRecords)
            .sorted { $0.rate > $1.rate }
            .map { .init(name: $0.name, rate: $0.rate, completed: $0.completed, total: $0.total) }
    }
}
