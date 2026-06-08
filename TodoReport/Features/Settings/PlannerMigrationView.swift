import SwiftUI

struct PlannerMigrationView: View {
    @State private var viewModel: PlannerMigrationViewModel
    @State private var rotationDegrees: Double = 0
    @State private var completedScale: CGFloat = 0.5
    @State private var showStatusSheet = false
    @Environment(\.dismiss) private var dismiss

    init(planner: Planner, mode: PlannerMigrationViewModel.SyncMode) {
        _viewModel = State(initialValue: PlannerMigrationViewModel(planner: planner, mode: mode))
    }

    private var isDBPickerStep: Bool {
        effectiveDisplayStep == .selectTodoDB || effectiveDisplayStep == .selectReportDB
    }

    private var effectiveDisplayStep: PlannerMigrationViewModel.Step {
        switch viewModel.step {
        case .running, .completed, .failed(_): return .idle
        default: return viewModel.step
        }
    }

    var body: some View {
        ZStack {
            NotionFlowContainer(title: navTitle) {
                Group {
                    switch effectiveDisplayStep {
                    case .idle:
                        EmptyView()
                    case .oauthRequired:
                        centeredContent { oauthWaitContent }
                    case .selectTodoDB:
                        NotionDBPickerView(
                            subtitle: "할일을 저장할 Notion DB를 선택하세요",
                            databases: viewModel.databases,
                            selectedId: viewModel.selectedTodoDBId,
                            isLoading: viewModel.isLoading,
                            onSelect: { viewModel.selectTodoDB($0) },
                            onRefresh: { await viewModel.fetchDatabases() }
                        )
                    case .mapTodoProps:
                        mapTodoPropsView
                    case .selectReportDB:
                        NotionDBPickerView(
                            subtitle: "데일리 리포트를 저장할 Notion DB를 선택하세요.\n연결하지 않으면 리포트는 앱 내에서만 저장됩니다.",
                            databases: viewModel.databases,
                            selectedId: viewModel.selectedReportDBId,
                            isLoading: viewModel.isLoading,
                            onSelect: { viewModel.selectReportDB($0) },
                            onRefresh: { await viewModel.fetchDatabases() },
                            onSkip: { Task { await viewModel.skipReportDB() } }
                        )
                    case .mapReportProps:
                        mapReportPropsView
                    default:
                        EmptyView()
                    }
                }
                .toolbar {
                    if showsBackButton {
                        ToolbarItem(placement: .navigationBarLeading) {
                            BackButton { viewModel.goBack() }
                        }
                    }
                    if isDBPickerStep {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            RefreshButton(isLoading: viewModel.isLoading) {
                                Task { await viewModel.fetchDatabases() }
                            }
                        }
                    } else if !showStatusSheet {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            CloseButton { dismiss() }
                        }
                    }
                }
            }

            if showStatusSheet {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)

                statusOverlayCard
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .interactiveDismissDisabled(viewModel.step == .running)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showStatusSheet)
        .onChange(of: viewModel.step) { _, step in
            switch step {
            case .running, .failed(_):
                showStatusSheet = true
            case .completed:
                completedScale = 0.5
                showStatusSheet = true
            case .idle:
                dismiss()
            default:
                break
            }
        }
        .onAppear { viewModel.startConnection() }
        .alert("오류", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("확인") { viewModel.alertMessage = nil }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }

    private var showsBackButton: Bool {
        switch effectiveDisplayStep {
        case .oauthRequired, .selectTodoDB, .mapTodoProps, .selectReportDB, .mapReportProps:
            return true
        default:
            return false
        }
    }

    private var navTitle: String {
        switch viewModel.step {
        case .idle, .oauthRequired:         return "노션 로그인"
        case .selectTodoDB:                 return "투두 DB 선택"
        case .mapTodoProps:                 return "투두 속성 연결"
        case .selectReportDB:               return "리포트 DB 선택"
        case .mapReportProps:               return "리포트 속성 연결"
        case .running, .completed, .failed(_):
            return viewModel.mode == .uploadToNotion ? "노션에 올리기" : "노션 가져오기"
        }
    }

    // MARK: - 레이아웃 헬퍼

    private func centeredContent<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 32) {
            Spacer()
            content()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - OAuth 대기

    private var oauthWaitContent: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.4)
            Text("Notion 로그인 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Safari에서 승인 후 돌아오세요")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - 투두 속성 매핑

    private var mapTodoPropsView: some View {
        PropMappingList(
            subtitle: "사용자의 노션 템플릿에 맞게 속성을 지정할 수 있습니다.",
            ctaTitle: "다음",
            ctaEnabled: viewModel.canProceedFromTodoProps,
            onCTA: { viewModel.proceedFromMapTodoProps() },
            requiredRows: {
                RequiredPropRow(
                    label: "완료 여부",
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

    // MARK: - 리포트 속성 매핑

    private var mapReportPropsView: some View {
        PropMappingList(
            subtitle: "사용자의 노션 템플릿에 맞게 속성을 지정할 수 있습니다.",
            ctaTitle: "완료",
            ctaEnabled: viewModel.canProceedFromReportProps && !viewModel.isLoading,
            isLoading: viewModel.isLoading,
            onCTA: { Task { await viewModel.proceedFromMapReportProps() } },
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

    // MARK: - 상태 오버레이 카드

    @ViewBuilder
    private var statusOverlayCard: some View {
        VStack(spacing: 28) {
            switch viewModel.step {
            case .running:
                runningContent
            case .completed:
                completedContent
            case .failed(let m):
                failedContent(message: m)
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
        .background(
            Color(.systemBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .padding(.horizontal, 36)
    }

    // MARK: - Running

    private var runningContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.2.circlepath")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(AppTheme.shared.accent)
                .rotationEffect(.degrees(rotationDegrees))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotationDegrees = 360
                    }
                }

            Text(viewModel.mode == .uploadToNotion ? "노션에 올리는 중..." : "노션 데이터 가져오는 중...")
                .font(.headline)

            if viewModel.mode == .uploadToNotion {
                Text("이전에 노션과 연동한 적 있는 플래너는 중복 데이터가 생길 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Text("\(viewModel.completedCount) / \(viewModel.totalCount)개 완료")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.shared.accent)
                            .frame(width: geo.size.width * CGFloat(min(viewModel.progress, 1.0)))
                    }
                }
                .frame(height: 6)
            }

            VStack(spacing: 6) {
                Text("작업이 끝날 때까지 잠시만 기다려주세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("앱을 닫지 마세요")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Completed

    private var completedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.shared.accent)
                .scaleEffect(completedScale)
                .onAppear {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                        completedScale = 1.0
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(1.3))
                        showStatusSheet = false
                        dismiss()
                    }
                }

            Text("연결이 완료됐습니다")
                .font(.headline)

            Text(viewModel.completionMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Failed

    private func failedContent(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if viewModel.mode == .importFromNotion {
                VStack(spacing: 10) {
                    Button("다시 시도") {
                        viewModel.retryMigration()
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(.label))
                    .foregroundStyle(Color(.systemBackground))
                    .clipShape(Capsule())

                    Button("닫기") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                // uploadToNotion 실패: SyncQueue가 자동 재시도하므로 확인만
                Button("확인") { dismiss() }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(.label))
                    .foregroundStyle(Color(.systemBackground))
                    .clipShape(Capsule())
            }
        }
    }
}
