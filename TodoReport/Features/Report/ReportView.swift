import SwiftUI
import Charts

struct ReportView: View {
    @Environment(MainTabCoordinator.self) private var tabCoordinator
    @State private var viewModel = ReportViewModel()
    @State private var daySlide = DaySlide.initial
    private var isPro: Bool { SubscriptionManager.shared.isPro }
    /// 집중 시간 칸·카드 잠금 표시. 구독 확인 전 「Pro 🔒」 깜빡임 방지 (지난번 상태로 먼저 보여 줌)
    private var isProContentLocked: Bool { SubscriptionManager.shared.proDisplayState == .free }

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 16) {
                        if viewModel.isLoading || (viewModel.selectedPeriod == .weekly ? viewModel.weeklyReport == nil : viewModel.monthlyReport == nil) {
                            VStack(spacing: 8) {
                                ProgressView()
                                if viewModel.isLoading && (viewModel.selectedPeriod == .weekly ? viewModel.weeklyReport == nil : viewModel.monthlyReport == nil) {
                                    Text("불러오는 중...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            if viewModel.isSyncing {
                                HStack(spacing: 8) {
                                    ProgressView().scaleEffect(0.85)
                                    Text("노션 동기화 중...")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            content
                                .daySlide(daySlide)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .safeAreaBar(edge: .top, spacing: 0) {
                    DateNavigationRow(
                        title: viewModel.periodTitle,
                        onPrev: { viewModel.goToPreviousPeriod() },
                        onNext: { viewModel.goToNextPeriod() },
                        canGoNext: viewModel.canGoNext
                    )
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
                .refreshable {
                    await viewModel.fetchReportWithNotionSync()
                }
            }
            .edgeSwipeNavigation(
                onPrev: { viewModel.goToPreviousPeriod() },
                onNext: { viewModel.goToNextPeriod() }
            )
            .background(Color(.systemGroupedBackground))
            .navigationTitle("리포트")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("기간", selection: $vm.selectedPeriod) {
                        ForEach(ReportPeriod.allCases, id: \.self) { period in
                            Text(period.localizedTitle).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 172)
                }
            }
            .onAppear { Task { await viewModel.fetchReportWithNotionSync() } }
            .onChange(of: tabCoordinator.reportReselectToken) { _, _ in
                viewModel.goToCurrentPeriod()
            }
            .onChange(of: tabCoordinator.foregroundRefreshToken) { _, _ in
                Task { await viewModel.handleForegroundRefresh() }
            }
            // 기간을 옮겨 새 리포트가 불러와지면 방향에 맞춰 슬라이드 (첫 로드는 제외)
            .onChange(of: viewModel.loadedPeriodOffset) { oldOffset, newOffset in
                guard let oldOffset, let newOffset, oldOffset != newOffset else { return }
                daySlide = daySlide.next(forward: newOffset > oldOffset)
            }
            .onChange(of: viewModel.selectedPeriod) { _, _ in
                viewModel.onPeriodChanged()
            }
            .onChange(of: PlannerService.shared.selectedPlannerId) { _, _ in
                viewModel.onPlannerChanged()
            }
            .sheet(isPresented: $vm.showPaywall, onDismiss: { viewModel.dismissPaywall() }) {
                PaywallView(message: viewModel.paywallMessage)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $vm.showSaveEditor) {
                if let period = viewModel.pendingPeriod {
                    NotionSaveEditorView(
                        reportPeriod: viewModel.selectedPeriod,
                        periodTitle: viewModel.pendingPeriodTitle,
                        period: period,
                        completionRate: viewModel.pendingCompletionRate,
                        avgRating: viewModel.pendingAvgRating,
                        comment: $vm.pendingInitialReview,
                        isLoadingInitialReview: viewModel.isPreparingSave,
                        onConfirm: { comment in
                            Task { await viewModel.confirmSave(comment: comment) }
                        },
                        onCancel: { viewModel.cancelSave() }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            .alert("노션에 연결하시겠습니까?", isPresented: $vm.showNotionConnectAlert) {
                Button("취소", role: .cancel) { viewModel.cancelNotionConnect() }
                Button("연결하기") { viewModel.confirmNotionConnect() }
            } message: {
                Text("노션에 연결하면 리포트를 노션에 저장할 수 있습니다.")
            }
            .sheet(isPresented: $vm.showMigrationSheet) {
                if let planner = PlannerService.shared.selectedPlanner {
                    PlannerMigrationView(planner: planner, mode: .uploadToNotion)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
            .alert("노션 저장 완료", isPresented: $vm.notionSaveSuccess) {
                Button("확인") { viewModel.dismissNotionSaveSuccess() }
            } message: {
                Text("리포트를 노션에 저장했습니다.")
            }
            .alert("저장 실패", isPresented: Binding(
                get: { viewModel.notionSaveError != nil },
                set: { if !$0 { viewModel.dismissSaveError() } }
            )) {
                Button("확인") { viewModel.dismissSaveError() }
            } message: {
                Text(viewModel.notionSaveError ?? "")
            }
        }
    }

    // MARK: - 기간별 콘텐츠

    @ViewBuilder
    private var content: some View {
        switch viewModel.selectedPeriod {
        case .weekly:
            if let report = viewModel.weeklyReport {
                weeklyContent(report)
            }
        case .monthly:
            if let report = viewModel.monthlyReport {
                monthlyContent(report)
            }
        }
    }

    @ViewBuilder
    private func weeklyContent(_ report: WeeklyReportData) -> some View {
        let cal = Calendar.current
        let weekBarRanges: [Range<Date>] = (0..<7).compactMap { i in
            guard let ds = cal.date(byAdding: .day, value: i, to: report.period.start),
                  let de = cal.date(byAdding: .day, value: 1, to: ds) else { return nil }
            return ds..<de
        }

        SummaryCard(
            completionRate: report.completionRate,
            averageRating: report.averageRating,
            focusMinutes: viewModel.timeUsage.completedMinutes,
            isFocusLocked: isProContentLocked
        )
        ExpandableCompletionCard(
            title: "완료율",
            labels: report.dailyCompletionRates.map(\.weekday),
            values: report.dailyCompletionRates.map(\.rate),
            todos: report.todos,
            barRanges: weekBarRanges
        )
        CategoryStatsCard(stats: report.categoryStats)
        TimeUsageCard(summary: viewModel.timeUsage, layout: .weekTimetable, isLocked: isProContentLocked)
        RatingLineChart(
            ratingLabel: RatingLabel.current,
            labels: report.dailyRatings.map(\.weekday),
            values: report.dailyRatings.map(\.rating)
        )
        ReviewTimelineCard(entries: report.reviewTimeline)
        NotionSaveButton(
            isSavingToNotion: viewModel.isSavingToNotion,
            isNotionConnected: viewModel.isNotionConnected,
            isPro: isPro
        ) {
            viewModel.prepareSave()
        }
    }

    private func monthlyBarRanges(for report: MonthlyReportData) -> [Range<Date>] {
        let cal = Calendar.current
        var ranges: [Range<Date>] = []
        var ws = report.period.start
        while ws < report.period.end {
            let we = min(cal.date(byAdding: .day, value: 7, to: ws) ?? report.period.end, report.period.end)
            ranges.append(ws..<we)
            ws = we
        }
        return ranges
    }

    @ViewBuilder
    private func monthlyContent(_ report: MonthlyReportData) -> some View {
        let monthBarRanges = monthlyBarRanges(for: report)

        SummaryCard(
            completionRate: report.completionRate,
            averageRating: report.averageRating,
            focusMinutes: viewModel.timeUsage.completedMinutes,
            isFocusLocked: isProContentLocked
        )
        ExpandableCompletionCard(
            title: "완료율",
            labels: report.weeklyCompletionRates.map(\.label),
            values: report.weeklyCompletionRates.map(\.rate),
            todos: report.todos,
            barRanges: monthBarRanges
        )
        CategoryStatsCard(stats: report.categoryStats)
        TimeUsageCard(summary: viewModel.timeUsage, layout: .bars, isLocked: isProContentLocked, barRanges: monthBarRanges)
        RatingLineChart(
            ratingLabel: RatingLabel.current,
            labels: report.dailyRatings.map(\.weekday),
            values: report.dailyRatings.map(\.rating)
        )
        ReviewTimelineCard(entries: report.reviewTimeline)
        NotionSaveButton(
            isSavingToNotion: viewModel.isSavingToNotion,
            isNotionConnected: viewModel.isNotionConnected,
            isPro: isPro
        ) {
            viewModel.prepareSave()
        }
    }
}

// MARK: - 요약 카드

private struct SummaryCard: View {
    let completionRate: Double
    let averageRating: Double
    /// 집중 시간 = 완료한 타임라인 블록 시간 합 (분)
    let focusMinutes: Int
    let isFocusLocked: Bool

    /// 숫자와 단위를 나눈 조각. 단위는 작게 그린다 (11h48m → [11,h][48,m])
    private typealias ValuePart = (number: String, unit: String)

    /// 집중 시간: 11h48m / 분이 0이면 11h / 1시간 미만이면 45m (`TimeUsageCard.hoursText`와 같은 규칙)
    private var focusParts: [ValuePart] {
        let total = max(focusMinutes, 0)
        let hours = total / 60
        let rest = total % 60
        if hours == 0 { return [(number: String(rest), unit: rest == 0 ? "h" : "m")] }
        if rest == 0 { return [(number: String(hours), unit: "h")] }
        return [(number: String(hours), unit: "h"), (number: String(rest), unit: "m")]
    }

    private var completionParts: [ValuePart] {
        let percent = Int((completionRate * 100).rounded())
        return [(number: percent.formatted(), unit: "%")]
    }

    var body: some View {
        HStack(spacing: 0) {
            summaryItem(
                parts: completionParts,
                label: String(localized: "평균 완료율"),
                color: .primary
            )
            Divider().frame(height: 48)
            summaryItem(
                parts: [(number: String(format: "%.1f", averageRating), unit: "")],
                label: RatingLabel.averageTitle(RatingLabel.current),
                prefix: "⭐",
                color: .primary
            )
            Divider().frame(height: 48)
            summaryItem(
                parts: isFocusLocked ? [(number: "Pro", unit: "")] : focusParts,
                label: String(localized: "집중 시간"),
                symbolName: isFocusLocked ? "lock.fill" : nil,
                symbolColor: .secondary,
                color: isFocusLocked ? .secondary : .primary
            )
        }
        .padding(.vertical, 16)
        .reportCard()
    }

    private func summaryItem(
        parts: [ValuePart],
        label: String,
        prefix: String = "",
        symbolName: String? = nil,
        symbolColor: Color = .primary,
        color: Color
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.subheadline)
                        .foregroundStyle(symbolColor)
                } else if !prefix.isEmpty {
                    Text(prefix).font(.subheadline)
                }
                // 숫자는 크게, 단위(%·h·m)는 작게 → 가로 폭이 줄고 숫자가 눈에 들어온다
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                        Text(verbatim: part.number)
                            .font(.title2.bold())
                            .foregroundStyle(color)
                        if !part.unit.isEmpty {
                            // 단위는 작게·굵게, 색은 숫자보다 조금 연하게 (회색 secondary는 너무 연해 보임)
                            Text(verbatim: part.unit)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(color.opacity(0.7))
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 완료율 막대 그래프 (막대 탭으로 해당 기간 투두 목록)

private struct ExpandableCompletionCard: View {
    let title: LocalizedStringKey
    let labels: [String]
    let values: [Double]
    let todos: [ReportTodoEntry]
    let barRanges: [Range<Date>]

    @State private var selectedBarIndex: Int? = nil

    private var data: [(label: String, value: Double)] {
        zip(labels, values).map { ($0, $1) }
    }

    private func todosFor(barIndex: Int) -> [ReportTodoEntry] {
        guard barIndex < barRanges.count else { return [] }
        let range = barRanges[barIndex]
        return todos.filter { range.contains($0.date) }
    }

    private func barHeader(for barIndex: Int) -> String {
        guard barIndex < barRanges.count else { return "" }
        let range = barRanges[barIndex]
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day ?? 1
        if days <= 1 {
            return AppDateFormat.reportDailyHeader(range.lowerBound)
        } else {
            let end = cal.date(byAdding: .day, value: -1, to: range.upperBound) ?? range.lowerBound
            return AppDateFormat.reportShortRange(from: range.lowerBound, to: end)
        }
    }

    private func barSpansMultipleDays(_ barIndex: Int) -> Bool {
        guard barIndex < barRanges.count else { return false }
        let range = barRanges[barIndex]
        let days = Calendar.current.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day ?? 1
        return days > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title).font(.subheadline.bold())
                    Spacer()
                    if selectedBarIndex != nil {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedBarIndex = nil }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Chart {
                    ForEach(Array(data.enumerated()), id: \.element.label) { idx, item in
                        BarMark(
                            x: .value("기간", item.label),
                            y: .value("완료율", item.value)
                        )
                        .foregroundStyle(
                            selectedBarIndex == idx
                            ? AppTheme.shared.accent
                            : Color(.label).opacity(0.7)
                        )
                        .cornerRadius(4)
                    }
                    RuleMark(y: .value("평균", values.reduce(0, +) / Double(max(values.count, 1))))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0, 0.5, 1.0]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v.formatted(.percent.precision(.fractionLength(0))))
                                    .font(.caption2)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().font(.caption2) }
                }
                .frame(height: 160)
                .chartOverlay { proxy in
                    GeometryReader { _ in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        if let label: String = proxy.value(atX: value.location.x, as: String.self),
                                           let idx = data.firstIndex(where: { $0.label == label }) {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedBarIndex = (selectedBarIndex == idx) ? nil : idx
                                            }
                                        }
                                    }
                            )
                    }
                }
            }
            .padding(16)

            if let idx = selectedBarIndex {
                let barTodos = todosFor(barIndex: idx)
                let incompleteTodos = barTodos.filter { !$0.isCompleted }.sorted { $0.date < $1.date }
                let completedTodos  = barTodos.filter {  $0.isCompleted }.sorted { $0.date < $1.date }
                Divider().padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 10) {
                    Text(barHeader(for: idx))
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    Text("\(barTodos.count)개 중 \(completedTodos.count)개 완료")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if barTodos.isEmpty {
                        Text("이 기간에 기록된 할일이 없습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        // 월간 막대(7일)는 날짜가 섞이니 날짜 표시, 주간 막대(하루)는 생략
                        let showsDate = barSpansMultipleDays(idx)
                        ForEach(incompleteTodos) { todo in
                            ReportTodoRow(todo: todo, showsDate: showsDate) { openTodoFromRow(todo) }
                        }
                        ForEach(completedTodos) { todo in
                            ReportTodoRow(todo: todo, showsDate: showsDate) { openTodoFromRow(todo) }
                        }
                    }
                }
                .padding(16)
                .transition(.opacity)
            }
        }
        .reportCard()
    }
}

