import SwiftUI
import UIKit

/// Installs a UIKit `inputAccessoryView` (Cancel / Done) onto the currently-focused `UITextField`.
/// This renders flush inside the keyboard chrome (like the native keypad accessory).
struct KeyboardInputAccessoryConfigurator: UIViewRepresentable {
    let isActive: Bool
    let accent: UIColor
    let onCancel: () -> Void
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCancel: onCancel, onDone: onDone)
    }

    func makeUIView(context: Context) -> AccessoryInjectorView {
        AccessoryInjectorView(accent: accent, coordinator: context.coordinator)
    }

    func updateUIView(_ uiView: AccessoryInjectorView, context: Context) {
        uiView.isActive = isActive
        uiView.accent = accent
        uiView.coordinator = context.coordinator
        uiView.updateAccessoryIfNeeded()
    }

    final class Coordinator: NSObject {
        let onCancel: () -> Void
        let onDone: () -> Void

        init(onCancel: @escaping () -> Void, onDone: @escaping () -> Void) {
            self.onCancel = onCancel
            self.onDone = onDone
        }

        @objc func cancelTapped() { onCancel() }
        @objc func doneTapped() { onDone() }
    }

    final class AccessoryInjectorView: UIView {
        var isActive: Bool = false
        var accent: UIColor
        var coordinator: Coordinator

        init(accent: UIColor, coordinator: Coordinator) {
            self.accent = accent
            self.coordinator = coordinator
            super.init(frame: .zero)
            isHidden = true
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            updateAccessoryIfNeeded()
        }

        func updateAccessoryIfNeeded() {
            guard isActive, let window else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard let tf = self.findFocusedTextField(in: window) else { return }

                // Build a native-feeling accessory: use default toolbar background (matches keyboard)
                let toolbar = UIToolbar()
                toolbar.sizeToFit()

                let cancel = UIBarButtonItem(
                    title: "Cancel",
                    style: .plain,
                    target: self.coordinator,
                    action: #selector(Coordinator.cancelTapped)
                )
                cancel.tintColor = self.accent.withAlphaComponent(0.55)

                let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

                let done = UIBarButtonItem(
                    title: "Done",
                    style: .done,
                    target: self.coordinator,
                    action: #selector(Coordinator.doneTapped)
                )
                done.tintColor = self.accent
                let boldFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
                done.setTitleTextAttributes([.font: boldFont], for: .normal)
                done.setTitleTextAttributes([.font: boldFont], for: .highlighted)

                toolbar.items = [cancel, spacer, done]
                tf.inputAccessoryView = toolbar
                tf.reloadInputViews()
            }
        }

        private func findFocusedTextField(in view: UIView) -> UITextField? {
            if let tf = view as? UITextField, tf.isFirstResponder { return tf }
            for sub in view.subviews {
                if let found = findFocusedTextField(in: sub) { return found }
            }
            return nil
        }
    }
}

