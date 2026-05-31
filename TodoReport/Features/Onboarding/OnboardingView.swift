import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            switch viewModel.step {
            case .signIn:
                SignInStepView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .connectionChoice:
                ConnectionChoiceStepView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .notionOAuth:
                NotionOAuthStepView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .localModeInfo:
                LocalModeStepView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .plannerName:
                PlannerNameStepView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .selectTodoDB:
                SelectDBStepView(
                    viewModel: viewModel,
                    title: "투두 데이터베이스",
                    subtitle: "투두를 저장할 노션 데이터베이스를 선택해주세요",
                    onSelect: { viewModel.selectTodoDB($0) }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .mapTodoProps:
                MapTodoPropsStepView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .selectReportDB:
                SelectDBStepView(
                    viewModel: viewModel,
                    title: "데일리리포트 데이터베이스",
                    subtitle: "데일리리포트를 저장할 노션 데이터베이스를 선택해주세요",
                    onSelect: { viewModel.selectReportDB($0) }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .mapReportProps:
                MapReportPropsStepView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.step)
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
                    .foregroundStyle(Color.nockOrange)

                Text("투두리포트")
                    .font(.largeTitle.bold())

                Text("앱에서 기록하고, 노션에 쌓아가세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                viewModel.handleSignInResult(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .padding(.horizontal, 24)

            // TODO: 배포 전 제거 — 개발 테스트용 임시 버튼
            Button("개발용 로그인 (테스트)") {
                viewModel.devLogin()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 12)
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
                    .background(Color.nockOrange)
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
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundStyle(.primary)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
    }
}

// MARK: - Step 3: Notion OAuth

private struct NotionOAuthStepView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "globe.badge.chevron.backward")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.nockOrange)

                Text("노션 연결")
                    .font(.title2.bold())

                Text("노션 계정을 연결하면 투두와 리포트가\n노션 데이터베이스에 자동으로 저장돼요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                Task { await viewModel.startNotionOAuth() }
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("노션으로 계속하기")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.nockOrange)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .disabled(viewModel.isLoading)
            .padding(.horizontal, 24)
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
                    .foregroundStyle(Color.nockOrange)

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
                    .background(Color.nockOrange)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
    }
}

// MARK: - Step 4 (Notion): Planner Name

private struct PlannerNameStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            OnboardingBackButton { viewModel.goBack() }
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "rectangle.and.pencil.and.ellipsis")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.nockOrange)

                Text("플래너 이름")
                    .font(.title2.bold())

                Text("투두를 기록할 플래너 이름을 입력해주세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 16) {
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
                        .background(Color.nockOrange)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
            }
        }
        .onAppear { focused = true }
    }
}

// MARK: - Step 5 & 7: Select DB (공통)

private struct SelectDBStepView: View {
    let viewModel: OnboardingViewModel
    let title: String
    let subtitle: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingBackButton { viewModel.goBack() }

            // 타이틀 + 새로고침 버튼
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 12) {
                    Text(title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.horizontal, 24)

                Button {
                    Task { await viewModel.fetchDatabases() }
                } label: {
                    if viewModel.isLoadingDBs {
                        ProgressView().scaleEffect(0.8)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .disabled(viewModel.isLoadingDBs)
                .padding(.top, 28)
                .padding(.trailing, 24)
            }

            // 컨텐츠
            if viewModel.isLoadingDBs && viewModel.databases.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("데이터베이스를 불러오는 중이에요...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if viewModel.databases.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("데이터베이스를 찾을 수 없어요")
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await viewModel.fetchDatabases() }
                    } label: {
                        Label("다시 시도", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLoadingDBs)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.databases) { db in
                            Button {
                                onSelect(db.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "tablecells")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 32)
                                    Text(db.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(16)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
            }
        }
    }
}

// MARK: - Step 6: Map Todo Props