// MARK: - 별점 꺾은선 그래프

private struct RatingLineChart: View {
    /// 사용자가 정한 이름 (nil = 기본 「별점」)
    let ratingLabel: String?
    let labels: [String]
    let values: [Double]

    private struct RatedPoint {
        let index: Int
        let value: Double
    }

    private var ratedPoints: [RatedPoint] {
        zip(values.indices, values)
            .filter { $0.1 > 0 }
            .map { RatedPoint(index: $0.0, value: $0.1) }
    }

    private var axisStep: Int { labels.count > 10 ? 5 : 1 }
    private var chartHeight: CGFloat { labels.count > 10 ? 160 : 140 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: RatingLabel.title(ratingLabel))
                .font(.subheadline.bold())

            if ratedPoints.isEmpty {
                Text(verbatim: RatingLabel.emptyText(ratingLabel))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: chartHeight)
            } else {
                Chart {
                    ForEach(Array(ratedPoints.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("인덱스", point.index),
                            y: .value("별점", point.value)
                        )
                        .foregroundStyle(AppTheme.shared.accent)
                        .interpolationMethod(.linear)

                        PointMark(
                            x: .value("인덱스", point.index),
                            y: .value("별점", point.value)
                        )
                        .foregroundStyle(AppTheme.shared.accent)
                        .symbolSize(48)
                    }
                }
                .chartXScale(domain: 0...(max(labels.count - 1, 1)))
                .chartYScale(domain: 1...5)
                .chartXAxis {
                    AxisMarks(values: Array(stride(from: 0, to: labels.count, by: axisStep))) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let i = value.as(Int.self), i < labels.count {
                                Text(labels[i])
                                    .font(.caption2)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                HStack(spacing: 1) {
                                    Text("\(v)")
                                        .font(.caption2)
                                        .foregroundStyle(Color(.secondaryLabel))
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 7))
                                        .foregroundStyle(Color(.systemFill))
                                }
                            }
                        }
                    }
                }
                .frame(height: chartHeight)
            }
        }
        .padding(16)
        .reportCard()
    }
}

