import SwiftUI

struct PlannerAddView: View {
    @State private var viewModel = PlannerAddViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingPlannerDetail = false
    @FocusState private var nameFocused: Bool

    private var isDBPickerStep: Bool {
        viewModel.step == .selectTodoDB || viewModel.step == .selectReportDB
    }

    var body: some View {
        NotionFlowContainer(title: navTitle, titleDisplayMode: .inline) {
            Group {
                switch viewModel.step {
                case .chooseMode, .notionOAuth:
                    chooseModeView
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
                        RefreshButton(isLoading: viewModel.isLoading) {
                            Task { await viewModel.fetchDatabases() }
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
    }

    private var navTitle: String {
        switch viewModel.step {
        case .chooseMode, .notionOAuth: return "플래너 추가"
        case .selectTodoDB:             return "투두 DB 선택"
        case .mapTodoProps:             return "투두 속성 연결"
        case .selectReportDB:           return "리포트 DB 선택"
        case .mapReportProps:           return "리포트 속성 연결"
        }
    }

    // MARK: - 모드 선택

    private var chooseModeView: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 8) {
                Text("노션 워크스페이스당 플래너 1개를 연결할 수 있어요.")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text("여러 워크스페이스를 사용하면 플래너를 더 추가할 수 있습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                Text("이름을 입력하고 저장 방식을 선택하세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("플래너 이름 (선택)", text: $viewModel.plannerName)
                    .focused($nameFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Button {
                    viewModel.selectNotionMode()
                } label: {
                    HStack(spacing: 14) {
                        Group {
                            if viewModel.step == .notionOAuth && viewModel.isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "n.square.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(AppTheme.shared.accent)
                            }
                        }
                        .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("노션에 저장")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("사용자의 노션 DB와 연결해요")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color(.separator), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.step == .notionOAuth && viewModel.isLoading)

                Button {
                    Task { await viewModel.selectLocalMode() }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "iphone.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("기기에 저장")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("노션 연결 없이 이 기기에만 저장")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color(.separator), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear { nameFocused = true }
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
                    label: "지수",
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
