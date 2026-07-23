import SwiftUI

private enum CalendarCategoryFilter: Hashable {
    case all
    case category(String)
    case uncategorized
}

struct MonthCalendarView: View {
    @Binding var focusedDate: Date?
    let onConfirmDate: (Date) -> Void

    @State private var displayedMonth: Date
    @State private var dotsByDay: [Date: DayCategoryDots] = [:]
    @State private var dayTodos: [Todo] = []
    @State private var monthShiftDirection: Int = 0
    @State private var categoryFilter: CalendarCategoryFilter = .all
    @State private var isFetchingNotion = false
    @State private var showFetchErrorAlert = false
    @State private var fetchErrorMessage = ""

    private var calendar: Calendar { AppCalendar.localized }
    private let dayCellHeight: CGFloat = 50
    private let dayGridRowSpacing: CGFloat = 8
    private let dayNumberFontSize: CGFloat = 17

    private var isNotionPlanner: Bool {
        let planner = PlannerService.shared.selectedPlanner
        return planner?.isNotionConnected == true && planner?.notionTodoDBId != nil
    }

    private var activeCategories: [Category] {
        CategoryService.shared.activeCategories
    }

    private var filteredDayTodos: [Todo] {
        switch categoryFilter {
        case .all:
            return dayTodos
        case .category(let id):
            return dayTodos.filter { $0.categoryId == id }
        case .uncategorized:
            return dayTodos.filter { $0.categoryId == nil }
        }
    }

    init(focusedDate: Binding<Date?>, onConfirmDate: @escaping (Date) -> Void) {
        _focusedDate = focusedDate
        self.onConfirmDate = onConfirmDate
        let cal = AppCalendar.localized
        let anchor = focusedDate.wrappedValue.map { cal.startOfDay(for: $0) } ?? cal.startOfDay(for: .now)
        let components = cal.dateComponents([.year, .month], from: anchor)
        _displayedMonth = State(initialValue: cal.date(from: components) ?? anchor)
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 12) {
                monthHeader
                weekdayHeader
                dayGrid
            }

            categoryLegendRow

            Divider()
                .padding(.top, 4)

            bottomContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task(id: monthIdentity(displayedMonth)) {
            await CategoryService.shared.refresh()
            dotsByDay = await TodoService.shared.fetchCategoryDots(forMonthContaining: displayedMonth)
        }
        .task(id: focusedDate.map { calendar.startOfDay(for: $0) }) {
            await loadDayTodos()
        }
        .alert("불러오기 실패", isPresented: $showFetchErrorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(fetchErrorMessage)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var monthHeader: some View {
        if isNotionPlanner {
            notionMonthHeader
        } else {
            localMonthHeader
        }
    }

    /// 로컬 플래너 — 기존 레이아웃 유지 (화살표 양끝, 제목 가운데)
    private var localMonthHeader: some View {
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

    /// 노션 플래너 — 화살표 양끝, 월 제목 헤더 중앙, 불러오기 아이콘은 제목 바로 오른쪽
    private var notionMonthHeader: some View {
        let fetchSlotWidth: CGFloat = 28
        return HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Color.clear
                    .frame(width: fetchSlotWidth, height: 44)
                Text(monthTitle(displayedMonth))
                    .font(.headline)
                Button {
                    Task { await fetchMonthFromNotion() }
                } label: {
                    if isFetchingNotion {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: fetchSlotWidth, height: 44)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.nockOrange)
                            .frame(width: fetchSlotWidth, height: 44)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isFetchingNotion)
                .accessibilityLabel("불러오기")
            }

            Spacer(minLength: 0)

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

    // MARK: - Category filter

    /// 전체 + 활성 카테고리 + 미분류 (표시 순서)
    private var allCategoryFilterOptions: [CalendarCategoryFilter] {
        var options: [CalendarCategoryFilter] = [.all]
        options.append(contentsOf: activeCategories.map { .category($0.id) })
        options.append(.uncategorized)
        return options
    }

    private var categoryLegendRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allCategoryFilterOptions, id: \.self) { option in
                    categoryLegendChip(option)
                }
            }
        }
    }

    private func categoryLegendChip(_ option: CalendarCategoryFilter) -> some View {
        let isSelected = categoryFilter == option
        return Button {
            categoryFilter = option
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(legendDotColor(for: option))
                    .frame(width: 8, height: 8)
                Text(legendTitle(for: option))
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.primary.opacity(0.55) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func legendTitle(for option: CalendarCategoryFilter) -> String {
        switch option {
        case .all:
            return "전체"
        case .category(let id):
            return CategoryService.shared.store.first(where: { $0.id == id })?.name ?? "카테고리"
        case .uncategorized:
            return "미분류"
        }
    }

    private func legendDotColor(for option: CalendarCategoryFilter) -> Color {
        switch option {
        case .all:
            return Color(.secondaryLabel)
        case .category(let id):
            return color(forCategoryId: id)
        case .uncategorized:
            return Color(.tertiaryLabel)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        let weekCount = max(gridDays.count / 7, 1)
        return LazyVGrid(columns: columns, spacing: dayGridRowSpacing) {
            ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(for: day)
                } else {
                    Color.clear
                        .frame(height: dayCellHeight)
                }
            }
        }
        .frame(height: dayGridHeight(weekCount: weekCount), alignment: .top)
        .id(monthIdentity(displayedMonth))
        .transition(.asymmetric(
            insertion: .move(edge: monthShiftDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: monthShiftDirection >= 0 ? .leading : .trailing).combined(with: .opacity)
        ))
    }

    private func dayGridHeight(weekCount: Int) -> CGFloat {
        dayCellHeight * CGFloat(weekCount) + dayGridRowSpacing * CGFloat(max(weekCount - 1, 0))
    }

    // MARK: - Day cell

    private func dayCell(for date: Date) -> some View {
        let isFocused = focusedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
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
                        .font(.system(size: dayNumberFontSize, weight: isFocused || isToday ? .semibold : .regular))
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
        let colors = filteredDotColors(from: dots)
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

    /// 필터 적용 후 점 색. 색은 그리는 시점에 Category 스토어에서 조회.
    private func filteredDotColors(from dots: DayCategoryDots?) -> [Color] {
        guard let dots else { return [] }
        switch categoryFilter {
        case .all:
            var colors: [Color] = dots.categoryIds.map { color(forCategoryId: $0) }
            if dots.hasUncategorized {
                colors.append(Color(.tertiaryLabel))
            }
            return colors
        case .category(let id):
            guard dots.categoryIds.contains(id) else { return [] }
            return [color(forCategoryId: id)]
        case .uncategorized:
            return dots.hasUncategorized ? [Color(.tertiaryLabel)] : []
        }
    }

    private func color(forCategoryId categoryId: String) -> Color {
        if let hex = CategoryService.shared.store.first(where: { $0.id == categoryId })?.colorHex {
            return Color(hex: hex)
        }
        return Color(.tertiaryLabel)
    }

    // MARK: - Bottom content

    @ViewBuilder
    private var bottomContent: some View {
        if focusedDate == nil {
            Text("날짜를 탭하세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 12)
        } else {
            dayTodoList
        }
    }

    private var dayTodoList: some View {
        Group {
            if filteredDayTodos.isEmpty {
                Text("할일 없음")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredDayTodos) { todo in
                            Button {
                                if let focusedDate {
                                    onConfirmDate(focusedDate)
                                }
                            } label: {
                                todoRow(todo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
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

    // MARK: - Data

    private func loadDayTodos() async {
        guard let focusedDate else {
            dayTodos = []
            return
        }
        let fetched = await TodoService.shared.fetchTodos(for: focusedDate)
        dayTodos = Self.sortedLikeTodoTab(fetched)
    }

    private func fetchMonthFromNotion() async {
        guard !isFetchingNotion else { return }
        isFetchingNotion = true
        defer { isFetchingNotion = false }

        var seoulCalendar = Calendar(identifier: .gregorian)
        guard let seoul = TimeZone(identifier: "Asia/Seoul") else { return }
        seoulCalendar.timeZone = seoul

        guard
            let monthStart = seoulCalendar.date(
                from: seoulCalendar.dateComponents([.year, .month], from: displayedMonth)
            ),
            let nextMonth = seoulCalendar.date(byAdding: .month, value: 1, to: monthStart),
            let monthEnd = seoulCalendar.date(byAdding: .day, value: -1, to: nextMonth)
        else { return }

        do {
            try await TodoService.shared.syncTodosFromNotionRange(start: monthStart, end: monthEnd)
            await CategoryService.shared.refresh()
            dotsByDay = await TodoService.shared.fetchCategoryDots(forMonthContaining: displayedMonth)
            await loadDayTodos()
        } catch {
            AppLogger.shared.warn(
                "MonthCalendarView",
                "노션 월 불러오기 실패 - \(error.localizedDescription)"
            )
            fetchErrorMessage = error.localizedDescription
            showFetchErrorAlert = true
        }
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

    private func shiftMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        monthShiftDirection = value
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

    /// 해당 월의 실제 주 수만큼만 칸 생성(5주/6주). 앞뒤 빈 칸은 nil.
    private var gridDays: [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)
        for day in dayRange {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: monthStart))
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
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
