import SwiftUI
import Charts

struct ReportView: View {
    @State private var viewModel = ReportViewModel()
    #if DEBUG
    @AppStorage("debugIsPro") private var debugIsPro = false
    private var isPro: Bool { debugIsPro }
    #else
    private let isPro = false
    #endif

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    periodHeader
                    if viewModel.isLoading {
                        VStack(spacing: 10) {
                            ProgressView()
                            if viewModel.isSyncing {
                                Text("노션에서 자료를 읽어오고 있습니다.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        content
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("리포트")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("기간", selection: $vm.selectedPeriod) {
                        ForEach(ReportPeriod.allCases, id: \.self) { period in
                            Text(period == .monthly && !isPro ? "월간 🔒" : period.rawValue)
                                .tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 172)
                }
            }
            .task { await viewModel.fetchReport() }
            .onChange(of: viewModel.selectedPeriod) { _, _ in
                viewModel.onPeriodChanged()
            }
            .sheet(isPresented: $vm.showPaywall) {
                ProPaywallSheet(
                    message: viewModel.paywallMessage,
                    onDismiss: { viewModel.dismissPaywall() }
                )
                .presentationDetents([.medium])
            }
            .alert("노션 저장 완료", isPresented: $vm.notionSaveSuccess) {
                Button("확인") { viewModel.dismissNotionSaveSuccess() }
            } message: {
                Text("이번 주 리포트를 노션에 저장했습니다.")
            }
        }
    }

    // MARK: - 기간 헤더

    private var periodHeader: some View {
        HStack(spacing: 0) {
            Button {
                viewModel.goToPreviousPeriod()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 36)
                    .contentShape(Rectangle())
            }

            Text(viewModel.periodTitle)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .center)

            Button {
                viewModel.goToNextPeriod()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(viewModel.canGoNext ? .secondary : Color(.quaternaryLabel))
                    .frame(width: 40, height: 36)
                    .contentShape(Rectangle())
            }
            .disabled(!viewModel.canGoNext)
        }
        .padding(.top, 4)
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
        SummaryCard(
            completionRate: report.completionRate,
            averageRating: report.averageRating,
            streakDays: report.streakDays
        )
        CompletionBarChart(
            title: "완료율",
            labels: report.dailyCompletionRates.map(\.weekday),
            values: report.dailyCompletionRates.map(\.rate)
        )
        RatingLineChart(
            title: "별점",
            labels: report.dailyRatings.map(\.weekday),
            values: report.dailyRatings.map(\.rating)
        )
        CategoryStatsCard(stats: report.categoryStats)
        NotionSaveButton(isSaving: viewModel.isSavingToNotion) {
            Task { await viewModel.saveWeeklyToNotion() }
        }
    }

    @ViewBuilder
    private func monthlyContent(_ report: MonthlyReportData) -> some View {
        SummaryCard(
            completionRate: report.completionRate,
            averageRating: report.averageRating,
            streakDays: report.streakDays
        )
        CompletionBarChart(
            title: "완료율",
            labels: report.weeklyCompletionRates.map(\.label),
            values: report.weeklyCompletionRates.map(\.rate)
        )
        RatingLineChart(
            title: "별점",
            labels: report.weeklyRatings.map(\.label),
            values: report.weeklyRatings.map(\.rating)
        )
        CategoryStatsCard(stats: report.categoryStats)
        NotionSaveButton(isSaving: false) {
            Task { await viewModel.saveWeeklyToNotion() }
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
                color: AppTheme.shared.accent
            )
            Divider().frame(height: 48)
            summaryItem(
                value: String(format: "%.1f", averageRating),
                label: "별점 평균",
                prefix: "⭐",
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
        color: Color
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                if !prefix.isEmpty {
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

// MARK: - 완료율 막대 그래프

private struct CompletionBarChart: View {
    let title: String
    let labels: [String]
    let values: [Double]

    private var data: [(label: String, value: Double)] {
        zip(labels, values).map { ($0, $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.bold())

            Chart {
                ForEach(data, id: \.label) { item in
                    BarMark(
                        x: .value("기간", item.label),
                        y: .value("완료율", item.value)
                    )
                    .foregroundStyle(AppTheme.shared.accent.gradient)
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
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .frame(height: 160)
        }
        .padding(16)
        .reportCard()
    }
}

// MARK: - 별점 꺾은선 그래프

private struct RatingLineChart: View {
    let title: String
    let labels: [String]
    let values: [Double]

    private var data: [(label: String, value: Double)] {
        zip(labels, values).map { ($0, $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.bold())

            Chart {
                ForEach(data, id: \.label) { item in
                    LineMark(
                        x: .value("기간", item.label),
                        y: .value("별점", item.value)
                    )
                    .foregroundStyle(AppTheme.shared.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("기간", item.label),
                        y: .value("별점", item.value)
                    )
                    .foregroundStyle(AppTheme.shared.accent)
                    .symbolSize(36)

                    AreaMark(
                        x: .value("기간", item.label),
                        y: .value("별점", item.value)
                    )
                    .foregroundStyle(AppTheme.shared.accent.opacity(0.08).gradient)
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: 1...5)
            .chartYAxis {
                AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)⭐")
                                .font(.caption2)
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .frame(height: 140)
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

// MARK: - 노션에 저장하기 버튼

private struct NotionSaveButton: View {
    let isSaving: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "arrow.up.circle")
                        .font(.subheadline)
                }
                Text(isSaving ? "저장 중..." : "노션에 저장하기")
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(isSaving ? Color(.tertiaryLabel) : AppTheme.shared.accent)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSaving ? Color(.separator) : AppTheme.shared.accent.opacity(0.4), lineWidth: 0.5)
            )
        }
        .disabled(isSaving)
    }
}

// MARK: - Pro 페이월 시트

struct ProPaywallSheet: View {
    let message: String
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(AppTheme.shared.accent)

                Text("Pro 기능")
                    .font(.title3.bold())

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    // TODO: StoreKit 연동
                } label: {
                    Text("Pro로 업그레이드")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(AppTheme.shared.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button("닫기") {
                    onDismiss()
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.horizontal, 16)
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
