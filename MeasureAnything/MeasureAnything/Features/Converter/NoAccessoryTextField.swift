import SwiftUI
import UIKit

struct NoAccessoryTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var accessibilityLabel: String? = nil
    var onFocusChange: ((Bool) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.inputView = NumberPadView(target: context.coordinator)
        tf.inputAccessoryView = nil
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.changed), for: .editingChanged)

        let base = UIFont.systemFont(ofSize: 40, weight: .bold)
        tf.font = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
            .withDesign(.rounded)
            .map { UIFont(descriptor: $0, size: 40) } ?? base

        tf.adjustsFontSizeToFitWidth = true
        tf.minimumFontSize = 22
        tf.textColor = .label
        tf.placeholder = placeholder

        if let accessibilityLabel {
            tf.accessibilityLabel = accessibilityLabel
        }

        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self

        if uiView.text != text {
            uiView.text = text
        }
        if uiView.placeholder != placeholder {
            uiView.placeholder = placeholder
        }
        if let accessibilityLabel, uiView.accessibilityLabel != accessibilityLabel {
            uiView.accessibilityLabel = accessibilityLabel
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NoAccessoryTextField

        init(parent: NoAccessoryTextField) {
            self.parent = parent
        }

        @objc func changed(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func handleKey(_ value: String) {
            if value == "⌫" {
                if !parent.text.isEmpty {
                    parent.text.removeLast()
                }
                return
            }

            if value == "." && parent.text.contains(".") {
                return
            }

            parent.text += value
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onFocusChange?(true)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.onFocusChange?(false)
        }
    }
}

final class NumberPadView: UIView {
    private weak var target: NoAccessoryTextField.Coordinator?

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 320)
    }

    init(target: NoAccessoryTextField.Coordinator) {
        self.target = target
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 320))

        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = UIColor.systemBackground

        let buttons = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            [".", "0", "⌫"],
        ]

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        for row in buttons {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 10
            rowStack.distribution = .fillEqually

            for title in row {
                let button = UIButton(type: .system)
                button.setTitle(title, for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 28, weight: .medium)
                button.backgroundColor = .secondarySystemBackground
                button.layer.cornerRadius = 14
                button.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
                rowStack.addArrangedSubview(button)
            }

            stack.addArrangedSubview(rowStack)
        }

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func tap(_ sender: UIButton) {
        guard let value = sender.title(for: .normal) else { return }
        target?.handleKey(value)
    }
}

