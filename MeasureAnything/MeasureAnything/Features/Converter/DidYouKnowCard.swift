import SwiftUI
import MeasureAnythingCore

struct DidYouKnowCard: View {
    let unit: UnitDefinition
    var accent: Color = Color(red: 0x2B / 255, green: 0x5C / 255, blue: 0xE6 / 255)
    /// When set, the card is tappable and shows a trailing arrow affordance.
    var onOpenFactCard: (() -> Void)?

    private let cornerRadius: CGFloat = 18

    @State private var showFact: Bool = false
    @State private var flashOpacity: Double = 1

    var body: some View {
        let resolved = resolvedFact()

        let content = VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("DID YOU KNOW")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(accent)

                Spacer()

                if onOpenFactCard != nil {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    .accessibilityHidden(true)
                }
            }

            Text(resolved)
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "#1A1A1A"))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color(hex: "#EBEBEB"), lineWidth: 0.5)
        )
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
