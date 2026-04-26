import Combine
import SwiftUI
import UIKit

final class KeyboardObserver: ObservableObject {
    @Published private(set) var isVisible: Bool = false

    private var willShow: NSObjectProtocol?
    private var willHide: NSObjectProtocol?

    init() {
        willShow = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isVisible = true
        }
        willHide = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isVisible = false
        }
    }

    deinit {
        if let willShow { NotificationCenter.default.removeObserver(willShow) }
        if let willHide { NotificationCenter.default.removeObserver(willHide) }
    }
}

enum AppAccent {
    /// Primary app accent (amber) used by the bottom nav selection and swap affordances.
    static let amber = Color(red: 175 / 255, green: 125 / 255, blue: 42 / 255) // #AF7D2A
}

