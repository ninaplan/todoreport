import SwiftUI

struct PlannerAddView: View {
    @State private var viewModel = PlannerAddViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingPlannerDetail = false
    @State private var showNotionWorkspaceInfoAlert = false

    private static let notionWorkspaceInfoMessage =
        "같은 워크스페이스에 여러 플래너를 연결할 수 있어요. 노션 연결 화면에서 기존에 허용했던 페이지는 체크 해제하지 말고, 새로 쓸 페이지만 추가로 체크해주세요."

    private var isDBPickerStep: Bool {
        viewModel.step == .selectTodoDB || viewModel.step == .selectReportDB
    }

    var body: some View {
        NotionFlowContainer(title: navTitle, titleDisplayMode: .inline) {
            Group {
                switch viewModel.step {
                case .chooseMode, .notionOAuth:
                    chooseModeView
                case .loadingDatabases:
                    loadingDatabasesView
                case .selectTodoDB:
                    NotionDBPickerView(
                        subtitle: "할일을 저장할 Notion DB를 선택하세요",
                        databases: viewModel.databases,
                        selectedId: viewModel.selectedTodoDBId,
                        isLoading: viewModel.isLoadingDatabases,
                        onSelect: { viewModel.selectTodoDB($0) },
                        onRefresh: { await viewModel.fetchDatabases() },
                        onForceRefresh: { await viewModel.refreshDatabases() }
                    )
                case .mapTodoProps:
                    mapTodoPropsView
                case .selectReportDB:
                    NotionDBPickerView(
                        subtitle: "데일리 리포트를 저장할 Notion DB를 선택하세요.\n연결하지 않으면 리포트는 앱 내에서만 저장됩니다.",
                        databases: viewModel.databases,
                        selectedId: viewModel.selectedReportDBId,
                        isLoading: viewModel.isLoadingDatabases,
                        onSelect: { viewModel.selectReportDB($0) },
                        onRefresh: { await viewModel.fetchDatabases() },
                        onForceRefresh: { await viewModel.refreshDatabases() },
                        onSkip: { Task { await viewModel.skipReportDB(); dismiss() } }
                    )
                case .mapReportProps:
                    mapReportPropsView
                }
            }
            .toolbar {
                if viewModel.step != .chooseMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        BackButton { viewModel.goBack() }
                    }
                }
                if isDBPickerStep {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        RefreshButton(isLoading: viewModel.isLoadingDatabases) {
                            Task { await viewModel.refreshDatabases() }
                        }
                    }
                }
                if !isDBPickerStep {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        CloseButton { dismiss() }
                    }
                }
            }
        }
        .onChange(of: viewModel.createdLocalPlanner) { _, planner in
            if planner != nil { showingPlannerDetail = true }
        }
        .fullScreenCover(isPresented: $showingPlannerDetail, onDismiss: { dismiss() }) {
            if let planner = viewModel.createdLocalPlanner {
                NavigationStack {
                    PlannerDetailView(planner: planner)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                CloseButton { showingPlannerDetail = false }
                            }
                        }
                }
            }
        }
        .alert("오류", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("확인") { viewModel.alertMessage = nil }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .alert("페이지 선택 시 주의해주세요", isPresented: $showNotionWorkspaceInfoAlert) {
            Button("취소", role: .cancel) { cancelNotionWorkspaceInfo() }
            Button("계속") { confirmNotionWorkspaceInfo() }
        } message: {
            Text(Self.notionWorkspaceInfoMessage)
        }
    }

    private var navTitle: String {
        switch viewModel.step {
        case .chooseMode, .notionOAuth, .loadingDatabases: return "플래너 추가"
        case .selectTodoDB:             return "투두 DB 선택"
        case .mapTodoProps:             return "투두 속성 연결"
        case .selectReportDB:           return "리포트 DB 선택"
        case .mapReportProps:           return "리포트 속성 연결"
        }
    }

    // MARK: - 모드 선택

    private var chooseModeView: some View {
        GeometryReader { geo in
            VStack(spacing: 40) {
                Text("저장 방식을 선택하세요")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Button {
                        requestNotionMode()
                    } label: {
                        HStack(spacing: 16) {
                            Group {
                                if viewModel.step == .notionOAuth && viewModel.isLoading {
                                    ProgressView()
                                        .frame(width: 48, height: 48)
                                } else {
                                    Image(systemName: "link")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(AppTheme.shared.accent)
                                        .frame(width: 48)
                                }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("노션에 저장")
                                    .font(.body.bold())
                                    .foregroundStyle(.primary)
                                Text("사용자의 노션 DB와 연결해요")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(.separator), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.step == .notionOAuth && viewModel.isLoading)

                    Button {
                        Task { await viewModel.selectLocalMode() }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "iphone.badge.checkmark")
                                .font(.system(size: 26, weight: .light))
                                .foregroundStyle(Color(.label).opacity(0.75))
                                .frame(width: 48)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("기기에 저장")
                                    .font(.body.bold())
                                    .foregroundStyle(.primary)
                                Text("노션 연결 없이 이 기기에만 저장")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(.separator), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
            }
            .frame(width: geo.size.width)
            .position(x: geo.size.width / 2, y: geo.size.height * 0.38)
        }
    }

    // MARK: - DB 로딩

    private var loadingDatabasesView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().scaleEffect(1.4)
            Text("데이터베이스 불러오는 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("처음 연결할 때는 시간이 걸릴 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            onCTA: { Task { await viewModel.proceedFromMapReportProps(); dismiss() } },
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

    // MARK: - 노션 연결 안내

    private func requestNotionMode() {
        if viewModel.showNotionWorkspaceInfo {
            showNotionWorkspaceInfoAlert = true
        } else {
            viewModel.selectNotionMode()
        }
    }

    private func confirmNotionWorkspaceInfo() {
        showNotionWorkspaceInfoAlert = false
        viewModel.selectNotionMode()
    }

    private func cancelNotionWorkspaceInfo() {
        showNotionWorkspaceInfoAlert = false
    }
}
