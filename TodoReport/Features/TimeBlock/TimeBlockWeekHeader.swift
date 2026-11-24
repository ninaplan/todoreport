import SwiftUI

/// 타임라인 상단: 작은 날짜 + 큰 제목(오늘/어제/내일/요일) + 주간 달력 7칸.
/// 좌우로 밀거나 ‹ › 로 주를 넘긴다. 주 시작 요일은 앱 설정을 따른다.
struct TimeBlockWeekHeader: View {
    let selectedDate: Date
    let weekDays: [Date]
    let onSelect: (Date) -> Void
    let onPreviousWeek: () -> Void
    let onNextWeek: () -> Void
    let onToday: () -> Void

    private var calendar: Calendar { Calendar.current }
    private var accent: Color { AppTheme.shared.accent }

    private var title: String {
        if calendar.isDateInToday(selectedDate) { return String(localized: "오늘") }
        if calendar.isDateInYesterday(selectedDate) { return String(localized: "어제") }
        if calendar.isDateInTomorrow(selectedDate) { return String(localized: "내일") }
        return selectedDate.formatted(.dateTime.weekday(.wide))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.year().month().day()))
                        .font(.footnote)
                        .foregroundStyle(Color(.secondaryLabel))
                    HStack(alignment: .center, spacing: 8) {
                        Text(title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color(.label))
                        if !calendar.isDateInToday(selectedDate) {
                            Button(action: onToday) {
                                Text("오늘")
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemFill), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Spacer()
                weekButton(systemName: "chevron.left", label: String(localized: "이전 주"), action: onPreviousWeek)
                weekButton(systemName: "chevron.right", label: String(localized: "다음 주"), action: onNextWeek)
            }
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let width = value.translation.width
                    guard abs(width) > abs(value.translation.height), abs(width) > 50 else { return }
                    if width < 0 { onNextWeek() } else { onPreviousWeek() }
                }
        )
    }

    private func weekButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(.label))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        return Button {
            onSelect(day)
        } label: {
            VStack(spacing: 3) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(isSelected ? accent : Color(.secondaryLabel))
                Text(day.formatted(.dateTime.day()))
                    .font(.body.weight(isSelected ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isSelected || isToday ? accent : Color(.label))
                Circle()
                    .fill(isSelected ? accent : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day.formatted(date: .complete, time: .omitted)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
