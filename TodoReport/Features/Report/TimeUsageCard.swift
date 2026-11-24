import SwiftUI

/// 리포트 「시간 사용」: 타임라인에서 완료한 블록 시간을 카테고리 색으로 쌓은 막대 + 카테고리별 시간.
/// 카테고리 색은 하루 타임라인이 아니라 여기(돌아보기)에서 주로 쓴다.
struct TimeUsageCard: View {
    let summary: TimeBlockUsageSummary
    let isLocked: Bool

    private static let chartHeight: CGFloat = 110

    private var maxBucketMinutes: Int {
        max(summary.buckets.map(\.totalMinutes).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("시간 사용")
                .font(.subheadline.bold())

            if isLocked {
                lockedMessage
            } else if !summary.hasBlocks {
                Text("타임라인에서 시간 블록을 만들고 완료하면 여기에 모입니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                stackedBars
                Divider()
                categoryList
            }
        }
        .padding(16)
        .reportCard()
    }

    private var lockedMessage: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundStyle(AppTheme.shared.accent)
            Text("타임라인으로 계획하고 완료한 시간을 카테고리별로 돌아봅니다. Pro 기능입니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 막대 (완료한 시간, 카테고리 색으로 쌓기)

    private var stackedBars: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(summary.buckets) { bucket in
                VStack(spacing: 6) {
                    VStack(spacing: 1) {
                        Spacer(minLength: 0)
                        // 위에서 아래로 그리므로 역순 → 많이 쓴 카테고리가 아래
                        ForEach(bucket.segments.reversed()) { segment in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color(hex: segment.colorHex))
                                .frame(height: barHeight(segment.minutes))
                        }
                        if bucket.segments.isEmpty {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: 3)
                        }
                    }
                    .frame(height: Self.chartHeight)
                    Text(bucket.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(bucket.label), \(Self.durationText(bucket.totalMinutes))"))
            }
        }
    }

    private func barHeight(_ minutes: Int) -> CGFloat {
        max(CGFloat(minutes) / CGFloat(maxBucketMinutes) * Self.chartHeight, 2)
    }

    // MARK: - 카테고리별 시간

    private var categoryList: some View {
        VStack(spacing: 10) {
            ForEach(summary.categories) { category in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: category.colorHex))
                        .frame(width: 8, height: 8)
                    Text(category.name)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(Self.durationText(category.completedMinutes))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Text(String(localized: "계획 \(Self.durationText(category.plannedMinutes))"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    static func durationText(_ minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
