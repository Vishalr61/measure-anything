import SwiftUI
import MeasureAnythingCore

struct DidYouKnowCard: View {
    let unit: UnitDefinition

    @State private var showFact: Bool = false
    @State private var flashOpacity: Double = 1

    var body: some View {
        let resolved = resolvedFact()

        return VStack(alignment: .leading, spacing: 10) {
            Text("Did you know")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(red: 0x2B / 255, green: 0x5C / 255, blue: 0xE6 / 255))
                .textCase(.uppercase)
                .tracking(0.54) // ≈ 0.06em at 9pt

            Text(resolved)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(red: 0x2C / 255, green: 0x2C / 255, blue: 0x2A / 255))
                .lineSpacing(7) // ≈ 13pt * (1.55 - 1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
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
        .accessibilityElement(children: .combine)
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

