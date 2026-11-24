import SwiftUI

/// 날짜가 바뀌면 다음 날은 오른쪽에서, 이전 날은 왼쪽에서 살짝 밀려 들어오게 한다.
/// - 이미 화면에 있던 줄: 신호가 바뀔 때 keyframe으로 옆으로 갔다가 제자리로
/// - 새 날짜라서 막 생긴 줄(할 일 행 등): 옆에 비켜 선 채로 생겨서 나타나자마자 제자리로
struct DaySlideModifier: ViewModifier {
    let slide: DaySlide

    /// 이미 있던 줄용 신호. 끝 값이 항상 0이라 애니메이션이 끝나면 제자리에 머문다
    @State private var changeTrigger = DaySlide.initial
    /// 막 생긴 줄의 시작 위치. 처음 생길 때만 정해지고(@State) 나타나면 0으로 애니메이션
    @State private var appearOffset: CGFloat

    private static let distance: CGFloat = 48

    init(slide: DaySlide) {
        self.slide = slide
        _appearOffset = State(initialValue: slide.isRecent ? CGFloat(slide.direction) * Self.distance : 0)
    }

    func body(content: Content) -> some View {
        content
            .offset(x: appearOffset)
            .opacity(Self.opacity(for: appearOffset))
            .keyframeAnimator(initialValue: CGFloat(0), trigger: changeTrigger) { view, offsetX in
                view
                    .offset(x: offsetX)
                    .opacity(Self.opacity(for: offsetX))
            } keyframes: { _ in
                KeyframeTrack {
                    MoveKeyframe(CGFloat(changeTrigger.direction) * Self.distance)
                    SpringKeyframe(0, duration: 0.32, spring: .snappy)
                }
            }
            .onAppear {
                guard appearOffset != 0 else { return }
                withAnimation(.snappy(duration: 0.32)) { appearOffset = 0 }
            }
            .onChange(of: slide) { _, newSlide in
                changeTrigger = newSlide
            }
    }

    private static func opacity(for offsetX: CGFloat) -> Double {
        1 - min(abs(offsetX) / 80, 0.6)
    }
}

extension View {
    func daySlide(_ slide: DaySlide) -> some View {
        modifier(DaySlideModifier(slide: slide))
    }
}