private struct MapTodoPropsStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingBackButton { viewModel.goBack() }
            VStack(spacing: 12) {
                Text("투두 속성 매핑")
                    .font(.title2.bold())
                Text("노션 DB의 속성을 앱 기능에 연결해주세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)

            List {
                PropMappingRow(
                    label: "완료", isRequired: true, typeIcon: "checkmark.square",
                    candidates: viewModel.todoProperties.filter { $0.type == "checkbox" },
                    fallback: viewModel.todoProperties,
                    selection: $viewModel.todoPropsMapping.completed
                )
                PropMappingRow(
                    label: "날짜", isRequired: true, typeIcon: "calendar",
                    candidates: viewModel.todoProperties.filter { $0.type == "date" },
                    fallback: viewModel.todoProperties,
                    selection: $viewModel.todoPropsMapping.date
                )
                OptionalPropRow(
                    label: "메모", typeIcon: "text.alignleft",
                    candidates: viewModel.todoProperties.filter { $0.type == "rich_text" },
                    mode: $viewModel.memoMode,
                    selection: $viewModel.todoPropsMapping.memo,
                    onCreate: { Task { await viewModel.createMemoProperty() } }
                )
                OptionalPropRow(
                    label: "상단고정", typeIcon: "pin",
                    candidates: viewModel.todoProperties.filter { $0.type == "checkbox" },
                    mode: $viewModel.isPinnedMode,
                    selection: $viewModel.todoPropsMapping.isPinned,
                    onCreate: { Task { await viewModel.createPinnedProperty() } }
                )
                OptionalPropRow(
                    label: "리포트", typeIcon: "link",
                    candidates: viewModel.todoProperties.filter { $0.type == "relation" },
                    mode: $viewModel.reportRelationMode,
                    selection: $viewModel.todoPropsMapping.reportRelation,
                    isRecommended: true
                )
            }
            .listStyle(.insetGrouped)

            Text("리포트를 연결하지 않으면 노션 데일리리포트 연동 및 통계가 집계되지 않아요")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            Button {
                viewModel.proceedFromMapTodoProps()
            } label: {
                Text("다음")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(viewModel.canProceedFromTodoProps ? Color.nockOrange : Color(.systemGray4))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .disabled(!viewModel.canProceedFromTodoProps)
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Step 8: Map Report Props

private struct MapReportPropsStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingBackButton { viewModel.goBack() }
            VStack(spacing: 12) {
                Text("데일리리포트 속성 매핑")
                    .font(.title2.bold())
                Text("노션 DB의 속성을 앱 기능에 연결해주세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)

            List {
                PropMappingRow(
                    label: "날짜", isRequired: true, typeIcon: "calendar",
                    candidates: viewModel.reportProperties.filter { $0.type == "date" },
                    fallback: viewModel.reportProperties,
                    selection: $viewModel.reportPropsMapping.date
                )
                OptionalPropRow(
                    label: "하루 리뷰", typeIcon: "text.alignleft",
                    candidates: viewModel.reportProperties.filter { $0.type == "rich_text" },
                    mode: $viewModel.reviewMode,
                    selection: $viewModel.reportPropsMapping.review
                )
                OptionalPropRow(
                    label: "별점", typeIcon: "star",
                    candidates: viewModel.reportProperties.filter { $0.type == "select" },
                    mode: $viewModel.ratingMode,
                    selection: $viewModel.reportPropsMapping.rating,
                    onCreate: { Task { await viewModel.createRatingProperty() } }
                )
            }
            .listStyle(.insetGrouped)

            Button {
                viewModel.proceedFromMapReportProps()
            } label: {
                Text("완료")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(viewModel.canProceedFromReportProps ? Color.nockOrange : Color(.systemGray4))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .disabled(!viewModel.canProceedFromReportProps)
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Back Button

private struct OnboardingBackButton: View {
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                Image(systemName: "chevron.left")
                    .font(.body.bold())
                    .foregroundStyle(.primary)
                    .padding(12)
                    .contentShape(Rectangle())
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
}

// MARK: - Small Tag

private struct SmallTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(.systemGray5))
            .foregroundStyle(Color(.secondaryLabel))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Prop Mapping Row (필수)

private struct PropMappingRow: View {
    let label: String
    var isRequired: Bool = false
    let typeIcon: String
    let candidates: [NotionProperty]
    let fallback: [NotionProperty]
    @Binding var selection: String?

    private var options: [NotionProperty] {
        candidates.isEmpty ? fallback : candidates
    }

    var body: some View {
        HStack {
            Image(systemName: typeIcon)
                .foregroundStyle(Color.nockOrange)
                .frame(width: 24)
            HStack(spacing: 6) {
                Text(label)
                if isRequired {
                    SmallTag(text: "필수")
                }
            }
            Spacer()
            Picker("", selection: $selection) {
                Text("선택 안 함").tag(nil as String?)
                ForEach(options, id: \.name) { prop in
                    Text(prop.name).tag(prop.name as String?)
                }
            }
            .pickerStyle(.menu)
            .tint(selection == nil ? .secondary : Color.nockOrange)
        }
    }
}

// MARK: - Optional Prop Row (선택)

private struct OptionalPropRow: View {
    let label: String
    let typeIcon: String
    let candidates: [NotionProperty]
    @Binding var mode: PropMappingMode
    @Binding var selection: String?
    var isRecommended: Bool = false
    var onCreate: (() -> Void)? = nil

    private var displayLabel: String {
        switch mode {
        case .appOnly:  return "앱에만 저장"
        case .existing: return selection ?? "선택 안 함"
        }
    }

    var body: some View {
        HStack {
            Image(systemName: typeIcon)
                .foregroundStyle(Color.nockOrange)
                .frame(width: 24)
            HStack(spacing: 6) {
                Text(label)
                if isRecommended {
                    SmallTag(text: "권장")
                }
            }
            Spacer()
            Menu {
                Button("앱에만 저장") {
                    mode = .appOnly
                    selection = nil
                }
                if let onCreate {
                    Button("생성하기") {
                        onCreate()
                    }
                }
                if !candidates.isEmpty {
                    Divider()
                    ForEach(candidates, id: \.name) { prop in
                        Button(prop.name) {
                            mode = .existing
                            selection = prop.name
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(displayLabel)
                        .font(.subheadline)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(mode == .appOnly ? .secondary : Color.nockOrange)
            }
        }
    }
}
