import SwiftUI
import UIKit

/// 길게 누른 뒤 끌기 — UIKit 제스처로 구현.
/// SwiftUI `LongPressGesture`는 블록 위에서 시작한 세로 스크롤까지 막아서 바꿨다.
/// UIKit 길게 누르기는 누르는 동안 손가락이 움직이면 바로 실패하므로 스크롤이 그대로 동작한다.
struct TimeBlockLongPressDragGesture: UIGestureRecognizerRepresentable {
    var minimumDuration: TimeInterval
    var isEnabled: Bool = true
    var onBegan: () -> Void
    /// 시작 지점부터 세로로 움직인 거리 (화면 기준)
    var onChanged: (CGFloat) -> Void
    var onEnded: () -> Void

    final class Coordinator {
        var startY: CGFloat = 0
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = minimumDuration
        recognizer.isEnabled = isEnabled
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        recognizer.minimumPressDuration = minimumDuration
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let y = recognizer.location(in: nil).y
        switch recognizer.state {
        case .began:
            context.coordinator.startY = y
            onBegan()
        case .changed:
            onChanged(y - context.coordinator.startY)
        case .ended, .cancelled, .failed:
            onEnded()
        default:
            break
        }
    }
}
