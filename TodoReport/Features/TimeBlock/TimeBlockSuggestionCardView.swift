import SwiftUI

/// 제안 블록 카드 — 점선 테두리 + 흐린 글자 + 반복 아이콘 (투두 탭 「예정」 줄과 같은 느낌).
/// 체크·길이 조절·이동 없음. 탭만 받는다.
struct TimeBlockSuggestionCardView: View {
    let suggestion: TimeBlockSuggestion
    let day: Date
    let endMinute: Int
    var pointsPerMinute: CGFloat = TimeBlockLayout.pointsPerMinute
    var onTap: () -> Void = {}

    private static let cornerRadius: CGFloat = 12

    private var height: CGFloat {
        max(CGFloat(endMinute - suggestion.startMinute) * pointsPerMinute - TimeBlockLayout.blockGap, 2)
    }

    /// 블록 카드와 같은 기준: 40pt 미만은 여백을 줄인 작은 모양, 15pt 미만은 테두리만
    private var isCompact: Bool { height < 40 }
    private var isTiny: Bool { height < 15 }

    private var startText: String {
        TimeBlockLayout.date(day: day, minute: suggestion.startMinute)
            .formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        Button(action: onTap) {
            content
                .frame(maxWidth: .infinity, minHeight: 0, alignment: .topLeading)
                .frame(height: height, alignment: .topLeading)
                .background {
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground).opacity(0.45))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                        .strokeBorder(Color(.tertiaryLabel), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(suggestion.title), \(String(localized: "제안 블록")), \(startText)"))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var content: some View {
        if isTiny {
            Color.clear
        } else {
            HStack(spacing: 6) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: isCompact ? 12 : 17))
                    .foregroundStyle(Color(.tertiaryLabel))
                // 투두 탭 「예정」 줄과 같이 제목 끝에 반복 아이콘 (NBSP로 줄바꿈 방지)
                Text("\(Text(verbatim: suggestion.title))\u{00A0}\(Text(Image(systemName: "arrow.triangle.2.circlepath")).font(isCompact ? .caption2 : .footnote).baselineOffset(1))")
                    // 작은 모양은 진짜 블록 카드와 같은 caption (15분 블록에서 잘리지 않게)
                    .font(isCompact ? .caption : .body)
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(startText)
                    .font(isCompact ? .caption2 : .caption)
                    .foregroundStyle(Color(.tertiaryLabel))
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, isCompact ? 2 : 8)
            .frame(maxHeight: isCompact ? .infinity : nil, alignment: .center)
        }
    }
}
