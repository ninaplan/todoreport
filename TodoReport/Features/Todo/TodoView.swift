import SwiftUI

struct TodoView: View {
    @Environment(MainTabCoordinator.self) private var tabCoordinator
    @State private var viewModel = TodoViewModel()
    @State private var dailyReportViewModel = DailyReportViewModel()
    @State private var newTodoTitle: String = ""
    @State private var isAddingTodo: Bool = false
    /// ⋯ 「순서 바꾸기」 — 켜면 줄 오른쪽 손잡이로 끌어 옮긴다 (길게 눌러 끌기는 메뉴와 부딪혀 폐기)
    @State private var isReordering = false
    @State private var showPlannerSheet: Bool = false
    @State private var showQuickCapture: Bool = false
    @State private var changingDateTodo: Todo? = nil
    @State private var editingTodo: Todo? = nil
    @State private var inlineEditingTodoId: String? = nil
    @State private var showCategorySheet: Bool = false
    @State private var showInboxSheet: Bool = false
    @State private var inboxSheetHighlightTodoId: String? = nil
    @State private var inboxBadgeCount: Int = 0
    @State private var highlightedTodoId: String? = nil
    @State private var highlightScrollTask: Task<Void, Never>? = nil

    @State private var hapticImpactTrigger = false
    /// 하루 리포트 카드의 집중 시간(분). Pro이고 그날 완료한 블록이 있을 때만 값이 있다
    @State private var dailyFocusMinutes: Int?
    @State private var hapticSuccessTrigger = false
    @State private var hapticWarningTrigger = false
    @State private var showCalendarOpenHint = false
    @AppStorage("hasSeenCalendarOpenHint") private var hasSeenCalendarOpenHint = false
    @State private var showDailyReportExpandHint = false
    @AppStorage("hasSeenDailyReportExpandHint_v2") private var hasSeenDailyReportExpandHint = false
    @State private var showInlineEditHint = false
    @AppStorage("hasSeenInlineEditHint") private var hasSeenInlineEditHint = false
    @AppStorage("lastSeenWhatsNewVersion") private var lastSeenWhatsNewVersion = ""

