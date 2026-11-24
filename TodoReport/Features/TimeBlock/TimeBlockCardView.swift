import SwiftUI

/// 타임라인 블록 한 칸.
/// - 색: 카테고리 있으면 진한 카테고리 색, 없으면 흰 블록
/// - 상태: 글자로만 표현 (완료 = 연한 글자 + 줄긋기, 지남 = 연한 글자)
struct TimeBlockCardView: View {
    let entry: TimeBlockEntry
    let status: TimeBlockStatus
    let displayStartMinute: Int
    let displayEndMinute: Int
    /// 메뉴 「카테고리 색상 보기」를 끄면 false → 흰 블록
    var usesCategoryColor: Bool = true
    /// 길게 눌러 이동 중 (떠오른 모양)
    var isMoving: Bool = false
    /// false면 예시 화면용 (탭·스와이프·길이 조절 없음)
    var isInteractive: Bool = true
    var onTap: () -> Void = {}
    var onSwipeComplete: () -> Void = {}
    var onResizeChanged: (CGFloat) -> Void = { _ in }
    var onResizeEnded: () -> Void = {}
    var onMoveBegan: () -> Void = {}
    var onMoveChanged: (CGFloat) -> Void = { _ in }
    var onMoveEnded: () -> Void = {}

    @State private var swipeOffset: CGFloat = 0
    @State private var completeFeedbackTrigger = 0
    @State private var moveFeedbackTrigger = 0
    @State private var isMoveGestureActive = false
    /// 제스처가 취소돼 onEnded가 안 불려도 이동 상태를 풀기 위한 안전장치
    @GestureState private var isMovePressing = false

    private static let swipeThreshold: CGFloat = 60
    private static let maxSwipeOffset: CGFloat = 84
    private static let cornerRadius: CGFloat = 8
    private static let moveLongPressDuration: Double = 0.3

    private var categoryColor: Color? {
        guard usesCategoryColor else { return nil }
        return entry.categoryColorHex.map { Color(hex: $0) }
    }

    private var background: Color {
        categoryColor ?? Color(.secondarySystemGroupedBackground)
    }

    private var foreground: Color {
        let isDimmed = status != .planned
        if let categoryColor {
            return categoryColor.readableForeground.opacity(isDimmed ? 0.55 : 1)
        }
        return isDimmed ? Color(.secondaryLabel) : Color(.label)
    }

    private var durationMinutes: Int {
        max(displayEndMinute - displayStartMinute, 1)
    }

    private var height: CGFloat {
        CGFloat(durationMinutes) * TimeBlockLayout.pointsPerMinute
    }

    /// 30분 이상이면 제목 아래 시간 표시
    private var showsTimeRange: Bool { durationMinutes >= 30 }

