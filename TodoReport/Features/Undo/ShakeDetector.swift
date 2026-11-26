import UIKit
import ObjectiveC

extension Notification.Name {
    /// 기기를 흔들었을 때 (앱 안 어디서든)
    static let appDeviceDidShake = Notification.Name("appDeviceDidShake")
}

/// 흔들기 감지.
/// SwiftUI 화면에는 키보드가 없으면 「첫 응답자」가 없어서 시스템 흔들어 되돌리기(UndoManager)가 반응하지 않는다.
/// 그래서 창(UIWindow)이 받는 흔들기 신호를 받아 알림으로 보낸다.
/// 원래 구현을 함수 포인터로 저장해 먼저 그대로 호출한다 → 글자 입력 중 시스템 「입력 실행 취소」는 영향 없음.
/// (이전 방식은 교환한 메서드를 Swift가 직접 불러 자기 자신을 끝없이 호출 → 흔들면 앱이 멈췄음)
enum ShakeDetector {
    private typealias MotionEndedFunction = @convention(c) (AnyObject, Selector, UIEvent.EventSubtype, UIEvent?) -> Void

    private static var isInstalled = false

    static func install() {
        guard !isInstalled else { return }
        let windowClass: AnyClass = UIWindow.self
        let selector = #selector(UIResponder.motionEnded(_:with:))
        guard let method = class_getInstanceMethod(windowClass, selector) else { return }
        isInstalled = true

        let originalImplementation = method_getImplementation(method)
        let original = unsafeBitCast(originalImplementation, to: MotionEndedFunction.self)
        let replacement: @convention(block) (AnyObject, UIEvent.EventSubtype, UIEvent?) -> Void = { window, motion, event in
            original(window, selector, motion, event)
            guard motion == .motionShake else { return }
            NotificationCenter.default.post(name: .appDeviceDidShake, object: nil)
        }
        let newImplementation = imp_implementationWithBlock(replacement)
        // UIWindow가 직접 구현하지 않았으면 UIWindow에만 추가 (UIResponder 원본은 그대로), 구현했으면 바꿔 끼운다
        if !class_addMethod(windowClass, selector, newImplementation, method_getTypeEncoding(method)) {
            method_setImplementation(method, newImplementation)
        }
    }
}