    /// 투두 탭 다시 탭 시 스크롤 목적지 (목록 맨 위 하루 리포트 카드)
    private static let listTopId = "todoListTop"

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
                    showInboxSheet: $showInboxSheet,
                    inboxHighlightTodoId: inboxSheetHighlightTodoId,
                    changingDateTodo: $changingDateTodo,
                    editingTodo: $editingTodo,
                    hapticSuccessTrigger: $hapticSuccessTrigger,
                    onInboxDismiss: {
                        inboxSheetHighlightTodoId = nil
                        refreshInboxBadge()
                        Task { await viewModel.fetchLocalTodos() }
                    }
                ))
                .modifier(TodoViewAlertsModifier(viewModel: viewModel))
                .sensoryFeedback(.impact, trigger: hapticImpactTrigger)
                .sensoryFeedback(.success, trigger: hapticSuccessTrigger)
                .sensoryFeedback(.warning, trigger: hapticWarningTrigger)
                .onAppear { refreshInboxBadge() }
        }
    }

    private func refreshInboxBadge() {
        inboxBadgeCount = TodoService.shared.inboxNowCount()
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
        if isReordering {
            ToolbarItem(placement: .topBarTrailing) {
                Button("완료") {
                    withAnimation { isReordering = false }
                }
                .fontWeight(.semibold)
                .tint(.primary)
            }
        } else {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showInboxSheet = true
            } label: {
                Image(systemName: "tray")
                    .frame(width: 44, height: 36)
                    .overlay(alignment: .topTrailing) {
                        if inboxBadgeCount > 0 {
                            Text(inboxBadgeCount > 99 ? "99+" : "\(inboxBadgeCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, inboxBadgeCount > 9 ? 4 : 5)
                                .padding(.vertical, 1)
                                .background(AppTheme.shared.accent, in: Capsule())
                                .padding([.top, .trailing], 1)
                                .offset(x: 1, y: -1)
                        }
                    }
            }
            .accessibilityLabel(String(localized: "수집함"))
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
                    Toggle("카테고리 아이콘으로 보기", isOn: Binding(
                        get: { vm.showCategoryChipIcon },
                        set: { vm.showCategoryChipIcon = $0 }
                    ))
                }
                Section {
                    Button {
                        withAnimation { isReordering = true }
                    } label: {
                        Label("순서 바꾸기", systemImage: "arrow.up.arrow.down")
                    }
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
    }

    private var todoRootContent: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .bottomTrailing) {
                todoScrollList
                    // 「순서 바꾸기」 중에만 편집 모드 → 줄 오른쪽에 손잡이 (스와이프는 이 동안 꺼짐)
                    .environment(\.editMode, .constant(isReordering ? .active : .inactive))
                    // 「실행 취소」 배너 — 오른쪽 아래 + 버튼(48pt + 여백 20) 왼쪽에, 버튼과 세로 가운데를 맞춘다
                    .undoBannerHost(.todo, trailingInset: 80, bottomInset: 20)
                if !isReordering {
                    FloatingCaptureButton {
                        showQuickCapture = true
                    }
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
        .tapToDismissKeyboard()
    }

    private var todoScrollList: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    DailyReportCard(
                        viewModel: dailyReportViewModel,
                        date: viewModel.selectedDate,
                        completionRate: viewModel.completionRate,
                        displayRate: viewModel.completionRate,
                        displayCompleted: viewModel.completedCount,
                        displayTotal: viewModel.totalCount,
                        onFirstAppear: { presentDailyReportExpandHintIfNeeded() },
                        expandToken: tabCoordinator.expandDailyReportToken,
                        focusMinutes: dailyFocusMinutes
                    )
                    // 날짜·완료 수가 바뀌거나 탭으로 돌아오면 다시 계산 (타임블록에서 완료했을 수 있음)
                    .task(id: dailyFocusRefreshKey) {
                        refreshDailyFocusMinutes()
                    }
                    .id(Self.listTopId)
                }
                .daySlide(viewModel.daySlide)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(
                    top: 4,
                    leading: 16,
                    // 칩 있음: bottom(8)+chip.top(4)=12; chip.bottom(8)+할일 여백(9)=17.
                    // 칩 없음: bottom 16 + 할일 여백(9)=25.
                    bottom: viewModel.activeCategories.isEmpty ? 16 : 8,
                    trailing: 16
                ))

                if !viewModel.activeCategories.isEmpty {
                    Section {
                        CategoryFilterBar(
                            categories: viewModel.activeCategories,
                            selectedIds: viewModel.effectiveCategoryFilter,
                            peekCategoryId: viewModel.peekCategoryId,
                            showCategoryChipIcon: viewModel.showCategoryChipIcon,
                            onPeek: { viewModel.peekCategory($0) },
                            onClearPeek: { viewModel.clearCategoryPeek() },
                            onClear: { viewModel.clearCategoryFilter() },
                            onToggle: { viewModel.toggleCategoryFilter($0) },
                            keepsFilter: viewModel.keepsCategoryFilter,
                            onSetKeepsFilter: { viewModel.setKeepsCategoryFilter($0) }
                        )
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
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
                consumePendingTodoNavigation(proxy: proxy)
                Task { await viewModel.onAppear() }
            }
            .onChange(of: tabCoordinator.selectedTab) { _, tab in
                if tab != .todo {
                    cleanupInlineAddingOnTabLeave()
                    isReordering = false
                } else {
                    presentTodoHintsIfNeeded()
                    consumePendingTodoNavigation(proxy: proxy)
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
            .alert("반복 할 일은 그날 만들어집니다.", isPresented: Binding(
                get: { viewModel.showRecurringPreviewInfo },
                set: { if !$0 { viewModel.cancelRecurringPreviewInfo() } }
            )) {
                Button("확인", role: .cancel) { viewModel.confirmRecurringPreviewInfo() }
            } message: {
                Text("미리 완료하거나 수정할 수 없습니다.")
            }
            .onChange(of: tabCoordinator.todoRootResetToken) { _, _ in
                resetTodoNavigationToRoot()
            }
            // 투두 탭을 다시 탭 → 오늘로 + 목록 맨 위로
            .onChange(of: tabCoordinator.todoReselectToken) { _, _ in
                viewModel.goToToday()
                withAnimation { proxy.scrollTo(Self.listTopId, anchor: .top) }
            }
            .onChange(of: tabCoordinator.pendingTodoDate) { _, _ in
                consumePendingTodoNavigation(proxy: proxy)
            }
            .onChange(of: tabCoordinator.pendingHighlightTodoId) { _, _ in
                consumePendingTodoNavigation(proxy: proxy)
            }
            .onChange(of: tabCoordinator.pendingInboxHighlightTodoId) { _, _ in
                consumePendingInboxNavigation()
            }
            .onChange(of: PlannerService.shared.selectedPlannerId) { _, _ in
                dailyReportViewModel.switchReport()
                refreshInboxBadge()
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
        // 탭은 시작 화면 설정을 따른다 (타임블록으로 정했으면 타임블록)
        tabCoordinator.openLaunchTab()
        showPlannerSheet = false
        showQuickCapture = false
        showCategorySheet = false
        changingDateTodo = nil
        editingTodo = nil
        inlineEditingTodoId = nil
        isAddingTodo = false
        newTodoTitle = ""
        showInboxSheet = false
        inboxSheetHighlightTodoId = nil
        viewModel.goToToday()
        highlightedTodoId = nil
        highlightScrollTask?.cancel()
        highlightScrollTask = nil
        viewModel.clearNavigationReveal()
    }

    private func consumePendingTodoNavigation(proxy: ScrollViewProxy) {
        if let id = tabCoordinator.pendingHighlightTodoId {
            viewModel.prepareRevealForNavigation(todoId: id)
            highlightedTodoId = id
            tabCoordinator.clearPendingHighlightTodoId()
            startHighlightScroll(proxy: proxy, todoId: id)
        }
        if let date = tabCoordinator.pendingTodoDate {
            viewModel.navigateToDate(date)
            tabCoordinator.clearPendingTodoDate()
        }
    }

    private func consumePendingInboxNavigation() {
        guard let id = tabCoordinator.pendingInboxHighlightTodoId else { return }
        inboxSheetHighlightTodoId = id
        tabCoordinator.clearPendingInboxHighlightTodoId()
        showInboxSheet = true
    }

    private func startHighlightScroll(proxy: ScrollViewProxy, todoId: String) {
        highlightScrollTask?.cancel()
        highlightScrollTask = Task { @MainActor in
            for _ in 0..<25 {
                if Task.isCancelled { return }
                if viewModel.filteredTodos.contains(where: { $0.id == todoId }) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(todoId, anchor: .center)
                    }
                    try? await Task.sleep(for: .seconds(1.2))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        if highlightedTodoId == todoId {
                            highlightedTodoId = nil
                        }
                    }
                    viewModel.clearNavigationReveal()
                    return
                }
                try? await Task.sleep(for: .milliseconds(120))
            }
            if highlightedTodoId == todoId {
                highlightedTodoId = nil
            }
            viewModel.clearNavigationReveal()
        }
    }

    /// 탭 이탈 시 인라인 입력·first responder 잔류를 정리한다.
    private func cleanupInlineAddingOnTabLeave() {
        // resign 먼저 → AddTodoRow.onDismiss가 초안을 저장한 뒤 isAdding을 내린다.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        if isAddingTodo {
            isAddingTodo = false
            newTodoTitle = ""
        }
        inlineEditingTodoId = nil
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
                // 미래 날짜: 아직 만들어지지 않은 반복 할 일 미리보기 (탭하면 안내만)
                ForEach(viewModel.visibleRecurringPreviews) { preview in
                    RecurringPreviewRow(preview: preview)
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.tapRecurringPreview() }
                        .daySlide(viewModel.daySlide)
                        .listRowInsets(TodoListRowSpacing.listRowInsets)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                addTodoRow
                    .daySlide(viewModel.daySlide)
                    .id("addTodoRow")
                if viewModel.emptyStateKind == .notionPullHint {
                    emptyTodoListHint
                        .daySlide(viewModel.daySlide)
                }
                Color.clear.frame(height: 120)
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
        case .sendToInbox:
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.sendToInbox(todo)
            }
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
                isReordering: isReordering,
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
            // 순서 바꾸는 동안 체크·제목 고치기·메뉴는 막는다 (손잡이는 줄 밖이라 그대로 동작)
            .allowsHitTesting(!isReordering)
            // 완료한 할 일·제목 고치는 중에는 끌어 옮기지 않음
            .moveDisabled(todo.isCompleted || inlineEditingTodoId != nil)
            // 날짜를 넘길 때 줄마다 옆에서 밀려 들어옴 (Section에 붙이면 할 일 줄까지 안 닿아서 줄에 직접)
            .daySlide(viewModel.daySlide)
            .id(todo.id)
            .listRowInsets(TodoListRowSpacing.listRowInsets)
            .listRowBackground(
                highlightedTodoId == todo.id
                    ? AppTheme.shared.accent.opacity(0.14)
                    : Color.clear
            )
        }
        // 「순서 바꾸기」 중에만 끌어 옮기기. 평소에 켜 두면 길게 누르기 메뉴와 부딪힌다
        .onMove(perform: isReordering ? { source, destination in
            viewModel.moveTodos(from: source, to: destination)
        } : nil)
        // 같은 날 추가·삭제는 기존처럼 페이드, 날짜가 바뀐 직후엔 끄고 슬라이드만 (둘이 겹치면 슬라이드가 안 보임)
        .animation(viewModel.daySlide.isRecent ? nil : .easeInOut(duration: 0.3), value: todos.map(\.id))
    }

    private var addTodoRow: some View {
        AddTodoRow(newTodoTitle: $newTodoTitle, isAdding: $isAddingTodo) {
            viewModel.addTodo(title: newTodoTitle, categoryId: viewModel.defaultCategoryIdForNewTodo)
            newTodoTitle = ""
            hapticSuccessTrigger.toggle()
        }
        // TodoRow와 동일한 세로 padding — defaultMinListRowHeight=0에서도 한 줄 할일과 높이 맞춤.
        .padding(.vertical, TodoListRowSpacing.verticalPadding)
        .listRowInsets(TodoListRowSpacing.listRowInsets)
    }

    // MARK: - 하루 리포트 집중 시간

    private var dailyFocusRefreshKey: String {
        "\(viewModel.selectedDate.timeIntervalSince1970)-\(viewModel.completedCount)-\(tabCoordinator.selectedTab == .todo)-\(SubscriptionManager.shared.isPro)"
    }

    /// 집중 시간은 Pro 기능 → 무료면 숨김. 완료한 블록이 없는 날도 숨김
    private func refreshDailyFocusMinutes() {
        guard SubscriptionManager.shared.isPro else {
            dailyFocusMinutes = nil
            return
        }
        let minutes = TimeBlockService.shared.completedMinutes(on: viewModel.selectedDate)
        dailyFocusMinutes = minutes > 0 ? minutes : nil
    }
}

