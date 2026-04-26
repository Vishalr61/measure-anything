import Combine
import SwiftUI
import UIKit

@MainActor
final class KeyboardObserver: ObservableObject {
    @Published private(set) var isVisible: Bool = false
    @Published private(set) var height: CGFloat = 0

    private var willChangeFrame: NSObjectProtocol?
    private var willHide: NSObjectProtocol?

    init() {
        willChangeFrame = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handleKeyboardFrameChange(note)
        }
        willHide = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isVisible = false
            self?.height = 0
        }
    }

    private func handleKeyboardFrameChange(_ note: Notification) {
        guard
            let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.keyWindow
        else {
            return
        }

        let converted = window.convert(frame, from: nil)
        let overlap = max(0, window.bounds.maxY - converted.minY)
        height = overlap
        isVisible = overlap > 0
    }

    deinit {
        if let willChangeFrame { NotificationCenter.default.removeObserver(willChangeFrame) }
        if let willHide { NotificationCenter.default.removeObserver(willHide) }
    }
}

enum AppAccent {
    /// Primary app accent (amber) used by the bottom nav selection and swap affordances.
    static let amber = Color(red: 175 / 255, green: 125 / 255, blue: 42 / 255) // #AF7D2A
}
