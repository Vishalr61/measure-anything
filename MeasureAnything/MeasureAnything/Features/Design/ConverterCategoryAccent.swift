import SwiftUI
import MeasureAnythingCore

/// Muted category hues for the converter only (surfaces stay neutral).
enum ConverterCategoryAccent {
    static func accent(for category: UnitCategory) -> Color {
        switch category {
        case .length:
            Color(red: 0.26, green: 0.48, blue: 0.62)
        case .mass:
            Color(red: 0.50, green: 0.40, blue: 0.34)
        case .time:
            Color(red: 0.44, green: 0.36, blue: 0.58)
        case .temperature:
            Color(red: 0.58, green: 0.34, blue: 0.32)
        case .volume:
            Color(red: 0.24, green: 0.50, blue: 0.52)
        }
    }
}
