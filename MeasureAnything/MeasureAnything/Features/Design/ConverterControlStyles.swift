import SwiftUI
import UIKit

/// Light press feedback for toolbar and swap actions.
struct ConverterPressingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Favorites entry: haptic fires on touch-down (not after release) plus visible press shrink.
struct FavoritesToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
    }
}
