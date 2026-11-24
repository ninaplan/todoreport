import SwiftUI
import UIKit

enum TabBarAppearance {
    /// Tab bar 선택 색만 UIKit appearance로 지정 — SwiftUI `.tint(accent)`는 alert까지 오염시키므로 사용하지 않음.
    /// 설정 > 포인트 컬러를 따른다. 바꾼 뒤 다시 호출하면 지금 보이는 탭바에도 바로 반영된다.
    static func applyNockAccent() {
        let accent = UIColor(AppTheme.shared.accent)
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        [appearance.stackedLayoutAppearance,
         appearance.inlineLayoutAppearance,
         appearance.compactInlineLayoutAppearance].forEach { item in
            item.selected.iconColor = accent
            item.selected.titleTextAttributes = [.foregroundColor: accent]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = accent

        // appearance 프록시는 새로 만들어지는 탭바에만 적용되므로, 이미 떠 있는 탭바도 직접 바꾼다
        for tabBar in visibleTabBars() {
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
            tabBar.tintColor = accent
        }
    }

    private static func visibleTabBars() -> [UITabBar] {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return windows.flatMap { findTabBars(in: $0) }
    }

    private static func findTabBars(in view: UIView) -> [UITabBar] {
        if let tabBar = view as? UITabBar { return [tabBar] }
        return view.subviews.flatMap { findTabBars(in: $0) }
    }
}
