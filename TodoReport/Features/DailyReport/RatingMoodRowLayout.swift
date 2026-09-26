import SwiftUI

/// 별점 라벨, 별, 저장 표시, 기분 칩을 한 줄에 둔다.
/// 자식 순서: 라벨, 별, 저장 표시, 칩.
/// 줄 높이는 캡션·24pt·저장 표시 중 큰 값이다. 칩이 없어도 같다.
/// EmptyView는 레이아웃 자식에서 빠지므로, 칩 없음은 자식 3개다.
struct RatingMoodRowLayout: Layout {
    static let minimumHeight: CGFloat = 24
    var gap: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? plan(total: .infinity, subviews: subviews).used
        let resolved = plan(total: width, subviews: subviews)
        let rowWidth = proposal.width ?? resolved.used
        return CGSize(width: rowWidth, height: resolved.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let resolved = plan(total: bounds.width, subviews: subviews)
        var x = bounds.minX
        place(subviews, index: 0, size: resolved.label, x: x, bounds: bounds, height: resolved.height)
        x += resolved.label.width
        place(subviews, index: 1, size: resolved.paws, x: x, bounds: bounds, height: resolved.height)
        x += resolved.paws.width
        if resolved.progress.width > 0.5 {
            place(subviews, index: 2, size: resolved.progress, x: x, bounds: bounds, height: resolved.height)
            x += resolved.progress.width
        }
        if resolved.chip.width > 0.5 {
            let chipX = bounds.maxX - resolved.chip.width
            place(subviews, index: 3, size: resolved.chip, x: chipX, bounds: bounds, height: resolved.height)
        }
    }

    private struct Plan {
        var label: CGSize
        var paws: CGSize
        var progress: CGSize
        var chip: CGSize
        var height: CGFloat
        var used: CGFloat
    }

    private func plan(total: CGFloat, subviews: Subviews) -> Plan {
        let label = size(of: subviews, index: 0)
        let pawIdeal = size(of: subviews, index: 1)
        let progress = size(of: subviews, index: 2)
        let chipIdeal = size(of: subviews, index: 3)
        let pawMin = subviews.count > 1
            ? subviews[1].sizeThatFits(ProposedViewSize(width: 1, height: nil))
            : .zero

        let progressWidth = progress.width > 0.5 ? progress.width : 0
        let showsChip = chipIdeal.width > 0.5
        let chipGap: CGFloat = showsChip ? gap : 0
        let available = max(0, total - label.width - progressWidth - chipGap)
        let floor = showsChip ? MoodButton.minimumWidth : 0

        let pawSlot: CGFloat
        let chipSlot: CGFloat
        if !showsChip || pawIdeal.width + chipIdeal.width <= available + 0.5 {
            pawSlot = pawIdeal.width
            chipSlot = chipIdeal.width
        } else if available - pawIdeal.width >= floor - 0.5 {
            pawSlot = pawIdeal.width
            chipSlot = min(chipIdeal.width, available - pawIdeal.width)
        } else {
            chipSlot = floor
            pawSlot = min(pawIdeal.width, max(pawMin.width, available - floor))
        }

        let paws = subviews.count > 1
            ? subviews[1].sizeThatFits(ProposedViewSize(width: pawSlot, height: nil))
            : .zero
        let chipMeasured = subviews.count > 3
            ? subviews[3].sizeThatFits(ProposedViewSize(width: chipSlot, height: nil))
            : .zero
        let chipWidth = chipIdeal.width <= chipSlot + 0.5 ? chipIdeal.width : chipSlot
        let chip = CGSize(width: chipWidth, height: max(chipMeasured.height, chipIdeal.height))
        let progressHeight = progress.height > 0.5 ? progress.height : 0
        let height = max(label.height, Self.minimumHeight, progressHeight)
        let used = label.width + paws.width + progressWidth + chipGap + chip.width
        return Plan(label: label, paws: paws, progress: progress, chip: chip, height: height, used: used)
    }

    private func size(of subviews: Subviews, index: Int) -> CGSize {
        guard subviews.count > index else { return .zero }
        return subviews[index].sizeThatFits(.unspecified)
    }

    private func place(
        _ subviews: Subviews,
        index: Int,
        size: CGSize,
        x: CGFloat,
        bounds: CGRect,
        height: CGFloat
    ) {
        guard subviews.count > index else { return }
        let y = bounds.minY + (height - size.height) / 2
        subviews[index].place(
            at: CGPoint(x: x, y: y),
            proposal: ProposedViewSize(width: size.width, height: size.height)
        )
    }
}
