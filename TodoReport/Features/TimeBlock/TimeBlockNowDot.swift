import SwiftUI

/// 타임블록 레일 위 「지금」 점. 진한 점과 바깥 연한 테두리가 함께 2초에 한 번 커졌다 작아진다 (숨쉬기).
/// 진한 점이 같이 움직여야 눈에 띈다. 「동작 줄이기」를 켠 사용자에게는 멈춘 점으로 보인다.
struct TimeBlockNowDot: View {
    let dotSize: CGFloat
    let ringWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { AppTheme.shared.accent }

    var body: some View {
        if reduceMotion {
            dot(core: 1, halo: 1, haloOpacity: 1)
        } else {
            // phaseAnimator는 화면을 1분마다 다시 그려도 끊기지 않고 계속 돈다
            Color.clear
                .frame(width: dotSize, height: dotSize)
                .phaseAnimator([false, true]) { _, expanded in
                    dot(
                        core: expanded ? 1.25 : 0.85,
                        halo: expanded ? 1.6 : 1,
                        haloOpacity: expanded ? 0.35 : 1
                    )
                } animation: { _ in
                    .easeInOut(duration: 1)
                }
        }
    }

    private func dot(core: CGFloat, halo: CGFloat, haloOpacity: Double) -> some View {
        Circle()
            .fill(accent)
            .frame(width: dotSize, height: dotSize)
            .scaleEffect(core)
            .background {
                Circle()
                    .stroke(accent.opacity(0.25), lineWidth: ringWidth)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(halo)
                    .opacity(haloOpacity)
            }
    }
}
