import UIKit

/// Lightweight haptic feedback for key actions (no analytics, local-only).
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func favorite() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func share() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
