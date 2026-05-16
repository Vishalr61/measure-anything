import SwiftUI
import MeasureAnythingCore

/// Muted category hues for the converter only (surfaces stay neutral).
enum ConverterCategoryAccent {
    static func accent(for category: UnitCategory) -> Color {
        switch category {
        case .length:
            Color(red: 26 / 255, green: 95 / 255, blue: 115 / 255) // #1A5F73 Ocean
        case .mass:
            Color(red: 61 / 255, green: 107 / 255, blue: 74 / 255) // #3D6B4A Earth
        case .time:
            Color(red: 61 / 255, green: 53 / 255, blue: 128 / 255) // #3D3580 Midnight
        case .temperature:
            Color(red: 139 / 255, green: 58 / 255, blue: 42 / 255) // #8B3A2A Volcanic
        case .volume:
            Color(red: 175 / 255, green: 125 / 255, blue: 42 / 255) // #AF7D2A Amber
        }
    }
}
