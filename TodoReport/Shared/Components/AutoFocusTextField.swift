import SwiftUI
import UIKit

/// UIKit 기반 텍스트 필드. 등장 시 자동 포커스, Return 키 동작을 콜백으로 제어.
struct AutoFocusTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var font: UIFont = .systemFont(ofSize: 17)
    var returnKeyType: UIReturnKeyType = .done
    /// Return 키 눌림 시 호출. true 반환 → firstResponder 유지 + 텍스트 clear, false 반환 → resign.
    var onReturn: (() -> Bool)? = nil
    /// 포커스를 잃는 모든 경우에 호출 (Return으로 resign + 외부 탭).
    var onDismiss: (() -> Void)? = nil

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.font = font
        tf.returnKeyType = returnKeyType
        tf.delegate = context.coordinator
        tf.becomeFirstResponder()
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        if tf.text != text { tf.text = text }
        context.coordinator.onReturn = onReturn
        context.coordinator.onDismiss = onDismiss
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onReturn: onReturn, onDismiss: onDismiss)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var onReturn: (() -> Bool)?
        var onDismiss: (() -> Void)?

        init(text: Binding<String>, onReturn: (() -> Bool)?, onDismiss: (() -> Void)?) {
            _text = text
            self.onReturn = onReturn
            self.onDismiss = onDismiss
        }

        func textField(_ tf: UITextField, shouldChangeCharactersIn range: NSRange, replacementString s: String) -> Bool {
            if let cur = tf.text, let r = Range(range, in: cur) {
                text = cur.replacingCharacters(in: r, with: s)
            }
            return true
        }

        func textFieldShouldReturn(_ tf: UITextField) -> Bool {
            Task { @MainActor in
                guard let handler = self.onReturn else { return }
                if handler() {
                    tf.text = ""
                } else {
                    tf.resignFirstResponder()
                }
            }
            return false
        }

        func textFieldDidEndEditing(_ tf: UITextField) {
            onDismiss?()
        }
    }
}
