import SwiftUI
import UIKit

/// `UITextField` backed by a custom `inputView` to replicate `.decimalPad` without QuickType.
struct MinimalPadTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    @Binding var isFocused: Bool
    var onFocusChange: ((Bool) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.delegate = context.coordinator

        // Avoid any keyboard accessory / suggestion UI.
        tf.inputAccessoryView = nil
        tf.inputAssistantItem.leadingBarButtonGroups = []
        tf.inputAssistantItem.trailingBarButtonGroups = []

        // Helps iOS treat this field like a numeric keypad field.
        tf.keyboardType = .decimalPad
        tf.textAlignment = .left

        // Use the system `.decimalPad` keypad (no custom container/view).

        tf.autocorrectionType = .no
        tf.spellCheckingType = .no

        tf.adjustsFontSizeToFitWidth = true
        tf.minimumFontSize = 22
        tf.textColor = .label

        tf.placeholder = placeholder
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.tertiaryLabel]
        )

        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Matches the existing Converter amount field typography.
        let boldDescriptor = UIFont.systemFont(ofSize: 40, weight: .bold).fontDescriptor
        if let roundedDescriptor = boldDescriptor.withDesign(.rounded) {
            tf.font = UIFont(descriptor: roundedDescriptor, size: 40)
        } else {
            tf.font = UIFont.systemFont(ofSize: 40, weight: .bold)
        }

        context.coordinator.textField = tf

        // Keep SwiftUI binding in sync with UIKit text changes.
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)

        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self

        if uiView.text != text {
            uiView.text = text
        }

        if uiView.placeholder != placeholder {
            uiView.placeholder = placeholder
            uiView.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: UIColor.tertiaryLabel]
            )
        }

        // Drive focus from SwiftUI state.
        if isFocused && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MinimalPadTextField
        weak var textField: UITextField?

        init(parent: MinimalPadTextField) {
            self.parent = parent
        }

        @objc func textDidChange(_ tf: UITextField) {
            parent.text = tf.text ?? ""
        }

        func textFieldDidBeginEditing(_ tf: UITextField) {
            parent.onFocusChange?(true)
            tf.reloadInputViews()
        }

        func textFieldDidEndEditing(_ tf: UITextField) {
            parent.onFocusChange?(false)
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Keep behavior aligned with the decimal keypad: prevent multiple decimals.
            if string == "." && (textField.text?.contains(".") ?? false) {
                return false
            }
            return true
        }
    }
}

