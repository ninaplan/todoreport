import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("투두", systemImage: "checklist") {
                TodoView()
            }
            Tab("리포트", systemImage: "chart.bar.fill") {
                ReportView()
            }
            Tab("설정", systemImage: "gearshape.fill") {
                NavigationStack {
                    SettingsView()
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .tint(.nockOrange)
    }
}
