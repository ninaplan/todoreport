import SwiftUI

struct ImportantTodoTag: View {
    var body: some View {
        Text("중요")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.shared.accent)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(AppTheme.shared.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
