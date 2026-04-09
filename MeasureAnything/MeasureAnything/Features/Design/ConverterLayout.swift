import SwiftUI

/// Shared spacing and radii for the converter screen (keeps layout consistent).
enum ConverterLayout {
    // Spacing rhythm (4 / 8 / 12 / 16 / 24)
    static let rhythm4: CGFloat = 4
    static let rhythm8: CGFloat = 8
    static let rhythm12: CGFloat = 12
    static let rhythm16: CGFloat = 16
    static let rhythm20: CGFloat = 20
    static let rhythm24: CGFloat = 24

    /// Vertical gap between the three main converter blocks (category/mode, input, result).
    static let majorBlockSpacing: CGFloat = 30

    /// Lighter secondary surfaces (category/mode + input).
    static let secondaryBlockPadding: CGFloat = 16
    static let secondaryBlockCornerRadius: CGFloat = 12

    /// Reference-style white conversion cards (input + unit rows) — soft, high-radius “dashboard” cards.
    static let referenceCardCornerRadius: CGFloat = 28
    static let referenceCardShadowOpacity: Double = 0.07
    static let referenceCardShadowRadius: CGFloat = 20
    static let referenceCardShadowY: CGFloat = 8

    /// Primary result hero card.
    static let resultHeroPadding: CGFloat = 24
    static let resultHeroCornerRadius: CGFloat = 28

    static let sectionSpacing: CGFloat = 28
    static let blockSpacing: CGFloat = 20
    static let tightSpacing: CGFloat = 10
    static let cardPadding: CGFloat = 22
    static let cardCornerRadius: CGFloat = 16
    static let insetCornerRadius: CGFloat = 12
    static let horizontalInset: CGFloat = 20

    // Strokes (systemic: pills ≈ card hairline; emphasis uses accent + same line width)
    static let strokeHairline: CGFloat = 1
    static let strokeOpacitySubtle: Double = 0.08
    static let strokeOpacityMedium: Double = 0.14
    static let accentBarWidth: CGFloat = 3
}
