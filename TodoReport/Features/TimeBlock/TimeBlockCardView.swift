import SwiftUI

/// 타임라인 블록 카드. 높이는 시간에 비례(기본 1시간 = 66pt, 핀치로 바뀜).
/// - 높이가 넉넉하면 제목 아래 할 일 메모(길면 …, 없으면 「+ 메모 추가」). 누르면 팝업의 메모 칸으로 (입구만)
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
    /// 1분 = 몇 pt (확대·축소)
    var pointsPerMinute: CGFloat = TimeBlockLayout.pointsPerMinute
    /// 메모·「+ 메모 추가」 탭 → 팝업을 메모 칸에 커서를 둔 채로 연다
    var onOpenMemo: () -> Void = {}

    @State private var completeFeedbackTrigger = 0
    @State private var moveFeedbackTrigger = 0
    @State private var isMoveGestureActive = false
    /// 모서리 손잡이를 끄는 중. 끝 신호(onEnded) 없이 취소돼도(예: 두 손가락 핀치) 자동으로 false가 된다
    @GestureState private var isResizeGestureActive = false

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

    /// 이어지는 블록끼리 붙어 보이지 않게 위아래 0.5pt씩 줄여 사이에 1pt 틈을 둔다 (시각 계산은 그대로)
    /// 최소 높이(2pt)도 틈을 넘지 않게 → 많이 줄여도 블록 사이 1pt 틈이 남는다
    private var height: CGFloat {
        max(CGFloat(durationMinutes) * pointsPerMinute - TimeBlockLayout.blockGap, 2)
    }

    /// 크기 기준은 분이 아니라 실제 높이 (확대·축소해도 글자가 넘치지 않게).
    /// 보통 모양(위아래 여백 8)은 약 40pt가 필요해서, 그보다 낮으면 여백을 줄인 작은 모양으로 (기본 크기에서 40분 미만)
    private var isCompact: Bool { height < 40 }
    /// 많이 줄여서 글자가 안 들어가면 색만 보여준다
    private var isTiny: Bool { height < 15 }
    /// 체크 원 크기 (짧은 블록은 작게)
    private var checkSide: CGFloat { isCompact ? 16 : 20 }
    /// 둘째 줄을 제목 글자와 맞추는 들여쓰기 = 체크 원 칸(side + 8) - 왼쪽 당김(4) + 간격(6)
    private var titleLeadingInset: CGFloat { checkSide + 10 }
    /// 기본 크기에서 50분 이상(약 54pt)이면 둘째 줄(길이·알림·진행 중) 표시
    private var showsDetailRow: Bool { height >= 54 }

    /// 메모 줄 수 (0이면 안 보임). 제목·길이 줄(약 62pt)을 먼저 채우고 남는 높이만큼 (1줄 ≈ 16pt, 최대 3줄)
    /// 기본 크기에서 1시간 20분부터 1줄
    private var memoLineLimit: Int {
        guard isInteractive || entry.memo != nil else { return 0 }
        let spare = height - 62
        guard spare >= 20 else { return 0 }
        return min(Int(spare / 16), 3)
    }

    private var showsMemo: Bool { memoLineLimit > 0 }

    private var memoText: String? {
        guard let memo = entry.memo?.trimmingCharacters(in: .whitespacesAndNewlines), !memo.isEmpty else { return nil }
        return memo
    }

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
        // 옮길 때 떠오른 모양은 가로로만 (세로로 커지면 위아래 블록 틈을 덮는다)
        .scaleEffect(x: isMoving ? 1.02 : 1, y: 1)
        .shadow(color: .black.opacity(isMoving ? 0.18 : 0), radius: isMoving ? 8 : 0, y: isMoving ? 3 : 0)
        .animation(.easeOut(duration: 0.15), value: isMoving)
        .sensoryFeedback(.success, trigger: completeFeedbackTrigger)
        .sensoryFeedback(.impact(weight: .medium), trigger: moveFeedbackTrigger)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !isTiny {
                headerRow
            }
            if showsDetailRow {
                secondRow
                    .padding(.leading, titleLeadingInset)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, isCompact ? 2 : 8)
        // minHeight 0: 내용이 카드보다 커도 카드(배경)가 블록 높이를 넘지 않게 → 위아래 틈을 덮지 않는다.
        // (최소값을 안 주면 내용 크기만큼 커져서 위아래로 삐져나왔다)
        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: isCompact ? .leading : .topLeading)
        .clipped()
        .background { cardBackground }
        .overlay(alignment: .bottomTrailing) {
            // 너무 작으면 손잡이 숨김
            if isInteractive, height >= 20 {
                resizeHandle
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .onTapGesture {
            guard isInteractive else { return }
            onTap()
        }
        // SwiftUI DragGesture·LongPressGesture는 블록 위에서 세로 스크롤을 막는다 →
        // 완료는 체크 원, 이동은 UIKit 길게 누르기로.
        .gesture(moveGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: status == .completed ? String(localized: "완료 취소") : String(localized: "완료로 표시")) {
            onToggleComplete()
        }
        .accessibilityAction(named: String(localized: "메모 고치기")) {
            openMemo()
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
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(startText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(secondaryForeground)
                .lineLimit(1)
                .fixedSize()
        }
    }

    /// 둘째 줄: 길이 (진행 중이면 「진행 중 · N분 남음」 캡슐 + 전체 길이). 셋째 줄부터: 메모 (자리 있을 때, 폭 전체)
    /// ○ 앱 홍보                   오후 3:00
    ///   1시간
    ///   + 메모 추가
    private var secondRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let remainingText {
                    Text(remainingText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(foreground)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(foreground.opacity(0.2), in: Capsule())
                        .fixedSize()
                }
                // 진행 중에도 전체 길이를 함께 (남은 시간만으로는 블록 길이를 모름)
                Text(durationText)
                    .font(.caption)
                    .foregroundStyle(secondaryForeground)
                    .lineLimit(1)
            }
            if showsMemo {
                memoArea
            }
        }
    }

    /// 메모 부분은 따로 누르는 버튼 → 블록 탭(빈 팝업)과 달리 팝업의 메모 칸에 커서를 둔 채로 연다.
    /// 안쪽 Button이 탭을 먼저 받고, 바깥 onTapGesture는 나머지 영역에서만 동작한다.
    @ViewBuilder
    private var memoArea: some View {
        if let memoText {
            Button(action: openMemo) {
                Text(memoText)
                    .font(.footnote)
                    .foregroundStyle(secondaryForeground)
                    .lineLimit(memoLineLimit)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("메모: \(memoText)"))
            .accessibilityHint(Text("탭하면 메모를 고칠 수 있습니다."))
        } else if isInteractive {
            Button(action: openMemo) {
                Label("메모 추가", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
                    .font(.footnote)
                    .foregroundStyle(secondaryForeground.opacity(0.8))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func openMemo() {
        guard isInteractive else { return }
        onOpenMemo()
    }

    /// 완료 체크 원 (투두 탭과 같은 모양)
    private var completionButton: some View {
        let isDone = status == .completed
        let side = checkSide
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
            // 4pt였을 때 스크롤하다 스치기만 해도 크기가 바뀌어서 10pt로 (잡는 영역 크기는 그대로)
            DragGesture(minimumDistance: 10, coordinateSpace: .global)
                .updating($isResizeGestureActive) { _, active, _ in active = true }
                .onChanged { value in onResizeChanged(value.translation.height) }
                .onEnded { _ in onResizeEnded() }
        )
        // 취소돼서 onEnded가 안 오면 여기서 마무리 (정상 종료 뒤에는 뷰모델이 이미 비워 둬서 아무 일 없음)
        .onChange(of: isResizeGestureActive) { _, active in
            if !active { onResizeEnded() }
        }
        .accessibilityHidden(true)
    }

    // MARK: - 제스처

    /// 길게 누른 뒤 위아래로 끌면 이동 (시작 시각만 바뀌고 길이는 유지)
    private var moveGesture: TimeBlockLongPressDragGesture {
        TimeBlockLongPressDragGesture(
            minimumDuration: Self.moveLongPressDuration,
            isEnabled: isInteractive,
            onBegan: {
                isMoveGestureActive = true
                moveFeedbackTrigger += 1
                onMoveBegan()
            },
            onChanged: { translation in
                guard isMoveGestureActive else { return }
                onMoveChanged(translation)
            },
            onEnded: {
                guard isMoveGestureActive else { return }
                isMoveGestureActive = false
                onMoveEnded()
            }
        )
    }

    private var accessibilityText: String {
        var base = "\(entry.title), \(startText) – \(endText)"
        if let memoText {
            base += ", \(memoText)"
        }
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
