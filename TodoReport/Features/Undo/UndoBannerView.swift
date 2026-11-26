import SwiftUI

/// 화면 아래 「○○했습니다 · 실행 취소」 캡슐. 아래로 쓸어내리면 닫힌다
struct UndoBannerView: View {
    let message: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 8)
            Button(action: onUndo) {
                Text("실행 취소")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.shared.accent)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 18)
        .padding(.trailing, 16)
        .frame(minHeight: 48)
        .glassEffect(.regular, in: .capsule)
        // 빈 곳(Spacer)도 잡히게 캡슐 전체를 터치 영역으로
        .contentShape(Capsule())
        .offset(y: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    // 아래로만 따라 내려간다
                    dragOffset = max(0, value.translation.height)
                }
                .onEnded { value in
                    if value.translation.height > 24 || value.predictedEndTranslation.height > 60 {
                        onDismiss()
                    } else {
                        withAnimation(.spring(duration: 0.25)) { dragOffset = 0 }
                    }
                }
        )
        .accessibilityElement(children: .contain)
    }
}
