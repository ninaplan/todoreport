import SwiftUI

struct TodoView: View {
    @Environment(MainTabCoordinator.self) private var tabCoordinator
    @State private var viewModel = TodoViewModel()
    @State private var dailyReportViewModel = DailyReportViewModel()
    @State private var newTodoTitle: String = ""
    @State private var isAddingTodo: Bool = false
    @State private var showViewOptions: Bool = false
    @State private var showPlannerSheet: Bool = false
    @State private var showQuickCapture: Bool = false
    @State private var changingDateTodo: Todo? = nil
    @State private var editingTodo: Todo? = nil
    @State private var showCategorySheet: Bool = false
    @State private var scrollOffset: CGFloat = 56

    @State private var hapticImpactTrigger = false
    @State private var hapticSuccessTrigger = false
    @State private var hapticWarningTrigger = false

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 EEEE"
        return f
    }()

    private var formattedDate: String {
        let cal = Calendar.current
        let date = viewModel.selectedDate
        let base = Self.dateFmt.string(from: date)
        if cal.isDateInToday(date)     { return "오늘, \(base)" }
        if cal.isDateInYesterday(date) { return "어제, \(base)" }
        if cal.isDateInTomorrow(date)  { return "내일, \(base)" }
        return base
    }

    private var arrowBgOpacity: Double {
        let scrolled = max(0, 56 - scrollOffset)
        return Double(min(scrolled / 30, 1))
    }

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            ZStack(alignment: .top) {
                ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { proxy in
                List {
                    // 데일리리포트 카드
                    Section {
                        DailyReportCard(
                            viewModel: dailyReportViewModel,
                            date: viewModel.selectedDate,
                            completionRate: viewModel.completionRate,
                            displayRate: viewModel.filteredCompletionRate,
                            displayCompleted: viewModel.filteredCompletedCount,
                            displayTotal: viewModel.filteredTotalCount,
                            onPrevDay: { viewModel.requestPreviousDay() },
                            onNextDay: { viewModel.requestNextDay() }
                        )
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .named("todoScroll")).minY
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    // 카테고리 필터 칩
                    if !viewModel.activeCategories.isEmpty {
                        Section {
                            CategoryFilterBar(
                                categories: viewModel.activeCategories,
                                selectedId: $viewModel.selectedCategoryFilter
                            )
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }

                    // 투두 목록
                    Section {
                        if viewModel.showsTodoListLoading {
                            TodoListLoadingView()
                        } else {
                            todoRows(for: viewModel.filteredTodos)
                            addTodoRow
                                .id("addTodoRow")
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: 56)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: 100)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    guard isAddingTodo else { return }
                    withAnimation { proxy.scrollTo("addTodoRow", anchor: .bottom) }
                }
                .onChange(of: viewModel.filteredTodos.count) { _, _ in
                    guard isAddingTodo else { return }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 80_000_000)
                        withAnimation { proxy.scrollTo("addTodoRow", anchor: .bottom) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await viewModel.refreshFromNotion()
                    await dailyReportViewModel.fetchReport(for: viewModel.selectedDate, completionRate: viewModel.completionRate)
                }
                .onAppear { Task { await viewModel.onAppear() } }
                .onChange(of: tabCoordinator.foregroundRefreshToken) { _, _ in
                    Task {
                        await viewModel.handleForegroundRefresh()
                        await dailyReportViewModel.fetchReport(
                            for: viewModel.selectedDate,
                            completionRate: viewModel.completionRate
                        )
                    }
                }
                .onChange(of: tabCoordinator.todoRootResetToken) { _, _ in
                    resetTodoNavigationToRoot()
                }
                .onChange(of: tabCoordinator.pendingTodoDate) { _, date in
                    guard let date else { return }
                    viewModel.navigateToDate(date)
                    tabCoordinator.clearPendingTodoDate()
                }
                .onChange(of: PlannerService.shared.selectedPlannerId) { _, _ in
                    dailyReportViewModel.switchReport()
                    Task {
                        await viewModel.switchPlanner()
                        await dailyReportViewModel.fetchReport(
                            for: viewModel.selectedDate,
                            completionRate: viewModel.completionRate
                        )
                    }
                }
                } // ScrollViewReader

                FloatingCaptureButton {
                    showQuickCapture = true
                }

                } // inner ZStack

                DateNavigationRow(
                    title: formattedDate,
                    onPrev: { viewModel.requestPreviousDay() },
                    onNext: { viewModel.requestNextDay() },
                    onTapTitle: { viewModel.requestDatePicker() },
                    arrowBgOpacity: arrowBgOpacity,
                    showTodayButton: viewModel.canGoNextDay,
                    onGoToday: { viewModel.goToToday() }
                )
                .padding(.horizontal, 16)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            let h = value.translation.width
                            let v = value.translation.height
                            guard abs(h) > abs(v) else { return }
                            if h < 0 { viewModel.requestNextDay() } else { viewModel.requestPreviousDay() }
                        }
                )
            } // outer ZStack
            .background(Color(.systemGroupedBackground))
            .coordinateSpace(.named("todoScroll"))
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { y in
                scrollOffset = y
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showPlannerSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            if let planner = PlannerService.shared.selectedPlanner {
                                PlannerIconView(
                                    iconType: planner.iconType,
                                    iconImageData: planner.iconImageData,
                                    colorHex: planner.colorHex,
                                    size: 22
                                )
                            }
                            Text(PlannerService.shared.selectedPlanner?.name ?? "내 플래너")
                                .font(.callout.weight(.semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .thin))
                        }
                    }
                    .tint(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showViewOptions.toggle()
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .tint(.primary)
                    .popover(isPresented: $showViewOptions) {
                        ViewOptionsPopover(viewModel: viewModel) {
                            showViewOptions = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showCategorySheet = true
                            }
                        }
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .sheet(isPresented: $vm.showDatePicker) {
                DatePickerSheet(selectedDate: Binding(
                    get: { viewModel.selectedDate },
                    set: { viewModel.selectedDate = $0 }
                ))
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $vm.showDatePaywall) {
                PaywallView(message: viewModel.datePaywallMessage)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPlannerSheet) {
                PlannerSelectionSheet()
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showQuickCapture) {
                QuickCaptureView(defaultCategoryId: viewModel.selectedCategoryFilter, initialDate: viewModel.selectedDate) { title, memo, categoryId, date, scheduledTime, alarmOffset, recurrenceRule, recurrenceEndDate, recurrenceCount in
                    viewModel.addTodo(title: title, memo: memo, categoryId: categoryId, date: date, scheduledTime: scheduledTime, alarmOffset: alarmOffset, recurrenceRule: recurrenceRule, recurrenceEndDate: recurrenceEndDate, recurrenceCount: recurrenceCount)
                    hapticSuccessTrigger.toggle()
                }
                .presentationDragIndicator(.visible)
            }
            .alert("반복 투두 삭제", isPresented: $viewModel.showDeleteAlert) {
                Button("이 항목만 삭제", role: .destructive) { viewModel.confirmDeleteSingle() }
                Button("이후 항목 모두 삭제", role: .destructive) { viewModel.confirmDeleteFuture() }
                Button("취소", role: .cancel) { viewModel.cancelDelete() }
            } message: {
                Text("어떻게 삭제할까요?")
            }
            .alert(viewModel.recurringEditAlertTitle, isPresented: $viewModel.showRecurringEditAlert) {
                Button(viewModel.recurringEditSingleLabel) { viewModel.confirmRecurringEditSingle() }
                Button(viewModel.recurringEditFutureLabel, role: .destructive) { viewModel.confirmRecurringEditFuture() }
                Button("취소", role: .cancel) { viewModel.cancelRecurringEdit() }
            } message: {
                Text("어떻게 변경할까요?")
            }
            .sheet(item: $changingDateTodo) { todo in
                TodoDateChangeSheet(initialDate: todo.date) { newDate in
                    viewModel.changeTodoDate(todo, to: newDate)
                    hapticSuccessTrigger.toggle()
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingTodo, onDismiss: { showCategorySheet = false }) { todo in
                TodoEditSheet(
                    todo: todo,
                    categories: viewModel.activeCategories,
                    onSave: { updated in
                        viewModel.saveTodoEdit(updated)
                        hapticSuccessTrigger.toggle()
                    },
                    onDeleteTapped: { deletingTodo in
                        editingTodo = nil
                        viewModel.requestEditDelete(deletingTodo)
                    }
                )
                .presentationDragIndicator(.visible)
            }
            .alert("이 할일을 삭제할까요?", isPresented: $viewModel.showEditDeleteAlert) {
                Button("삭제", role: .destructive) { viewModel.confirmEditDelete() }
                Button("취소", role: .cancel) { viewModel.cancelEditDelete() }
            }
            .alert("읽기 전용 플래너", isPresented: $viewModel.showReadOnlyAlert) {
                Button("확인", role: .cancel) { viewModel.cancelReadOnlyAlert() }
            } message: {
                Text("이 플래너는 읽기 전용입니다. Pro 구독 시 다시 활성화됩니다.")
            }
            .sheet(isPresented: $showCategorySheet) {
                NavigationStack {
                    CategoryView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sensoryFeedback(.impact, trigger: hapticImpactTrigger)
            .sensoryFeedback(.success, trigger: hapticSuccessTrigger)
            .sensoryFeedback(.warning, trigger: hapticWarningTrigger)
        }
    }

    // MARK: - 투두 행 빌더 (공통 스와이프 액션 포함)

    private func resetTodoNavigationToRoot() {
        tabCoordinator.selectedTab = .todo
        showViewOptions = false
        showPlannerSheet = false
        showQuickCapture = false
        showCategorySheet = false
        changingDateTodo = nil
        editingTodo = nil
        isAddingTodo = false
        newTodoTitle = ""
        viewModel.goToToday()
    }

    @ViewBuilder
    private func todoRows(for todos: [Todo]) -> some View {
        ForEach(todos) { todo in
            TodoRow(todo: todo, showMemo: viewModel.showMemo, onCheckboxTap: {
                viewModel.toggleTodo(todo)
                hapticSuccessTrigger.toggle()
            })
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.4) {
                editingTodo = todo
                hapticImpactTrigger.toggle()
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    viewModel.pinTodo(todo)
                    hapticImpactTrigger.toggle()
                } label: {
                    Image(systemName: todo.isPinned ? "pin.slash" : "pin")
                }
                .tint(todo.isPinned ? .gray : Color(red: 1, green: 0.584, blue: 0))
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    viewModel.requestDelete(todo)
                    hapticWarningTrigger.toggle()
                } label: {
                    Image(systemName: "trash")
                }
                Button {
                    changingDateTodo = todo
                } label: {
                    Image(systemName: "calendar")
                }
                .tint(Color(red: 1, green: 0.584, blue: 0))
                Button {
                    viewModel.moveToTomorrow(todo)
                } label: {
                    Image(systemName: "arrow.forward.folder")
                }
                .tint(.blue)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
        }
        .animation(.easeInOut(duration: 0.3), value: todos.map(\.id))
    }

    private var addTodoRow: some View {
        AddTodoRow(newTodoTitle: $newTodoTitle, isAdding: $isAddingTodo) {
            viewModel.addTodo(title: newTodoTitle, categoryId: viewModel.selectedCategoryFilter)
            newTodoTitle = ""
            hapticSuccessTrigger.toggle()
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
    }
}

