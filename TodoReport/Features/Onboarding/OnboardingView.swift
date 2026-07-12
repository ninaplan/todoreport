import SwiftUI

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    let onComplete: () -> Void

    private var isNotionDBPickerStep: Bool {
        viewModel.step == .selectTodoDB || viewModel.step == .selectReportDB
    }

    private var isNotionBackButtonStep: Bool {
        switch viewModel.step {
        case .selectTodoDB, .selectReportDB, .mapTodoProps, .mapReportProps:
            return true
        default:
            return false
        }
    }

    var body: some View {
        ZStack {
            switch viewModel.step {
            case .welcome:
                OnboardingWelcomeView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .plannerName, .selectTodoDB, .mapTodoProps, .selectReportDB, .mapReportProps:
                NotionFlowContainer(title: notionNavTitle, titleDisplayMode: .inline) {
                    notionFlowContent
                        .toolbar {
                            if isNotionBackButtonStep {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    BackButton { viewModel.goBack() }
                                }
                            }
                            if isNotionDBPickerStep {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    RefreshButton(isLoading: viewModel.isLoadingDatabases) {
                                        Task { await viewModel.refreshDatabases() }
                                    }
                                }
                            }
                        }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }

            if viewModel.isFetchingInitialData {
                InitialFetchLoadingView(progress: viewModel.fetchProgress)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.step)
        .animation(.easeInOut(duration: 0.4), value: viewModel.isFetchingInitialData)
        .onChange(of: viewModel.isComplete) { _, complete in
            if complete { onComplete() }
        }
        .alert("오류", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.clearAlert() } }
        )) {
            Button("확인") { viewModel.clearAlert() }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }

    private var notionNavTitle: String {
        switch viewModel.step {
        case .plannerName:    return ""
        case .selectTodoDB:   return "투두 DB 선택"
        case .mapTodoProps:   return "투두 속성 연결"
        case .selectReportDB: return "리포트 DB 선택"
        case .mapReportProps: return "리포트 속성 연결"
        default:              return ""
        }
    }

    @ViewBuilder
    private var notionFlowContent: some View {
        switch viewModel.step {
        case .plannerName:
            PlannerNameStepView(viewModel: viewModel)
        case .selectTodoDB:
            NotionDBPickerView(
                subtitle: "투두를 저장할 노션 데이터베이스를 선택해주세요",
                databases: viewModel.databases,
                selectedId: viewModel.selectedTodoDBId,
                isLoading: viewModel.isLoadingDatabases,
                onSelect: { viewModel.selectTodoDB($0) },
                onRefresh: { await viewModel.fetchDatabases() },
                onForceRefresh: { await viewModel.refreshDatabases() }
            )
        case .selectReportDB:
            NotionDBPickerView(
                subtitle: "데일리리포트를 저장할 노션 DB를 선택해주세요.\n연결하지 않으면 리포트는 앱 내에서만 저장됩니다.",
                databases: viewModel.databases,
                selectedId: viewModel.selectedReportDBId,
                isLoading: viewModel.isLoadingDatabases,
                onSelect: { viewModel.selectReportDB($0) },
                onRefresh: { await viewModel.fetchDatabases() },
                onForceRefresh: { await viewModel.refreshDatabases() },
                onSkip: { viewModel.skipReportDB() }
            )
        case .mapTodoProps:
            MapTodoPropsStepView(viewModel: viewModel)
        case .mapReportProps:
            MapReportPropsStepView(viewModel: viewModel)
        default:
            EmptyView()
        }
    }
}

// MARK: - Notion Step: Planner Name

private struct PlannerNameStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Text("플래너 이름")
                    .font(.title2.bold())

                Image(systemName: "rectangle.and.pencil.and.ellipsis")
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.shared.accent)

                VStack(spacing: 16) {
                    Text("투두를 기록할 플래너 이름을 입력해주세요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    TextField("예: 나의 투두", text: $viewModel.plannerName)
                        .font(.title3)
                        .focused($focused)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color(.separator), lineWidth: 0.5)
                        )
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    viewModel.proceedFromPlannerName()
                } label: {
                    Text("다음")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(.label))
                        .foregroundStyle(Color(.systemBackground))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)

                Button("뒤로가기") { viewModel.goBack() }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            .padding(.bottom, 52)
        }
        .onAppear {
            focused = true
            if viewModel.plannerName.isEmpty {
                viewModel.plannerName = PlannerService.defaultNamePool.randomElement() ?? "내 플래너"
            }
        }
    }
}

// MARK: - Notion Step: Map Todo Props

