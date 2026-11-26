import SwiftUI

/// 화면 아래에 「실행 취소」 배너 자리를 만든다. 자기 화면(`scope`) 배너만 보인다
struct UndoBannerHostModifier: ViewModifier {
    let scope: UndoBannerScope
    /// 오른쪽 여백 (투두 탭은 오른쪽 아래 + 버튼을 피한다)
    let trailingInset: CGFloat
    let bottomInset: CGFloat

    private var center: AppUndoCenter { AppUndoCenter.shared }

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let banner = center.banner, banner.scope == scope {
                UndoBannerView(
                    message: banner.message,
                    onUndo: { center.performUndo() },
                    onDismiss: { center.dismissBanner() }
                )
                .id(banner.id)
                .padding(.leading, 16)
                .padding(.trailing, trailingInset)
                .padding(.bottom, bottomInset)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

extension View {
    func undoBannerHost(_ scope: UndoBannerScope, trailingInset: CGFloat = 16, bottomInset: CGFloat = 16) -> some View {
        modifier(UndoBannerHostModifier(scope: scope, trailingInset: trailingInset, bottomInset: bottomInset))
    }
}
