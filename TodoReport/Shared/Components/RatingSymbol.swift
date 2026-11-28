import SwiftUI

/// 별점 한 칸. 기본은 예전과 같은 ⭐ 이모지 / 회색 별.
/// 아이콘을 고르면 위 밝음 → 아래 진함 그라데이션, 빈 칸은 같은 모양 회색
struct RatingSymbol: View {
    let style: RatingStyle
    let filled: Bool
    let size: CGFloat

    var body: some View {
        Group {
            if let icon = style.icon {
                Image(systemName: CategoryIconName.resolved(icon))
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(fill)
            } else if filled {
                // ⭐ 이모지는 글자 상자가 글자 크기보다 커서 칸(size)보다 넓어지면 Text가 잘라 버림
                // → 조금 줄이고, fixedSize로 자기 크기 그대로 그리게(칸을 넘쳐도 자르지 않음)
                Text("⭐")
                    .font(.system(size: size * 0.85))
                    .fixedSize()
            } else {
                Image(systemName: "star.fill")
                    .font(.system(size: size))
                    .foregroundStyle(Color(.systemFill))
            }
        }
        .frame(width: size, height: size)
    }

    private var fill: AnyShapeStyle {
        guard filled else { return AnyShapeStyle(Color(.systemFill)) }
        let color = Color(hex: style.resolvedColorHex)
        return AnyShapeStyle(
            LinearGradient(
                colors: [color.mix(with: .white, by: 0.35), color],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
