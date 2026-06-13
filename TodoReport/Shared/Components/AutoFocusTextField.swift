import SwiftUI
import UIKit

/// UIKit 기반 텍스트 필드. 등장 시 자동 포커스, Return 키 동작을 콜백으로 제어.
struct AutoFocusTextField: View {
    @Binding var text: String
    let placeholder: String
    /// 설정 시 Dynamic Type에 맞춰 스케일 (SwiftUI `.font(.body)` 등과 동일 계열).
    var textStyle: UIFont.TextStyle? = nil
    /// textStyle 미지정 시에만 사용. 고정 pt — Dynamic Type 미반영.
    var font: UIFont? = nil
    var returnKeyType: UIReturnKeyType = .done
    var contentVerticalAlignment: UITextField.ContentVerticalAlignment = .center
    /// false로 설정하면 등장 시 자동 포커스 없음 (편집 시트 등 기존 내용 수정 시 사용).
    var autoFocus: Bool = true
    var axis: Axis = .horizontal
    /// Return 키 눌림 시 호출. true 반환 → firstResponder 유지 + 텍스트 clear, false 반환 → resign.
    var onReturn: (() -> Bool)? = nil
    /// 포커스를 잃는 모든 경우에 호출 (Return으로 resign + 외부 탭).
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        switch axis {
        case .vertical:
            AutoFocusMultilineTextFieldRepresentable(
                text: $text,
                placeholder: placeholder,
                textStyle: textStyle,
                font: font,
                autoFocus: autoFocus,
                onDismiss: onDismiss
            )
        default:
            AutoFocusSingleLineTextFieldRepresentable(
                text: $text,
                placeholder: placeholder,
                textStyle: textStyle,
                font: font,
                returnKeyType: returnKeyType,
                contentVerticalAlignment: contentVerticalAlignment,
                autoFocus: autoFocus,
                onReturn: onReturn,
                onDismiss: onDismiss
            )
        }
    }
}

// MARK: - Single line (UITextField)

private struct AutoFocusSingleLineTextFieldRepresentable: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var textStyle: UIFont.TextStyle? = nil
    var font: UIFont? = nil
    var returnKeyType: UIReturnKeyType = .done
    var contentVerticalAlignment: UITextField.ContentVerticalAlignment = .center
    var autoFocus: Bool = true
    var onReturn: (() -> Bool)? = nil
    var onDismiss: (() -> Void)? = nil

    private func resolvedFont(compatibleWith traitCollection: UITraitCollection) -> UIFont {
        if let textStyle {
            return UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traitCollection)
        }
        if let font {
            return font
        }
        return UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.font = resolvedFont(compatibleWith: tf.traitCollection)
        tf.returnKeyType = returnKeyType
        tf.borderStyle = .none
        tf.contentVerticalAlignment = contentVerticalAlignment
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        if autoFocus {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak tf] in
                tf?.becomeFirstResponder()
            }
        }
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        if textStyle != nil {
            tf.font = resolvedFont(compatibleWith: tf.traitCollection)
        }
        tf.contentVerticalAlignment = contentVerticalAlignment
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
            text = tf.text ?? ""
            onDismiss?()
        }
    }
}

// MARK: - Multiline (UITextView)

private final class GrowingTextView: UITextView {
    var minContentHeight: CGFloat = 36

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : (superview?.bounds.width ?? 0)
        guard width > 0 else {
            return CGSize(width: UIView.noIntrinsicMetric, height: minContentHeight)
        }
        let fitted = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: max(minContentHeight, fitted.height))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}

private struct AutoFocusMultilineTextFieldRepresentable: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var textStyle: UIFont.TextStyle? = nil
    var font: UIFont? = nil
    var autoFocus: Bool = true
    var onDismiss: (() -> Void)? = nil

    private func resolvedFont(compatibleWith traitCollection: UITraitCollection) -> UIFont {
        if let textStyle {
            return UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traitCollection)
        }
        if let font {
            return font
        }
        return UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
    }

    func makeUIView(context: Context) -> GrowingTextView {
        let tv = GrowingTextView()
        tv.font = resolvedFont(compatibleWith: tv.traitCollection)
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        tv.textContainer.lineFragmentPadding = 0
        tv.isScrollEnabled = false
        tv.delegate = context.coordinator
        tv.text = text

        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.font = tv.font
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.isHidden = !text.isEmpty
        tv.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: tv.topAnchor, constant: 8),
            placeholderLabel.leadingAnchor.constraint(equalTo: tv.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: tv.trailingAnchor)
        ])
        context.coordinator.placeholderLabel = placeholderLabel

        if autoFocus {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak tv] in
                tv?.becomeFirstResponder()
            }
        }
        return tv
    }

    func updateUIView(_ tv: GrowingTextView, context: Context) {
        if textStyle != nil {
            tv.font = resolvedFont(compatibleWith: tv.traitCollection)
            context.coordinator.placeholderLabel?.font = tv.font
        }
        if tv.markedTextRange == nil, tv.text != text {
            tv.text = text
        }
        context.coordinator.placeholderLabel?.isHidden = !tv.text.isEmpty
        context.coordinator.onDismiss = onDismiss
        tv.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: GrowingTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(uiView.minContentHeight, fitted.height))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onDismiss: onDismiss)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var onDismiss: (() -> Void)?
        weak var placeholderLabel: UILabel?

        init(text: Binding<String>, onDismiss: (() -> Void)?) {
            _text = text
            self.onDismiss = onDismiss
        }

        func textViewDidChange(_ textView: UITextView) {
            placeholderLabel?.isHidden = !textView.text.isEmpty
            if textView.markedTextRange == nil {
                text = textView.text ?? ""
            }
            textView.invalidateIntrinsicContentSize()
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            text = textView.text ?? ""
            placeholderLabel?.isHidden = !textView.text.isEmpty
            textView.invalidateIntrinsicContentSize()
            onDismiss?()
        }
    }
}
