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
        HStack(spacing: 0) {
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
        .padding(.vertical, 8)
        .background {
            Color.white
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(hex: "#E8E8E8"))
                .frame(height: 0.5)
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
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? selectionTint : Color(hex: "#B4B2A9"))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? selectionTint : Color(hex: "#B4B2A9"))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
