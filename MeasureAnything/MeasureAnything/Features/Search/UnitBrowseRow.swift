import SwiftUI
import MeasureAnythingCore

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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .highPriorityGesture(TapGesture().onEnded { _ in onTap() })

                if let fact = unit.funFact {
                    if let openFact = onOpenFactCard {
                        FactCardRowAffordance(text: fact, accent: accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .highPriorityGesture(TapGesture().onEnded { _ in openFact() })
                    } else {
                        Text(fact)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
                .contentShape(Rectangle())
                .highPriorityGesture(TapGesture().onEnded { _ in onTap() })
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