private struct MapTodoPropsStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        PropMappingList(
            subtitle: "사용자의 노션 템플릿에 맞게 속성을 지정할 수 있습니다.",
            ctaTitle: "다음",
            ctaEnabled: viewModel.canProceedFromTodoProps,
            onCTA: { viewModel.proceedFromMapTodoProps() },
            requiredRows: {
                RequiredPropRow(
                    label: "완료",
                    props: viewModel.todoProperties.filter { $0.type == "checkbox" },
                    selection: Binding(
                        get: { viewModel.todoPropsMapping.completed },
                        set: { viewModel.todoPropsMapping.completed = $0 }
                    )
                )
                RequiredPropRow(
                    label: "날짜",
                    props: viewModel.todoProperties.filter { $0.type == "date" },
                    selection: Binding(
                        get: { viewModel.todoPropsMapping.date },
                        set: { viewModel.todoPropsMapping.date = $0 }
                    )
                )
            },
            optionalRows: {
                OptionalPropMenu(
                    label: "메모",
                    mode: $viewModel.memoMode,
                    props: viewModel.todoProperties.filter { $0.type == "rich_text" },
                    selection: Binding(
                        get: { viewModel.todoPropsMapping.memo },
                        set: { viewModel.todoPropsMapping.memo = $0 }
                    ),
                    onCreateTap: { Task { await viewModel.createMemoProperty() } }
                )
                OptionalPropMenu(
                    label: "상단고정",
                    mode: $viewModel.isPinnedMode,
                    props: viewModel.todoProperties.filter { $0.type == "checkbox" },
                    selection: Binding(
                        get: { viewModel.todoPropsMapping.isPinned },
                        set: { viewModel.todoPropsMapping.isPinned = $0 }
                    ),
                    onCreateTap: { Task { await viewModel.createPinnedProperty() } }
                )
                OptionalPropMenu(
                    label: "카테고리",
                    mode: $viewModel.categoryMode,
                    props: CategoryNotionProperty.candidates(from: viewModel.todoProperties),
                    selection: Binding(
                        get: { viewModel.todoPropsMapping.category },
                        set: { viewModel.selectCategory($0) }
                    ),
                    onCreateTap: { Task { await viewModel.createCategoryProperty() } }
                )
                if !viewModel.todoProperties.filter({ $0.type == "relation" }).isEmpty {
                    OptionalPropMenu(
                        label: "리포트 연결",
                        mode: $viewModel.reportRelationMode,
                        props: viewModel.todoProperties.filter { $0.type == "relation" },
                        selection: Binding(
                            get: { viewModel.todoPropsMapping.reportRelation },
                            set: { viewModel.todoPropsMapping.reportRelation = $0 }
                        )
                    )
                }
            }
        )
    }
}

// MARK: - Notion Step: Map Report Props

private struct MapReportPropsStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        PropMappingList(
            subtitle: "사용자의 노션 템플릿에 맞게 속성을 지정할 수 있습니다.",
            ctaTitle: "완료",
            ctaEnabled: viewModel.canProceedFromReportProps,
            onCTA: { viewModel.proceedFromMapReportProps() },
            requiredRows: {
                RequiredPropRow(
                    label: "날짜",
                    props: viewModel.reportProperties.filter { $0.type == "date" },
                    selection: Binding(
                        get: { viewModel.reportPropsMapping.date },
                        set: { viewModel.reportPropsMapping.date = $0 }
                    )
                )
            },
            optionalRows: {
                OptionalPropMenu(
                    label: "하루 리뷰",
                    mode: $viewModel.reviewMode,
                    props: viewModel.reportProperties.filter { $0.type == "rich_text" },
                    selection: Binding(
                        get: { viewModel.reportPropsMapping.review },
                        set: { viewModel.reportPropsMapping.review = $0 }
                    )
                )
                OptionalPropMenu(
                    label: "별점",
                    mode: $viewModel.ratingMode,
                    props: viewModel.reportProperties.filter { $0.type == "select" || $0.type == "status" },
                    selection: Binding(
                        get: { viewModel.reportPropsMapping.rating },
                        set: { viewModel.selectRating($0) }
                    ),
                    onCreateTap: { Task { await viewModel.createRatingProperty() } }
                )
            }
        )
    }
}

// MARK: - 초기 데이터 로딩 오버레이

private struct InitialFetchLoadingView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                VStack(spacing: 20) {
                    NotionConnectionGraphic(iconSize: 64, laneWidth: 66, spacing: 14)
                    VStack(spacing: 8) {
                        Text("노션에서 자료를 가져오고 있습니다...")
                            .font(.headline)
                        Text("최근 7일치 투두와 리포트를 불러옵니다")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(AppTheme.shared.accent)
                        .frame(width: 220)
                    Text("\(Int(progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(32)
        }
    }
}
