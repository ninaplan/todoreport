import SwiftUI

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
        .environment(tabCoordinator)
    }
}
