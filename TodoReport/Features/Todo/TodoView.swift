import SwiftUI

struct TodoView: View {
    @Environment(MainTabCoordinator.self) private var tabCoordinator
    @State private var viewModel = TodoViewModel()
    @State private var dailyReportViewModel = DailyReportViewModel()
    @State private var newTodoTitle: String = ""
    @State private var isAddingTodo: Bool = false
    @State private var showPlannerSheet: Bool = false
    @State private var showQuickCapture: Bool = false
    @State private var changingDateTodo: Todo? = nil
    @State private var editingTodo: Todo? = nil
    @State private var inlineEditingTodoId: String? = nil
    @State private var showCategorySheet: Bool = false

    @State private var hapticImpactTrigger = false
    @State private var hapticSuccessTrigger = false
    @State private var hapticWarningTrigger = false
    @State private var showCalendarOpenHint = false
    @AppStorage("hasSeenCalendarOpenHint") private var hasSeenCalendarOpenHint = false
    @State private var showDailyReportExpandHint = false
    @AppStorage("hasSeenDailyReportExpandHint_v2") private var hasSeenDailyReportExpandHint = false
    @State private var showInlineEditHint = false
    @AppStorage("hasSeenInlineEditHint") private var hasSeenInlineEditHint = false
    @AppStorage("lastSeenWhatsNewVersion") private var lastSeenWhatsNewVersion = ""
    @State private var allChipColorHex: String = AllChipColorStore.hex(
        for: PlannerService.shared.selectedPlanner?.id
    )

