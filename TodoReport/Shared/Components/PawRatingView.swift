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
                        pawIcon(index: index)
                    }
                    .buttonStyle(.plain)
                } else {
                    pawIcon(index: index)
                }
            }
        }
    }

    private func pawIcon(index: Int) -> some View {
        Image(systemName: "pawprint.circle.fill")
            .font(.system(size: size))
            .foregroundStyle(index <= rating ? Color(.label) : Color(.systemFill))
    }
}
