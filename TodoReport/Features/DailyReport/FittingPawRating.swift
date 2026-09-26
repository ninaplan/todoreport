import SwiftUI

/// 별 5개의 크기를 제안 너비에 맞춘다.
/// 기본 20pt·간격 6. 칩이 최소 폭까지 줄어든 뒤에만 1pt씩 줄이고 15pt에서 멈춘다.
struct FittingPawRating: View {
    let rating: Int
    let onTap: (Int) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            paw(size: 20, preferred: 20, spacing: 6)
            paw(size: 19, preferred: 20, spacing: 6)
            paw(size: 18, preferred: 20, spacing: 6)
            paw(size: 17, preferred: 20, spacing: 6)
            paw(size: 16, preferred: 20, spacing: 6)
            paw(size: 15, preferred: 20, spacing: 6)
        }
    }

    private func paw(size: CGFloat, preferred: CGFloat, spacing: CGFloat) -> some View {
        PawRatingView(
            rating: rating,
            interactive: true,
            size: size,
            spacing: spacing * size / preferred,
            onTap: onTap
        )
        .fixedSize(horizontal: true, vertical: true)
    }
}