    private var formattedDate: String {
        let cal = Calendar.current
        let date = viewModel.selectedDate
        let base = AppDateFormat.todoNavigationBase(date, includeWeekday: true)
        if cal.isDateInToday(date)     { return String(localized: "오늘, \(base)") }
        if cal.isDateInYesterday(date) { return String(localized: "어제, \(base)") }
        if cal.isDateInTomorrow(date)  { return String(localized: "내일, \(base)") }
        return base
    }

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            todoRootContent
                .background(Color(.systemGroupedBackground))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { todoToolbar(vm: vm) }
                .modifier(TodoViewSheetsModifier(
                    viewModel: viewModel,
                    showPlannerSheet: $showPlannerSheet,
                    showQuickCapture: $showQuickCapture,
                    showCategorySheet: $showCategorySheet,
                    changingDateTodo: $changingDateTodo,
                    editingTodo: $editingTodo,
                    hapticSuccessTrigger: $hapticSuccessTrigger,
                    onCategoryDismiss: refreshAllChipColor
                ))
                .modifier(TodoViewAlertsModifier(viewModel: viewModel))
                .sensoryFeedback(.impact, trigger: hapticImpactTrigger)
                .sensoryFeedback(.success, trigger: hapticSuccessTrigger)
                .sensoryFeedback(.warning, trigger: hapticWarningTrigger)
        }
    }

    @ToolbarContentBuilder
    private func todoToolbar(vm: TodoViewModel) -> some ToolbarContent {
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
            Menu {
                Section {
                    Toggle(
                        "완료된 할일 보기",
                        isOn: Binding(
                            get: { !vm.hideCompleted },
                            set: { vm.hideCompleted = !$0 }
                        )
                    )
                    Toggle("할일 메모 보기", isOn: Binding(
                        get: { vm.showMemo },
                        set: { vm.showMemo = $0 }
                    ))
                    Toggle("설정 시간 보기", isOn: Binding(
                        get: { vm.showScheduledTime },
                        set: { vm.showScheduledTime = $0 }
                    ))
                }
                Section {
                    Button {
                        showCategorySheet = true
                    } label: {
                        Label("카테고리 설정", systemImage: "tag")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .tint(.primary)
        }
    }

    private var todoRootContent: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .bottomTrailing) {
                todoScrollList
                FloatingCaptureButton {
                    showQuickCapture = true
                }
            }

            if showCalendarOpenHint {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCalendarOpenHint = false
                        }
                    }
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 36)
                    calendarOpenHintBubble
                    Spacer(minLength: 0)
                }
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if showInlineEditHint {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissInlineEditHint()
                    }
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: inlineEditHintTopOffset)
                    HStack {
                        inlineEditHintBubble
                            .padding(.leading, 40)
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                }
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if showDailyReportExpandHint {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 78)
                    HStack {
                        Spacer()
                        dailyReportExpandHintBubble
                            .padding(.trailing, 28)
                    }
                    Spacer(minLength: 0)
                }
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            presentTodoHintsIfNeeded()
        }
        .onChange(of: viewModel.filteredTodos.count) { _, _ in
            presentInlineEditHintIfNeeded()
        }
        .onChange(of: lastSeenWhatsNewVersion) { _, _ in
            presentInlineEditHintIfNeeded()
        }
        .onChange(of: tabCoordinator.isWhatsNewPopupPresented) { _, presented in
            guard !presented else { return }
            presentTodoHintsIfNeeded()
        }
        .edgeSwipeNavigation(
            onPrev: { viewModel.requestPreviousDay() },
            onNext: { viewModel.requestNextDay() }
        )
    }

    private var todoScrollList: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    DailyReportCard(
                        viewModel: dailyReportViewModel,
                        date: viewModel.selectedDate,
                        completionRate: viewModel.completionRate,
                        displayRate: viewModel.filteredCompletionRate,
                        displayCompleted: viewModel.filteredCompletedCount,
                        displayTotal: viewModel.filteredTotalCount,
                        onFirstAppear: { presentDailyReportExpandHintIfNeeded() }
                    )
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(
                    top: 4,
                    leading: 16,
                    // 칩 있음: bottom(8)+chip.top(4)=12; chip.bottom(0)+할일 자체 여백(12)=12.
                    // 칩 없음: bottom 12 유지.
                    bottom: viewModel.activeCategories.isEmpty ? 12 : 8,
                    trailing: 16
                ))

                if !viewModel.activeCategories.isEmpty {
                    Section {
                        CategoryFilterBar(
                            categories: viewModel.activeCategories,
                            selectedId: Binding(
                                get: { viewModel.selectedCategoryFilter },
                                set: { viewModel.selectedCategoryFilter = $0 }
                            ),
                            allChipColor: Color(hex: allChipColorHex)
                        )
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0))
                }

                todoListSections
            }
            .environment(\.defaultMinListRowHeight, 0)
            .safeAreaBar(edge: .top, spacing: 0) {
                DateNavigationRow(
                    title: formattedDate,
                    onPrev: { viewModel.requestPreviousDay() },
                    onNext: { viewModel.requestNextDay() },
                    onTapTitle: { viewModel.requestDatePicker() },
                    showTodayButton: viewModel.canGoNextDay,
                    onGoToday: { viewModel.goToToday() }
                )
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
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
            .scrollEdgeEffectStyle(.soft, for: .top)
            .refreshable {
                await viewModel.refreshFromNotion()
                await dailyReportViewModel.fetchReport(for: viewModel.selectedDate, completionRate: viewModel.completionRate)
            }
            .onAppear {
                refreshAllChipColor()
                Task { await viewModel.onAppear() }
            }
            .onChange(of: tabCoordinator.selectedTab) { _, tab in
                if tab != .todo {
                    cleanupInlineAddingOnTabLeave()
                } else {
                    refreshAllChipColor()
                    presentTodoHintsIfNeeded()
                }
            }
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
                refreshAllChipColor()
                dailyReportViewModel.switchReport()
                Task {
                    await viewModel.switchPlanner()
                    await dailyReportViewModel.fetchReport(
                        for: viewModel.selectedDate,
                        completionRate: viewModel.completionRate
                    )
                }
            }
        }
    }

    private var calendarOpenHintBubble: some View {
        VStack(spacing: 0) {
            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.black)
                .offset(y: 2)

            Text("탭하면 달력을 볼 수 있어요")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    /// 투두 탭이 보이고 업데이트 팝업이 덮지 않을 때만 안내 말풍선 표시.
    private var canPresentTodoHints: Bool {
        tabCoordinator.selectedTab == .todo && !tabCoordinator.isWhatsNewPopupPresented
    }

    private func presentTodoHintsIfNeeded() {
        presentCalendarOpenHintIfNeeded()
        presentDailyReportExpandHintIfNeeded()
        presentInlineEditHintIfNeeded()
    }

    private func presentCalendarOpenHintIfNeeded() {
        guard !hasSeenCalendarOpenHint else { return }
        guard canPresentTodoHints else { return }
        guard !showCalendarOpenHint else { return }

        hasSeenCalendarOpenHint = true
        withAnimation(.easeInOut(duration: 0.2)) {
            showCalendarOpenHint = true
        }
    }

    /// 날짜행·리포트·칩 아래, 첫 할일 제목 근처.
    private var inlineEditHintTopOffset: CGFloat {
        var offset: CGFloat = 40 + 78
        if !viewModel.activeCategories.isEmpty {
            offset += 44
        }
        return offset
    }

    /// 업데이트 팝업을 본 뒤·할일이 있을 때만 1회. 신규 설치는 온보딩에서 선저장.
    private func presentInlineEditHintIfNeeded() {
        guard !hasSeenInlineEditHint else { return }
        guard canPresentTodoHints else { return }
        guard !viewModel.filteredTodos.isEmpty else { return }
        guard let latestId = whatsNewReleases.first?.id,
              lastSeenWhatsNewVersion == latestId else { return }
        guard !showInlineEditHint else { return }

        hasSeenInlineEditHint = true
        withAnimation(.easeInOut(duration: 0.2)) {
            showInlineEditHint = true
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                dismissInlineEditHint()
            }
        }
    }

    private func dismissInlineEditHint() {
        guard showInlineEditHint else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            showInlineEditHint = false
        }
    }

    private var inlineEditHintBubble: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("할 일 이름을 탭하면 바로 수정할 수 있어요")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.black)
                .rotationEffect(.degrees(180))
                .padding(.leading, 28)
                .offset(y: -2)
        }
    }

    private func presentDailyReportExpandHintIfNeeded() {
        guard !hasSeenDailyReportExpandHint else { return }
        guard canPresentTodoHints else { return }
        guard !showDailyReportExpandHint else { return }

        hasSeenDailyReportExpandHint = true
        withAnimation(.easeInOut(duration: 0.2)) {
            showDailyReportExpandHint = true
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDailyReportExpandHint = false
                }
            }
        }
    }

    private var dailyReportExpandHintBubble: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.black)
                .offset(y: 2)

            Text("탭하면 리포트를 펼쳐볼 수 있어요")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var emptyTodoListHint: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.secondary)
            VStack(spacing: 2) {
                Text("목록이 안 보이나요?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("위에서 아래로 당겨 새로고침해보세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    // MARK: - 투두 행 빌더 (공통 스와이프 액션 포함)

    private func resetTodoNavigationToRoot() {
        tabCoordinator.selectedTab = .todo
        showPlannerSheet = false
        showQuickCapture = false
        showCategorySheet = false
        changingDateTodo = nil
        editingTodo = nil
        inlineEditingTodoId = nil
        isAddingTodo = false
        newTodoTitle = ""
        viewModel.goToToday()
    }

    /// 탭 이탈 시 인라인 입력·first responder 잔류를 정리한다.
    private func cleanupInlineAddingOnTabLeave() {
        if isAddingTodo {
            isAddingTodo = false
            newTodoTitle = ""
        }
        inlineEditingTodoId = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func refreshAllChipColor() {
        allChipColorHex = AllChipColorStore.hex(for: PlannerService.shared.selectedPlanner?.id)
    }

    @ViewBuilder
    private var todoListSections: some View {
        if viewModel.showsTodoListLoading {
            Section {
                TodoListLoadingView()
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            Section {
                todoRows(for: viewModel.filteredTodos)
                addTodoRow
                    .id("addTodoRow")
                if viewModel.emptyStateKind == .notionPullHint {
                    emptyTodoListHint
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func performRowAction(_ kind: TodoRowActionKind, for todo: Todo) {
        switch kind {
        case .edit:
            editingTodo = todo
            hapticImpactTrigger.toggle()
        case .pin:
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.pinTodo(todo)
            }
            hapticImpactTrigger.toggle()
        case .moveToTomorrow:
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.moveToTomorrow(todo)
            }
        case .changeDate:
            changingDateTodo = todo
        case .delete:
            viewModel.requestDelete(todo)
            hapticWarningTrigger.toggle()
        }
    }

    private func commitInlineTitleEdit(todo: Todo, draft: String) {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != todo.title {
            viewModel.updateTodoTitle(todo, title: trimmed)
        }
        if inlineEditingTodoId == todo.id {
            inlineEditingTodoId = nil
        }
    }

    private func openDetailFromInline(todo: Todo, draft: String) {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        var toEdit = todo
        if !trimmed.isEmpty {
            toEdit.title = trimmed
            if trimmed != todo.title {
                viewModel.updateTodoTitle(todo, title: trimmed)
            }
        }
        inlineEditingTodoId = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        editingTodo = toEdit
        hapticImpactTrigger.toggle()
    }

    @ViewBuilder
    private func todoRows(for todos: [Todo]) -> some View {
        ForEach(todos) { todo in
            TodoInteractiveRow(
                todo: todo,
                showMemo: viewModel.showMemo,
                showScheduledTime: viewModel.showScheduledTime,
                isInlineEditing: inlineEditingTodoId == todo.id,
                onCheckboxTap: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.toggleTodo(todo)
                    }
                    hapticSuccessTrigger.toggle()
                },
                onStartInlineEdit: { inlineEditingTodoId = todo.id },
                onCommitInlineEdit: { draft in commitInlineTitleEdit(todo: todo, draft: draft) },
                onOpenDetailFromInline: { draft in openDetailFromInline(todo: todo, draft: draft) },
                onAction: { performRowAction($0, for: todo) }
            )
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
        // TodoRow와 동일한 세로 padding — defaultMinListRowHeight=0에서도 한 줄 할일과 높이 맞춤.
        .padding(.vertical, 8)
        .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
    }
}

// MARK: - TodoView presentation helpers

private struct TodoViewSheetsModifier: ViewModifier {
    @Bindable var viewModel: TodoViewModel
    @Binding var showPlannerSheet: Bool
    @Binding var showQuickCapture: Bool
    @Binding var showCategorySheet: Bool
    @Binding var changingDateTodo: Todo?
    @Binding var editingTodo: Todo?
    @Binding var hapticSuccessTrigger: Bool
    let onCategoryDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showDatePicker) {
                DatePickerSheet(selectedDate: Binding(
                    get: { viewModel.selectedDate },
                    set: { viewModel.selectedDate = $0 }
                ))
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPlannerSheet) {
                PlannerSelectionSheet()
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showQuickCapture) {
                QuickCaptureView(
                    defaultCategoryId: viewModel.selectedCategoryFilter,
                    initialDate: viewModel.selectedDate
                ) { title, memo, categoryId, date, scheduledTime, alarmOffset, recurrenceRule, recurrenceEndDate, recurrenceCount in
                    viewModel.addTodo(
                        title: title,
                        memo: memo,
                        categoryId: categoryId,
                        date: date,
                        scheduledTime: scheduledTime,
                        alarmOffset: alarmOffset,
                        recurrenceRule: recurrenceRule,
                        recurrenceEndDate: recurrenceEndDate,
                        recurrenceCount: recurrenceCount
                    )
                    hapticSuccessTrigger.toggle()
                }
                .presentationDragIndicator(.visible)
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
            .sheet(isPresented: $showCategorySheet, onDismiss: onCategoryDismiss) {
                NavigationStack {
                    CategoryView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
    }
}

private struct TodoViewAlertsModifier: ViewModifier {
    @Bindable var viewModel: TodoViewModel

    func body(content: Content) -> some View {
        content
            .alert("반복 투두 삭제", isPresented: $viewModel.showDeleteAlert) {
                Button("이 항목만 삭제", role: .destructive) { viewModel.confirmDeleteSingle() }
                Button("이후 항목 모두 삭제", role: .destructive) { viewModel.confirmDeleteFuture() }
                Button("취소", role: .cancel) { viewModel.cancelDelete() }
            } message: {
                Text("어떻게 삭제할까요?")
            }
            .alert("이 할 일을 삭제할까요?", isPresented: $viewModel.showSingleDeleteAlert) {
                Button("삭제", role: .destructive) { viewModel.confirmSingleDelete() }
                Button("취소", role: .cancel) { viewModel.cancelSingleDelete() }
            }
            .alert(viewModel.recurringEditAlertTitle, isPresented: $viewModel.showRecurringEditAlert) {
                Button(viewModel.recurringEditSingleLabel) { viewModel.confirmRecurringEditSingle() }
                Button(viewModel.recurringEditFutureLabel, role: .destructive) { viewModel.confirmRecurringEditFuture() }
                Button("취소", role: .cancel) { viewModel.cancelRecurringEdit() }
            } message: {
                Text("어떻게 변경할까요?")
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
            .alert("저장 실패", isPresented: $viewModel.showTodoSaveFailedAlert) {
                Button("확인", role: .cancel) { viewModel.cancelTodoSaveFailedAlert() }
            } message: {
                Text("할 일 저장에 실패했습니다. 다시 시도해 주세요.")
            }
    }
}

// MARK: - 투두 행 + 스와이프/메뉴

private struct TodoInteractiveRow: View {
    let todo: Todo
    let showMemo: Bool
    let showScheduledTime: Bool
    let isInlineEditing: Bool
    let onCheckboxTap: () -> Void
    let onStartInlineEdit: () -> Void
    let onCommitInlineEdit: (String) -> Void
    let onOpenDetailFromInline: (String) -> Void
    let onAction: (TodoRowActionKind) -> Void

    var body: some View {
        TodoRow(
            todo: todo,
            showMemo: showMemo,
            showScheduledTime: showScheduledTime,
            isInlineEditing: isInlineEditing,
            onCheckboxTap: onCheckboxTap,
            onStartInlineEdit: onStartInlineEdit,
            onCommitInlineEdit: onCommitInlineEdit,
            onOpenDetailFromInline: onOpenDetailFromInline
        )
        .id(todo.id)
        .contentShape(Rectangle())
        .modifier(TodoRowContextMenuModifier(
            enabled: !isInlineEditing,
            todo: todo,
            onAction: onAction
        ))
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            ForEach(TodoRowActionCatalog.leadingSwipeActions(for: todo)) { action in
                Button {
                    onAction(action.kind)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
                .tint(action.tint)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            ForEach(TodoRowActionCatalog.trailingSwipeActions(for: todo)) { action in
                Button(role: action.isDestructive ? .destructive : nil) {
                    onAction(action.kind)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
                .labelStyle(.iconOnly)
                .tint(action.isDestructive ? nil : action.tint)
            }
        }
    }
}

// MARK: - 카테고리 필터 바

private struct CategoryFilterBar: View {
    let categories: [Category]
    @Binding var selectedId: String?
    let allChipColor: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: String(localized: "전체"), color: allChipColor, isSelected: selectedId == nil) {
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
            .padding(.horizontal, 24)
            .padding(.vertical, 4)
        }
        .sensoryFeedback(.selection, trigger: selectedId)
    }
}

private struct FilterChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(
                    isSelected
                    ? color.readableForeground
                    : color.readableText(on: colorScheme)
                )
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

// MARK: - 투두 행 컨텍스트 메뉴

private struct TodoRowContextMenuModifier: ViewModifier {
    let enabled: Bool
    let todo: Todo
    let onAction: (TodoRowActionKind) -> Void

    func body(content: Content) -> some View {
        Group {
            if enabled {
                content.contextMenu {
                    ForEach(TodoRowActionCatalog.contextMenuActions(for: todo)) { action in
                        Button(role: action.isDestructive ? .destructive : nil) {
                            onAction(action.kind)
                        } label: {
                            Label(action.title, systemImage: action.systemImage)
                        }
                    }
                }
            } else {
                content
            }
        }
    }
}

// MARK: - 인라인 제목 편집

/// 생성 시점에 초기 제목을 주입해, 부모 `@State` 타이밍/`id` 교체로 필드가 비는 문제를 막는다.
private struct TodoInlineTitleEditor: View {
    @State private var draftTitle: String
    @State private var didCommit = false
    let onCommit: (String) -> Void
    let onOpenDetail: (String) -> Void

    init(
        initialTitle: String,
        onCommit: @escaping (String) -> Void,
        onOpenDetail: @escaping (String) -> Void
    ) {
        _draftTitle = State(initialValue: initialTitle)
        self.onCommit = onCommit
        self.onOpenDetail = onOpenDetail
    }

    private var firstLineHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight
    }

    var body: some View {
        AutoFocusTextField(
            text: $draftTitle,
            placeholder: "",
            textStyle: .body,
            contentVerticalAlignment: .center,
            onReturn: {
                commitOnce()
                return false
            },
            onDismiss: {
                commitOnce()
            },
            keyboardAccessoryTitle: String(localized: "자세히"),
            onKeyboardAccessory: {
                openDetailOnce()
            }
        )
        .frame(maxWidth: .infinity, minHeight: firstLineHeight, maxHeight: firstLineHeight, alignment: .leading)
        .layoutPriority(0)
    }

    private func commitOnce() {
        guard !didCommit else { return }
        didCommit = true
        onCommit(draftTitle)
    }

    private func openDetailOnce() {
        guard !didCommit else { return }
        didCommit = true
        onOpenDetail(draftTitle)
    }
}

/// 시간 태그 색 — 고정(오렌지)과 구분. 제목(primary)보다 약하고 secondary보다 진하게.
private enum TodoScheduledTimeTagStyle {
    static var foreground: Color { Color.primary.opacity(0.62) }
    static var background: Color { Color(.secondarySystemGroupedBackground) }
    /// 완료 행에서 태그가 튀지 않도록.
    static let completedOpacity: Double = 0.45
}

// MARK: - 투두 행

private struct TodoRow: View {
    let todo: Todo
    let showMemo: Bool
    let showScheduledTime: Bool
    let isInlineEditing: Bool
    var onCheckboxTap: (() -> Void)? = nil
    var onStartInlineEdit: (() -> Void)? = nil
    var onCommitInlineEdit: ((String) -> Void)? = nil
    var onOpenDetailFromInline: ((String) -> Void)? = nil

    /// 완료 체크 채움 — accent보다 시선을 덜 끌도록 투명도 적용.
    private let completedCheckboxOpacity: Double = 0.55

    /// 제목 첫 줄 높이 — 체크박스·태그·인라인 편집 공통 기준.
    private var firstLineHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            checkbox

            VStack(alignment: .leading, spacing: 6) {
                titleArea

                if showMemo, let memo = todo.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // defaultMinListRowHeight=0 전제 — List 최소 높이 보정 없이 이 padding만으로 위아래 여백 결정.
        // 이전 한 줄 행(최소 높이 44 중앙 정렬)과 비슷한 체감: insets(4)+padding(8)=12.
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.2), value: showMemo)
        .animation(.easeInOut(duration: 0.2), value: showScheduledTime)
    }

    @ViewBuilder
    private var titleArea: some View {
        if isInlineEditing {
            titleRow
        } else {
            titleRow
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(rowAccessibilityLabel)
        }
    }

    private var checkbox: some View {
        Button {
            onCheckboxTap?()
        } label: {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(checkboxForeground)
                .frame(height: firstLineHeight)
                .animation(.easeInOut(duration: 0.15), value: todo.isCompleted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "완료 토글"))
        .accessibilityValue(
            todo.isCompleted
            ? String(localized: "완료됨")
            : String(localized: "미완료")
        )
        .accessibilityAddTraits(.isButton)
    }

    private var checkboxForeground: Color {
        if todo.isCompleted {
            return AppTheme.shared.accent.opacity(completedCheckboxOpacity)
        }
        return Color(.tertiaryLabel)
    }

    @ViewBuilder
    private var titleRow: some View {
        HStack(alignment: .top, spacing: 6) {
            if isInlineEditing {
                TodoInlineTitleEditor(
                    initialTitle: todo.title,
                    onCommit: { onCommitInlineEdit?($0) },
                    onOpenDetail: { onOpenDetailFromInline?($0) }
                )
                .id(todo.id)
            } else {
                titleLabel
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onStartInlineEdit?()
                    }
                    .animation(.easeInOut(duration: 0.15), value: todo.isCompleted)
            }

            // 인라인 편집 중에는 제목이 TextField라 핀을 옆에 따로 둔다.
            if isInlineEditing, todo.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.shared.accent)
                    .opacity(todo.isCompleted ? completedCheckboxOpacity : 1)
                    .frame(height: firstLineHeight)
                    .layoutPriority(1)
                    .accessibilityHidden(true)
            }

            // 제목·핀 | 남는 공간 | 시간 태그(trailing)
            if showScheduledTime, todo.scheduledTime != nil {
                Spacer(minLength: 0)
            } else if !isInlineEditing {
                Spacer(minLength: 0)
            }

            if showScheduledTime, let scheduledTime = todo.scheduledTime {
                scheduledTimeTag(scheduledTime)
                    .frame(height: firstLineHeight)
                    .layoutPriority(1)
            }
        }
    }

    /// 일반 표시: 핀을 제목 Text 뒤에 붙여 줄바꿈 시에도 글자 옆에 붙게 한다.
    private var titleLabel: Text {
        let title = Text(todo.title)
            .font(.body)
            .strikethrough(todo.isCompleted)
            .foregroundStyle(todo.isCompleted ? Color.secondary : Color.primary)

        guard todo.isPinned else { return title }

        let pin = Text(Image(systemName: "pin.fill"))
            .font(.caption)
            .foregroundStyle(
                AppTheme.shared.accent.opacity(todo.isCompleted ? completedCheckboxOpacity : 1)
            )

        return title + Text(" ") + pin
    }

    @ViewBuilder
    private func scheduledTimeTag(_ scheduledTime: Date) -> some View {
        let hasAlarm = todo.alarmOffset != nil
        HStack(spacing: 3) {
            Image(systemName: "clock")
                .font(.caption2)
                .accessibilityHidden(true)
            Text(scheduledTime, format: .dateTime.hour().minute())
                .font(.caption2)
                .monospacedDigit()
            if hasAlarm {
                Image(systemName: "bell")
                    .font(.caption2)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(TodoScheduledTimeTagStyle.foreground)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            TodoScheduledTimeTagStyle.background,
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
        .opacity(todo.isCompleted ? TodoScheduledTimeTagStyle.completedOpacity : 1)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityHidden(true)
    }

    private var rowAccessibilityLabel: String {
        var parts: [String] = [todo.title]
        if todo.isPinned {
            parts.append(String(localized: "고정됨"))
        }
        if todo.isCompleted {
            parts.append(String(localized: "완료됨"))
        }
        if showScheduledTime, let scheduledTime = todo.scheduledTime {
            let timeText = scheduledTime.formatted(date: .omitted, time: .shortened)
            if todo.alarmOffset != nil {
                parts.append(String(localized: "\(timeText), 알림 있음"))
            } else {
                parts.append(timeText)
            }
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - 투두 추가 행

private struct AddTodoRow: View {
    @Binding var newTodoTitle: String
    @Binding var isAdding: Bool
    let onAdd: () -> Void
    /// 추가 버튼을 누를 때마다 갱신 → AutoFocusTextField가 fresh 인스턴스로 다시 만들어짐.
    @State private var focusEpoch = UUID()

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
                .id(focusEpoch)
                .frame(height: 36)
            }
        } else {
            Button {
                focusEpoch = UUID()
                isAdding = true
            } label: {
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
            PaywallView(message: String(localized: "멀티 플래너는 Pro 기능이에요"))
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

private var localizedCalendar: Calendar { AppCalendar.localized }

// MARK: - 날짜 피커 시트

private struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    @State private var focusedDate: Date?
    @State private var showMoveHint = false
    @AppStorage("hasSeenCalendarMoveHint") private var hasSeenCalendarMoveHint = false

    init(selectedDate: Binding<Date>) {
        _selectedDate = selectedDate
        _focusedDate = State(initialValue: nil)
    }

    private var hasFocusedDate: Bool { focusedDate != nil }

    var body: some View {
        NavigationStack {
            MonthCalendarView(
                focusedDate: $focusedDate,
                onConfirmDate: { date in
                    selectedDate = date
                    dismiss()
                }
            )
            .padding(.horizontal)
            .padding(.top, 4)
            .overlay(alignment: .topTrailing) {
                if showMoveHint {
                    calendarMoveHintBubble
                        .padding(.trailing, 4)
                        .padding(.top, 2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .navigationTitle("달력 보기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let focusedDate else { return }
                        selectedDate = focusedDate
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(hasFocusedDate ? Color.nockOrange : Color(.tertiaryLabel))
                    }
                }
            }
        }
        .presentationDetents([.large])
        .onChange(of: focusedDate) { oldValue, newValue in
            guard oldValue == nil, newValue != nil, !hasSeenCalendarMoveHint else { return }
            hasSeenCalendarMoveHint = true
            withAnimation(.easeInOut(duration: 0.2)) {
                showMoveHint = true
            }
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showMoveHint = false
                    }
                }
            }
        }
    }

    private var calendarMoveHintBubble: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.black)
                .rotationEffect(.degrees(180))
                .padding(.trailing, 14)

            Text("선택한 날짜로 이동해요")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .allowsHitTesting(false)
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
                        TodoScheduledTime.applyingDateChange(to: &saved, newDate: draft.date)
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
