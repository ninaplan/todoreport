import SwiftUI

struct MainTabView: View {
    let onAccountDeleted: () -> Void
    @State private var tabCoordinator = MainTabCoordinator.shared
    @State private var showSearchTabHint = false
    @AppStorage("hasSeenSearchTabHint") private var hasSeenSearchTabHint = false
    @AppStorage("lastSeenWhatsNewVersion") private var lastSeenWhatsNewVersion = ""

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
            Tab(value: MainTabCoordinator.Tab.search, role: .search) {
                NavigationStack {
                    TodoSearchView()
                }
            }
        }
        .environment(tabCoordinator)
        .overlay(alignment: .bottomTrailing) {
            if showSearchTabHint {
                searchTabHintBubble
                    .padding(.trailing, 18)
                    .padding(.bottom, 58)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            presentSearchTabHintIfNeeded()
        }
        .onChange(of: lastSeenWhatsNewVersion) { _, _ in
            presentSearchTabHintIfNeeded()
        }
        .onChange(of: tabCoordinator.isWhatsNewPopupPresented) { _, presented in
            guard !presented else { return }
            presentSearchTabHintIfNeeded()
        }
    }

    /// 업데이트 팝업을 본 뒤에만 1회. 신규 설치는 온보딩에서 latest 버전을 선저장.
    private func presentSearchTabHintIfNeeded() {
        guard !hasSeenSearchTabHint else { return }
        guard !tabCoordinator.isWhatsNewPopupPresented else { return }
        guard let latestId = whatsNewReleases.first?.id,
              lastSeenWhatsNewVersion == latestId else { return }
        guard !showSearchTabHint else { return }

        hasSeenSearchTabHint = true
        withAnimation(.easeInOut(duration: 0.2)) {
            showSearchTabHint = true
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSearchTabHint = false
                }
            }
        }
    }

    private var searchTabHintBubble: some View {
        VStack(spacing: 0) {
            Text("여기서 할 일을 검색해보세요")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 190)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.black)
                .rotationEffect(.degrees(180))
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(y: -2)
        }
        .fixedSize()
    }
}