// MARK: - 카테고리 필터 바

private struct CategoryFilterBar: View {
    let categories: [Category]
    @Binding var selectedId: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "전체", color: AppTheme.shared.accent, isSelected: selectedId == nil) {
                    selectedId = nil
                }
                ForEach(categories) { category in
                    FilterChip(
                        label: category.name,
                        color: Color(hex: category.colorHex),
                        isSelected: selectedId == category.id
                    ) {
                        selectedId = category.id
                    }
                }
            }
            .padding(.leading, 24)
            .padding(.trailing, 48)  // 그라데이션 영역 확보
            .padding(.vertical, 4)
        }
        // 우측 페이드 아웃 (스크롤 힌트)
        .overlay(alignment: .trailing) {
            LinearGradient(
                colors: [.clear, Color(.systemGroupedBackground)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 48)
            .allowsHitTesting(false)
        }
        .sensoryFeedback(.selection, trigger: selectedId)
    }
}

private struct FilterChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? color : color.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - 투두 행

private struct TodoRow: View {
    let todo: Todo
    let showMemo: Bool
    var onCheckboxTap: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(todo.isCompleted ? AppTheme.shared.accent : Color(.tertiaryLabel))
                .animation(.easeInOut(duration: 0.15), value: todo.isCompleted)
                .padding(.top, (showMemo && todo.memo != nil) ? 2 : 0)
                .contentShape(Rectangle())
                .onTapGesture { onCheckboxTap?() }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(todo.title)
                        .font(.body)
                        .strikethrough(todo.isCompleted)
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .animation(.easeInOut(duration: 0.15), value: todo.isCompleted)

