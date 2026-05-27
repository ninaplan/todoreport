import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("투두", systemImage: "checklist") {
                TodoView()
            }
            Tab("리포트", systemImage: "chart.bar.fill") {
                NavigationStack {
                    Text("리포트")
                        .navigationTitle("리포트")
                }
            }
            Tab("설정", systemImage: "gearshape.fill") {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(.nockOrange)
    }
}
