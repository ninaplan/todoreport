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
        Group {
            if index <= rating {
                Text("⭐")
                    .font(.system(size: size))
            } else {
                Image(systemName: "star.fill")
                    .font(.system(size: size))
                    .foregroundStyle(Color(.systemFill))
            }
        }
        .frame(width: size, height: size)
    }
}
