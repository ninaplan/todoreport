import SwiftUI
import UIKit

/// 플래너 이름 입력. 글자 수 제한은 조합이 끝난 뒤에만 적용한다.
struct PlannerNameField: View {
    @Binding var text: String
    var placeholder: String
    var textStyle: UIFont.TextStyle = .headline
    var isEnabled: Bool = true
    var autoFocus: Bool = false

    var body: some View {
        PlannerNameFieldRepresentable(
            text: $text,
            placeholder: placeholder,
            textStyle: textStyle,
            isEnabled: isEnabled,
            autoFocus: autoFocus
        )
    }
}

private struct PlannerNameFieldRepresentable: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var textStyle: UIFont.TextStyle
    var isEnabled: Bool
    var autoFocus: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.textColor = .label
        textField.returnKeyType = .done
        textField.adjustsFontForContentSizeCategory = true
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        context.coordinator.applyStyle(textStyle, to: textField)
        textField.text = text
        textField.placeholder = placeholder
        textField.isEnabled = isEnabled
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.autoFocus = autoFocus
        textField.placeholder = placeholder
        textField.isEnabled = isEnabled
        context.coordinator.applyStyle(textStyle, to: textField)
        // 조합 중에 text를 다시 넣으면 글자가 깨지거나 두 번 들어간다.
        if textField.markedTextRange == nil, textField.text != text {
            textField.text = text
        }
        if autoFocus, !context.coordinator.didAutoFocus, textField.window != nil {
            context.coordinator.didAutoFocus = true
            textField.becomeFirstResponder()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        let font = uiView.font ?? UIFont.preferredFont(forTextStyle: textStyle)
        let width = proposal.width ?? 0
        return CGSize(width: max(width, 0), height: ceil(font.lineHeight))
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        var autoFocus = false
        var didAutoFocus = false

        init(text: Binding<String>) {
            self.text = text
        }

        func applyStyle(_ textStyle: UIFont.TextStyle, to textField: UITextField) {
            textField.font = UIFont.preferredFont(forTextStyle: textStyle)
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            if textField.markedTextRange != nil {
                return true
            }
            let current = textField.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return true }
            let updated = current.replacingCharacters(in: swiftRange, with: string)
            let limited = Planner.clampedNameInput(updated, replacing: current)
            guard limited != updated else { return true }
            write(limited, to: textField, keepingSelectionFrom: range)
            return false
        }

        @objc func editingChanged(_ textField: UITextField) {
            guard textField.markedTextRange == nil else { return }
            let current = textField.text ?? ""
            let limited = Planner.clampedNameInput(current, replacing: text.wrappedValue)
            if limited != current {
                write(limited, to: textField, keepingSelectionFrom: nil)
                return
            }
            if text.wrappedValue != current {
                text.wrappedValue = current
            }
        }

        private func write(_ value: String, to textField: UITextField, keepingSelectionFrom range: NSRange?) {
            let caretOffset = range.map { $0.location + $0.length } ?? (textField.text as NSString?)?.length ?? 0
            textField.text = value
            let utf16Count = (value as NSString).length
            let clamped = min(caretOffset, utf16Count)
            if let position = textField.position(from: textField.beginningOfDocument, offset: clamped) {
                textField.selectedTextRange = textField.textRange(from: position, to: position)
            }
            if text.wrappedValue != value {
                text.wrappedValue = value
            }
        }
    }
}
