import SwiftUI

/// 타임라인 탭 (Pro). 무료 사용자는 예시 화면 + 결제 안내.
struct TimeBlockView: View {
    @Environment(MainTabCoordinator.self) private var tabCoordinator
    @State private var viewModel = TimeBlockViewModel()
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var didInitialScroll = false
    @State private var showPlannerSheet = false

    private var isPro: Bool { SubscriptionManager.shared.isPro }

    var body: some View {
        NavigationStack {
            Group {
                if isPro {
                    timelineContent
                } else {
                    TimeBlockLockedView(onStart: { viewModel.requestPaywall() })
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
                PaywallView(message: String(localized: "타임라인은 Pro 기능입니다."))
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .alert(viewModel.errorMessage, isPresented: errorAlertBinding) {
                Button("확인", role: .cancel) { viewModel.dismissErrorAlert() }
            }
        }
        .overlay {
            // 블록 탭 → 시간 편집 팝업, 빈 칸 탭 → 할 일 고르기 팝업 (둘 다 시트 대신)
            if let entry = viewModel.editingEntry {
                TimeBlockEditPopup(
                    entry: entry,
                    isStartAlarmGloballyEnabled: viewModel.isStartAlarmEnabled,
                    isEndAlarmGloballyEnabled: viewModel.isEndAlarmEnabled,
                    onSave: { viewModel.saveEdit(start: $0, end: $1, startAlarm: $2, endAlarm: $3) },
                    onDelete: { viewModel.deleteEditingBlock() },
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
        }
        .scrollPosition($scrollPosition)
        .safeAreaBar(edge: .top, spacing: 0) {
            TimeBlockWeekHeader(
                selectedDate: viewModel.selectedDate,
                weekDays: viewModel.weekDays,
                onSelect: { viewModel.selectDate($0) },
                onPreviousWeek: { viewModel.goToPreviousWeek() },
                onNextWeek: { viewModel.goToNextWeek() },
                onToday: { viewModel.goToToday() }
            )
        }
        // hard는 아래가 선으로 뚝 끊겨서 soft 유지. 대신 주간 달력 뒤에 그라데이션 덮개를 깔아 더 가린다
        .scrollEdgeEffectStyle(.soft, for: .top)
        // safeAreaBar·scrollEdgeEffectStyle은 ScrollView에 바로 붙어야 날짜행 뒤 블러가 생긴다.
        // 다른 modifier는 반드시 그 뒤에 둘 것.
        .scrollDisabled(viewModel.isDraggingBlock)
        .sensoryFeedback(.error, trigger: viewModel.moveRejectedToken)
        .onAppear { scrollToInitialPositionIfNeeded() }
    }

    /// 처음 열 때: 오늘이면 지금 1시간 전, 아니면 오전 8시로
    private func scrollToInitialPositionIfNeeded() {
        guard !didInitialScroll else { return }
        didInitialScroll = true
        if viewModel.isToday {
            scrollToNow(animated: false)
        } else {
            scroll(toMinute: TimeBlockLayout.defaultScrollHour * 60, animated: false)
        }
    }

    /// 지금 1시간 전이 화면 위에 오도록
    private func scrollToNow(animated: Bool) {
        let nowMinute = TimeBlockLayout.minute(of: .now, day: Calendar.current.startOfDay(for: .now))
        scroll(toMinute: max(nowMinute - 60, 0), animated: animated)
    }

    private func scroll(toMinute minute: Int, animated: Bool) {
        let targetY = max(TimeBlockLayout.y(for: minute) - 8, 0)
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
        if isPro {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("블록 단위", selection: snapBinding) {
                        ForEach(TimeBlockLayout.snapOptions, id: \.self) { minutes in
                            Text(snapLabel(minutes)).tag(minutes)
                        }
                    }
                    .pickerStyle(.inline)
                    Section {
                        Toggle("카테고리 색상 보기", isOn: categoryColorBinding)
                        Toggle("블록 시작 알림", isOn: startAlarmBinding)
                        Toggle("블록 종료 알림", isOn: endAlarmBinding)
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

    private var snapBinding: Binding<Int> {
        Binding(
            get: { viewModel.snapMinutes },
            set: { viewModel.setSnapMinutes($0) }
        )
    }
}
