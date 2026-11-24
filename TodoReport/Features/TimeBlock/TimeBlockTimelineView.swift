import SwiftUI

/// 하루 24시간 격자 + 블록 + 현재 시각 선. 스크롤은 바깥(`TimeBlockView`)이 담당한다.
struct TimeBlockTimelineView: View {
    let viewModel: TimeBlockViewModel
    let now: Date

    private var blockLeading: CGFloat { TimeBlockLayout.labelColumnWidth + 6 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            hourGrid
            tapLayer
            blocks
            if viewModel.isToday {
                nowIndicator
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: TimeBlockLayout.contentHeight, alignment: .topLeading)
    }

    // MARK: - 격자

    private var hourGrid: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0...24, id: \.self) { hour in
                let y = TimeBlockLayout.y(for: hour * 60)
                HStack(spacing: 0) {
                    TimeBlockHourLabel(hour: hour)
                        .frame(width: TimeBlockLayout.labelColumnWidth - 8, alignment: .trailing)
                        .padding(.trailing, 8)
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5)
                }
                .frame(height: 20)
                .offset(y: y - 10)

                if hour < 24 {
                    halfHourLine
                        .padding(.leading, TimeBlockLayout.labelColumnWidth)
                        .offset(y: TimeBlockLayout.y(for: hour * 60 + 30))
                }
            }
        }
        .accessibilityHidden(true)
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
            .padding(.leading, TimeBlockLayout.labelColumnWidth)
            .onTapGesture(coordinateSpace: .local) { location in
                viewModel.requestSlot(atMinute: TimeBlockLayout.minute(for: location.y))
            }
            .accessibilityHidden(true)
    }

    // MARK: - 블록

    private var blocks: some View {
        ForEach(viewModel.entries) { entry in
            TimeBlockCardView(
                entry: entry,
                status: entry.status(now: now),
                displayStartMinute: viewModel.displayStartMinute(for: entry),
                displayEndMinute: viewModel.displayEndMinute(for: entry),
                usesCategoryColor: viewModel.showsCategoryColor,
                isMoving: viewModel.movingBlockId == entry.id,
                onTap: { viewModel.openEditor(entry) },
                onSwipeComplete: { viewModel.toggleCompletion(entry) },
                onResizeChanged: { height in
                    viewModel.beginResize(entry)
                    viewModel.updateResize(translationHeight: height)
                },
                onResizeEnded: { viewModel.endResize() },
                onMoveBegan: { viewModel.beginMove(entry) },
                onMoveChanged: { viewModel.updateMove(translationHeight: $0) },
                onMoveEnded: { viewModel.endMove() }
            )
            .padding(.leading, blockLeading)
            .padding(.trailing, TimeBlockLayout.blockTrailingPadding)
            .offset(y: TimeBlockLayout.y(for: viewModel.displayStartMinute(for: entry)) + 1)
            .zIndex(viewModel.movingBlockId == entry.id ? 1 : 0)
        }
    }

    // MARK: - 현재 시각

    private var nowMinute: Int {
        TimeBlockLayout.minute(of: now, day: viewModel.selectedDate)
    }

    private var nowIndicator: some View {
        let y = TimeBlockLayout.y(for: nowMinute)
        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(AppTheme.shared.accent)
                .frame(height: 1.5)
                .padding(.leading, TimeBlockLayout.labelColumnWidth - 4)
            Text(now.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(AppTheme.shared.accent, in: Capsule())
                .fixedSize()
        }
        .frame(height: 18)
        .offset(y: y - 9)
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
