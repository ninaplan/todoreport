import SwiftUI

/// 타임라인 탭 (Pro). 무료 사용자는 예시 화면 + 결제 안내.
struct TimeBlockView: View {
    @Environment(MainTabCoordinator.self) private var tabCoordinator
    @State private var viewModel = TimeBlockViewModel()
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var didInitialScroll = false
    @State private var showPlannerSheet = false

    private var isPro: Bool { SubscriptionManager.shared.isPro }

    private var formattedDate: String {
        let calendar = Calendar.current
        let date = viewModel.selectedDate
        let base = AppDateFormat.todoNavigationBase(date, includeWeekday: true)
        if calendar.isDateInToday(date) { return String(localized: "오늘, \(base)") }
        if calendar.isDateInYesterday(date) { return String(localized: "어제, \(base)") }
        if calendar.isDateInTomorrow(date) { return String(localized: "내일, \(base)") }
        return base
    }

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
            .sheet(item: pickerBinding) { request in
                TimeBlockTodoPickerSheet(
                    request: request,
                    options: viewModel.todoOptions,
                    onPick: { viewModel.placeTodo($0) },
                    onCreate: { viewModel.createTodoInSlot(title: $0) },
                    onClose: { viewModel.dismissPicker() }
                )
            }
            .sheet(item: editorBinding) { entry in
                TimeBlockEditSheet(
                    entry: entry,
                    onSave: { viewModel.saveEdit(start: $0, end: $1) },
                    onDelete: { viewModel.deleteEditingBlock() },
                    onClose: { viewModel.dismissEditor() }
                )
            }
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
        .onAppear {
            Task { await viewModel.onAppear() }
        }
        .onChange(of: tabCoordinator.selectedTab) { _, tab in
            guard tab == .timeline else { return }
            Task { await viewModel.reload() }
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
            DateNavigationRow(
                title: formattedDate,
                onPrev: { viewModel.goToPreviousDay() },
                onNext: { viewModel.goToNextDay() },
                showTodayButton: !viewModel.isToday,
                onGoToday: { viewModel.goToToday() }
            )
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
        }
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
        let targetMinute: Int
        if viewModel.isToday {
            targetMinute = max(TimeBlockLayout.minute(of: .now, day: viewModel.selectedDate) - 60, 0)
        } else {
            targetMinute = TimeBlockLayout.defaultScrollHour * 60
        }
        let targetY = max(TimeBlockLayout.y(for: targetMinute) - 8, 0)
        Task { @MainActor in
            // 첫 레이아웃이 끝난 뒤 스크롤해야 위치가 적용된다
            try? await Task.sleep(for: .milliseconds(50))
            scrollPosition.scrollTo(y: targetY)
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

    private var pickerBinding: Binding<TimeBlockSlotRequest?> {
        Binding(
            get: { viewModel.pickerRequest },
            set: { if $0 == nil { viewModel.dismissPicker() } }
        )
    }

    private var editorBinding: Binding<TimeBlockEntry?> {
        Binding(
            get: { viewModel.editingEntry },
            set: { if $0 == nil { viewModel.dismissEditor() } }
        )
    }

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
