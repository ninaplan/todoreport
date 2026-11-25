import SwiftUI

/// 일과 시간 범위의 격자 + 블록 + 현재 시각(레일 위 점). 스크롤은 바깥(`TimeBlockView`)이 담당한다.
/// 화면 맨 위 = 일과 시간 시작. 범위가 자정을 넘으면 자정 줄에 다음 날 날짜를 붙인다.
struct TimeBlockTimelineView: View {
    let viewModel: TimeBlockViewModel
    let now: Date

    private var blockLeading: CGFloat { TimeBlockLayout.blockLeading }
    private var range: TimeBlockDayRange { viewModel.dayRange }
    private var scale: CGFloat { viewModel.pointsPerMinute }
    private var rangeHeight: CGFloat { CGFloat(range.durationMinutes) * scale }
    private var contentHeight: CGFloat { TimeBlockLayout.contentHeight(for: range, pointsPerMinute: scale) }
    /// 많이 줄이면 30분 점선은 빼서 덜 복잡하게
    private var showsHalfHourLines: Bool { scale >= 0.8 }
    /// 아주 많이 줄이면 시각 글자는 2시간마다
    private var hourLabelStep: Int { scale < 0.55 ? 2 : 1 }

    private func y(_ minute: Int) -> CGFloat {
        TimeBlockLayout.y(for: minute, in: range, pointsPerMinute: scale)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            hourGrid
            tapLayer
            rail
            blocks
            if viewModel.isToday, range.contains(start: nowMinute, end: nowMinute) {
                nowIndicator
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: contentHeight, alignment: .topLeading)
    }

    // MARK: - 격자

