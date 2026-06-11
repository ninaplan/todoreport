import SwiftUI

struct TodoListLoadingView: View {
    var body: some View {
        NotionConnectionGraphic.compact
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .accessibilityLabel("할 일 목록을 불러오는 중")
    }
}
