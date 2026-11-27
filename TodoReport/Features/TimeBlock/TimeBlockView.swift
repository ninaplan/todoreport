import SwiftUI

/// 타임라인 탭 (Pro). 무료 사용자는 예시 화면 + 결제 안내.
struct TimeBlockView: View {
    @Environment(MainTabCoordinator.self) private var tabCoordinator
    @State private var viewModel = TimeBlockViewModel()
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var didInitialScroll = false
    @State private var showPlannerSheet = false
    @State private var daySlide = DaySlide.initial
    /// 지금 스크롤 위치·보이는 높이 (핀치 기준점, 「하루 한눈에 보기」용)
    @State private var scrollOffsetY: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    /// 위 날짜 바(safeAreaBar)만큼 가려진 높이
    @State private var topInset: CGFloat = 0
    /// 핀치 시작 때 값 (scale, 손가락 사이 지점의 분, 그 지점의 화면 y)
    @State private var pinchStart: (scale: CGFloat, minute: CGFloat, viewY: CGFloat)?
    /// 핀치 중인지. 손가락이 화면 밖으로 나가 끝 신호(onEnded) 없이 취소돼도 자동으로 false로 돌아온다
    /// (예전엔 pinchStart만 보고 스크롤을 막아, 끝 신호를 못 받으면 스크롤이 계속 멈춰 있었다)
    @GestureState private var isPinching = false

