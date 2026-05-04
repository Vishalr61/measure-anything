import SwiftUI
import UIKit

/// Renders `ShareCardView` to a UIImage and presents `UIActivityViewController`
/// directly via UIKit — ImageRenderer guarantees the image is fully formed
/// before the activity sheet is constructed, fixing the empty-on-first-tap race.
struct ShareCardPresenter {

    @MainActor
    static func present(
        from viewController: UIViewController,
        fromValue: String,
        fromUnit: String,
        toValue: String,
        toUnit: String,
        category: String,
        isPrecisionMode: Bool,
        equationText: String
    ) {
        guard #available(iOS 16.0, *) else { return }

        let card = ShareCardView(
            fromValue: fromValue,
            fromUnit: fromUnit,
            toValue: formatForCard(toValue),
            toUnit: toUnit,
            category: category,
            isPrecisionMode: isPrecisionMode,
            equationText: equationText
        )

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0  // @3x for crisp output across all screen sizes
        renderer.proposedSize = ProposedViewSize(
            width: ShareCardView.cardWidth,
            height: ShareCardView.cardHeight
        )

        guard let image = renderer.uiImage else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let vc = UIActivityViewController(
                activityItems: [image],
                applicationActivities: nil
            )
            // iPad popover support
            if let popover = vc.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(
                    x: viewController.view.bounds.midX,
                    y: viewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
            viewController.present(vc, animated: true)
        }
    }

    /// Formats the result number for the share card:
    /// - ≥ 1B → "1.2B"
    /// - ≥ 1M → "3.4M"
    /// - ≥ 10K → "12,345" (with thousands separator)
    /// - else → max 4 significant figures
    static func formatForCard(_ value: String) -> String {
        guard let number = Double(value) else { return value }
        let absNumber = abs(number)

        switch absNumber {
        case 1_000_000_000...:
            return String(format: "%.1fB", number / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", number / 1_000_000)
        case 10_000...:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: number)) ?? "\(Int(number))"
        default:
            return number.significantFigures(4)
        }
    }
}

// MARK: - Significant figures helper

extension Double {
    /// Rounds to N significant figures, trims trailing zeros after the decimal.
    func significantFigures(_ figures: Int) -> String {
        if self == 0 { return "0" }
        let d = ceil(log10(abs(self)))
        let power = figures - Int(d)
        let magnitude = pow(10.0, Double(power))
        let shifted = (self * magnitude).rounded()
        let result = shifted / magnitude
        if result.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", result)
        }
        return "\(result)"
    }
}
