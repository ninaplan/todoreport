import Charts
import SwiftUI

/// 리포트 「집중한 시간」: 타임블록에서 완료한 블록 시간을 카테고리 색으로 돌아본다.
/// - 주간: 일주일 시간표 (요일 칸 × 시각). 완료한 블록은 진하게, 못 한 블록은 연한 테두리 → 언제 무엇에 집중했는지 한눈에
/// - 월간: 완료율 그래프와 같은 모양의 막대 (주별, 카테고리 색으로 쌓기)
/// 카테고리 색은 하루 타임라인이 아니라 여기(돌아보기)에서 주로 쓴다.
struct TimeUsageCard: View {
    enum Layout {
        case weekTimetable
        case bars
    }

    let summary: TimeBlockUsageSummary
    let layout: Layout
    let isLocked: Bool
    /// 막대 구간 날짜 (월간 막대 탭 시 기간 표시). 완료율 그래프와 같은 구간
    var barRanges: [Range<Date>] = []

    /// 월간 막대에서 탭한 주 (완료율 그래프처럼 다시 탭하거나 ✕로 닫기)
    @State private var selectedBarIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("집중한 시간")
                    .font(.subheadline.bold())
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
                    .accessibilityLabel(Text("닫기"))
                }
            }

            if isLocked {
                lockedMessage
            } else if !summary.hasBlocks {
                Text("타임블록에서 시간 블록을 만들고 완료하면 여기에 모입니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                switch layout {
                case .weekTimetable:
                    WeekTimetable(summary: summary)
                case .bars:
                    bars
                }
                Divider()
                if let index = selectedBarIndex, index < summary.buckets.count {
                    selectedBucketList(summary.buckets[index], index: index)
                        .transition(.opacity)
                } else {
                    categoryList
                }
            }
        }
        .padding(16)
        .reportCard()
        // 기간을 넘기면 선택 해제
        .onChange(of: summary) { _, _ in selectedBarIndex = nil }
    }

    private var lockedMessage: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundStyle(AppTheme.shared.accent)
            Text("타임블록으로 계획하고 완료한 시간을 카테고리별로 돌아봅니다. Pro 기능입니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 월간 막대 (완료율 그래프와 같은 모양: 검정 70%, 탭하면 포인트 컬러, 평균 점선)

    private var averageHours: Double {
        let totals = summary.buckets.map { Double($0.totalMinutes) / 60 }
        return totals.reduce(0, +) / Double(max(totals.count, 1))
    }

    private var bars: some View {
        Chart {
            ForEach(Array(summary.buckets.enumerated()), id: \.element.id) { index, bucket in
                BarMark(
                    x: .value("기간", bucket.label),
                    y: .value("시간", Double(bucket.totalMinutes) / 60)
                )
                .foregroundStyle(
                    selectedBarIndex == index
                    ? AppTheme.shared.accent
                    : Color(.label).opacity(0.7)
                )
                .cornerRadius(4)
            }
            RuleMark(y: .value("평균", averageHours))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        // 기록 없는 주도 칸은 남긴다
        .chartXScale(domain: summary.buckets.map(\.label))
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text(verbatim: Self.hoursText(Int((hours * 60).rounded())))
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
                                   let index = summary.buckets.firstIndex(where: { $0.label == label }) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedBarIndex = (selectedBarIndex == index) ? nil : index
                                    }
                                }
                            }
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: summary.buckets
            .map { "\($0.label) \(Self.hoursText($0.totalMinutes))" }
            .joined(separator: ", ")))
    }

    // MARK: - 탭한 주의 카테고리별 시간

    private func selectedBucketList(_ bucket: TimeBlockUsageSummary.Bucket, index: Int) -> some View {
        let completedById = Dictionary(bucket.segments.map { ($0.id, $0.minutes) }, uniquingKeysWith: +)
        let rows = summary.categories.filter {
            (completedById[$0.id] ?? 0) > 0 || (bucket.plannedMinutesByCategory[$0.id] ?? 0) > 0
        }
        return VStack(alignment: .leading, spacing: 10) {
            Text(rangeHeader(for: index) ?? bucket.label)
                .font(.caption.bold())
            if rows.isEmpty {
                Text("이 기간에 기록된 블록이 없습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
                    ForEach(rows) { category in
                        categoryRow(
                            name: category.name,
                            colorHex: category.colorHex,
                            completedMinutes: completedById[category.id] ?? 0,
                            plannedMinutes: bucket.plannedMinutesByCategory[category.id] ?? 0
                        )
                    }
                }
            }
        }
    }

    /// 완료율 그래프와 같은 기간 표시
    private func rangeHeader(for index: Int) -> String? {
        guard index < barRanges.count else { return nil }
        let range = barRanges[index]
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day ?? 1
        guard days > 1 else { return AppDateFormat.reportDailyHeader(range.lowerBound) }
        let end = calendar.date(byAdding: .day, value: -1, to: range.upperBound) ?? range.lowerBound
        return AppDateFormat.reportShortRange(from: range.lowerBound, to: end)
    }

    // MARK: - 카테고리별 시간

    private var categoryList: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
            ForEach(summary.categories) { category in
                categoryRow(
                    name: category.name,
                    colorHex: category.colorHex,
                    completedMinutes: category.completedMinutes,
                    plannedMinutes: category.plannedMinutes
                )
            }
        }
    }

    /// Grid 한 줄: [점·이름] [집중 시간] [계획]. 시간 두 칸은 각각 오른쪽 끝을 맞춰 줄끼리 정렬된다
    private func categoryRow(name: String, colorHex: String, completedMinutes: Int, plannedMinutes: Int) -> some View {
        GridRow {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(Self.durationText(completedMinutes))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .gridColumnAlignment(.trailing)
            Text(String(localized: "계획 \(Self.durationText(plannedMinutes))"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .gridColumnAlignment(.trailing)
        }
    }

    /// 한국어는 「12시간 9분」 그대로, 그 외 언어는 짧게 「12h 9m」 (영어 「12 hr, 9 min」이 길어 잘렸음)
    static func durationText(_ minutes: Int) -> String {
        let isKorean = Locale.autoupdatingCurrent.language.languageCode?.identifier == "ko"
        return Duration.seconds(minutes * 60).formatted(
            .units(allowed: [.hours, .minutes], width: isKorean ? .abbreviated : .narrow)
        )
    }

    /// 11h30m 처럼 짧게 (소수 6.8h는 헷갈려서 시·분으로). 언어와 무관하게 h·m
    /// 분이 0이면 11h, 1시간 미만이면 45m, 0이면 0h
    static func hoursText(_ minutes: Int) -> String {
        let total = max(minutes, 0)
        let hours = total / 60
        let rest = total % 60
        if hours == 0 { return rest == 0 ? "0h" : "\(rest)m" }
        return rest == 0 ? "\(hours)h" : "\(hours)h\(rest)m"
    }
}

// MARK: - 주간 시간표

/// 요일 7칸 × 시각. 그 주 블록이 있는 시간대만 세로로 보여준다 (빈 새벽 생략).
/// 칸 아래는 그날 집중 시간 합계.
private struct WeekTimetable: View {
    let summary: TimeBlockUsageSummary

    private static let gridHeight: CGFloat = 240
    private static let axisWidth: CGFloat = 30
    private static let columnSpacing: CGFloat = 4
    /// 세로 범위가 너무 짧으면 블록이 길쭉하게 커 보여서 최소 6시간
    private static let minimumSpanMinutes = 6 * 60
    private static let axisStepHours = 3

    /// 세로 범위 (정각 단위). 다음 날 새벽 블록(1440 초과)도 그대로 아래에 이어진다
    private var minuteRange: ClosedRange<Int> {
        let starts = summary.blocks.map(\.startMinute)
        let ends = summary.blocks.map(\.endMinute)
        var lower = ((starts.min() ?? 9 * 60) / 60) * 60
        var upper = (((ends.max() ?? 18 * 60) + 59) / 60) * 60
        if upper - lower < Self.minimumSpanMinutes {
            let missing = Self.minimumSpanMinutes - (upper - lower)
            lower = max(lower - missing / 2, 0)
            upper = lower + Self.minimumSpanMinutes
        }
        return lower...upper
    }

    private var pointsPerMinute: CGFloat {
        Self.gridHeight / CGFloat(max(minuteRange.upperBound - minuteRange.lowerBound, 1))
    }

    /// 세로축 시각: 3시간 간격 정각
    private var axisHours: [Int] {
        let first = (minuteRange.lowerBound / 60 + Self.axisStepHours - 1) / Self.axisStepHours * Self.axisStepHours
        let last = minuteRange.upperBound / 60
        guard first <= last else { return [] }
        return Array(stride(from: first, through: last, by: Self.axisStepHours))
    }

    private func y(_ minute: Int) -> CGFloat {
        CGFloat(minute - minuteRange.lowerBound) * pointsPerMinute
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                axis
                columns
            }
            .frame(height: Self.gridHeight)
            footer
        }
        .padding(.top, 6)
    }

    private var axis: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(axisHours, id: \.self) { hour in
                TimeBlockHourLabel(hour: hour, isCompact: true)
                    .frame(width: Self.axisWidth, alignment: .trailing)
                    .offset(y: y(hour * 60) - 6)
            }
        }
        .frame(width: Self.axisWidth, height: Self.gridHeight, alignment: .topTrailing)
        .accessibilityHidden(true)
    }

    private var columns: some View {
        ZStack(alignment: .topLeading) {
            // 가로 눈금선 (완료율 그래프의 AxisGridLine과 같은 느낌)
            ForEach(axisHours, id: \.self) { hour in
                Rectangle()
                    .fill(Color(.separator).opacity(0.5))
                    .frame(height: 0.5)
                    .offset(y: y(hour * 60))
            }
            HStack(alignment: .top, spacing: Self.columnSpacing) {
                ForEach(summary.buckets) { bucket in
                    column(for: bucket)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: Self.gridHeight, alignment: .topLeading)
    }

    private func column(for bucket: TimeBlockUsageSummary.Bucket) -> some View {
        let blocks = summary.blocks.filter { $0.bucketIndex == bucket.id }
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(.tertiarySystemFill).opacity(0.5))
            ForEach(blocks) { block in
                blockShape(block)
                    .frame(height: max(CGFloat(block.endMinute - block.startMinute) * pointsPerMinute - 1, 2))
                    .offset(y: y(block.startMinute) + 0.5)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.gridHeight, alignment: .top)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(bucket.label), \(TimeUsageCard.hoursText(bucket.totalMinutes))"))
    }

    /// 완료 = 카테고리 색으로 채움, 못 한 블록 = 연한 테두리만 (계획 대비 실제)
    @ViewBuilder
    private func blockShape(_ block: TimeBlockUsageSummary.PlacedBlock) -> some View {
        let color = Color(hex: block.colorHex)
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
        if block.isCompleted {
            shape.fill(color)
        } else {
            shape
                .fill(color.opacity(0.08))
                .overlay(shape.strokeBorder(color.opacity(0.55), lineWidth: 1))
        }
    }

    /// 요일 아래 집중 시간 글자 기울기·칸 높이 (기울이면 높이가 늘어 겹치지 않게 칸을 키움)
    private static let footerLabelAngle: Double = -35
    private static let footerLabelHeight: CGFloat = 24

    /// 요일 + 그날 합계
    private var footer: some View {
        HStack(alignment: .top, spacing: 6) {
            Color.clear.frame(width: Self.axisWidth, height: 1)
            HStack(spacing: Self.columnSpacing) {
                ForEach(summary.buckets) { bucket in
                    VStack(spacing: 2) {
                        Text(bucket.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        // 글자끼리 붙어 보여서 사선으로 기울이고 한 단계 연하게 (「–」는 그대로)
                        Text(verbatim: bucket.totalMinutes > 0 ? TimeUsageCard.hoursText(bucket.totalMinutes) : "–")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(bucket.totalMinutes > 0 ? Color(.secondaryLabel) : Color(.tertiaryLabel))
                            .fixedSize()
                            .rotationEffect(.degrees(bucket.totalMinutes > 0 ? Self.footerLabelAngle : 0))
                            .frame(height: Self.footerLabelHeight)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
