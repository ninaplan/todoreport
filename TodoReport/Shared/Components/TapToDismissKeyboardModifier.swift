import SwiftUI
import UIKit

// MARK: - First responder

extension UIView {
    /// 서브트리에서 텍스트 입력(UITextField/UITextView) first responder만 찾는다.
    /// List의 CellHostingView 등 isFirstResponder만 true인 컨테이너는 무시한다.
    func firstResponderInHierarchy() -> UIView? {
        if isFirstResponder, self is UITextField || self is UITextView {
            return self
        }
        for subview in subviews {
            if let found = subview.firstResponderInHierarchy() {
                return found
            }
        }
        return nil
    }
}

// MARK: - Tap catcher (glass pane)

/// first responder가 있을 때만 탭을 가로채 키보드를 내린다.
/// 포커스 없음·first responder(편집 중 텍스트필드) 위는 hitTest nil로 아래로 통과시킨다.
private final class TapCatcherView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard bounds.contains(point) else { return nil }

        guard let responder = window?.firstResponderInHierarchy() else {
            return nil
        }

        let frameInSelf = responder.convert(responder.bounds, to: self)
        if frameInSelf.contains(point) {
            return nil
        }

        return self
    }
}

// MARK: - UIViewRepresentable

private struct TapCatcherRepresentable: UIViewRepresentable {
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

    func updateUIView(_ uiView: TapCatcherView, context: Context) {}

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
    func body(content: Content) -> some View {
        content.overlay {
            TapCatcherRepresentable()
        }
    }
}

extension View {
    func tapToDismissKeyboard() -> some View {
        modifier(TapToDismissKeyboardModifier())
    }
}
