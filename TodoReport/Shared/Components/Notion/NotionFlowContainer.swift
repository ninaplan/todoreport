import SwiftUI

struct NotionFlowContainer<Content: View>: View {
    let title: String
    var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .navigationBarTitleDisplayMode(titleDisplayMode)
                .navigationTitle(title)
                .background(Color(.systemGroupedBackground))
        }
    }
}
