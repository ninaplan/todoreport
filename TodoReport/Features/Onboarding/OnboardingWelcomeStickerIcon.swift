import SwiftUI

/// 온보딩 웰컴 — 1페이지 PNG 로고, 2~4페이지 SF Symbol 라인 아이콘.
struct OnboardingWelcomeStickerIcon: View {
    let page: OnboardingWelcomePage

    @Environment(\.colorScheme) private var colorScheme

    private let defaultOuterSize: CGFloat = 120
    private let symbolPointSize: CGFloat = 52

    private var outerSize: CGFloat {
        page.usesBrandLogoAsset ? defaultOuterSize * 0.8 : defaultOuterSize
    }

    var body: some View {
        Group {
            if page.usesBrandLogoAsset {
                Image("AppLogoSticker")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
            } else if let symbolName = page.lineSymbolName {
                Image(systemName: symbolName)
                    .font(.system(size: symbolPointSize, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: outerSize, height: outerSize)
        .shadow(color: OnboardingWelcomeAssets.iconShadowColor(for: colorScheme), radius: 10, x: 0, y: 5)
        .accessibilityHidden(true)
    }
}

enum OnboardingWelcomeAssets {
    static func iconShadowColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.18)
    }
}
