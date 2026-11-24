import SwiftUI

/// 무료 사용자용: 고정된 예시 블록을 흐리게 깔고, 그 위에 Pro 안내 카드.
/// 사용자 실제 데이터는 읽지 않는다.
struct TimeBlockLockedView: View {
    let onStart: () -> Void

    private static let sampleDay = Calendar.current.startOfDay(for: .now)

    private static let sampleEntries: [TimeBlockEntry] = [
        sample(id: "sample-1", title: String(localized: "집중 작업"), start: 9 * 60, end: 11 * 60, colorHex: "#5B8DEF", icon: "briefcase.fill", completed: true),
        sample(id: "sample-2", title: String(localized: "점심"), start: 12 * 60, end: 13 * 60, colorHex: nil, icon: nil, completed: false),
        sample(id: "sample-3", title: String(localized: "운동"), start: 13 * 60 + 30, end: 14 * 60 + 30, colorHex: "#34C38F", icon: "figure.run", completed: false),
        sample(id: "sample-4", title: String(localized: "공부"), start: 15 * 60, end: 17 * 60, colorHex: "#FD6845", icon: "book.fill", completed: false)
    ]

    /// 예시에서 「진행 중」으로 보여줄 블록
    private static let sampleCurrentId = "sample-3"

    private static func sample(id: String, title: String, start: Int, end: Int, colorHex: String?, icon: String?, completed: Bool) -> TimeBlockEntry {
        TimeBlockEntry(
            block: TimeBlock(id: id, plannerId: nil, todoId: id, day: sampleDay, startMinute: start, endMinute: end, alarmEnabled: true),
            title: title,
            isCompleted: completed,
            categoryColorHex: colorHex,
            categoryIcon: icon
        )
    }

    private static func sampleStatus(_ entry: TimeBlockEntry) -> TimeBlockStatus {
        if entry.isCompleted { return .completed }
        return entry.id == sampleCurrentId ? .current : .planned
    }

    /// 예시는 9시~17시만 보여준다
    private static let visibleStartMinute = 8 * 60 + 30
    private static let visibleEndMinute = 17 * 60 + 30

    var body: some View {
        ZStack {
            samplePreview
                .opacity(0.4)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            lockCard
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var samplePreview: some View {
        let offsetY = TimeBlockLayout.y(for: Self.visibleStartMinute)
        let height = CGFloat(Self.visibleEndMinute - Self.visibleStartMinute) * TimeBlockLayout.pointsPerMinute
        return ZStack(alignment: .topLeading) {
            ForEach(9...17, id: \.self) { hour in
                HStack(spacing: 0) {
                    TimeBlockHourLabel(hour: hour)
                        .frame(width: TimeBlockLayout.labelColumnWidth - 8, alignment: .trailing)
                        .padding(.trailing, 8)
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5)
                }
                .frame(height: 20)
                .offset(y: TimeBlockLayout.y(for: hour * 60) - offsetY - 10)
            }
            ForEach(Self.sampleEntries) { entry in
                TimeBlockCardView(
                    entry: entry,
                    status: Self.sampleStatus(entry),
                    displayStartMinute: entry.block.startMinute,
                    displayEndMinute: entry.block.endMinute,
                    now: TimeBlockLayout.date(day: Self.sampleDay, minute: 14 * 60),
                    showsAlarmIcon: true,
                    isInteractive: false
                )
                .padding(.leading, TimeBlockLayout.blockLeading)
                .padding(.trailing, TimeBlockLayout.blockTrailingPadding)
                .offset(y: TimeBlockLayout.y(for: entry.block.startMinute) - offsetY + 1)
            }
        }
        .frame(height: height, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 12)
        .clipped()
    }

    private var lockCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.shared.accent)
            Text("하루를 시간으로 계획하기")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("할 일을 시간 블록에 넣고, 계획대로 했는지 한눈에 확인합니다. 타임라인은 Pro 기능입니다.")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
            Button(action: onStart) {
                Text("Pro 시작하기")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.shared.accent)
            .padding(.top, 6)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
