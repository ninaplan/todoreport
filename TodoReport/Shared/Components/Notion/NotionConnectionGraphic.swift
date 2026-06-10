import SwiftUI

/// 투두리포트 아이콘 + 데이터 교환 애니메이션 + 노션 로고.
struct NotionConnectionGraphic: View {
    var iconSize: CGFloat = 56
    var laneWidth: CGFloat = 60
    var spacing: CGFloat = 12

    var body: some View {
        HStack(spacing: spacing) {
            connectionIcon(named: "AppLogoSticker")
            NotionDataExchangeAnimation(laneWidth: laneWidth)
            connectionIcon(named: "NotionLogo")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("투두리포트와 노션이 연결됩니다")
    }

    private func connectionIcon(named assetName: String) -> some View {
        Image(assetName)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
            .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 5)
    }
}
