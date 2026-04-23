import SwiftUI
import MeasureAnythingCore

struct DidYouKnowCard: View {
    let unit: UnitDefinition
    var accent: Color = Color(red: 0x2B / 255, green: 0x5C / 255, blue: 0xE6 / 255)
    /// When set, the card is tappable and shows a trailing arrow affordance.
    var onOpenFactCard: (() -> Void)?

    /// Fixed card height so the layout matches the Roll-the-Dice card above and
    /// doesn't jump when fun fact length changes.
    private let cardHeight: CGFloat = 128
    private let cornerRadius: CGFloat = 16
    private let textMaxLines: Int = 4

    @State private var showFact: Bool = false
    @State private var flashOpacity: Double = 1

    var body: some View {
        let resolved = resolvedFact()

        let content = HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Did you know")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(accent)
                    .textCase(.uppercase)
                    .tracking(0.54) // ≈ 0.06em at 9pt

                Text(resolved)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(red: 0x2C / 255, green: 0x2C / 255, blue: 0x2A / 255))
                    .lineSpacing(5)
                    .multilineTextAlignment(.leading)
                    .lineLimit(textMaxLines)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            if onOpenFactCard != nil {
                Text("→")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(.top, 1)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: cardHeight)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(accent.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.08), radius: 8, x: 0, y: 3)
        .opacity(showFact ? flashOpacity : 0)
        .animation(.easeIn(duration: 0.3), value: unit.id)
        .onAppear {
            showFact = true
        }
        .onChange(of: unit.id) { _, _ in
            showFact = true
            flash()
        }

        Group {
            if let onOpenFactCard {
                Button(action: onOpenFactCard) {
                    content
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Did you know")
                .accessibilityValue(resolved)
                .accessibilityHint("Opens full fact card")
            } else {
                content
                    .accessibilityElement(children: .combine)
            }
        }
    }

    /// Soft paper-like surface with a subtle, category-specific pattern tinted
    /// by the accent color so the card feels part of the app theme instead of
    /// a plain white rectangle.
    private var cardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white,
                    accent.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            CategoryTilePattern(
                category: unit.category,
                color: accent,
                patternOpacity: 0.09
            )
            .blendMode(.multiply)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.55),
                    Color.white.opacity(0.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)
        }
    }

    private func flash() {
        withAnimation(.easeIn(duration: 0.1)) {
            flashOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.1)) {
                flashOpacity = 1
            }
        }
    }

    private func resolvedFact() -> String {
        guard let fact = unit.funFact else { return "" }
        var s = stripBraceTokens(fact)

        // Normalize whitespace + punctuation.
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        s = s.replacingOccurrences(of: " .", with: ".")
        s = s.replacingOccurrences(of: " ,", with: ",")
        s = s.replacingOccurrences(of: " :", with: ":")
        s = s.replacingOccurrences(of: "—  ", with: "— ")

        // Avoid ".." / "..." artifacts after edits.
        while s.contains("..") { s = s.replacingOccurrences(of: "..", with: ".") }

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripBraceTokens(_ s: String) -> String {
        var out = s
        while let open = out.firstIndex(of: "{"),
              let close = out[open...].firstIndex(of: "}") {
            out.removeSubrange(open...close)
        }
        return out
    }
}
