import SwiftUI

/// 투두리포트 ↔ 노션 사이 — 회색 점이 좌→우, 우→좌로 번갈아 커졌다 작아짐.
struct NotionDataExchangeAnimation: View {
    var laneWidth: CGFloat = 60

    private let dotDiameter: CGFloat = 5
    private let maxScale: CGFloat = 1.65
    private let dotCount = 5
    private let dotSpacing: CGFloat = 7
    private let halfCycleDuration: Double = 1.0
    private let slotSize: CGFloat = 8

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let activeIndex = activeDotIndex(elapsed: elapsed)
            HStack(spacing: dotSpacing) {
                ForEach(0..<dotCount, id: \.self) { index in
                    let isActive = index == activeIndex
                    Circle()
                        .fill(isActive ? Color.primary : Color(.systemGray4))
                        .frame(width: dotDiameter, height: dotDiameter)
                        .scaleEffect(isActive ? dotScale(elapsed: elapsed) : 1)
                        .frame(width: slotSize, height: slotSize)
                }
            }
            .frame(width: laneWidth)
        }
        .accessibilityHidden(true)
    }

    private func activeDotIndex(elapsed: TimeInterval) -> Int {
        let fullCycle = halfCycleDuration * 2
        let position = elapsed.truncatingRemainder(dividingBy: fullCycle)
        let stepDuration = halfCycleDuration / Double(dotCount)
        let step = Int(position.truncatingRemainder(dividingBy: halfCycleDuration) / stepDuration) % dotCount

        if position < halfCycleDuration {
            return step
        }
        return (dotCount - 1) - step
    }

    private func dotScale(elapsed: TimeInterval) -> CGFloat {
        let stepDuration = halfCycleDuration / Double(dotCount)
        let fullCycle = halfCycleDuration * 2
        let position = elapsed.truncatingRemainder(dividingBy: fullCycle)
        let withinStep = (position.truncatingRemainder(dividingBy: stepDuration)) / stepDuration

        if withinStep < 0.5 {
            let t = withinStep / 0.5
            return 1 + (maxScale - 1) * t
        }
        let t = (withinStep - 0.5) / 0.5
        return maxScale - (maxScale - 1) * t
    }
}
