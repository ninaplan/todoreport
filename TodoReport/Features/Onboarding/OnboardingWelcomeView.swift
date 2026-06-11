import SwiftUI

struct OnboardingWelcomeView: View {
    @Bindable var viewModel: OnboardingViewModel

    private let bottomActionsMinHeight: CGFloat = 124
    private let primaryButtonHeight: CGFloat = 56
    private let secondaryActionRowHeight: CGFloat = 44
    private let actionStackSpacing: CGFloat = 12

    private var isLastPage: Bool {
        viewModel.welcomePageIndex == OnboardingWelcomePage.allCases.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: welcomePageSelection) {
                ForEach(OnboardingWelcomePage.allCases) { page in
                    welcomePageContent(page)
                        .tag(page.rawValue)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: viewModel.welcomePageIndex)

            pageIndicator
                .padding(.top, 20)

            bottomActions
                .frame(minHeight: bottomActionsMinHeight, alignment: .bottom)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 52)
        }
    }

    private var welcomePageSelection: Binding<Int> {
        Binding(
            get: { viewModel.welcomePageIndex },
            set: { viewModel.goToWelcomePage($0) }
        )
    }

    @ViewBuilder
    private func welcomePageContent(_ page: OnboardingWelcomePage) -> some View {
        VStack(spacing: 20) {
            Spacer()

            if page.usesConnectionIcon {
                NotionConnectionStaticGraphic(iconSize: 62, outerSize: 132)
            } else {
                OnboardingWelcomeStickerIcon(page: page)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(page.showsBrandAccent ? .largeTitle.bold() : .title2.bold())
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingWelcomePage.allCases) { page in
                Circle()
                    .fill(page.rawValue == viewModel.welcomePageIndex
                          ? Color(.systemGray2)
                          : Color(.systemGray4))
                    .frame(width: page.rawValue == viewModel.welcomePageIndex ? 8 : 6,
                           height: page.rawValue == viewModel.welcomePageIndex ? 8 : 6)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.welcomePageIndex)
            }
        }
    }

    private var bottomActions: some View {
        VStack(spacing: actionStackSpacing) {
            if isLastPage {
                Button {
                    viewModel.selectLocalMode()
                } label: {
                    Text("나중에 연결하기")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: secondaryActionRowHeight)
                }
                .disabled(viewModel.isLoading)
            } else {
                Color.clear
                    .frame(height: secondaryActionRowHeight)
                    .accessibilityHidden(true)
            }

            if isLastPage {
                primaryCapsuleButton(
                    title: "노션 연결하기",
                    background: Color(.label),
                    foreground: Color(.systemBackground),
                    isLoading: viewModel.isLoading
                ) {
                    viewModel.selectNotionConnection()
                }
                .disabled(viewModel.isLoading)
            } else {
                primaryCapsuleButton(
                    title: "다음",
                    background: Color(.label),
                    foreground: Color(.systemBackground),
                    isLoading: false
                ) {
                    viewModel.advanceWelcomePage()
                }
            }
        }
    }

    private func primaryCapsuleButton(
        title: String,
        background: Color,
        foreground: Color,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(foreground)
                } else {
                    Text(title)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: primaryButtonHeight)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
        }
    }
}