                    if todo.isPinned {
                        ImportantTodoTag()
                    }
                }

                if showMemo, let memo = todo.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: showMemo)
    }
}

// MARK: - 투두 추가 행

private struct AddTodoRow: View {
    @Binding var newTodoTitle: String
    @Binding var isAdding: Bool
    let onAdd: () -> Void

    var body: some View {
        if isAdding {
            HStack(spacing: 12) {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(Color(.tertiaryLabel))
                // AutoFocusTextField(UITextField 기반) — SwiftUI TextField 사용 시 한글 자모음 분리 버그 방지
                AutoFocusTextField(
                    text: $newTodoTitle,
                    placeholder: "새 투두",
                    font: .systemFont(ofSize: 17),
                    onReturn: {
                        let trimmed = newTodoTitle.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { return false }
                        onAdd()
                        return true  // 포커스 유지 → textFieldShouldReturn이 tf.text="" 처리
                    },
                    onDismiss: {
                        isAdding = false
                    }
                )
                .frame(height: 36)
            }
        } else {
            Button { isAdding = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.shared.accent)
                    Text("투두 추가")
                        .font(.body)
                        .foregroundStyle(AppTheme.shared.accent)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 보기 옵션 팝오버

private struct ViewOptionsPopover: View {
    @Bindable var viewModel: TodoViewModel
    let onShowCategorySheet: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            optionRow(icon: "eye.slash", label: "완료된 할일 숨기기", isOn: viewModel.hideCompleted) {
                viewModel.hideCompleted.toggle()
            }
            Divider()
            optionRow(icon: "text.alignleft", label: "할일 메모 보기", isOn: viewModel.showMemo) {
                viewModel.showMemo.toggle()
            }
            Divider()

            Button(action: onShowCategorySheet) {
                HStack(spacing: 12) {
                    Image(systemName: "tag")
                        .font(.system(size: AppConstants.IconSize.menu))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text("카테고리 설정")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: AppConstants.IconSize.menu).bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(minWidth: 260)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func optionRow(icon: String, label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: AppConstants.IconSize.menu))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                checkmark(visible: isOn)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func checkmark(visible: Bool) -> some View {
        Image(systemName: "checkmark")
            .font(.system(size: AppConstants.IconSize.menu).bold())
            .foregroundStyle(AppTheme.shared.accent)
            .opacity(visible ? 1 : 0)
            .frame(width: 16)
    }
}

// MARK: - 플래너 선택 시트

private struct PlannerSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showAddPlanner = false
    @State private var showPaywall = false
    private var isPro: Bool { SubscriptionManager.shared.isPro }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(PlannerService.shared.store) { planner in
                        PlannerCard(
                            planner: planner,
                            isSelected: planner.id == PlannerService.shared.selectedPlannerId
                        ) {
                            PlannerService.shared.selectPlanner(planner)
                            dismiss()
                        }
                    }

                    Button {
                        guard isPro else { showPaywall = true; return }
                        showAddPlanner = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(isPro ? AppTheme.shared.accent : .secondary)
                            HStack(spacing: 6) {
                                Text("플래너 추가")
                                    .font(.subheadline)
                                    .foregroundStyle(isPro ? AppTheme.shared.accent : .secondary)
                                if !isPro { ProBadge() }
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color(.separator), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("플래너")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                        .toolbarPrimaryActionStyle()
                }
            }
        }
        .presentationDetents([.medium])
        .sheet(isPresented: $showAddPlanner) {
            PlannerAddView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(message: "멀티 플래너는 Pro 기능이에요")
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - 플래너 카드

private struct PlannerCard: View {
    let planner: Planner
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                PlannerIconView(
                    iconType: planner.iconType,
                    iconImageData: planner.iconImageData,
                    colorHex: planner.colorHex,
                    size: 48
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(planner.name)
                        .font(.body.bold())
                        .foregroundStyle(.primary)
                    Text(planner.isReadOnly ? "읽기 전용" : (planner.isNotionConnected ? "노션에 연결됨" : "로컬 저장"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.shared.accent)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? AppTheme.shared.accent : Color(.separator),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(planner.isReadOnly)
        .opacity(planner.isReadOnly ? 0.5 : 1.0)
    }
}

private var localizedCalendar: Calendar {
    var cal = Calendar.current
    let startWeekday = UserDefaults.standard.string(forKey: "startWeekday") ?? "월"
    cal.firstWeekday = startWeekday == "일" ? 1 : 2
    return cal
}

// MARK: - 날짜 피커 시트

private struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker("날짜 선택", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(AppTheme.shared.accent)
                .environment(\.calendar, localizedCalendar)
                .padding(.horizontal)
                .navigationTitle("날짜 선택")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                        .toolbarPrimaryActionStyle()
                    }
                }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 투두 날짜 변경 시트

private struct TodoDateChangeSheet: View {
    let initialDate: Date
    let onConfirm: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date

    init(initialDate: Date, onConfirm: @escaping (Date) -> Void) {
        self.initialDate = initialDate
        self.onConfirm = onConfirm
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: initialDate))
    }

    var body: some View {
        NavigationStack {
            DatePicker("날짜 선택", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(AppTheme.shared.accent)
                .environment(\.calendar, localizedCalendar)
                .padding(.horizontal)
                .navigationTitle("날짜 변경")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("취소") { dismiss() }
                            .toolbarSecondaryActionStyle()
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("완료") {
                            onConfirm(selectedDate)
                            dismiss()
                        }
                        .toolbarPrimaryActionStyle()
                    }
                }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 투두 편집 시트

private struct TodoEditSheet: View {
    let categories: [Category]
    let onSave: (Todo) -> Void
    let onDeleteTapped: ((Todo) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Todo
    @State private var showDatePicker = false

    init(todo: Todo, categories: [Category], onSave: @escaping (Todo) -> Void, onDeleteTapped: ((Todo) -> Void)? = nil) {
        self.categories = categories
        self.onSave = onSave
        self.onDeleteTapped = onDeleteTapped
        _draft = State(initialValue: todo)
    }

    private var isSaveEnabled: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TodoEditFormView(
                    title: $draft.title,
                    memo: Binding(
                        get: { draft.memo ?? "" },
                        set: { draft.memo = $0.isEmpty ? nil : $0 }
                    ),
                    categoryId: $draft.categoryId,
                    date: $draft.date,
                    showDatePicker: $showDatePicker,
                    scheduledTime: $draft.scheduledTime,
                    alarmOffset: $draft.alarmOffset,
                    categories: categories,
                    autoFocus: false
                )

                if onDeleteTapped != nil {
                    Section {
                        Button("삭제") {
                            onDeleteTapped?(draft)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소", role: .cancel) { dismiss() }
                        .toolbarSecondaryActionStyle()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        let trimmed = draft.title.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        var saved = draft
                        saved.title = trimmed
                        saved.date = Calendar.current.startOfDay(for: draft.date)
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(!isSaveEnabled)
                    .toolbarPrimaryActionStyle(isEnabled: isSaveEnabled)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - 플로팅 캡처 버튼

private struct FloatingCaptureButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(AppTheme.shared.accent)
                .clipShape(Circle())
                .shadow(color: AppTheme.shared.accent.opacity(0.4), radius: 8, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
}
