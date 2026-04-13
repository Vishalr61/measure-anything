import SwiftUI

/// Pill-style button that triggers the unit picker sheet.
/// `style` controls the visual; `.capsule` matches the FROM card, `.inline` matches the TO card.
struct UnitPickerPillButton: View {
    enum Style { case capsule, inline }

    let name: String
    let accent: Color
    var style: Style = .capsule
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            content
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) unit, opens picker")
        .accessibilityHint("Choose a unit")
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .capsule:
            HStack(spacing: 8) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent.opacity(0.92))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent.opacity(0.65))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)

        case .inline:
            HStack(spacing: 3) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}