// MARK: - TodoView presentation helpers

private struct TodoViewSheetsModifier: ViewModifier {
    @Bindable var viewModel: TodoViewModel
    @Binding var showPlannerSheet: Bool
    @Binding var showQuickCapture: Bool
    @Binding var showCategorySheet: Bool
    @Binding var showInboxSheet: Bool
    var inboxHighlightTodoId: String? = nil
    @Binding var changingDateTodo: Todo?
    @Binding var editingTodo: Todo?
    @Binding var hapticSuccessTrigger: Bool
    let onInboxDismiss: () -> Void

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
            .sheet(isPresented: $showQuickCapture, onDismiss: onInboxDismiss) {
                QuickCaptureView(
                    defaultCategoryId: viewModel.defaultCategoryIdForNewTodo,
                    initialDate: viewModel.selectedDate
                ) { title, memo, categoryId, date, scheduledTime, alarmOffset, recurrenceRule, recurrenceEndDate, recurrenceCount in
                    if let date {
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
                    } else {
                        viewModel.addInboxTodo(
                            title: title,
                            memo: memo,
                            categoryId: categoryId
                        )
                    }
                    hapticSuccessTrigger.toggle()
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $changingDateTodo) { todo in
                TodoDateChangeSheet(initialDate: todo.date ?? Calendar.current.startOfDay(for: .now)) { newDate in
                    viewModel.changeTodoDate(todo, to: newDate)
                    hapticSuccessTrigger.toggle()
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingTodo, onDismiss: {
                showCategorySheet = false
                onInboxDismiss()
            }) { todo in
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
            .sheet(isPresented: $showCategorySheet) {
                NavigationStack {
                    CategoryView(presentsAsSheet: true)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showInboxSheet, onDismiss: onInboxDismiss) {
                NavigationStack {
                    InboxView(highlightTodoId: inboxHighlightTodoId)
                        .id(inboxHighlightTodoId ?? "inbox-tray")
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $viewModel.showCategoryFilterPaywall, onDismiss: {
                viewModel.dismissCategoryFilterPaywall()
            }) {
                PaywallView(message: String(localized: "여러 카테고리 보기는 Pro 기능입니다."))
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
            .alert(viewModel.recurringEditAlertTitle, isPresented: $viewModel.showRecurringEditAlert) {
                Button(viewModel.recurringEditSingleLabel) { viewModel.confirmRecurringEditSingle() }
                Button(viewModel.recurringEditFutureLabel, role: .destructive) { viewModel.confirmRecurringEditFuture() }
                Button("취소", role: .cancel) { viewModel.cancelRecurringEdit() }
            } message: {
                Text(viewModel.recurringEditAlertMessage)
            }
            .alert("수집함으로 보내기", isPresented: $viewModel.showSendRecurringToInboxAlert) {
                Button("이 할일만 보내기") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.confirmSendRecurringToInboxSingle()
                    }
                }
                Button("이후 반복 모두 해제하고 보내기", role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.confirmSendRecurringToInboxFuture()
                    }
                }
                Button("취소", role: .cancel) { viewModel.cancelSendRecurringToInbox() }
            } message: {
                Text("이 할일만 보낼지, 이후 반복을 모두 해제하고 보낼지 선택해 주세요.")
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
    /// 「순서 바꾸기」 중이면 길게 누르기 메뉴를 끈다 (메뉴와 끌기가 같이 일어남)
    let isReordering: Bool
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
            enabled: !isInlineEditing && !isReordering,
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
                .labelStyle(.iconOnly)
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
    let selectedIds: Set<String>
    let peekCategoryId: String?
    let showCategoryChipIcon: Bool
    let onPeek: (String) -> Void
    let onClearPeek: () -> Void
    let onClear: () -> Void
    let onToggle: (String) -> Void
    let keepsFilter: Bool
    let onSetKeepsFilter: (Bool) -> Void

    private var isPeeking: Bool { peekCategoryId != nil }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterControl

                ForEach(categories) { category in
                    FilterChip(
                        label: category.name,
                        systemImage: CategoryIconName.resolved(category.icon),
                        showsIcon: showCategoryChipIcon,
                        color: Color(hex: category.colorHex),
                        isSelected: peekCategoryId == category.id,
                        isInFilter: selectedIds.contains(category.id)
                    ) {
                        onPeek(category.id)
                    }
                }

                FilterChip(
                    label: String(localized: "미분류"),
                    systemImage: "tag.slash",
                    showsIcon: showCategoryChipIcon,
                    color: Color(.tertiaryLabel),
                    isSelected: peekCategoryId == TodoViewModel.uncategorizedFilterId,
                    isInFilter: selectedIds.contains(TodoViewModel.uncategorizedFilterId)
                ) {
                    onPeek(TodoViewModel.uncategorizedFilterId)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 4)
        }
        .sensoryFeedback(.selection, trigger: selectedIds)
        .sensoryFeedback(.selection, trigger: peekCategoryId)
    }

    @ViewBuilder
    private var filterControl: some View {
        if isPeeking {
            Button(action: onClearPeek) {
                filterIcon
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "잠깐 보기 종료"))
        } else {
            Menu {
                Toggle(isOn: Binding(
                    get: { selectedIds.isEmpty },
                    set: { isOn in
                        if isOn { onClear() }
                    }
                )) {
                    Text("전체")
                }

                ForEach(categories) { category in
                    Toggle(isOn: Binding(
                        get: { selectedIds.contains(category.id) },
                        set: { _ in onToggle(category.id) }
                    )) {
                        Text(category.name)
                    }
                    .menuActionDismissBehavior(.disabled)
                }

                Toggle(isOn: Binding(
                    get: { selectedIds.contains(TodoViewModel.uncategorizedFilterId) },
                    set: { _ in onToggle(TodoViewModel.uncategorizedFilterId) }
                )) {
                    Text("미분류")
                }
                .menuActionDismissBehavior(.disabled)

                Divider()

                Toggle(isOn: Binding(
                    get: { keepsFilter },
                    set: { onSetKeepsFilter($0) }
                )) {
                    Text("필터 기억하기")
                }
                .menuActionDismissBehavior(.disabled)
            } label: {
                filterIcon
            }
            .buttonStyle(.plain)
            .tint(.primary)
            .accessibilityLabel(String(localized: "카테고리 필터"))
        }
    }

    private var filterIcon: some View {
        Image(systemName: "line.3.horizontal.decrease")
            .font(.body.weight(.medium))
            .foregroundStyle(Color.primary)
            .frame(width: 32, height: 32)
            .overlay(alignment: .topTrailing) {
                if !selectedIds.isEmpty {
                    Circle()
                        .fill(AppTheme.shared.accent)
                        .frame(width: 6, height: 6)
                        .offset(x: -4, y: 4)
                }
            }
            .accessibilityHidden(true)
    }
}

private struct FilterChip: View {
    let label: String
    let systemImage: String
    let showsIcon: Bool
    let color: Color
    let isSelected: Bool
    let isInFilter: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Group {
                if showsIcon {
                    Image(systemName: systemImage)
                } else {
                    Text(label)
                }
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(
                isSelected
                ? color.readableForeground
                : color.readableText(on: colorScheme)
            )
            .overlay(alignment: .topTrailing) {
                if isInFilter {
                    Circle()
                        .fill(AppTheme.shared.accent)
                        .frame(width: 6, height: 6)
                        .offset(x: 2, y: -2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isInFilter ? String(localized: "필터에 포함됨") : "")
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isInFilter)
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

/// 투두 목록 행 세로 여백. inset은 공통, padding은 메모 표시 여부로 나눔.
/// 미래 날짜 반복 할 일 미리보기 행 — 흐린 글자 + 점선 원 + 순환 화살표 + 「예정」. 저장되지 않은 줄이라 체크·편집 없음.
private struct RecurringPreviewRow: View {
    let preview: RecurringOccurrencePreview

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.dashed")
                .font(.title3)
                .foregroundStyle(Color(.tertiaryLabel))
            // `+`로 Text를 붙이는 방식은 iOS 26에서 지원 종료 예정 → 문자열 끼워 넣기로 (NBSP로 줄바꿈 방지)
            Text("\(Text(verbatim: preview.title))\u{00A0}\(Text(Image(systemName: "arrow.triangle.2.circlepath")).font(.footnote).baselineOffset(1))")
                .font(.body)
                .foregroundStyle(Color(.secondaryLabel))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("예정")
                .font(.caption)
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.vertical, TodoListRowSpacing.verticalPadding)
        .opacity(0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(preview.title), \(String(localized: "예정"))"))
    }
}

private enum TodoListRowSpacing {
    static let verticalInset: CGFloat = 4
    static let verticalPadding: CGFloat = 8
    static let verticalPaddingWithMemo: CGFloat = 6

    static var listRowInsets: EdgeInsets {
        EdgeInsets(top: verticalInset, leading: 24, bottom: verticalInset, trailing: 24)
    }

    static func verticalPadding(isMemoVisible: Bool) -> CGFloat {
        isMemoVisible ? verticalPaddingWithMemo : verticalPadding
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

    private var isMemoVisible: Bool {
        guard showMemo, let memo = todo.memo, !memo.isEmpty else { return false }
        return true
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            checkbox

            VStack(alignment: .leading, spacing: 6) {
                titleArea

                if isMemoVisible, let memo = todo.memo {
                    Text(memo)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // defaultMinListRowHeight=0 전제 — List 최소 높이 보정 없이 이 padding만으로 위아래 여백 결정.
        .padding(.vertical, TodoListRowSpacing.verticalPadding(isMemoVisible: isMemoVisible))
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

                if todo.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.shared.accent)
                        .opacity(todo.isCompleted ? completedCheckboxOpacity : 1)
                        .frame(height: firstLineHeight)
                        .layoutPriority(1)
                        .accessibilityHidden(true)
                }

                if showScheduledTime, todo.scheduledTime != nil {
                    Spacer(minLength: 0)
                }
            } else {
                // layoutPriority(0)+Spacer면 제목이 먼저 압축되고 Spacer가 빈 폭을 가져가
                // 일찍 줄바꿈됨 → 제목이 태그 앞까지 maxWidth를 쓰게 한다.
                titleLabel
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onStartInlineEdit?()
                    }
                    .animation(.easeInOut(duration: 0.15), value: todo.isCompleted)
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

        var label = title
        if todo.isPinned {
            let pin = Text(Image(systemName: "pin.fill"))
                .font(.caption)
                .foregroundStyle(
                    AppTheme.shared.accent.opacity(todo.isCompleted ? completedCheckboxOpacity : 1)
                )
            // 일반 공백은 줄바꿈 가능 → NBSP로 마지막 글자와 핀을 한 덩어리로 유지
            label = Text("\(label)\u{00A0}\(pin)")
        }
        if todo.recurrenceId != nil {
            // 반복 할 일 표시 (연회색 순환 화살표, 글자 가운데에 맞추려 baselineOffset)
            let repeatIcon = Text(Image(systemName: "arrow.triangle.2.circlepath"))
                .font(.footnote)
                .baselineOffset(1)
                .foregroundStyle(Color(.tertiaryLabel))
            label = Text("\(label)\u{00A0}\(repeatIcon)")
        }
        return label
    }

    @ViewBuilder
    private func scheduledTimeTag(_ scheduledTime: Date) -> some View {
        let hasAlarm = todo.alarmOffset != nil
        HStack(spacing: 3) {
            if hasAlarm {
                Image(systemName: "bell")
                    .font(.caption2)
                    .accessibilityHidden(true)
            }
            Text(scheduledTime, format: .dateTime.hour().minute())
                .font(.caption2)
                .monospacedDigit()
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
        if todo.recurrenceId != nil {
            parts.append(String(localized: "반복"))
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

    private var firstLineHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight
    }

    var body: some View {
        if isAdding {
            HStack(spacing: 8) {
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
                        let trimmed = newTodoTitle.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            onAdd()
                        }
                        isAdding = false
                    }
                )
                .id(focusEpoch)
                .frame(maxWidth: .infinity, minHeight: firstLineHeight, maxHeight: firstLineHeight, alignment: .leading)
                .layoutPriority(0)
            }
        } else {
            Button {
                focusEpoch = UUID()
                isAdding = true
            } label: {
                HStack(spacing: 8) {
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

/// 투두 탭·타임라인 탭 공용 (플래너 이름 탭 시)
struct PlannerSelectionSheet: View {
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
                    Text(planner.isReadOnly ? "읽기 전용" : (planner.isNotionConnected ? "노션에 연결됨" : "기기에 저장"))
                        .font(.system(size: 14, weight: .regular))
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
                            .foregroundStyle(hasFocusedDate ? AppTheme.shared.accent : Color(.tertiaryLabel))
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

// MARK: - 플로팅 캡처 버튼

private struct FloatingCaptureButton: View {
    let action: () -> Void

    private var accent: Color { AppTheme.shared.accent }

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                // glassProminent가 둘레에 넣던 여백만큼 — 버튼 크기는 그대로
                .padding(7)
                .background {
                    // 타임블록 진행 중 블록과 같은 그라데이션 (왼쪽 위 밝게 → 오른쪽 아래 원래 색)
                    Circle().fill(
                        LinearGradient(
                            colors: [accent.mix(with: .white, by: 0.35), accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // 유리 재질의 가장자리 빛·누를 때 출렁임은 유지
        .glassEffect(.regular.interactive(), in: .circle)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
}
