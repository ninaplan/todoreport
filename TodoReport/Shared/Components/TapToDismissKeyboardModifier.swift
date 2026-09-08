import SwiftUI
import UIKit

// MARK: - First responder

extension UIView {
    /// 이 뷰 서브트리에서 현재 first responder를 재귀적으로 찾는다.
    func firstResponderInHierarchy() -> UIView? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let found = subview.firstResponderInHierarchy() {
                return found
            }
        }
        return nil
    }
}

// MARK: - Tap catcher (glass pane)

/// `isActive`일 때만 탭을 가로채 키보드를 내린다.
/// 비활성·first responder(편집 중 텍스트필드) 위는 hitTest nil로 아래로 통과시킨다.
private final class TapCatcherView: UIView {
    var isActive: Bool = false

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isActive, bounds.contains(point) else { return nil }

        if let responder = window?.firstResponderInHierarchy() {
            let frameInSelf = responder.convert(responder.bounds, to: self)
            if frameInSelf.contains(point) {
                return nil
            }
        }

        return self
    }
}

// MARK: - UIViewRepresentable

private struct TapCatcherRepresentable: UIViewRepresentable {
    var isActive: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> TapCatcherView {
        let view = TapCatcherView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap)
        )
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: TapCatcherView, context: Context) {
        uiView.isActive = isActive
    }

    final class Coordinator: NSObject {
        @objc func handleTap() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
}

// MARK: - ViewModifier

private struct TapToDismissKeyboardModifier: ViewModifier {
    var isActive: Bool

    func body(content: Content) -> some View {
        content.overlay {
            TapCatcherRepresentable(isActive: isActive)
        }
    }
}

extension View {
    func tapToDismissKeyboard(isActive: Bool) -> some View {
        modifier(TapToDismissKeyboardModifier(isActive: isActive))
    }
}
