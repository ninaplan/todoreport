import SwiftUI
import Charts

struct ReportView: View {
    @Environment(MainTabCoordinator.self) private var tabCoordinator
    @State private var viewModel = ReportViewModel()
    @State private var reportScrollOffset: CGFloat = 52
    @State private var showReviewTodoRestrictedAlert = false
    @State private var showReviewTodoProPaywall = false
    private var isPro: Bool { SubscriptionManager.shared.isPro }

    private var reportArrowBgOpacity: Double {
        let scrolled = max(0, 52 - reportScrollOffset)
        return Double(min(scrolled / 30, 1))
    }

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 16) {
                        Color.clear
                            .frame(height: 0)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: geo.frame(in: .named("reportScroll")).minY
                                    )
                                }
                            )
                        if viewModel.isLoading || (viewModel.selectedPeriod == .weekly ? viewModel.weeklyReport == nil : viewModel.monthlyReport == nil) {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            if viewModel.isSyncing {
                                HStack(spacing: 6) {
                                    ProgressView().scaleEffect(0.75)
                                    Text("노션 동기화 중...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            content
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 52)
                    .padding(.bottom, 32)
                }
                .coordinateSpace(.named("reportScroll"))
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { y in
                    reportScrollOffset = y
                }
                .refreshable {
                    await viewModel.fetchReportWithNotionSync()
                }

                DateNavigationRow(
                    title: viewModel.periodTitle,
                    onPrev: { viewModel.goToPreviousPeriod() },
                    onNext: { viewModel.goToNextPeriod() },
                    canGoNext: viewModel.canGoNext,
                    arrowBgOpacity: reportArrowBgOpacity
                )
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("리포트")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("기간", selection: $vm.selectedPeriod) {
                        ForEach(ReportPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 172)
                }
            }
            .onAppear { Task { await viewModel.fetchReportWithNotionSync() } }
            .onChange(of: tabCoordinator.foregroundRefreshToken) { _, _ in
                Task { await viewModel.handleForegroundRefresh() }
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
            .alert("투두 화면 이동", isPresented: $showReviewTodoRestrictedAlert) {
                Button("Pro 알아보기") { showReviewTodoProPaywall = true }
                Button("확인", role: .cancel) {}
            } message: {
                Text("어제·오늘·내일만 투두 화면으로 이동할 수 있어요. 다른 날은 Pro에서 확인할 수 있습니다.")
            }
            .sheet(isPresented: $showReviewTodoProPaywall) {
                PaywallView(message: "다른 날 투두 확인은 Pro 기능이에요")
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
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
            streakDays: report.streakDays
        )
        ExpandableCompletionCard(
            title: "완료율",
            labels: report.dailyCompletionRates.map(\.weekday),
            values: report.dailyCompletionRates.map(\.rate),
            todos: report.todos,
            barRanges: weekBarRanges
        )
        RatingLineChart(
            title: "별점",
            labels: report.dailyRatings.map(\.weekday),
            values: report.dailyRatings.map(\.rating)
        )
        CategoryStatsCard(stats: report.categoryStats)
        ReviewTimelineCard(
            entries: report.reviewTimeline,
            onRestrictedDateTap: { showReviewTodoRestrictedAlert = true }
        )
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
            streakDays: report.streakDays
        )
        ExpandableCompletionCard(
            title: "완료율",
            labels: report.weeklyCompletionRates.map(\.label),
            values: report.weeklyCompletionRates.map(\.rate),
            todos: report.todos,
            barRanges: monthBarRanges
        )
        RatingLineChart(
            title: "별점",
            labels: report.dailyRatings.map(\.weekday),
            values: report.dailyRatings.map(\.rating)
        )
        CategoryStatsCard(stats: report.categoryStats)
        ReviewTimelineCard(
            entries: report.reviewTimeline,
            onRestrictedDateTap: { showReviewTodoRestrictedAlert = true }
        )
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
    let streakDays: Int

    var body: some View {
        HStack(spacing: 0) {
            summaryItem(
                value: "\(Int(completionRate * 100))%",
                label: "평균 완료율",
                color: .primary
            )
            Divider().frame(height: 48)
            summaryItem(
                value: String(format: "%.1f", averageRating),
                label: "별점 평균",
                symbolName: "star.fill",
                symbolColor: Color(.systemFill),
                color: .primary
            )
            Divider().frame(height: 48)
            summaryItem(
                value: "\(streakDays)일",
                label: "연속 달성",
                prefix: "🔥",
                color: .primary
            )
        }
        .padding(.vertical, 16)
        .reportCard()
    }

    private func summaryItem(
        value: String,
        label: String,
        prefix: String = "",
        symbolName: String? = nil,
        symbolColor: Color = .primary,
        color: Color
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.subheadline)
                        .foregroundStyle(symbolColor)
                } else if !prefix.isEmpty {
                    Text(prefix).font(.subheadline)
                }
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(color)
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
    let title: String
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
            return Self.dailyHeaderFmt.string(from: range.lowerBound)
        } else {
            let end = cal.date(byAdding: .day, value: -1, to: range.upperBound) ?? range.lowerBound
            return "\(Self.shortDateFmt.string(from: range.lowerBound)) ~ \(Self.shortDateFmt.string(from: end))"
        }
    }

    private static let dailyHeaderFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy.MM.dd EEEE"
        return f
    }()

    private static let shortDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()

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
                                Text("\(Int(v * 100))%")
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
                        ForEach(incompleteTodos) { todo in todoRow(todo) }
                        ForEach(completedTodos)  { todo in todoRow(todo) }
                    }
                }
                .padding(16)
                .transition(.opacity)
            }
        }
        .reportCard()
    }

    private func todoRow(_ todo: ReportTodoEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(todo.isCompleted ? AppTheme.shared.accent : Color(.tertiaryLabel))
            Text(todo.title)
                .font(.subheadline)
                .foregroundStyle(todo.isCompleted ? Color(.secondaryLabel) : .primary)
                .strikethrough(todo.isCompleted, color: Color(.secondaryLabel))
            Spacer()
        }
    }
}

