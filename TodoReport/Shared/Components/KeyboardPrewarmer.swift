import UIKit

/// 콜드 스타트 시 첫 becomeFirstResponder(~1초) 비용을 앱 시작 직후가 아닌 지연 후 앞당긴다.
/// (즉시 실행 시 메인 스레드가 ~1초 블로킹되어 시작 직후 스크롤이 먹통이 됨.)
@MainActor
enum KeyboardPrewarmer {
    private static var didSchedule = false
    private static var didPrewarm = false

    static func scheduleAfterLaunch(delay: TimeInterval = 2.5) {
        guard !didSchedule else { return }
        didSchedule = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Task { @MainActor in
                prewarmOnce()
            }
        }
    }

    private static func prewarmOnce() {
        guard !didPrewarm else { return }
        didPrewarm = true

        if FirstResponderProbe.current != nil { return }
        guard let window = keyWindow else { return }

        let field = UITextField(frame: .zero)
        field.alpha = 0
        field.isUserInteractionEnabled = false
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        window.addSubview(field)
        _ = field.becomeFirstResponder()
        _ = field.resignFirstResponder()
        field.removeFromSuperview()
    }

    private static var keyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        return active?.windows.first(where: \.isKeyWindow) ?? active?.windows.first
    }
}

/// 현재 first responder 조회 (프리웜 스킵·탭 이탈 정리용).
enum FirstResponderProbe {
    private static weak var collector: UIResponder?

    static var current: UIResponder? {
        collector = nil
        UIApplication.shared.sendAction(#selector(UIResponder._nockCaptureFirstResponder(_:)), to: nil, from: nil, for: nil)
        return collector
    }

    fileprivate static func capture(_ responder: UIResponder) {
        collector = responder
    }
}

private extension UIResponder {
    @objc func _nockCaptureFirstResponder(_ sender: Any?) {
        FirstResponderProbe.capture(self)
    }
}
