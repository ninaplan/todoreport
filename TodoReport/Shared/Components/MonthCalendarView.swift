import SwiftUI

struct MonthCalendarView: View {
    let initialDate: Date
    let onConfirmDate: (Date) -> Void

    @State private var displayedMonth: Date
    @State private var focusedDate: Date
    @State private var dotsByDay: [Date: DayCategoryDots] = [:]
    @State private var dayTodos: [Todo] = []
    @State private var swipeDirection: Int = 0

    private var calendar: Calendar { AppCalendar.localized }
    private let dayCellHeight: CGFloat = 48

    init(initialDate: Date, onConfirmDate: @escaping (Date) -> Void) {
        self.initialDate = initialDate
        self.onConfirmDate = onConfirmDate
        let cal = AppCalendar.localized
        let start = cal.startOfDay(for: initialDate)
        let components = cal.dateComponents([.year, .month], from: start)
        _focusedDate = State(initialValue: start)
        _displayedMonth = State(initialValue: cal.date(from: components) ?? start)
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 12) {
                monthHeader
                weekdayHeader
                dayGrid
            }
            .contentShape(Rectangle())
            .gesture(monthSwipeGesture)

            Divider()
                .padding(.top, 4)

            dayTodoList
            goToDateButton
        }
        .task(id: monthIdentity(displayedMonth)) {
            await CategoryService.shared.refresh()
            dotsByDay = await TodoService.shared.fetchCategoryDots(forMonthContaining: displayedMonth)
        }
        .task(id: calendar.startOfDay(for: focusedDate)) {
            await loadDayTodos()
        }
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Text(monthTitle(displayedMonth))
                .font(.headline)
                .frame(maxWidth: .infinity)

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(for: day)
                } else {
                    Color.clear
                        .frame(height: dayCellHeight)
                }
            }
        }
        .frame(height: dayGridHeight, alignment: .top)
        .id(monthIdentity(displayedMonth))
        .transition(.asymmetric(
            insertion: .move(edge: swipeDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: swipeDirection >= 0 ? .leading : .trailing).combined(with: .opacity)
        ))
    }

    private var dayGridHeight: CGFloat {
        // 6행 고정 — 월 전환 시 제목/레이아웃 흔들림 방지
        dayCellHeight * 6 + 8 * 5
    }

    // MARK: - Day cell

    private func dayCell(for date: Date) -> some View {
        let isFocused = calendar.isDate(date, inSameDayAs: focusedDate)
        let isToday = calendar.isDateInToday(date)
        let dayStart = calendar.startOfDay(for: date)
        let dots = dotsByDay[dayStart]

        return Button {
            focusedDate = dayStart
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isFocused {
                        Circle()
                            .fill(AppTheme.shared.accent)
                            .frame(width: 32, height: 32)
                    } else if isToday {
                        Circle()
                            .stroke(AppTheme.shared.accent, lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                    }

                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 16, weight: isFocused || isToday ? .semibold : .regular))
                        .foregroundStyle(isFocused ? Color.white : .primary)
                }
                .frame(height: 32)

                dotsRow(dots)
                    .frame(height: 8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: dayCellHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dotsRow(_ dots: DayCategoryDots?) -> some View {
        let colors = dotColors(from: dots)
        if colors.isEmpty {
            Color.clear
        } else if colors.count <= 4 {
            HStack(spacing: 2) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                }
            }
        } else {
            HStack(spacing: 2) {
                ForEach(Array(colors.prefix(3).enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                }
                Text("+\(colors.count - 3)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 그리는 시점에 Category 스토어에서 색 조회 (캐시/복제 없음)
    private func dotColors(from dots: DayCategoryDots?) -> [Color] {
        guard let dots else { return [] }
        var colors: [Color] = dots.categoryIds.map { color(forCategoryId: $0) }
        if dots.hasUncategorized {
            colors.append(Color(.tertiaryLabel))
        }
        return colors
    }

    private func color(forCategoryId categoryId: String) -> Color {
        if let hex = CategoryService.shared.store.first(where: { $0.id == categoryId })?.colorHex {
            return Color(hex: hex)
        }
        return Color(.tertiaryLabel)
    }

    // MARK: - Day todo list

    private var dayTodoList: some View {
        Group {
            if dayTodos.isEmpty {
                Text("할일 없음")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(dayTodos) { todo in
                            Button {
                                onConfirmDate(focusedDate)
                            } label: {
                                todoRow(todo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private func todoRow(_ todo: Todo) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(todoCategoryColor(todo))
                .frame(width: 8, height: 8)

            Text(todo.title)
                .font(.body)
                .foregroundStyle(todo.isCompleted ? Color.secondary : Color.primary)
                .strikethrough(todo.isCompleted)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func todoCategoryColor(_ todo: Todo) -> Color {
        guard let categoryId = todo.categoryId else {
            return Color(.tertiaryLabel)
        }
        return color(forCategoryId: categoryId)
    }

    private var goToDateButton: some View {
        Button {
            onConfirmDate(focusedDate)
        } label: {
            Text("이 날짜로 이동")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.nockOrange, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Data

    private func loadDayTodos() async {
        let fetched = await TodoService.shared.fetchTodos(for: focusedDate)
        dayTodos = Self.sortedLikeTodoTab(fetched)
    }

    /// 투두 탭 displayedTodos와 동일: 고정(미완료) → 일반(미완료) → 완료
    private static func sortedLikeTodoTab(_ todos: [Todo]) -> [Todo] {
        func sortDate(_ todo: Todo) -> Date { todo.notionCreatedAt ?? todo.createdAt }
        let pinned = todos
            .filter { $0.isPinned && !$0.isCompleted }
            .sorted { sortDate($0) < sortDate($1) }
        let normal = todos
            .filter { !$0.isPinned && !$0.isCompleted }
            .sorted { sortDate($0) < sortDate($1) }
        let completed = todos
            .filter(\.isCompleted)
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
        return pinned + normal + completed
    }

    // MARK: - Month navigation

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical), abs(horizontal) > 50 else { return }
                shiftMonth(by: horizontal < 0 ? 1 : -1)
            }
    }

    private func shiftMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        swipeDirection = value
        withAnimation(.easeInOut(duration: 0.25)) {
            displayedMonth = next
        }
    }

    // MARK: - Helpers

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let startIndex = calendar.firstWeekday - 1
        return Array(symbols[startIndex...]) + Array(symbols[..<startIndex])
    }

    /// 항상 6주(42칸). 빈 칸은 nil로 두어 투명 유지.
    private var gridDays: [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return Array(repeating: nil, count: 42)
        }
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)
        for day in dayRange {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: monthStart))
        }
        while days.count < 42 {
            days.append(nil)
        }
        return Array(days.prefix(42))
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: date)
    }

    private func monthIdentity(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)"
    }
}
