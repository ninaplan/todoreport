import SwiftUI

struct MainTabView: View {
    let onAccountDeleted: () -> Void
    @State private var tabCoordinator = MainTabCoordinator.shared

    init(onAccountDeleted: @escaping () -> Void = {}) {
        self.onAccountDeleted = onAccountDeleted
    }

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
                    SettingsView(onAccountDeleted: onAccountDeleted)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .environment(tabCoordinator)
    }
}
