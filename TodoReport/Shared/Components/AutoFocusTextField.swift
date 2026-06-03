import SwiftUI
import UIKit

/// UIKit 기반 텍스트 필드. 등장 시 자동 포커스, Return 키 동작을 콜백으로 제어.
struct AutoFocusTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var font: UIFont = .systemFont(ofSize: 17)
    var returnKeyType: UIReturnKeyType = .done
    /// false로 설정하면 등장 시 자동 포커스 없음 (편집 시트 등 기존 내용 수정 시 사용).
    var autoFocus: Bool = true
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
        // editingChanged: IME 조합 완료 후 binding 반영 (shouldChangeCharactersIn 대비 한글 자모음 분리 방지)
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        if autoFocus {
            // 키보드 dismiss 애니메이션(~0.25s) 완료를 기다린 후 포커스 획득
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak tf] in
                tf?.becomeFirstResponder()
            }
        }
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        // IME 조합 중에는 외부에서 text 덮어쓰기 금지 (한글 자모음 분리 방지)
        if tf.markedTextRange == nil, tf.text != text { tf.text = text }
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

        @objc func textChanged(_ tf: UITextField) {
            // markedTextRange가 nil일 때만 (IME 조합 완료) binding 업데이트
            if tf.markedTextRange == nil {
                text = tf.text ?? ""
            }
        }

        func textFieldShouldReturn(_ tf: UITextField) -> Bool {
            if let handler = onReturn {
                if handler() {
                    tf.text = ""
                } else {
                    tf.resignFirstResponder()
                }
            } else {
                tf.resignFirstResponder()
            }
            return false
        }

        func textFieldDidEndEditing(_ tf: UITextField) {
            // 조합 중 포커스 해제 시 최종 텍스트 동기화
            text = tf.text ?? ""
            onDismiss?()
        }
    }
}
