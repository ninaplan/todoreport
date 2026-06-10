import SwiftUI

/// 투두리포트 + 링크 + 노션 로고 정적 연결 아이콘 (온보딩 마지막 페이지용).
struct NotionConnectionStaticGraphic: View {
    var iconSize: CGFloat = 56
    var spacing: CGFloat = 12
    var outerSize: CGFloat = 120

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: spacing) {
            connectionIcon(named: "AppLogoSticker")
            Image(systemName: "link")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)
            connectionIcon(named: "NotionLogo")
        }
        .frame(width: outerSize, height: outerSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("투두리포트와 노션을 연결합니다")
    }

    private func connectionIcon(named assetName: String) -> some View {
        Image(assetName)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
            .shadow(color: OnboardingWelcomeAssets.iconShadowColor(for: colorScheme), radius: 10, x: 0, y: 5)
    }
}
