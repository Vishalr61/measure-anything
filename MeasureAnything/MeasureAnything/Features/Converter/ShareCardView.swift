import SwiftUI
import UIKit

// MARK: - String truncation helper

extension String {
    /// Truncates with an ellipsis if longer than `length`.
    func truncated(to length: Int) -> String {
        count > length ? String(prefix(length)) + "…" : self
    }
}

// MARK: - ShareCardView
//
// 9:16 portrait card (390 × 693). Used both as an in-app preview (scaled)
// and as the source for ImageRenderer capture at full resolution. All
// layout values are fixed so the captured image is identical on every
// device including iPad.

struct ShareCardView: View {
    let fromValue: String
    let fromUnit: String
    let toValue: String
    let toUnit: String
    /// One of "LENGTH", "MASS", "TIME", "TEMP", "VOLUME".
    let category: String
    let isPrecisionMode: Bool

    static let cardWidth: CGFloat = 390
    static let cardHeight: CGFloat = 693

    var accentColor: Color {
        switch category {
        case "LENGTH": return Color(hex: "#1A6E87")
        case "MASS":   return Color(hex: "#3D7A52")
        case "TIME":   return Color(hex: "#4A3FA0")
        case "TEMP":   return Color(hex: "#A84232")
        case "VOLUME": return Color(hex: "#C48E2E")
        default:       return Color(hex: "#1A6E87")
        }
    }

    var equationText: String {
        "\(fromValue) \(fromUnit) converted into something you can actually picture."
    }

    var resultFontSize: CGFloat {
        switch toValue.count {
        case 0...4: return 110
        case 5...6: return 82
        case 7...9: return 60
        default:    return 44
        }
    }

    var body: some View {
        ZStack {
            accentColor

            // Layer 1 — Ghost number
            Text(toValue)
                .font(.system(size: 280, weight: .black))
                .foregroundStyle(Color.white.opacity(0.045))
                .lineLimit(1)
                .minimumScaleFactor(0.1)
                .frame(width: Self.cardWidth)

            // Layer 3 — Centre content
            VStack(spacing: 0) {
                approxRow
                    .padding(.bottom, 4)

                Text(toValue)
                    .font(.system(size: resultFontSize, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .tracking(-4)
                    .frame(maxWidth: 310)

                Text(toUnit.truncated(to: 20))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(1)
                    .padding(.top, 10)

                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 2)
                    .cornerRadius(1)
                    .padding(.vertical, 20)

                Text(equationText)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 260)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Layer 2 — Top row + Layer 4 — Brand footer
            VStack {
                topRow
                    .padding(.horizontal, 40)
                    .padding(.top, 40)

                Spacer()

                Text("MEASURE ANYTHING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.white.opacity(0.22))
                    .padding(.bottom, 40)
            }
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
    }

    // MARK: – Subviews

    @ViewBuilder
    private var approxRow: some View {
        HStack(spacing: 8) {
            Text(isPrecisionMode ? "=" : "≈")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
            if isPrecisionMode {
                Text("PRECISION")
                    .font(.system(size: 9, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.2)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5))
            }
        }
    }

    private var topRow: some View {
        HStack(alignment: .center) {
            // FROM chip
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(fromValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(fromUnit.truncated(to: 20))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.13)))

            Spacer()

            // Category tag
            Text(category)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.1)))
        }
    }
}

// MARK: - Number formatting for the share card

extension ShareCardView {
    /// Formats a numeric string for display on the card:
    /// - ≥ 1B → "1.2B"
    /// - ≥ 1M → "3.4M"
    /// - ≥ 10K → "12,345" (with thousands separator)
    /// - else → max 4 significant figures, trailing zeros stripped
    static func formatForCard(_ value: String) -> String {
        guard let number = Double(value) else { return value }
        let absNumber = Swift.abs(number)
        let sign = number < 0 ? "-" : ""

        switch absNumber {
        case 1_000_000_000...:
            return sign + String(format: "%.1fB", absNumber / 1_000_000_000)
        case 1_000_000...:
            return sign + String(format: "%.1fM", absNumber / 1_000_000)
        case 10_000...:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return sign + (formatter.string(from: NSNumber(value: absNumber)) ?? value)
        default:
            if absNumber == 0 { return "0" }
            let d = ceil(log10(absNumber == 0 ? 1 : absNumber))
            let power = 4 - Int(d)
            let magnitude = pow(10.0, Double(power))
            let rounded = (absNumber * magnitude).rounded() / magnitude
            if rounded.truncatingRemainder(dividingBy: 1) == 0 {
                return sign + String(format: "%.0f", rounded)
            }
            return sign + "\(rounded)"
        }
    }
}
