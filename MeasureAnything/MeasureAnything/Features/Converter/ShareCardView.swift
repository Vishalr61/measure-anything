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
// 9:16 portrait card (390 × 693) rendered to an image via ImageRenderer.
// The fixed dimensions guarantee identical output across all screen sizes
// including iPad — ImageRenderer always captures at this resolution.

struct ShareCardView: View {
    let fromValue: String
    let fromUnit: String
    let toValue: String
    let toUnit: String
    /// One of "LENGTH", "MASS", "TIME", "TEMP", "VOLUME".
    let category: String
    let isPrecisionMode: Bool
    let equationText: String

    static let cardWidth: CGFloat = 390
    static let cardHeight: CGFloat = 693

    private var bgColor: Color {
        switch category {
        case "LENGTH": return Color(hex: "#1A6E87")
        case "MASS":   return Color(hex: "#3D7A52")
        case "TIME":   return Color(hex: "#4A3FA0")
        case "TEMP":   return Color(hex: "#A84232")
        case "VOLUME": return Color(hex: "#C48E2E")
        default:       return Color(hex: "#1A6E87")
        }
    }

    private func resultFontSize(for value: String) -> CGFloat {
        switch value.count {
        case 1...4:  return 110
        case 5...6:  return 82
        case 7...9:  return 60
        default:     return 44
        }
    }

    var body: some View {
        ZStack {
            // Background
            bgColor

            // Layer 1 — Ghost number
            Text(toValue)
                .font(.system(size: 280, weight: .black))
                .foregroundStyle(Color.white.opacity(0.045))
                .lineLimit(1)
                .minimumScaleFactor(0.1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Layer 3 — Centre content
            VStack(spacing: 0) {
                approxRow

                Text(toValue)
                    .font(.system(size: resultFontSize(for: toValue), weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .tracking(-4)

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

            // Layer 2 — Top row + Layer 4 — Bottom brand
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

    // MARK: — Subviews

    @ViewBuilder
    private var approxRow: some View {
        HStack(spacing: 8) {
            if isPrecisionMode {
                Text("=")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
                Text("PRECISION")
                    .font(.system(size: 9, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.2)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5))
            } else {
                Text("≈")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
        }
    }

    private var topRow: some View {
        HStack {
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
