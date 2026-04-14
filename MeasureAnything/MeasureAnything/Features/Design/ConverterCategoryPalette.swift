import SwiftUI
import MeasureAnythingCore

/// Per-category color ramp for rich surfaces (e.g. fact card bands). `ConverterCategoryAccent` stays the single accent for list rows and converter chrome.
struct CategoryPalette {
    let deep: Color
    let medium: Color
    let light: Color
    let onDeep: Color
    let onDeepMuted: Color
    /// Large value line on `medium` — darker than `deep` for readable contrast on pale mints/teals.
    let valueProclamation: Color
}

enum ConverterCategoryPalette {
    static func palette(for category: UnitCategory) -> CategoryPalette {
        switch category {
        case .mass:
            CategoryPalette(
                deep: Color(red: 39 / 255, green: 80 / 255, blue: 10 / 255),
                medium: Color(red: 220 / 255, green: 239 / 255, blue: 228 / 255),
                light: Color(red: 245 / 255, green: 250 / 255, blue: 239 / 255),
                onDeep: Color.white,
                onDeepMuted: Color(red: 192 / 255, green: 221 / 255, blue: 151 / 255),
                valueProclamation: Color(red: 23 / 255, green: 52 / 255, blue: 4 / 255)
            )
        case .length:
            CategoryPalette(
                deep: Color(red: 15 / 255, green: 61 / 255, blue: 74 / 255),
                medium: Color(red: 212 / 255, green: 234 / 255, blue: 240 / 255),
                light: Color(red: 240 / 255, green: 248 / 255, blue: 250 / 255),
                onDeep: Color.white,
                onDeepMuted: Color(red: 159 / 255, green: 200 / 255, blue: 212 / 255),
                valueProclamation: Color(red: 8 / 255, green: 42 / 255, blue: 51 / 255)
            )
        case .time:
            CategoryPalette(
                deep: Color(red: 38 / 255, green: 31 / 255, blue: 82 / 255),
                medium: Color(red: 228 / 255, green: 226 / 255, blue: 244 / 255),
                light: Color(red: 245 / 255, green: 244 / 255, blue: 251 / 255),
                onDeep: Color.white,
                onDeepMuted: Color(red: 173 / 255, green: 165 / 255, blue: 214 / 255),
                valueProclamation: Color(red: 22 / 255, green: 16 / 255, blue: 64 / 255)
            )
        case .temperature:
            CategoryPalette(
                deep: Color(red: 92 / 255, green: 36 / 255, blue: 25 / 255),
                medium: Color(red: 240 / 255, green: 228 / 255, blue: 225 / 255),
                light: Color(red: 251 / 255, green: 246 / 255, blue: 245 / 255),
                onDeep: Color.white,
                onDeepMuted: Color(red: 212 / 255, green: 160 / 255, blue: 143 / 255),
                valueProclamation: Color(red: 61 / 255, green: 21 / 255, blue: 15 / 255)
            )
        case .volume:
            // Hue aligned with converter accent #AF7D2A (amber).
            CategoryPalette(
                deep: Color(red: 107 / 255, green: 73 / 255, blue: 16 / 255),
                medium: Color(red: 245 / 255, green: 235 / 255, blue: 216 / 255),
                light: Color(red: 252 / 255, green: 249 / 255, blue: 242 / 255),
                onDeep: Color.white,
                onDeepMuted: Color(red: 224 / 255, green: 196 / 255, blue: 138 / 255),
                valueProclamation: Color(red: 61 / 255, green: 42 / 255, blue: 6 / 255)
            )
        }
    }
}
