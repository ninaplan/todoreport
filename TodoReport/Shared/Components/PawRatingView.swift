import SwiftUI

struct PawRatingView: View {
    let rating: Int
    var interactive: Bool = false
    var size: CGFloat = 22
    var spacing: CGFloat = 6
    var onTap: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { index in
                if interactive, let onTap {
                    Button { onTap(index) } label: {
                        starIcon(index: index)
                    }
                    .buttonStyle(.plain)
                } else {
                    starIcon(index: index)
                }
            }
        }
    }

    private func starIcon(index: Int) -> some View {
        let filled = index <= rating
        return ZStack {
            Text("⭐")
                .font(.system(size: size))
                .fixedSize()
                .opacity(filled ? 1 : 0)
                .accessibilityHidden(!filled)
            Image(systemName: "star.fill")
                .font(.system(size: size))
                .foregroundStyle(Color(.systemFill))
                .fixedSize()
                .opacity(filled ? 0 : 1)
                .accessibilityHidden(filled)
        }
        .fixedSize()
    }
}
