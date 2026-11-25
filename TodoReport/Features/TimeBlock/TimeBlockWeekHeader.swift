import SwiftUI

/// 타임라인 상단: 작은 날짜 + 큰 제목(오늘/어제/내일/요일) + 주간 달력 7칸.
/// 주간 줄은 시스템 페이지 스크롤이라 손가락을 따라 넘어가고, ‹ › 는 애니메이션으로 넘긴다. 주 시작 요일은 앱 설정을 따른다.
struct TimeBlockWeekHeader: View {
    let selectedDate: Date
    /// 타임블록의 오늘 (일과 시간이 새벽까지면 새벽엔 전날). 제목·「오늘」 표시 기준
    let today: Date
    let weekDays: [Date]
    let onSelect: (Date) -> Void
    /// n주 넘기기 (+ 다음, - 이전)
    let onShiftWeeks: (Int) -> Void
    let onToday: () -> Void

    /// 가로 페이지 스크롤에서 지금 보이는 주 (오늘이 든 주 = 0)
    @State private var visibleWeek: Int?

    /// 앞뒤 10년치 주. LazyHStack이라 보이는 것만 그린다
    private static let weekRange = -520...520

    init(
        selectedDate: Date,
        today: Date,
        weekDays: [Date],
        onSelect: @escaping (Date) -> Void,
        onShiftWeeks: @escaping (Int) -> Void,
        onToday: @escaping () -> Void
    ) {
        self.selectedDate = selectedDate
        self.today = today
        self.weekDays = weekDays
        self.onSelect = onSelect
        self.onShiftWeeks = onShiftWeeks
        self.onToday = onToday
        // 처음부터 이번 주에서 시작 (onAppear에서 맞추면 맨 앞 주로 갔다가 튄다)
        _visibleWeek = State(initialValue: Self.weekIndex(of: weekDays.first))
    }

    private var calendar: Calendar { Calendar.current }
    private var accent: Color { AppTheme.shared.accent }

    private var isSelectedToday: Bool { calendar.isDate(selectedDate, inSameDayAs: today) }

    private func isDay(_ day: Date, offsetFromToday offset: Int) -> Bool {
        guard let target = calendar.date(byAdding: .day, value: offset, to: today) else { return false }
        return calendar.isDate(day, inSameDayAs: target)
    }

    private var title: String {
        if isSelectedToday { return String(localized: "오늘") }
        if isDay(selectedDate, offsetFromToday: -1) { return String(localized: "어제") }
        if isDay(selectedDate, offsetFromToday: 1) { return String(localized: "내일") }
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
                        if !isSelectedToday {
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
                weekButton(systemName: "chevron.left", label: String(localized: "이전 주")) { onShiftWeeks(-1) }
                weekButton(systemName: "chevron.right", label: String(localized: "다음 주")) { onShiftWeeks(1) }
            }
            weekPager
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    // MARK: - 주 넘기기 (시스템 페이지 스크롤 — 손가락을 따라 움직이고 놓으면 한 주씩 딱 맞춰 선다)

    /// 높이는 보이지 않는 이번 주 줄로 정하고, 그 위에 가로 스크롤을 얹는다.
    /// (가로 ScrollView는 세로로 끝없이 늘어나서 화면을 덮어 버리기 때문)
    private var weekPager: some View {
        weekRow(weekDays)
            .hidden()
            .accessibilityHidden(true)
            .overlay { weekScroll }
    }

    private var weekScroll: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Self.weekRange, id: \.self) { index in
                    weekRow(days(forWeek: index))
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $visibleWeek)
        // ‹ › 나 가장자리 스와이프로 날짜가 다른 주로 가면 달력도 그 주로 넘어간다
        .onChange(of: currentWeekIndex) { _, newIndex in
            guard visibleWeek != newIndex else { return }
            withAnimation(.snappy(duration: 0.3)) { visibleWeek = newIndex }
        }
        // 손으로 넘겨서 멈추면 그때 실제 날짜를 옮긴다 (끄는 도중·버튼으로 넘길 때는 무시)
        .onScrollPhaseChange { oldPhase, phase in
            guard phase == .idle,
                  oldPhase == .interacting || oldPhase == .decelerating,
                  let visible = visibleWeek else { return }
            let delta = visible - currentWeekIndex
            guard delta != 0 else { return }
            onShiftWeeks(delta)
        }
    }

    private func weekRow(_ days: [Date]) -> some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                dayCell(day)
            }
        }
    }

    /// 주 시작 요일은 앱 설정(AppCalendar)을 따른다
    private var weekCalendar: Calendar { AppCalendar.localized }

    private static var anchorWeekStart: Date {
        let weekCalendar = AppCalendar.localized
        return weekCalendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? weekCalendar.startOfDay(for: .now)
    }

    /// 오늘이 든 주 = 0 기준으로 몇 번째 주인지
    private static func weekIndex(of weekStart: Date?) -> Int {
        guard let weekStart else { return 0 }
        let days = AppCalendar.localized.dateComponents([.day], from: anchorWeekStart, to: weekStart).day ?? 0
        return Int((Double(days) / 7).rounded())
    }

    private var currentWeekIndex: Int { Self.weekIndex(of: weekDays.first) }

    private func days(forWeek index: Int) -> [Date] {
        guard let start = weekCalendar.date(byAdding: .day, value: index * 7, to: Self.anchorWeekStart) else { return [] }
        return (0..<7).compactMap { weekCalendar.date(byAdding: .day, value: $0, to: start) }
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
        let isToday = calendar.isDate(day, inSameDayAs: today)
        return Button {
            onSelect(day)
        } label: {
            // 오늘 = 포인트 컬러 숫자 + 점 (회색 원 없음), 오늘이 아닌 고른 날 = 회색 원 + 굵은 숫자
            VStack(spacing: 3) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(isToday ? accent : (isSelected ? Color(.label) : Color(.secondaryLabel)))
                // .dateTime.day()는 한국어에서 「24일」이 되므로 숫자만
                Text(calendar.component(.day, from: day), format: .number)
                    .font(.body.weight(isSelected ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? accent : Color(.label))
                    .frame(width: 34, height: 34)
                    .background(isSelected && !isToday ? Color(.tertiarySystemFill) : Color.clear, in: Circle())
                Circle()
                    .fill(isToday ? accent : Color.clear)
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
