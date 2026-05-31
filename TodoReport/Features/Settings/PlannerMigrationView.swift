import SwiftUI

struct PlannerMigrationView: View {
    @State private var viewModel: PlannerMigrationViewModel
    @Environment(\.dismiss) private var dismiss

    init(planner: Planner) {
        _viewModel = State(initialValue: PlannerMigrationViewModel(planner: planner))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .idle:
                    centeredContent { idleContent }
                case .oauthRequired:
                    centeredContent { oauthWaitContent }
                case .selectTodoDB:
                    selectDBView(isTodo: true)
                case .mapTodoProps:
                    mapPropsView(isTodo: true)
                case .selectReportDB:
                    selectDBView(isTodo: false)
                case .mapReportProps:
                    mapPropsView(isTodo: false)
                case .chooseMode:
                    centeredContent { chooseModeContent }
                case .running:
                    centeredContent { runningContent }
                case .completed:
                    centeredContent { completedContent }
                case .failed(let m):
                    centeredContent { failedContent(message: m) }
                }
            }
            .navigationTitle("노션 플래너와 연결하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    switch viewModel.step {
                    case .oauthRequired, .selectTodoDB, .mapTodoProps, .selectReportDB, .mapReportProps:
                        Button("뒤로") { viewModel.goBack() }
                    default:
                        EmptyView()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.step != .running {
                        Button("닫기") { dismiss() }
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
    }

    // MARK: - 레이아웃 헬퍼

    private func centeredContent<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 32) {
            Spacer()
            content()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Idle

    private var idleContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "n.square.fill")
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.shared.accent)

            VStack(spacing: 8) {
                Text("Notion과 연결하기")
                    .font(.title3.bold())
                Text("Notion DB를 선택하고\n데이터 처리 방법을 선택해주세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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

            Button("시작하기") { viewModel.startConnection() }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.shared.accent)
        }
    }

    // MARK: - OAuth 대기

    private var oauthWaitContent: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Notion 로그인 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Safari에서 승인 후 돌아오세요")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
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
            .padding(.top, 8)
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
                    .padding(.top, 16)
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
            .padding(.top, 8)
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
                    Task { await viewModel.proceedFromMapReportProps() }
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

    // MARK: - 데이터 처리 선택

    private var chooseModeContent: some View {
        VStack(spacing: 16) {
            Text("데이터 처리 방법 선택")
                .font(.title3.bold())

            VStack(spacing: 12) {
                modeButton(
                    icon: "arrow.up.to.line.circle.fill",
                    title: "앱 데이터를 노션에 올리기",
                    description: "이 플래너의 투두·리포트를 Notion에 업로드해요\n기존 앱 데이터는 유지됩니다",
                    color: AppTheme.shared.accent
                ) {
                    Task { await viewModel.startMigration(mode: .uploadToNotion) }
                }

                modeButton(
                    icon: "arrow.down.to.line.circle.fill",
                    title: "노션 데이터 가져오기",
                    description: "Notion DB의 데이터를 앱으로 가져와요\n기존 앱 데이터는 대체됩니다",
                    color: .blue
                ) {
                    Task { await viewModel.startMigration(mode: .importFromNotion) }
                }
            }
        }
    }

    private func modeButton(
        icon: String, title: String, description: String, color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(color)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
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
    }

    // MARK: - Running

    private var runningContent: some View {
        VStack(spacing: 20) {
            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)
                .tint(AppTheme.shared.accent)

            Text("\(viewModel.completedCount) / \(viewModel.totalCount)개 완료")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("처리 중... 앱을 닫지 말아주세요")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Completed

    private var completedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)

            Text("완료!")
                .font(.title3.bold())
            Text(viewModel.completionMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("닫기") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.shared.accent)
        }
    }

    // MARK: - Failed

    private func failedContent(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange)

            Text("연결 실패")
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("다시 시도") { viewModel.goBack() }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.shared.accent)
        }
    }

    // MARK: - 속성 행 헬퍼

    private func requiredPropRow(label: String, props: [NotionProperty], binding: Binding<String?>) -> some View {
        HStack {
            Text(label)
            MigrationSmallTag("필수")
            Spacer()
            Menu {
                ForEach(props) { prop in
                    Button {
                        binding.wrappedValue = prop.name
                    } label: {
                        HStack {
                            Text(prop.name)
                            if binding.wrappedValue == prop.name { Image(systemName: "checkmark") }
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
        label: String, mode: Binding<PropMappingMode>, props: [NotionProperty],
        binding: Binding<String?>, onCreateTap: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            Menu {
                Button("앱에만 저장") { mode.wrappedValue = .appOnly; binding.wrappedValue = nil }
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

// MARK: - 태그

private struct MigrationSmallTag: View {
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
