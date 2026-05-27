import SwiftUI

// TODO: 배포 전 제거 — 개발용 설정 임시 뷰
private struct SettingsPlaceholderView: View {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false

    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    onboardingCompleted = false
                } label: {
                    Text("온보딩 초기화 (개발용)")
                }
            }
        }
    }
}

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
                    SettingsPlaceholderView()
                        .navigationTitle("설정")
                }
            }
        }
        .tint(.nockOrange)
    }
}
