import SwiftUI

/// 타임라인 블록 카드. 높이는 시간에 비례(1시간 = 66pt).
/// - 평소: 흰 카드(카테고리 색상 보기 켜면 연한 카테고리 색) + 완료 체크 원 + 오른쪽 시작 시각
/// - 진행 중: 진한 카테고리 색(없거나 색상 보기 끄면 포인트 컬러) 그라데이션 + 「진행 중 · N분 남음」
/// - 완료 = 연한 글자 + 줄긋기, 지남·미완료 = 연한 글자
struct TimeBlockCardView: View {
    let entry: TimeBlockEntry
    let status: TimeBlockStatus
    let displayStartMinute: Int
    let displayEndMinute: Int
    var now: Date = .now
    /// 메뉴 「카테고리 색상 보기」를 끄면 false → 흰 카드, 진행 중은 포인트 컬러
    var usesCategoryColor: Bool = true
    /// 블록 시작 알림이 실제로 켜져 있는지 (전체 설정 + 블록 설정)
    var showsAlarmIcon: Bool = false
    /// 길게 눌러 이동 중 (떠오른 모양)
    var isMoving: Bool = false
    /// false면 예시 화면용 (탭·스와이프·길이 조절 없음)
    var isInteractive: Bool = true
    var onTap: () -> Void = {}
    /// 체크 원 탭 → 완료/완료 취소
    var onToggleComplete: () -> Void = {}
    var onResizeChanged: (CGFloat) -> Void = { _ in }
    var onResizeEnded: () -> Void = {}
    var onMoveBegan: () -> Void = {}
    var onMoveChanged: (CGFloat) -> Void = { _ in }
    var onMoveEnded: () -> Void = {}

    @State private var completeFeedbackTrigger = 0
    @State private var moveFeedbackTrigger = 0
    @State private var isMoveGestureActive = false
    /// 제스처가 취소돼 onEnded가 안 불려도 이동 상태를 풀기 위한 안전장치
    @GestureState private var isMovePressing = false

    private static let cornerRadius: CGFloat = 12
    private static let moveLongPressDuration: Double = 0.3

    // MARK: - 색

    private var categoryColor: Color? {
        guard usesCategoryColor else { return nil }
        return entry.categoryColorHex.map { Color(hex: $0) }
    }

    private var isCurrent: Bool { status == .current }

    /// 진행 중 카드 색
    private var highlightColor: Color {
        categoryColor ?? AppTheme.shared.accent
    }

    private var foreground: Color {
        if isCurrent { return highlightColor.readableForeground }
        switch status {
        case .completed, .missed: return Color(.secondaryLabel)
        case .planned, .current: return Color(.label)
        }
    }

    private var secondaryForeground: Color {
        isCurrent ? highlightColor.readableForeground.opacity(0.85) : Color(.secondaryLabel)
    }

    // MARK: - 크기·시간

    private var durationMinutes: Int {
        max(displayEndMinute - displayStartMinute, 1)
    }

    private var height: CGFloat {
        CGFloat(durationMinutes) * TimeBlockLayout.pointsPerMinute
    }

    private var isCompact: Bool { durationMinutes < 30 }
    /// 50분 이상이면 둘째 줄(길이·알림·진행 중) 표시
    private var showsDetailRow: Bool { durationMinutes >= 50 }

    private var startText: String {
        TimeBlockLayout.date(day: entry.block.day, minute: displayStartMinute)
            .formatted(date: .omitted, time: .shortened)
    }

    private var endText: String {
        TimeBlockLayout.date(day: entry.block.day, minute: displayEndMinute)
            .formatted(date: .omitted, time: .shortened)
    }

