import SwiftUI

/// Shared spacing and radii for the converter screen (keeps layout consistent).
enum ConverterLayout {
    // Spacing rhythm (8 / 12 / 16 / 24)
    static let rhythm8: CGFloat = 8
    static let rhythm12: CGFloat = 12
    static let rhythm16: CGFloat = 16
    static let rhythm24: CGFloat = 24

    /// Vertical gap between the three main converter blocks (category/mode, input, result).
    static let majorBlockSpacing: CGFloat = 24

    /// Lighter secondary surfaces (category/mode + input).
    static let secondaryBlockPadding: CGFloat = 16
    static let secondaryBlockCornerRadius: CGFloat = 12

    /// Primary result hero card.
    static let resultHeroPadding: CGFloat = 24
    static let resultHeroCornerRadius: CGFloat = 24

    static let sectionSpacing: CGFloat = 24
    static let blockSpacing: CGFloat = 16
    static let tightSpacing: CGFloat = 10
    static let cardPadding: CGFloat = 20
    static let cardCornerRadius: CGFloat = 16
    static let insetCornerRadius: CGFloat = 12
    static let horizontalInset: CGFloat = 20
}
