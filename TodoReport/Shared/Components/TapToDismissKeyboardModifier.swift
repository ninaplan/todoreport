import SwiftUI
import UIKit

// MARK: - UIViewRepresentable

/// 화면을 덮는 투명 호스트. 자체는 터치를 받지 않고(아래 뷰로 통과),
/// 윈도우에 탭 제스처를 붙여 first responder를 내려 기존 onDismiss 체인을 탄다.
private struct TapToDismissKeyboardRepresentable: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.attach(to: uiView)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var attachedWindow: UIWindow?
        private lazy var tapRecognizer: UITapGestureRecognizer = {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            return tap
        }()

        func attach(to view: UIView) {
            if let window = view.window {
                install(on: window)
                return
            }
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let window = view?.window else { return }
                self.install(on: window)
            }
        }

        private func install(on window: UIWindow) {
            if attachedWindow === window { return }
            detach()
            window.addGestureRecognizer(tapRecognizer)
            attachedWindow = window
        }

        func detach() {
            tapRecognizer.view?.removeGestureRecognizer(tapRecognizer)
            attachedWindow = nil
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        /// 텍스트필드·텍스트뷰 자체 탭은 커서 이동/포커스 유지 — resign 하지 않음.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView {
                    return false
                }
                view = current.superview
            }
            return true
        }

        @objc private func handleTap() {
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
            TapToDismissKeyboardRepresentable()
        }
    }
}

extension View {
    func tapToDismissKeyboard() -> some View {
        modifier(TapToDismissKeyboardModifier())
    }
}
