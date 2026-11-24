import SwiftUI

/// 타임블록 레일 위 「지금」 점. 바깥 연한 테두리가 2초에 한 번 천천히 커졌다 작아진다 (숨쉬기).
/// 「동작 줄이기」를 켠 사용자에게는 멈춘 점으로 보인다.
struct TimeBlockNowDot: View {
    let dotSize: CGFloat
    let ringWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { AppTheme.shared.accent }

    var body: some View {
        Circle()
            .fill(accent)
            .frame(width: dotSize, height: dotSize)
            .background { halo }
    }

    @ViewBuilder
    private var halo: some View {
        let ring = Circle()
            .stroke(accent.opacity(0.25), lineWidth: ringWidth)
            .frame(width: dotSize, height: dotSize)
        if reduceMotion {
            ring
        } else {
            // phaseAnimator는 화면을 1분마다 다시 그려도 끊기지 않고 계속 돈다
            ring.phaseAnimator([false, true]) { view, expanded in
                view
                    .scaleEffect(expanded ? 1.35 : 1)
                    .opacity(expanded ? 0.55 : 1)
            } animation: { _ in
                .easeInOut(duration: 1)
            }
        }
    }
}
