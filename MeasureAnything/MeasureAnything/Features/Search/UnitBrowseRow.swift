import SwiftUI
import MeasureAnythingCore

// MARK: – Info button (matches the search results row info button exactly)

struct UnitInfoButton: View {
    let accent: Color
    let unitName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accent)
            }
            .frame(width: 34, height: 34)
            .background(
                accent.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open fact card for \(unitName)")
        .accessibilityHint("Opens a detail card with interesting facts about this unit")
    }
}

// MARK: –

struct UnitBrowseRow: View {
    let unit: UnitDefinition
    let accent: Color
    var isSelected: Bool = false
    var nextRowSelected: Bool = false
    var selectionLightShade: Color = .clear
    var horizontalInset: CGFloat = 0
    /// Icon + name + chevron + spare middle area (two-step Explore selection).
    let onTap: () -> Void
    /// When set and `unit.funFact` is non-nil, the fun-fact line opens the fact card.
    var onOpenFactCard: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(isSelected ? accent : accent.opacity(0.15))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: unit.iconName ?? "circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isSelected ? .white : accent)
                )
                .contentShape(Circle())
                .onTapGesture { onTap() }

            VStack(alignment: .leading, spacing: 3) {
                Text(unit.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.primary)

                if let fact = unit.funFact {
                    Text(fact)
                        .font(.system(size: 12))
                        .foregroundStyle(accent.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            if let openFact = onOpenFactCard {
                UnitInfoButton(accent: accent, unitName: unit.name, action: openFact)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, horizontalInset)
        .background(isSelected ? selectionLightShade.opacity(0.5) : .clear)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            if !isSelected && !nextRowSelected {
                Divider()
                    .padding(.horizontal, horizontalInset)
            }
        }
    }
}
