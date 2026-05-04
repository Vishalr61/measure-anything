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

    /// Plain-text version of `fromValue` for the bottom equation line. Scientific
    /// notation (`×10^N`) is left intact — the equation text is small enough
    /// that the literal `^` exponent reads cleanly without typographic superscript.
    var equationFromValue: String {
        fromValue
    }

    var equationText: String {
        "\(equationFromValue) \(fromUnit) converted into something you can actually picture."
    }

    var resultFontSize: CGFloat {
        switch toValue.count {
        case 0...4:   return 110
        case 5...6:   return 82
        case 7...9:   return 60
        case 10...13: return 44
        default:      return 32
        }
    }

    var body: some View {
        ZStack {
            accentColor

            // Layer 1 — Ghost number
            ExponentTextView(value: toValue, fontSize: 280)
                .opacity(0.045)
                .frame(width: Self.cardWidth)
                .allowsHitTesting(false)

            // Layer 3 — Centre content
            VStack(spacing: 0) {
                approxRow
                    .padding(.bottom, 4)

                ExponentTextView(value: toValue, fontSize: resultFontSize)

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
                ExponentTextView(
                    value: fromValue,
                    fontSize: 14,
                    maxWidth: 100,
                    foregroundColor: .white
                )
                .fixedSize()

                Text(fromUnit.truncated(to: 20))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.13)))
            .fixedSize()

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
    /// Formats a numeric string for display on the card. Handles scientific-notation
    /// inputs ("1.235e+08") since `Double(value)` parses them back to a Double, then
    /// we re-bucket the absolute magnitude.
    /// - ≥ 1B → "1.2B"
    /// - ≥ 1M → "3.4M"
    /// - ≥ 10K → "12,345" (with thousands separator)
    /// - 0.0001 ... < 10K → 4 significant figures, trailing zeros stripped
    /// - < 0.0001 → "1.23×10^-7" style scientific notation
    static func formatForCard(_ value: String) -> String {
        // Parse — handles both standard and scientific notation strings.
        guard let number = Double(value) else { return value }
        let absVal = Swift.abs(number)
        let sign = number < 0 ? "-" : ""

        switch absVal {
        case 1_000_000_000...:
            return sign + String(format: "%.1fB", absVal / 1_000_000_000)
        case 1_000_000...:
            return sign + String(format: "%.1fM", absVal / 1_000_000)
        case 10_000...:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return sign + (formatter.string(from: NSNumber(value: absVal)) ?? value)
        case 1...:
            // 4 significant figures
            return sign + fourSigFigs(absVal)
        case 0.0001...:
            // Small decimals — 4 sig figs
            return sign + fourSigFigs(absVal)
        default:
            // Very small — emit "1.23×10^N" / "1.23×10^−N" so ExponentTextView can
            // split it and render the exponent as a true superscript glyph.
            // Unicode minus (U+2212) is used for negative exponents so that the parse
            // step can detect them deterministically and to render visually balanced.
            return sign + String(format: "%.2e", absVal)
                .replacingOccurrences(of: "e+0", with: "×10^")
                .replacingOccurrences(of: "e+", with: "×10^")
                .replacingOccurrences(of: "e-0", with: "×10^−")
                .replacingOccurrences(of: "e-", with: "×10^−")
        }
    }

    private static func fourSigFigs(_ value: Double) -> String {
        guard value > 0 else { return "0" }
        let d = ceil(log10(value))
        let power = 4 - Int(d)
        let magnitude = pow(10.0, Double(power))
        let rounded = (value * magnitude).rounded() / magnitude
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", rounded)
        }
        // Strip unnecessary trailing zeros
        return "\(rounded)"
    }
}

// MARK: - Scientific notation parsing + rendering

private struct ScientificComponents {
    let coefficient: String   // e.g. "3.758"
    let base: String          // always "×10"
    let exponent: String      // unsigned exponent digits, e.g. "10" or "7"
    let isNegativeExp: Bool
}

/// Splits a value string like "3.758×10^10" or "-5.1×10^−7" into its parts.
/// Returns nil for plain decimals — caller falls back to a plain `Text`.
private func parseScientific(_ value: String) -> ScientificComponents? {
    guard value.contains("×10^") else { return nil }
    let parts = value.components(separatedBy: "×10^")
    guard parts.count == 2 else { return nil }
    let coeff = parts[0]
    let exp = parts[1]
    // Accept Unicode minus (U+2212) and ASCII hyphen as negative markers.
    let isNeg = exp.hasPrefix("−") || exp.hasPrefix("-")
    let expDigits = isNeg ? String(exp.dropFirst()) : exp
    return ScientificComponents(
        coefficient: coeff,
        base: "×10",
        exponent: expDigits,
        isNegativeExp: isNeg
    )
}

/// Renders a value with a true typographic superscript when it contains
/// scientific notation; otherwise renders the value as a plain Text.
struct ExponentTextView: View {
    let value: String
    let fontSize: CGFloat
    var maxWidth: CGFloat = 310
    var foregroundColor: Color = .white

    var body: some View {
        if let sci = parseScientific(value) {
            HStack(alignment: .top, spacing: 0) {
                Text(sci.coefficient + "×10")
                    .font(.system(size: fontSize, weight: .black))
                    .foregroundStyle(foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .tracking(-2)

                VStack(spacing: 0) {
                    Text((sci.isNegativeExp ? "−" : "") + sci.exponent)
                        .font(.system(size: fontSize * 0.42, weight: .black))
                        .foregroundStyle(foregroundColor)
                        .lineLimit(1)
                        .padding(.top, fontSize * 0.06)
                    Spacer(minLength: 0)
                }
                .frame(height: fontSize * 0.88)
            }
            .frame(maxWidth: maxWidth)
        } else {
            Text(value)
                .font(.system(size: fontSize, weight: .black))
                .foregroundStyle(foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .tracking(-4)
                .frame(maxWidth: maxWidth)
        }
    }
}