    private var durationText: String {
        Duration.seconds(durationMinutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private var remainingText: String? {
        guard isCurrent else { return nil }
        let end = TimeBlockLayout.date(day: entry.block.day, minute: displayEndMinute)
        let minutes = max(Int(ceil(end.timeIntervalSince(now) / 60)), 1)
        let remaining = Duration.seconds(minutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
        return String(localized: "진행 중 · \(remaining) 남음")
    }

    // MARK: - Body

    var body: some View {
        card
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
        VStack(alignment: .leading, spacing: 4) {
            headerRow
            if showsDetailRow {
                detailRow
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, isCompact ? 2 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isCompact ? .leading : .topLeading)
        .background { cardBackground }
        .overlay(alignment: .bottomTrailing) {
            if isInteractive {
                resizeHandle
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .onTapGesture {
            guard isInteractive else { return }
            onTap()
        }
        // 스와이프(DragGesture)는 블록 위에서 세로 스크롤을 막아서 없앴다. 완료는 체크 원으로.
        .gesture(moveGesture, including: isInteractive ? .all : .none)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: status == .completed ? String(localized: "완료 취소") : String(localized: "완료로 표시")) {
            onToggleComplete()
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        if isCurrent {
            shape.fill(
                LinearGradient(
                    colors: [highlightColor.mix(with: .white, by: 0.35), highlightColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            shape
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    if let categoryColor {
                        shape.fill(categoryColor.opacity(0.16))
                    }
                }
                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            completionButton
            Text(entry.title)
                .font(isCompact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .strikethrough(status == .completed, color: foreground)
                .foregroundStyle(foreground)
                .lineLimit(showsDetailRow ? 2 : 1)
            Spacer(minLength: 4)
            Text(startText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(secondaryForeground)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var detailRow: some View {
        HStack(spacing: 6) {
            if let remainingText {
                Text(remainingText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(foreground)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(foreground.opacity(0.2), in: Capsule())
            } else {
                Text(durationText)
                    .font(.caption)
                    .foregroundStyle(secondaryForeground)
            }
            if showsAlarmIcon {
                Image(systemName: "bell.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(secondaryForeground)
            }
        }
    }

    /// 완료 체크 원 (투두 탭과 같은 모양)
    private var completionButton: some View {
        let isDone = status == .completed
        let side: CGFloat = isCompact ? 16 : 20
        let tint: Color = isCurrent ? foreground : (categoryColor ?? AppTheme.shared.accent)
        return Button {
            guard isInteractive else { return }
            completeFeedbackTrigger += 1
            onToggleComplete()
        } label: {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: side - 2, weight: .regular))
                .foregroundStyle(isDone ? tint.opacity(0.55) : (isCurrent ? foreground : Color(.tertiaryLabel)))
                .frame(width: side + 8, height: side + 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, -4)
        .accessibilityHidden(true)
    }

    /// 오른쪽 아래 모서리 손잡이 — 끌어서 끝 시각 조절 (스크롤보다 우선).
    /// 보이는 사선 표시는 작게, 잡는 영역은 넉넉하게.
    private var resizeHandle: some View {
        let gripColor = foreground.opacity(0.35)
        return Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width, y: size.height * 0.25))
            path.addLine(to: CGPoint(x: size.width * 0.25, y: size.height))
            path.move(to: CGPoint(x: size.width, y: size.height * 0.65))
            path.addLine(to: CGPoint(x: size.width * 0.65, y: size.height))
            context.stroke(path, with: .color(gripColor), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        .frame(width: 9, height: 9)
        .padding(.trailing, 5)
        .padding(.bottom, 4)
        .frame(width: 40, height: 26, alignment: .bottomTrailing)
        .contentShape(Rectangle())
        .highPriorityGesture(
            // 손잡이가 블록과 함께 움직이므로, 손잡이 기준 좌표를 쓰면 이동량이 흔들린다 → 화면 기준 좌표
            DragGesture(minimumDistance: 4, coordinateSpace: .global)
                .onChanged { value in onResizeChanged(value.translation.height) }
                .onEnded { _ in onResizeEnded() }
        )
        .accessibilityHidden(true)
    }

    // MARK: - 제스처

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

    private var accessibilityText: String {
        let base = "\(entry.title), \(startText) – \(endText)"
        switch status {
        case .planned:
            return base
        case .current:
            return "\(base), \(remainingText ?? "")"
        case .completed:
            return "\(base), \(String(localized: "완료됨"))"
        case .missed:
            return "\(base), \(String(localized: "지난 시간"))"
        }
    }
}
