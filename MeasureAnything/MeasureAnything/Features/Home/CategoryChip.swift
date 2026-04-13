import SwiftUI
import MeasureAnythingCore

/// SF Symbol for taxonomy display names and built-in `UnitCategory` cases.
enum CategoryChipIcon {
    private static let byDisplayName: [String: String] = [
        "Length": "ruler",
        "Mass": "scalemass",
        "Time": "clock",
        "Temperature": "thermometer",
        "Volume": "flask",
        "Pressure": "gauge",
        "Speed": "speedometer",
        "Area": "square.dashed"
    ]

    static func symbol(for category: UnitCategory, displayName: String) -> String {
        if let s = byDisplayName[displayName] { return s }
        switch category {
        case .length: return "ruler"
        case .mass: return "scalemass"
        case .time: return "clock"
        case .temperature: return "thermometer"
        case .volume: return "flask"
        }
    }
}

struct CategoryChip: View {
    let category: UnitCategory
    let displayName: String
    /// Per-category hue (matches `ConverterCategoryAccent`).
    let accent: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: CategoryChipIcon.symbol(for: category, displayName: displayName))
                    .font(.system(size: 9, weight: .medium))
                Text(displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? accent : Color(hex: "#F0F0F3"))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        isSelected ? accent.opacity(0.35) : Color.primary.opacity(ConverterLayout.strokeOpacitySubtle),
                        lineWidth: ConverterLayout.strokeHairline
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(displayName) category")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
