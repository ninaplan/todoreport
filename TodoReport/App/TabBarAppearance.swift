import UIKit

enum TabBarAppearance {
    static let nockOrange = UIColor(red: 0xFD / 255, green: 0x68 / 255, blue: 0x45 / 255, alpha: 1)

    /// Tab bar 선택 색만 UIKit appearance로 지정 — SwiftUI `.tint(accent)`는 alert까지 오염시키므로 사용하지 않음
    static func applyNockAccent() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        [appearance.stackedLayoutAppearance,
         appearance.inlineLayoutAppearance,
         appearance.compactInlineLayoutAppearance].forEach { item in
            item.selected.iconColor = nockOrange
            item.selected.titleTextAttributes = [.foregroundColor: nockOrange]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = nockOrange
    }
}
