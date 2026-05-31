import SwiftUI

struct PlannerAddView: View {
    @State private var viewModel = PlannerAddViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingPlannerDetail = false

    var body: some View {
        VStack(spacing: 0) {
            navBar

            switch viewModel.step {
            case .chooseMode, .notionOAuth:
                chooseModeView
            case .selectTodoDB:
                selectDBView(isTodo: true)
            case .mapTodoProps:
                mapPropsView(isTodo: true)
            case .selectReportDB:
                selectDBView(isTodo: false)
            case .mapReportProps:
                mapPropsView(isTodo: false)
            }
        }
        .onChange(of: viewModel.createdLocalPlanner) { _, planner in
            if planner != nil { showingPlannerDetail = true }
        }
        .fullScreenCover(isPresented: $showingPlannerDetail, onDismiss: { dismiss() }) {
            if let planner = viewModel.createdLocalPlanner {
                NavigationStack {
                    PlannerDetailView(planner: planner)
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

    // MARK: - 네비게이션 바

    private var navBar: some View {
        HStack {
            if viewModel.step != .chooseMode {
                Button { viewModel.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                }
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color(.systemGray5), in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - 모드 선택

    private var chooseModeView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("플래너 추가")
                    .font(.title2.bold())
                Text("이름을 입력하고 저장 방식을 선택하세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("플래너 이름 (선택)", text: $viewModel.plannerName)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                modeCard(
                    icon: "internaldrive",
                    iconColor: .secondary,
                    title: "기기에 저장",
                    description: "Notion 없이 이 기기에만 저장해요",
                    isLoading: false
                ) {
                    Task { await viewModel.selectLocalMode() }
                }

                modeCard(
                    icon: "n.square.fill",
                    iconColor: AppTheme.shared.accent,
                    title: "Notion에 저장",
                    description: "Notion DB에 연결해서 저장해요",
                    isLoading: viewModel.step == .notionOAuth && viewModel.isLoading
                ) {
                    viewModel.selectNotionMode()
                }

                if viewModel.showNotionWorkspaceInfo {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("같은 노션 워크스페이스는 1개 플래너만 연동 가능해요.\n다른 워크스페이스로 연동하면 여러 플래너를 사용할 수 있어요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func modeCard(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Group {
                    if isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundStyle(iconColor)
                    }
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(.separator), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    // MARK: - DB 선택

    private func selectDBView(isTodo: Bool) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(isTodo ? "투두 DB 선택" : "리포트 DB 선택")
                    .font(.title2.bold())
                Text(isTodo
                     ? "할일을 저장할 Notion DB를 선택하세요"
                     : "데일리 리포트를 저장할 Notion DB를 선택하세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)

            if viewModel.isLoading && viewModel.databases.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.databases) { db in
                            let isSelected = isTodo
                                ? viewModel.selectedTodoDBId == db.id
                                : viewModel.selectedReportDBId == db.id
                            Button {
                                if isTodo { viewModel.selectTodoDB(db.id) }
                                else      { viewModel.selectReportDB(db.id) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "tablecells")
                                        .font(.system(size: 16))
                                        .foregroundStyle(AppTheme.shared.accent)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Color(.tertiarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 8)
                                        )
                                    Text(db.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppTheme.shared.accent)
                                    }
                                }
                                .padding(14)
                                .background(
                                    Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                }
            }
        }
        .task {
            if viewModel.databases.isEmpty {
                await viewModel.fetchDatabases()
            }
        }
    }

    // MARK: - 속성 매핑

    private func mapPropsView(isTodo: Bool) -> some View {
        let props = isTodo ? viewModel.todoProperties : viewModel.reportProperties
        let canProceed = isTodo
            ? viewModel.canProceedFromTodoProps
            : (viewModel.canProceedFromReportProps && !viewModel.isLoading)

        return VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(isTodo ? "투두 속성 연결" : "리포트 속성 연결")
                    .font(.title2.bold())
                Text(isTodo
                     ? "필수 속성을 Notion DB와 연결해주세요"
                     : "리포트 연결 없이도 계속할 수 있어요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)

            List {
                Section("필수") {
                    if isTodo {
                        requiredPropRow(
                            label: "완료 여부",
                            props: props.filter { $0.type == "checkbox" },
                            binding: Binding(
                                get: { viewModel.todoPropsMapping.completed },
                                set: { viewModel.todoPropsMapping.completed = $0 }
                            )
                        )
                        requiredPropRow(
                            label: "날짜",
                            props: props.filter { $0.type == "date" },
                            binding: Binding(
                                get: { viewModel.todoPropsMapping.date },
                                set: { viewModel.todoPropsMapping.date = $0 }
                            )
                        )
                    } else {
                        requiredPropRow(
                            label: "날짜",
                            props: props.filter { $0.type == "date" },
                            binding: Binding(
                                get: { viewModel.reportPropsMapping.date },
                                set: { viewModel.reportPropsMapping.date = $0 }
                            )
                        )
                    }
                }

                Section("선택") {
                    if isTodo {
                        optionalPropMenu(
                            label: "메모",
                            mode: $viewModel.memoMode,
                            props: props.filter { $0.type == "rich_text" },
                            binding: Binding(
                                get: { viewModel.todoPropsMapping.memo },
                                set: { viewModel.todoPropsMapping.memo = $0 }
                            ),
                            onCreateTap: { Task { await viewModel.createMemoProperty() } }
                        )
                        optionalPropMenu(
                            label: "상단고정",
                            mode: $viewModel.isPinnedMode,
                            props: props.filter { $0.type == "checkbox" },
                            binding: Binding(
                                get: { viewModel.todoPropsMapping.isPinned },
                                set: { viewModel.todoPropsMapping.isPinned = $0 }
                            ),
                            onCreateTap: { Task { await viewModel.createPinnedProperty() } }
                        )
                    } else {
                        optionalPropMenu(
                            label: "하루 리뷰",
                            mode: $viewModel.reviewMode,
                            props: props.filter { $0.type == "rich_text" },
                            binding: Binding(
                                get: { viewModel.reportPropsMapping.review },
                                set: { viewModel.reportPropsMapping.review = $0 }
                            ),
                            onCreateTap: { }
                        )
                        optionalPropMenu(
                            label: "별점",
                            mode: $viewModel.ratingMode,
                            props: props.filter { $0.type == "select" },
                            binding: Binding(
                                get: { viewModel.reportPropsMapping.rating },
                                set: { viewModel.reportPropsMapping.rating = $0 }
                            ),
                            onCreateTap: { Task { await viewModel.createRatingProperty() } }
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)

            Button {
                if isTodo {
                    viewModel.proceedFromMapTodoProps()
                } else {
                    Task { await viewModel.proceedFromMapReportProps(); dismiss() }
                }
            } label: {
                Text(isTodo ? "다음" : "완료")
                    .font(.body.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canProceed ? AppTheme.shared.accent : Color(.systemGray4), in: Capsule())
            }
            .disabled(!canProceed)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - 속성 행 헬퍼

    private func requiredPropRow(
        label: String,
        props: [NotionProperty],
        binding: Binding<String?>
    ) -> some View {
        HStack {
            Text(label)
            PlannerAddSmallTag("필수")
            Spacer()
            Menu {
                ForEach(props) { prop in
                    Button {
                        binding.wrappedValue = prop.name
                    } label: {
                        HStack {
                            Text(prop.name)
                            if binding.wrappedValue == prop.name {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(binding.wrappedValue ?? "선택")
                    .foregroundStyle(binding.wrappedValue == nil ? .secondary : .primary)
            }
        }
    }

    private func optionalPropMenu(
        label: String,
        mode: Binding<PropMappingMode>,
        props: [NotionProperty],
        binding: Binding<String?>,
        onCreateTap: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            Menu {
                Button("앱에만 저장") {
                    mode.wrappedValue = .appOnly
                    binding.wrappedValue = nil
                }
                Divider()
                ForEach(props) { prop in
                    Button {
                        mode.wrappedValue = .existing
                        binding.wrappedValue = prop.name
                    } label: {
                        HStack {
                            Text(prop.name)
                            if binding.wrappedValue == prop.name { Image(systemName: "checkmark") }
                        }
                    }
                }
                Divider()
                Button("Notion에 생성하기", action: onCreateTap)
            } label: {
                Text(mode.wrappedValue == .appOnly ? "앱에만 저장" : (binding.wrappedValue ?? "선택"))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 작은 태그

private struct PlannerAddSmallTag: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
