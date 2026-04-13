import SwiftUI
import MeasureAnythingCore

struct CategoryBrowseCard: View {
    let category: UnitCategory
    let units: [UnitDefinition]
    let accent: Color
    let onTap: () -> Void

    private var sampleNames: [String] {
        Array(
            units
                .filter { $0.kind == .absurd }
                .sorted { ($0.interestScore ?? 0) > ($1.interestScore ?? 0) }
                .prefix(3)
                .map(\.name)
        )
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.white.opacity(0.65))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: SearchCategoryIcon.symbol(for: category))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(accent)
                            )
                        Text(category.rawValue.capitalized)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(accent.opacity(0.9))
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Text("\(units.count) units")
                            .font(.system(size: 12))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.5))
                            .clipShape(Capsule())
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(accent)
                    }
                }

                HStack(spacing: 6) {
                    ForEach(sampleNames, id: \.self) { name in
                        Text(name)
                            .font(.system(size: 12))
                            .foregroundStyle(accent.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.65))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    let remainder = units.count - sampleNames.count
                    if remainder > 0 {
                        Text("+\(remainder)")
                            .font(.system(size: 12))
                            .foregroundStyle(accent.opacity(0.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accent.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(accent.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
