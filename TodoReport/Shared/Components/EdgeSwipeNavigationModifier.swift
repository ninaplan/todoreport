import SwiftUI
import UIKit

// MARK: - Edge swipe host (center touches pass through to content below)

private final class EdgeSwipeHostView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard bounds.contains(point) else { return nil }
        let margin = Self.edgeHitMargin
        if point.x < margin || point.x > bounds.width - margin {
            return self
        }
        return nil
    }

    private static let edgeHitMargin: CGFloat = 20
}

// MARK: - UIViewRepresentable

private struct EdgeSwipeNavigationRepresentable: UIViewRepresentable {
    let onPrev: () -> Void
    let onNext: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPrev: onPrev, onNext: onNext)
    }

    func makeUIView(context: Context) -> EdgeSwipeHostView {
        let view = EdgeSwipeHostView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let leftRecognizer = UIScreenEdgePanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLeftEdgePan(_:))
        )
        leftRecognizer.edges = .left
        leftRecognizer.cancelsTouchesInView = false
        leftRecognizer.delaysTouchesBegan = false
        leftRecognizer.delegate = context.coordinator
        view.addGestureRecognizer(leftRecognizer)

        let rightRecognizer = UIScreenEdgePanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleRightEdgePan(_:))
        )
        rightRecognizer.edges = .right
        rightRecognizer.cancelsTouchesInView = false
        rightRecognizer.delaysTouchesBegan = false
        rightRecognizer.delegate = context.coordinator
        view.addGestureRecognizer(rightRecognizer)

        return view
    }

    func updateUIView(_ uiView: EdgeSwipeHostView, context: Context) {
        context.coordinator.onPrev = onPrev
        context.coordinator.onNext = onNext
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPrev: () -> Void
        var onNext: () -> Void

        init(onPrev: @escaping () -> Void, onNext: @escaping () -> Void) {
            self.onPrev = onPrev
            self.onNext = onNext
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc func handleLeftEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
            guard gesture.state == .ended else { return }
            onPrev()
        }

        @objc func handleRightEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
            guard gesture.state == .ended else { return }
            onNext()
        }
    }
}

// MARK: - ViewModifier

private struct EdgeSwipeNavigationModifier: ViewModifier {
    let onPrev: () -> Void
    let onNext: () -> Void

    func body(content: Content) -> some View {
        content.overlay {
            EdgeSwipeNavigationRepresentable(onPrev: onPrev, onNext: onNext)
        }
    }
}

extension View {
    func edgeSwipeNavigation(onPrev: @escaping () -> Void, onNext: @escaping () -> Void) -> some View {
        modifier(EdgeSwipeNavigationModifier(onPrev: onPrev, onNext: onNext))
    }
}