    var body: some View {
        NavigationStack {
            Group {
                // 구독 확인 전 깜빡임 방지: 지난번 상태로 먼저 보여 준다 (`proDisplayState`)
                switch SubscriptionManager.shared.proDisplayState {
                case .pro:
                    timelineContent
                case .free:
                    TimeBlockLockedView(onStart: { viewModel.requestPaywall() })
                case .checking:
                    Color.clear
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showPlannerSheet) {
                PlannerSelectionSheet()
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: paywallBinding) {
                PaywallView(message: String(localized: "타임블록은 Pro 기능입니다."))
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .alert(viewModel.errorMessage, isPresented: errorAlertBinding) {
                Button("확인", role: .cancel) { viewModel.dismissErrorAlert() }
            }
            // 진행 중 블록 완료 → 일찍 끝났으면 종료를 지금으로 줄이기
            .alert(finishEarlyTitle, isPresented: finishEarlyAlertBinding) {
                Button("지금으로 바꾸기") { viewModel.confirmFinishEarly() }
                Button("그대로 두기", role: .cancel) { viewModel.cancelFinishEarly() }
            } message: {
                Text("블록이 지금까지로 줄어들고, 집중한 시간도 그만큼 계산됩니다.")
            }
            // 미래 날짜 제안 블록 탭 (투두 탭 「예정」 안내와 같은 제목)
            .alert("반복 할 일은 그날 만들어집니다.", isPresented: suggestionPreviewInfoBinding) {
                Button("확인", role: .cancel) { viewModel.confirmSuggestionPreviewInfo() }
            } message: {
                Text("그날이 되면 탭해서 블록으로 넣을 수 있습니다.")
            }
        }
        .overlay {
            // 블록 탭 → 시간 편집 팝업, 빈 칸 탭 → 할 일 고르기 팝업 (둘 다 시트 대신)
            if viewModel.showDayRangeEditor {
                TimeBlockDayRangePopup(
                    range: viewModel.dayRange,
                    onSave: { viewModel.saveDayRange($0) },
                    onClose: { viewModel.dismissDayRangeEditor() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if let entry = viewModel.editingEntry {
                TimeBlockEditPopup(
                    entry: entry,
                    dayRange: viewModel.dayRange,
                    categories: viewModel.editableCategories,
                    focusesMemo: viewModel.editorFocusesMemo,
                    onSave: { viewModel.saveEdit($0) },
                    onDelete: { viewModel.deleteEditingBlock() },
                    onDeleteTodo: { viewModel.deleteEditingTodo($0) },
                    onClose: { viewModel.dismissEditor() }
                )
                .id(entry.id)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if let request = viewModel.pickerRequest {
                TimeBlockTodoPickerPopup(
                    request: request,
                    options: viewModel.todoOptions,
                    onPick: { viewModel.placeTodo($0) },
                    onCreate: { viewModel.createTodoInSlot(title: $0) },
                    onClose: { viewModel.dismissPicker() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: viewModel.pickerRequest)
        .animation(.easeOut(duration: 0.18), value: viewModel.editingEntry)
        .animation(.easeOut(duration: 0.18), value: viewModel.showDayRangeEditor)
        .onAppear {
            Task {
                await viewModel.onAppear()
                // 시작 화면을 타임라인으로 정했어도 Pro가 아니면 투두에서 시작
                if tabCoordinator.consumeLaunchedIntoTimeline(), !SubscriptionManager.shared.isPro {
                    tabCoordinator.openTodoTab()
                }
            }
        }
        .onChange(of: tabCoordinator.selectedTab) { _, tab in
            guard tab == .timeline else { return }
            Task { await viewModel.reload() }
        }
        // 타임라인 탭을 다시 탭 → 오늘로 + 지금 시각으로
        .onChange(of: tabCoordinator.timelineReselectToken) { _, _ in
            viewModel.goToToday()
            scrollToNow(animated: true)
        }
        .onChange(of: viewModel.entriesDay) { oldDay, newDay in
            daySlide = daySlide.next(forward: newDay > oldDay)
        }
        .onChange(of: tabCoordinator.foregroundRefreshToken) { _, _ in
            Task { await viewModel.reload() }
        }
        .onChange(of: PlannerService.shared.selectedPlannerId) { _, _ in
            Task { await viewModel.reload() }
        }
    }

    // MARK: - 타임라인

    private var timelineContent: some View {
        ScrollView {
            TimelineView(.everyMinute) { context in
                TimeBlockTimelineView(viewModel: viewModel, now: context.date)
            }
            .daySlide(daySlide)
        }
        .scrollPosition($scrollPosition)
        .safeAreaBar(edge: .top, spacing: 0) {
            TimeBlockWeekHeader(
                selectedDate: viewModel.selectedDate,
                today: viewModel.todayDate,
                weekDays: viewModel.weekDays,
                onSelect: { viewModel.selectDate($0) },
                onShiftWeeks: { viewModel.shiftWeeks(by: $0) },
                onToday: { viewModel.goToToday() }
            )
        }
        // 타임라인만 hard: 반투명 유리 + 아래가 딱 끊기는 경계. 시간 줄·블록이 흐리게 번져 겹쳐 보이지 않게.
        // (투두·리포트는 날짜 한 줄이라 soft 유지)
        .scrollEdgeEffectStyle(.hard, for: .top)
        // safeAreaBar·scrollEdgeEffectStyle은 ScrollView에 바로 붙어야 날짜행 뒤 블러가 생긴다.
        // 다른 modifier는 반드시 그 뒤에 둘 것.
        // 묶어 받기: x = 위 가림 높이, y = 보이는 영역 맨 위의 내용 y, height = 가림을 뺀 보이는 높이
        .onScrollGeometryChange(for: CGRect.self) { geometry in
            CGRect(
                x: geometry.contentInsets.top,
                y: geometry.contentOffset.y + geometry.contentInsets.top,
                width: 0,
                height: geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom
            )
        } action: { _, value in
            topInset = value.minX
            scrollOffsetY = value.minY
            viewportHeight = value.height
        }
        .scrollDisabled(viewModel.isDraggingBlock || isPinching)
        .sensoryFeedback(.error, trigger: viewModel.moveRejectedToken)
        // 투두·리포트 탭과 같은 화면 가장자리 스와이프로 하루씩 이동 (가운데 스크롤·블록 드래그와 안 겹침)
        .edgeSwipeNavigation(
            onPrev: { viewModel.goToPreviousDay() },
            onNext: { viewModel.goToNextDay() }
        )
        // 두 손가락으로 오므리면 하루가 한눈에, 벌리면 크게 (손가락 사이 시각이 제자리에 남게)
        .simultaneousGesture(pinchGesture)
        // 핀치가 끝나거나 취소되면 기준값을 비우고 크기를 저장
        .onChange(of: isPinching) { _, pinching in
            guard !pinching, pinchStart != nil else { return }
            pinchStart = nil
            viewModel.commitPointsPerMinute()
        }
        .overlay(alignment: .bottom) { outOfRangeNotice }
        .undoBannerHost(.timeBlock)
        .onAppear { scrollToInitialPositionIfNeeded() }
    }

    /// 일과 시간 밖으로 나간 블록이 있으면 아래에 작게 알림. 누르면 일과 시간 설정
    @ViewBuilder
    private var outOfRangeNotice: some View {
        let count = viewModel.outOfRangeCount
        // 「실행 취소」 배너가 같은 자리에 뜨는 동안은 숨긴다
        if count > 0, AppUndoCenter.shared.banner?.scope != .timeBlock {
            Button {
                viewModel.openDayRangeEditor()
            } label: {
                Text("범위 밖 블록 \(count)개")
                    .font(.footnote)
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
            .accessibilityHint(Text("일과 시간을 바꿀 수 있습니다."))
        }
    }

    /// 처음 열 때: 오늘이면 지금 1시간 전, 아니면 오전 8시로 (일과 시간이 더 늦게 시작하면 맨 위)
    private func scrollToInitialPositionIfNeeded() {
        guard !didInitialScroll else { return }
        didInitialScroll = true
        if viewModel.isToday {
            scrollToNow(animated: false)
        } else {
            scroll(toMinute: TimeBlockLayout.defaultScrollHour * 60, animated: false)
        }
    }

    /// 지금 1시간 전이 화면 위에 오도록 (타임블록의 오늘 기준 — 새벽이면 전날 화면의 아래쪽)
    private func scrollToNow(animated: Bool) {
        let nowMinute = TimeBlockLayout.minutesSince(day: viewModel.todayDate, until: .now)
        scroll(toMinute: nowMinute - 60, animated: animated)
    }

    // MARK: - 확대·축소

    private var pinchGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.02)
            .updating($isPinching) { _, state, _ in
                state = true
            }
            .onChanged { value in
                let range = viewModel.dayRange
                if pinchStart == nil {
                    viewModel.cancelBlockDrags()
                    let scale = viewModel.pointsPerMinute
                    // 손가락 사이 지점을 날짜 바 아래 보이는 영역 기준으로
                    let viewY = value.startLocation.y - topInset
                    let contentY = scrollOffsetY + viewY
                    let minute = CGFloat(range.startMinute) + (contentY - TimeBlockLayout.verticalPadding) / scale
                    pinchStart = (scale, minute, viewY)
                }
                guard let start = pinchStart else { return }
                viewModel.setPointsPerMinute(start.scale * value.magnification)
                let newScale = viewModel.pointsPerMinute
                let anchorY = TimeBlockLayout.verticalPadding + (start.minute - CGFloat(range.startMinute)) * newScale
                scrollPosition.scrollTo(y: max(anchorY - start.viewY, 0))
            }
            .onEnded { _ in
                pinchStart = nil
                viewModel.commitPointsPerMinute()
            }
    }

    private func scroll(toMinute minute: Int, animated: Bool) {
        let range = viewModel.dayRange
        let targetY = max(TimeBlockLayout.y(for: range.clamp(minute), in: range, pointsPerMinute: viewModel.pointsPerMinute) - 8, 0)
        Task { @MainActor in
            // 첫 레이아웃이 끝난 뒤 스크롤해야 위치가 적용된다
            try? await Task.sleep(for: .milliseconds(50))
            if animated {
                withAnimation(.easeInOut(duration: 0.3)) { scrollPosition.scrollTo(y: targetY) }
            } else {
                scrollPosition.scrollTo(y: targetY)
            }
        }
    }

    // MARK: - 툴바

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // 투두 탭과 같은 모양·동작: 탭하면 플래너 선택 시트
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
                    Text(PlannerService.shared.selectedPlanner?.name ?? String(localized: "내 플래너"))
                        .font(.callout.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .thin))
                }
            }
            .tint(.primary)
        }
        // 본문과 같은 기준으로 ⋯ 메뉴도 보여 준다 (확인 전 메뉴가 늦게 나타나는 깜빡임 방지)
        if SubscriptionManager.shared.proDisplayState == .pro {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section {
                        Button("하루 한눈에 보기") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.fitDayToHeight(viewportHeight)
                            }
                            scroll(toMinute: viewModel.dayRange.startMinute, animated: true)
                        }
                        if !viewModel.isDefaultScale {
                            Button("기본 크기로") {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    viewModel.resetPointsPerMinute()
                                }
                                if viewModel.isToday { scrollToNow(animated: true) }
                            }
                        }
                    }
                    Section {
                        Toggle("카테고리 색상 보기", isOn: categoryColorBinding)
                        Toggle("제안 블록 보기", isOn: suggestionsBinding)
                    }
                    // 한 번 정하면 잘 안 바꾸는 설정. 지금 값은 제목 아래 작은 글씨 (메뉴 라벨의 둘째 Text)
                    // Picker(.menu)는 iOS 26 메뉴 안에서 지금 값을 안 보여 줘서 Menu로 감쌌다
                    Section {
                        Menu {
                            Picker("블록 단위", selection: snapBinding) {
                                ForEach(TimeBlockLayout.snapOptions, id: \.self) { minutes in
                                    Text(snapLabel(minutes)).tag(minutes)
                                }
                            }
                            .pickerStyle(.inline)
                        } label: {
                            Text("블록 단위")
                            Text(snapLabel(viewModel.snapMinutes))
                        }
                        Button {
                            viewModel.openDayRangeEditor()
                        } label: {
                            Text("일과 시간")
                            Text(TimeBlockDayRangePopup.compactSummary(of: viewModel.dayRange))
                        }
                    }
                    // 새로 만드는 블록의 기본값. 이미 있는 블록은 블록 팝업의 종으로 따로 켜고 끈다
                    Section("새 블록 기본 알림") {
                        Toggle("시작 알림", isOn: startAlarmBinding)
                        Toggle("종료 알림", isOn: endAlarmBinding)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .accessibilityLabel(Text("보기 옵션"))
                }
                .tint(.primary)
            }
        }
    }

    private func snapLabel(_ minutes: Int) -> String {
        let duration = Duration.seconds(minutes * 60)
        let text = duration.formatted(.units(allowed: [.hours, .minutes], width: .wide))
        return String(localized: "\(text) 단위")
    }

    // MARK: - Bindings (상태 변경은 ViewModel 메서드로만)

    private var paywallBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showPaywall },
            set: { if !$0 { viewModel.dismissPaywall() } }
        )
    }

    private var finishEarlyTitle: String {
        let time = viewModel.finishEarlyTime.formatted(date: .omitted, time: .shortened)
        return String(localized: "종료 시각을 지금(\(time))으로 바꿀까요?")
    }

    private var finishEarlyAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showFinishEarlyAlert },
            set: { if !$0 { viewModel.dismissFinishEarlyAlert() } }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showErrorAlert },
            set: { if !$0 { viewModel.dismissErrorAlert() } }
        )
    }

    private var endAlarmBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isEndAlarmEnabled },
            set: { viewModel.setEndAlarmEnabled($0) }
        )
    }

    private var startAlarmBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isStartAlarmEnabled },
            set: { viewModel.setStartAlarmEnabled($0) }
        )
    }

    private var categoryColorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showsCategoryColor },
            set: { viewModel.setShowsCategoryColor($0) }
        )
    }

    private var suggestionsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showsSuggestions },
            set: { viewModel.setShowsSuggestions($0) }
        )
    }

    private var suggestionPreviewInfoBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showSuggestionPreviewInfo },
            set: { if !$0 { viewModel.cancelSuggestionPreviewInfo() } }
        )
    }

    private var snapBinding: Binding<Int> {
        Binding(
            get: { viewModel.snapMinutes },
            set: { viewModel.setSnapMinutes($0) }
        )
    }
}
