import SwiftUI
import MeasureAnythingCore

struct RecentPairRow: View {
    let fromUnit: UnitDefinition
    let toUnit: UnitDefinition
    let category: UnitCategory
    let accent: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: SearchCategoryIcon.symbol(for: category))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(accent)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(fromUnit.name) → \(toUnit.name)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.primary)
                    Text(category.rawValue.uppercased())
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                        .tracking(0.4)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