    private var timeRangeText: String {
        let start = TimeBlockLayout.date(day: entry.block.day, minute: displayStartMinute)
        let end = TimeBlockLayout.date(day: entry.block.day, minute: displayEndMinute)
        return "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        ZStack(alignment: .leading) {
            swipeRevealIcon
            card
                .offset(x: swipeOffset)
        }
        .frame(height: height)
        .scaleEffect(isMoving ? 1.02 : 1)
        .shadow(color: .black.opacity(isMoving ? 0.18 : 0), radius: isMoving ? 8 : 0, y: isMoving ? 3 : 0)
        .animation(.easeOut(duration: 0.15), value: isMoving)
        .sensoryFeedback(.success, trigger: completeFeedbackTrigger)
        .sensoryFeedback(.impact(weight: .medium), trigger: moveFeedbackTrigger)
        .onChange(of: isMovePressing) { _, pressing in
            guard !pressing, isMoveGestureActive else { return }
            isMoveGestureActive = false
            onMoveEnded()
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.title)
                .font(durationMinutes < 25 ? .caption.weight(.medium) : .subheadline.weight(.medium))
                .strikethrough(status == .completed, color: foreground)
                .lineLimit(showsTimeRange ? 2 : 1)
            if showsTimeRange {
                Text(timeRangeText)
                    .font(.caption)
                    .opacity(0.8)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, durationMinutes < 25 ? 2 : 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(background, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            if categoryColor == nil {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
            }
        }
        .overlay(alignment: .bottom) {
            if isInteractive {
                resizeHandle
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .onTapGesture {
            guard isInteractive else { return }
            onTap()
        }
        .gesture(moveGesture, including: isInteractive ? .all : .none)
        .simultaneousGesture(swipeGesture, including: isInteractive ? .all : .none)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: status == .completed ? String(localized: "완료 취소") : String(localized: "완료로 표시")) {
            onSwipeComplete()
        }
    }

    /// 스와이프 중 블록 뒤에 보이는 아이콘
    private var swipeRevealIcon: some View {
        Image(systemName: status == .completed ? "arrow.uturn.backward" : "checkmark")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppTheme.shared.accent)
            .padding(.leading, 12)
            .opacity(min(Double(swipeOffset / Self.swipeThreshold), 1))
            .accessibilityHidden(true)
    }

    /// 블록 아래 손잡이 — 끌어서 끝 시각 조절 (스크롤보다 우선)
    private var resizeHandle: some View {
        Capsule()
            .fill(foreground.opacity(0.45))
            .frame(width: 28, height: 4)
            .frame(width: 56, height: 16)
            .contentShape(Rectangle())
            .highPriorityGesture(
                // 손잡이가 블록과 함께 움직이므로, 손잡이 기준 좌표를 쓰면 이동량이 흔들린다 → 화면 기준 좌표
                DragGesture(minimumDistance: 4, coordinateSpace: .global)
                    .onChanged { value in onResizeChanged(value.translation.height) }
                    .onEnded { _ in onResizeEnded() }
            )
            .accessibilityHidden(true)
    }

    /// 길게 누른 뒤 위아래로 끌면 이동 (시작 시각만 바뀌고 길이는 유지)
    private var moveGesture: some Gesture {
        LongPressGesture(minimumDuration: Self.moveLongPressDuration)
            // 블록이 손가락을 따라 움직이므로 화면 기준 좌표로 이동량을 잰다
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($isMovePressing) { value, state, _ in
                if case .second(true, _) = value { state = true }
            }
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if !isMoveGestureActive {
                    isMoveGestureActive = true
                    swipeOffset = 0
                    moveFeedbackTrigger += 1
                    onMoveBegan()
                }
                if let drag {
                    onMoveChanged(drag.translation.height)
                }
            }
            .onEnded { _ in
                guard isMoveGestureActive else { return }
                isMoveGestureActive = false
                onMoveEnded()
            }
    }

    /// 오른쪽으로 밀면 완료/완료 취소. 세로 스크롤은 그대로 통과시킨다.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard !isMoveGestureActive else { return }
                let width = value.translation.width
                guard width > 0, abs(width) > abs(value.translation.height) else { return }
                swipeOffset = min(width, Self.maxSwipeOffset)
            }
            .onEnded { value in
                guard !isMoveGestureActive else { return }
                let width = value.translation.width
                let isHorizontal = abs(width) > abs(value.translation.height) * 1.5
                if isHorizontal, width > Self.swipeThreshold {
                    completeFeedbackTrigger += 1
                    onSwipeComplete()
                }
                withAnimation(.spring(duration: 0.25)) {
                    swipeOffset = 0
                }
            }
    }

    private var accessibilityText: String {
        switch status {
        case .planned:
            return "\(entry.title), \(timeRangeText)"
        case .completed:
            return "\(entry.title), \(timeRangeText), \(String(localized: "완료됨"))"
        case .missed:
            return "\(entry.title), \(timeRangeText), \(String(localized: "지난 시간"))"
        }
    }
}
