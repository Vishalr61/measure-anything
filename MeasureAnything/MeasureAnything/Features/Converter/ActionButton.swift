import SwiftUI

/// Compact icon + uppercase label for TO card action row.
struct ActionButton: View {
    let icon: String
    let label: String
    let background: Color
    let foreground: Color
    var disabled: Bool = false
    /// When `false`, a disabled control (e.g. saved pair) stays at full opacity so filled symbols read clearly.
    var fadeWhenDisabled: Bool = true
    var iconScale: CGFloat = 1
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(background)
                    .frame(height: 36)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundStyle(foreground)
                            .scaleEffect(iconScale)
                    )
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(foreground)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled && fadeWhenDisabled ? 0.4 : 1)
    }
}