// MARK: - 카테고리별 완료율

private struct CategoryStatsCard: View {
    let stats: [CategoryStat]

    /// 막대 / 원형 보기. 앱 전체에 하나로 기억 (기본 막대 — 기존 화면 유지)
    private enum DisplayStyle: String {
        case bar
        case ring
    }

    @AppStorage("reportCategoryStatsStyle") private var styleRaw: String = DisplayStyle.bar.rawValue

    private var style: DisplayStyle {
        DisplayStyle(rawValue: styleRaw) ?? .bar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("카테고리별 완료율")
                    .font(.subheadline.bold())
                Spacer()
                if !stats.isEmpty {
                    styleToggle
                }
            }

            if stats.isEmpty {
                Text("카테고리를 추가하면 완료율을 확인할 수 있습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else if style == .ring {
                CategoryRingGrid(stats: stats)
            } else {
                VStack(spacing: 12) {
                    ForEach(stats) { stat in
                        CategoryStatRow(stat: stat)
                    }
                }
            }
        }
        .padding(16)
        .reportCard()
    }

    /// 노션 보기 전환처럼 작은 아이콘 두 개
    private var styleToggle: some View {
        HStack(spacing: 2) {
            styleButton(.bar, systemImage: "list.bullet", label: String(localized: "막대로 보기"))
            styleButton(.ring, systemImage: "circle.grid.3x3", label: String(localized: "원형으로 보기"))
        }
        .padding(2)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }

    private func styleButton(_ target: DisplayStyle, systemImage: String, label: String) -> some View {
        let isSelected = style == target
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { styleRaw = target.rawValue }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Color.primary : Color(.tertiaryLabel))
                .frame(width: 30, height: 24)
                .background(isSelected ? Color(.secondarySystemGroupedBackground) : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct CategoryStatRow: View {
    let stat: CategoryStat

    @State private var isExpanded = false

    private var incompleteTodos: [ReportTodoEntry] {
        stat.todos.filter { !$0.isCompleted }.sorted { $0.date < $1.date }
    }

    private var completedTodos: [ReportTodoEntry] {
        stat.todos.filter { $0.isCompleted }.sorted { $0.date < $1.date }
    }

    private var iconColor: Color {
        stat.isUncategorized ? Color(.label) : Color(hex: stat.colorHex)
    }

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: CategoryIconName.resolved(stat.icon))
                        .font(.system(size: 12))
                        .foregroundStyle(iconColor)
                        .frame(width: 14, height: 14)
                    Text(stat.name)
                        .font(.subheadline)
                    Spacer()
                    if stat.hasRecords {
                        Text("\(stat.completed)/\(stat.total)개")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(stat.rate.formatted(.percent.precision(.fractionLength(0))))
                            .font(.caption.bold())
                            .foregroundStyle(Color.primary.opacity(0.62))
                            .frame(width: 36, alignment: .trailing)
                    } else {
                        // 이 기간에 할 일이 없는 카테고리 (0%와 구분)
                        Text(verbatim: "–")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                            .frame(width: 36, alignment: .trailing)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(stat.hasRecords ? Color(hex: stat.colorHex).opacity(0.12) : Color(.systemGray5))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: stat.colorHex))
                            .frame(width: geo.size.width * stat.rate, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if stat.todos.isEmpty {
                        Text("이 기간에 기록된 할일이 없습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        // 반복 할 일은 이름이 같아서 날짜로 구분
                        ForEach(incompleteTodos) { todo in
                            ReportTodoRow(todo: todo, showsDate: true) { openTodoFromRow(todo) }
                        }
                        ForEach(completedTodos) { todo in
                            ReportTodoRow(todo: todo, showsDate: true) { openTodoFromRow(todo) }
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
    }
}

/// 리포트 목록 줄 탭 → 투두 탭 그 날짜로 (원형 보기 `CategoryRingGrid`에서도 사용)
func openTodoFromRow(_ entry: ReportTodoEntry) {
    MainTabCoordinator.shared.openTodo(on: entry.date, highlightTodoId: entry.id)
}

/// 리포트 펼친 목록 한 줄 (원형 보기 `CategoryRingGrid`에서도 사용)
struct ReportTodoRow: View {
    let todo: ReportTodoEntry
    /// 줄 끝에 날짜 표시 (여러 날이 섞인 목록에서 같은 이름의 반복 할 일 구분)
    var showsDate: Bool = false
    var onOpenTodo: (() -> Void)? = nil

    var body: some View {
        if let onOpenTodo {
            Button(action: onOpenTodo) {
                rowContent
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(todo.isCompleted ? AppTheme.shared.accent.opacity(0.55) : Color(.tertiaryLabel))
            Text(todo.title)
                .font(.subheadline)
                .foregroundStyle(todo.isCompleted ? Color(.secondaryLabel) : .primary)
                .strikethrough(todo.isCompleted, color: Color(.secondaryLabel))
            Spacer()
            if showsDate {
                Text(verbatim: AppDateFormat.reportTodoRow(todo.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

// MARK: - 하루 리뷰 타임라인

private struct ReviewTimelineCard: View {
    let entries: [ReviewTimelineEntry]

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("하루 리뷰")
                    .font(.subheadline.bold())
                Spacer()
                if !entries.isEmpty {
                    Group {
                        if isExpanded {
                            Text("접기")
                        } else {
                            Text("\(entries.count)일 보기")
                        }
                    }
                        .font(.caption)
                        .foregroundStyle(AppTheme.shared.accent)
                }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !entries.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            }

            if entries.isEmpty {
                Text("리뷰를 작성한 날이 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 16)
            } else if isExpanded {
                Divider().padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                        timelineRow(entry)
                        if idx < entries.count - 1 {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .reportCard()
    }

    private func timelineRow(_ entry: ReviewTimelineEntry) -> some View {
        ReviewTimelineRow(entry: entry) {
            openTodoFromReview(on: entry.date)
        }
    }

    private func openTodoFromReview(on date: Date) {
        MainTabCoordinator.shared.openTodo(on: date)
    }
}

// MARK: - 하루 리뷰 타임라인 행 (날짜 탭 → 투두)

private struct ReviewTimelineRow: View {
    let entry: ReviewTimelineEntry
    let onOpenTodo: () -> Void

    @State private var isExpanded = false
    @State private var truncatedHeight: CGFloat = 0
    @State private var fullHeight: CGFloat = 0

    private var isTruncated: Bool {
        fullHeight > truncatedHeight + 0.5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onOpenTodo) {
                HStack(spacing: 6) {
                    Text(AppDateFormat.reviewTimeline(entry.date))
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    if entry.rating > 0 {
                        PawRatingView(rating: Int(entry.rating), size: 10, spacing: 3)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(entry.review)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(isExpanded ? nil : 3)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(alignment: .topLeading) {
                    Text(entry.review)
                        .font(.subheadline)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { truncatedHeight = $0 }
                }
                .background(alignment: .topLeading) {
                    Text(entry.review)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { fullHeight = $0 }
                }

            if isTruncated {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Group {
                            if isExpanded {
                                Text("접기")
                            } else {
                                Text("더보기")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(AppTheme.shared.accent)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color(.tertiaryLabel))
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(16)
    }
}

// MARK: - 노션에 저장하기 버튼

private struct NotionSaveButton: View {
    let isSavingToNotion: Bool
    let isNotionConnected: Bool
    let isPro: Bool
    let action: () -> Void

    private var isActive: Bool { !isSavingToNotion && isNotionConnected && isPro }

    private var buttonLabel: String {
        if isSavingToNotion { return String(localized: "저장 중...") }
        return String(localized: "노션에 리포트 저장하기")
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSavingToNotion {
                    ProgressView()
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: isNotionConnected ? "square.and.arrow.up" : "lock.circle")
                        .font(.subheadline)
                        .foregroundStyle(isActive ? AppTheme.shared.accent : .secondary)
                }
                HStack(spacing: 6) {
                    Text(buttonLabel)
                        .font(.subheadline.bold())
                        .foregroundStyle(isActive ? AppTheme.shared.accent : .secondary)
                    ProBadge()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isActive ? AppTheme.shared.accent.opacity(0.4) : Color(.separator), lineWidth: 0.5)
            )
        }
        .disabled(isSavingToNotion)
    }
}


// MARK: - 카드 스타일 ViewModifier

extension View {
    /// 리포트 카드 공통 모양 (TimeUsageCard 등 다른 파일에서도 사용)
    func reportCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(.separator), lineWidth: 0.5)
            )
    }
}

