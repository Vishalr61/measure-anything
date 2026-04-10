import SwiftUI

extension Color {
    /// Parses `#RRGGBB` or `#RRGGBBAA` (alpha optional).
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            a = 255
            r = (value >> 8) * 17
            g = (value >> 4 & 0xF) * 17
            b = (value & 0xF) * 17
        case 6:
            a = 255
            r = value >> 16
            g = value >> 8 & 0xFF
            b = value & 0xFF
        case 8:
            a = value >> 24
            r = value >> 16 & 0xFF
            g = value >> 8 & 0xFF
            b = value & 0xFF
        default:
            a = 255
            r = 0
            g = 0
            b = 0
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
