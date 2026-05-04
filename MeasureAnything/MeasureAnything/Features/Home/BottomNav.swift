import SwiftUI

struct BottomNav: View {
    @Binding var selected: Tab
    /// Matches active category accent on the Convert tab.
    var selectionTint: Color
    /// Fired when the user taps a tab they're already on.
    var onRetap: ((Tab) -> Void)?

    enum Tab: Hashable {
        case convert
        case explore
        case settings
    }

    var body: some View {
        HStack(spacing: 56) {
            NavTab(
                iconBase: "arrow.left.arrow.right",
                label: "Convert",
                isSelected: selected == .convert,
                selectionTint: selectionTint
            ) {
                if selected == .convert { onRetap?(.convert) }
                selected = .convert
            }
            NavTab(
                iconBase: "sparkles",
                label: "Explore",
                isSelected: selected == .explore,
                selectionTint: selectionTint
            ) {
                if selected == .explore { onRetap?(.explore) }
                selected = .explore
            }
            NavTab(
                iconBase: "gearshape",
                label: "Settings",
                isSelected: selected == .settings,
                selectionTint: selectionTint
            ) {
                if selected == .settings { onRetap?(.settings) }
                selected = .settings
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .background {
            Color.white
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

private struct NavTab: View {
    let iconBase: String
    let label: String
    let isSelected: Bool
    let selectionTint: Color
    let action: () -> Void

    private var systemImage: String {
        switch iconBase {
        case "arrow.left.arrow.right":
            return isSelected ? "arrow.left.arrow.right.circle.fill" : "arrow.left.arrow.right"
        case "sparkles":
            return "sparkles"
        case "gearshape":
            return isSelected ? "gearshape.fill" : "gearshape"
        default:
            return iconBase
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? selectionTint : Color(hex: "#B4B2A9"))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? selectionTint : Color(hex: "#B4B2A9"))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSelected ? "" : "Switch to \(label) tab")
    }
}
