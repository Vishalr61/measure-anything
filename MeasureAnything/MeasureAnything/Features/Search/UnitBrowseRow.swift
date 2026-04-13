import SwiftUI
import MeasureAnythingCore

struct UnitBrowseRow: View {
    let unit: UnitDefinition
    let accent: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: unit.iconName ?? "circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(accent)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(unit.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.primary)
                    if let fact = unit.funFact {
                        Text(fact)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(
            Divider().frame(maxWidth: .infinity),
            alignment: .bottom
        )
    }
}
