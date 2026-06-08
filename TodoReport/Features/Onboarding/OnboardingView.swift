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
            case .signIn:
                SignInStepView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .connectionChoice:
                ConnectionChoiceStepView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .localModeInfo:
                LocalModeStepView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .notionOAuth, .plannerName, .selectTodoDB, .mapTodoProps, .selectReportDB, .mapReportProps:
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
                                    RefreshButton(isLoading: viewModel.isLoadingDBs) {
                                        Task { await viewModel.fetchDatabases() }
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
        case .notionOAuth:    return ""
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
        case .notionOAuth:
            NotionOAuthStepView(viewModel: viewModel)
        case .plannerName:
            PlannerNameStepView(viewModel: viewModel)
        case .selectTodoDB:
            NotionDBPickerView(
                subtitle: "투두를 저장할 노션 데이터베이스를 선택해주세요",
                databases: viewModel.databases,
                selectedId: viewModel.selectedTodoDBId,
                isLoading: viewModel.isLoadingDBs,
                onSelect: { viewModel.selectTodoDB($0) },
                onRefresh: { await viewModel.fetchDatabases() }
            )
        case .selectReportDB:
            NotionDBPickerView(
                subtitle: "데일리리포트를 저장할 노션 DB를 선택해주세요.\n연결하지 않으면 리포트는 앱 내에서만 저장됩니다.",
                databases: viewModel.databases,
                selectedId: viewModel.selectedReportDBId,
                isLoading: viewModel.isLoadingDBs,
                onSelect: { viewModel.selectReportDB($0) },
                onRefresh: { await viewModel.fetchDatabases() },
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

// MARK: - Step 1: Sign In

private struct SignInStepView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(AppTheme.shared.accent)

                Text("투두리포트")
                    .font(.largeTitle.bold())

                Text("앱에서 기록하고, 노션에 쌓아가세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                viewModel.devLogin()
            } label: {
                Text("시작하기")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppTheme.shared.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
    }
}

// MARK: - Step 2: Connection Choice

private struct ConnectionChoiceStepView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Text("데이터를 어디에 저장할까요?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("설정에서 언제든 변경할 수 있어요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    viewModel.selectNotionConnection()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "link.circle.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("노션 연결하기")
                                .font(.headline)
                            Text("노션에 자동 저장")
                                .font(.caption)
                                .opacity(0.85)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.shared.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }

                Button {
                    viewModel.selectLocalMode()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "iphone.circle.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("나중에 하기")
                                .font(.headline)
                            Text("이 기기에만 저장")
                                .font(.caption)
                                .opacity(0.7)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.primary)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
    }
}

// MARK: - Notion Step: OAuth

private struct NotionOAuthStepView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Text("노션 연결")
                    .font(.title2.bold())

                Image(systemName: "globe.badge.chevron.backward")
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.shared.accent)

                Text("노션 계정을 연결하면 투두와 리포트가\n노션 데이터베이스에 자동으로 저장돼요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await viewModel.startNotionOAuth() }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView().tint(Color(.systemBackground))
                        } else {
                            Text("노션으로 계속하기").font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.label))
                    .foregroundStyle(Color(.systemBackground))
                    .clipShape(Capsule())
                }
                .disabled(viewModel.isLoading)
                .padding(.horizontal, 24)

                Button("뒤로가기") { viewModel.goBack() }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            .padding(.bottom, 52)
        }
    }
}

// MARK: - Step 4 (Local): Local Mode Info

private struct LocalModeStepView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "iphone.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)

                Text("기기 저장 모드")
                    .font(.title2.bold())

                VStack(spacing: 8) {
                    Text("데이터가 이 기기에만 저장됩니다.")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Text("기기를 변경하면 데이터를 불러올 수 없어요.\n설정에서 언제든 노션을 연결할 수 있어요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                viewModel.completeWithLocalMode()
            } label: {
                Text("시작하기")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppTheme.shared.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
    }
}

// MARK: - Notion Step: Planner Name

private struct PlannerNameStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var focused: Bool

    private let autoNames = ["내 플래너", "나의 할 일", "오늘의 투두", "일상 기록", "할 일 모음", "나만의 계획"]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Text("플래너 이름")
                    .font(.title2.bold())

                Image(systemName: "rectangle.and.pencil.and.ellipsis")
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.shared.accent)

                Text("투두를 기록할 플래너 이름을 입력해주세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                TextField("예: 나의 투두", text: $viewModel.plannerName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .padding(.horizontal, 24)

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
                viewModel.plannerName = autoNames.randomElement() ?? "내 플래너"
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
                    ProgressView()
                        .scaleEffect(1.4)
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
