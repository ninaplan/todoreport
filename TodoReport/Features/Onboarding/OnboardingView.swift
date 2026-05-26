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
                            Text("투두와 리포트가 노션에 자동 저장돼요")
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
                            Text("이 기기에만 저장돼요")
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

// MARK: - Step 4: Local Mode Info

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