    private var hourGrid: some View {
        ZStack(alignment: .topLeading) {
            ForEach(hours, id: \.self) { hour in
                let lineY = y(hour * 60)
                HStack(spacing: 0) {
                    TimeBlockHourLabel(hour: hour)
                        .frame(width: TimeBlockLayout.labelColumnWidth - 8, alignment: .trailing)
                        .padding(.trailing, 8)
                        .opacity(hour % hourLabelStep == 0 ? 1 : 0)
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5)
                }
                .frame(height: 20)
                .offset(y: lineY - 10)

                if hour * 60 == TimeBlockLayout.minutesPerDay, range.spansMidnight {
                    nextDayLabel
                        .frame(width: TimeBlockLayout.labelColumnWidth - 8, alignment: .trailing)
                        .offset(y: lineY + 9)
                }

                if hour < lastHour, showsHalfHourLines {
                    halfHourLine
                        .padding(.leading, TimeBlockLayout.labelColumnWidth)
                        .offset(y: y(hour * 60 + 30))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var firstHour: Int { range.startMinute / 60 }
    private var lastHour: Int { range.endMinute / 60 }
    private var hours: [Int] { Array(firstHour...lastHour) }

    /// 자정 줄 아래 작은 다음 날 날짜 (예: 11/25)
    private var nextDayLabel: some View {
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        return Text(nextDay.formatted(.dateTime.month(.defaultDigits).day()))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(AppTheme.shared.accent)
            .lineLimit(1)
            .fixedSize()
    }

    private var halfHourLine: some View {
        Line()
            .stroke(Color(.separator).opacity(0.6), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            .frame(height: 0.5)
    }

    // MARK: - 빈 칸 탭

    private var tapLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .padding(.leading, TimeBlockLayout.railX)
            .onTapGesture(coordinateSpace: .local) { location in
                viewModel.requestSlot(atMinute: TimeBlockLayout.minute(for: location.y, in: range, pointsPerMinute: scale))
            }
            .accessibilityHidden(true)
    }

    // MARK: - 블록


    /// 일과 시간에 걸친 블록은 범위 밖 부분을 잘라서 보여준다 (mask)
    private var blocks: some View {
        ZStack(alignment: .topLeading) {
            blockCards
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: contentHeight, alignment: .topLeading)
        .mask(alignment: .topLeading) {
            Rectangle()
                .frame(height: rangeHeight)
                .offset(y: TimeBlockLayout.verticalPadding)
        }
    }

    private var blockCards: some View {
        ForEach(viewModel.visibleEntries) { entry in
            TimeBlockCardView(
                entry: entry,
                status: entry.status(now: now),
                displayStartMinute: viewModel.displayStartMinute(for: entry),
                displayEndMinute: viewModel.displayEndMinute(for: entry),
                now: now,
                usesCategoryColor: viewModel.showsCategoryColor,
                isMoving: viewModel.movingBlockId == entry.id,
                onTap: { viewModel.openEditor(entry) },
                onToggleComplete: { viewModel.toggleCompletion(entry) },
                onResizeChanged: { height in
                    viewModel.beginResize(entry)
                    viewModel.updateResize(translationHeight: height)
                },
                onResizeEnded: { viewModel.endResize() },
                onMoveBegan: { viewModel.beginMove(entry) },
                onMoveChanged: { viewModel.updateMove(translationHeight: $0) },
                onMoveEnded: { viewModel.endMove() },
                pointsPerMinute: scale,
                onOpenMemo: { viewModel.openEditor(entry, focusesMemo: true) }
            )
            .padding(.leading, blockLeading)
            .padding(.trailing, TimeBlockLayout.blockTrailingPadding)
            .offset(y: y(viewModel.displayStartMinute(for: entry)) + TimeBlockLayout.blockGap / 2)
            .zIndex(viewModel.movingBlockId == entry.id ? 1 : 0)
        }
    }

    // MARK: - 레일 (세로 줄 + 블록 시작 점)

    private var rail: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(AppTheme.shared.accent.opacity(0.18))
                .frame(width: 1.5, height: rangeHeight)
                .offset(x: TimeBlockLayout.railX - 0.75, y: TimeBlockLayout.verticalPadding)
            // 진행 중 블록의 점은 시작 자리에 두지 않고, 지금 시각 점(nowIndicator)이 되어 같이 내려간다
            ForEach(viewModel.visibleEntries.filter {
                $0.status(now: now) != .current && range.contains(start: viewModel.displayStartMinute(for: $0), end: viewModel.displayStartMinute(for: $0))
            }) { entry in
                railDot(for: entry.status(now: now))
                    // 점 가운데 = 블록 시작 시각 (왼쪽 시각 눈금과 같은 높이)
                    .offset(y: y(viewModel.displayStartMinute(for: entry)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 진행 중 = 크게 채운 점 + 테두리 (지금 시각을 따라 움직임), 그 밖 = 빈 원
    @ViewBuilder
    private func railDot(for status: TimeBlockStatus) -> some View {
        let accent = AppTheme.shared.accent
        let size: CGFloat = status == .current ? 13 : 9
        Group {
            switch status {
            case .current:
                Circle()
                    .fill(accent)
                    .overlay(Circle().stroke(accent.opacity(0.25), lineWidth: 4))
            case .completed, .missed, .planned:
                // 끝난 블록도 예정과 같은 빈 원으로 돌아간다
                Circle()
                    .fill(Color(.systemGroupedBackground))
                    .overlay(Circle().stroke(accent, lineWidth: 1.5))
            }
        }
        .frame(width: size, height: size)
        .offset(x: TimeBlockLayout.railX - size / 2, y: -size / 2)
    }

    // MARK: - 현재 시각

    /// 보고 있는 날 0시부터 지금까지 분 (새벽 꼬리면 1440 초과)
    private var nowMinute: Int {
        TimeBlockLayout.minutesSince(day: viewModel.selectedDate, until: now)
    }

    /// 가로선·시각 글씨 없이 레일 위 지금 점만.
    /// 진행 중 블록이 있으면 그 블록의 점이 지금 시각을 따라 내려온 모양: 안쪽 원은 작게, 연한 테두리는 그만큼 넓게 (전체 크기는 그대로)
    private var nowIndicator: some View {
        let nowY = y(nowMinute)
        let isInBlock = viewModel.visibleEntries.contains { $0.status(now: now) == .current }
        let dotSize: CGFloat = isInBlock ? 9 : 8
        let ringWidth: CGFloat = isInBlock ? 8 : 4
        return TimeBlockNowDot(dotSize: dotSize, ringWidth: ringWidth)
            .offset(x: TimeBlockLayout.railX - dotSize / 2, y: nowY - dotSize / 2)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// 가로 한 줄 (점선용)
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
