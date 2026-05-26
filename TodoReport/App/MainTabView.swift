import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("투두", systemImage: "checklist") {
                NavigationStack {
                    Text("투두")
                        .navigationTitle("투두")
                }
            }
            Tab("리포트", systemImage: "chart.bar.fill") {
                NavigationStack {
                    Text("리포트")
                        .navigationTitle("리포트")
                }
            }
            Tab("설정", systemImage: "gearshape.fill") {
                NavigationStack {
                    Text("설정")
                        .navigationTitle("설정")
                }
            }
        }
        .tint(.nockOrange)
    }
}
