import UIKit

/// Minimal keypad that mimics the iOS `.decimalPad` layout.
/// Used as a custom `UITextField.inputView` to remove the QuickType/input assistant bar.
final class MinimalNumberPad: UIView {
    var onKey: ((String) -> Void)?

    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    private var bottomInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first?
            .safeAreaInsets.bottom ?? 0
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 260 + bottomInset)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1.0)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            // `intrinsicContentSize` already includes the safe area bottom inset.
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])

        for row in keys {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 6

            for key in row {
                let btn = UIButton(type: .system)

                if key == "⌫" {
                    btn.setImage(UIImage(systemName: "delete.backward"), for: .normal)
                    btn.tintColor = .label
                } else {
                    btn.setTitle(key, for: .normal)
                    btn.setTitleColor(.label, for: .normal)
                    btn.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .regular)
                }

                let isGreyKey = key == "." || key == "⌫"
                btn.backgroundColor = isGreyKey
                    ? UIColor(red: 0.69, green: 0.71, blue: 0.73, alpha: 1.0)
                    : .white

                btn.layer.cornerRadius = 10
                btn.layer.shadowColor = UIColor.black.cgColor
                btn.layer.shadowOpacity = 0.15
                btn.layer.shadowOffset = CGSize(width: 0, height: 1)
                btn.layer.shadowRadius = 0.5

                btn.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
                btn.accessibilityLabel = (key == "⌫") ? "Delete" : key

                rowStack.addArrangedSubview(btn)
            }
            stack.addArrangedSubview(rowStack)
        }
    }

    @objc private func keyTapped(_ sender: UIButton) {
        if let title = sender.title(for: .normal) {
            onKey?(title)
        } else {
            onKey?("⌫")
        }
    }
}