// MARK: - 별점 꺾은선 그래프

private struct RatingLineChart: View {
    let title: String
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
            Text(title)
                .font(.subheadline.bold())

            if ratedPoints.isEmpty {
                Text("별점 데이터가 없습니다.")
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

// MARK: - 카테고리별 달성률

private struct CategoryStatsCard: View {
    let stats: [CategoryStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("카테고리별 달성률")
                .font(.subheadline.bold())

            if stats.isEmpty {
                Text("카테고리를 추가하면 달성률을 확인할 수 있습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
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
}

private struct CategoryStatRow: View {
    let stat: CategoryStat

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Circle()
                    .fill(Color(hex: stat.colorHex))
                    .frame(width: 8, height: 8)
                Text(stat.name)
                    .font(.subheadline)
                Spacer()
                Text("\(stat.completed)/\(stat.total)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Int(stat.rate * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(Color(hex: stat.colorHex))
                    .frame(width: 36, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: stat.colorHex).opacity(0.12))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: stat.colorHex))
                        .frame(width: geo.size.width * stat.rate, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - 하루 리뷰 타임라인

private struct ReviewTimelineCard: View {
    let entries: [ReviewTimelineEntry]
    var onRestrictedDateTap: (() -> Void)?

    @State private var isExpanded = false

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("하루 리뷰")
                    .font(.subheadline.bold())
                Spacer()
                if !entries.isEmpty {
                    Text(isExpanded ? "접기" : "\(entries.count)일 보기")
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
        ReviewTimelineRow(entry: entry, dateFmt: Self.dateFmt) {
            openTodoFromReview(on: entry.date)
        }
    }

    private func openTodoFromReview(on date: Date) {
        if TodoDateAccess.canView(date: date, isPro: SubscriptionManager.shared.isPro) {
            MainTabCoordinator.shared.openTodo(on: date)
        } else {
            onRestrictedDateTap?()
        }
    }
}

// MARK: - 하루 리뷰 타임라인 행 (날짜 탭 → 투두)

private struct ReviewTimelineRow: View {
    let entry: ReviewTimelineEntry
    let dateFmt: DateFormatter
    let onOpenTodo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onOpenTodo) {
                HStack(spacing: 6) {
                    Text(dateFmt.string(from: entry.date))
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    if entry.rating > 0 {
                        PawRatingView(rating: Int(entry.rating), size: 10, spacing: 2)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(entry.review)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
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
        if isSavingToNotion { return "저장 중..." }
        return "노션에 리포트 저장하기"
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

private extension View {
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

