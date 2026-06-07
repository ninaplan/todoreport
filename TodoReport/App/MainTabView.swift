import SwiftUI
import UIKit

struct MainTabView: View {
    @State private var tabCoordinator = MainTabCoordinator.shared

    var body: some View {
        @Bindable var tabs = tabCoordinator
        TabView(selection: $tabs.selectedTab) {
            Tab("투두", systemImage: "checklist", value: MainTabCoordinator.Tab.todo) {
                TodoView()
            }
            Tab("리포트", systemImage: "chart.bar.fill", value: MainTabCoordinator.Tab.report) {
                ReportView()
            }
            Tab("설정", systemImage: "gearshape.fill", value: MainTabCoordinator.Tab.settings) {
                NavigationStack {
                    SettingsView()
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .tint(AppTheme.shared.accent)
        .environment(tabCoordinator)
        .onAppear { Self.applyTabBarAccent() }
    }

    /// iOS 26 Tab bar는 SwiftUI `.tint` 우선. UIKit appearance는 구형 tab bar 폴백.
    private static func applyTabBarAccent() {
        let color = UIColor(red: 0xFD / 255, green: 0x68 / 255, blue: 0x45 / 255, alpha: 1)
        UITabBar.appearance().tintColor = color
    }
}
