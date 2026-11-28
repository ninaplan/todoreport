import SwiftUI

struct PawRatingView: View {
    let rating: Int
    var interactive: Bool = false
    var size: CGFloat = 22
    var spacing: CGFloat = 6
    /// nil이면 지금 플래너의 별점 모양 (편집 화면 미리보기만 넘긴다)
    var style: RatingStyle? = nil
    var onTap: ((Int) -> Void)? = nil

    var body: some View {
        let resolved = style ?? RatingStyle.current
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { index in
                if interactive, let onTap {
                    Button { onTap(index) } label: {
                        RatingSymbol(style: resolved, filled: index <= rating, size: size)
                    }
                    .buttonStyle(.plain)
                } else {
                    RatingSymbol(style: resolved, filled: index <= rating, size: size)
                }
            }
        }
    }
}
