import SwiftUI
import MeasureAnythingCore

/// Explore fact card (modal). Step 2: single card, first four comparisons, no shuffle / no rabbit-hole navigation yet.
struct FactCardSheet: View {
    let unit: UnitDefinition
    @ObservedObject var viewModel: ConverterViewModel

    @Environment(\.dismiss) private var dismiss

    private var accent: Color {
        ConverterCategoryAccent.accent(for: unit.category)
    }

    private var curated: FactCardEntry? {
        FactCardStore.shared.entry(for: unit.id)
    }

    /// Step 2: static first four; shuffle arrives in a later step.
    private var previewComparisons: [FactCardComparison] {
        guard let curated else { return [] }
        return Array(curated.comparisons.prefix(4))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                    .padding(.top, 12)
                funFactSection
                if let curated {
                    curatedValueSection(curated)
                    if !previewComparisons.isEmpty {
                        comparisonsSection
                    }
                } else if let parts = Self.computedCanonicalParts(for: unit) {
                    computedValueSection(parts)
                }
                Color.clear.frame(height: 60)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent.opacity(0.12))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: SearchCategoryIcon.symbol(for: unit.category))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(accent)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(unit.name)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.primary)
                Text(unit.category.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.secondary, Color(.tertiarySystemFill))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Fun fact

    private var funFactSection: some View {
        Group {
            if let fact = unit.funFact, !fact.isEmpty {
                Text(Self.resolvedFunFact(fact))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.primary)
                    .lineSpacing(5.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Value (curated)

    private func curatedValueSection(_ entry: FactCardEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.valueHeadline)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)
                .tracking(0.65)
            Text(entry.valueDisplay)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    // MARK: - Value (computed)

    private struct ComputedCanonical {
        let headlineUpper: String
        let valueLine: String
    }

    private func computedValueSection(_ parts: ComputedCanonical) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(parts.headlineUpper)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)
                .tracking(0.65)
            Text(parts.valueLine)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    // MARK: - Comparisons

    private var comparisonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About the same as")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)
                .tracking(0.65)
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(previewComparisons.enumerated()), id: \.offset) { _, row in
                    comparisonSentence(row)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func comparisonSentence(_ row: FactCardComparison) -> some View {
        let target = try? viewModel.currentRegistry.unit(id: row.targetUnitID)
        if let target {
            FactCardComparisonSentenceView(
                template: row.template,
                targetUnitName: target.name,
                accent: accent
            )
            .font(.system(size: 14))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(row.template)
                .font(.system(size: 14))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Text helpers (shared with converter cards later)

    static func resolvedFunFact(_ raw: String) -> String {
        var s = stripBraceTokens(raw)
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        s = s.replacingOccurrences(of: " .", with: ".")
        s = s.replacingOccurrences(of: " ,", with: ",")
        s = s.replacingOccurrences(of: " :", with: ":")
        s = s.replacingOccurrences(of: "—  ", with: "— ")
        while s.contains("..") { s = s.replacingOccurrences(of: "..", with: ".") }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripBraceTokens(_ s: String) -> String {
        var out = s
        while let open = out.firstIndex(of: "{"),
              let close = out[open...].firstIndex(of: "}") {
            out.removeSubrange(open...close)
        }
        return out
    }

    private static func computedCanonicalParts(for unit: UnitDefinition) -> ComputedCanonical? {
        guard let factor = unit.factor else { return nil }
        let nameLower = unit.name.lowercased()
        let headline: String = {
            switch unit.category {
            case .mass: return "One \(nameLower) weighs"
            case .length: return "One \(nameLower) is"
            case .volume: return "One \(nameLower) holds"
            case .time: return "One \(nameLower) lasts"
            case .temperature: return "One \(nameLower) is"
            }
        }()
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 6
        nf.minimumFractionDigits = 0
        nf.usesGroupingSeparator = true
        nf.locale = Locale(identifier: "en_US")
        let num = nf.string(from: NSNumber(value: factor)) ?? String(format: "%g", factor)
        let valueLine = "\(num) \(unit.baseUnit)"
        return ComputedCanonical(headlineUpper: headline, valueLine: valueLine)
    }
}

// MARK: - Comparison sentence (dotted link span)

private struct FactCardComparisonSentenceView: View {
    let template: String
    let targetUnitName: String
    let accent: Color

    var body: some View {
        buildText()
            .fixedSize(horizontal: false, vertical: true)
    }

    private func buildText() -> Text {
        guard let pieces = Self.splitTemplate(template, targetName: targetUnitName) else {
            return Text(template)
        }
        return Text(pieces.leading)
            + Text(pieces.link)
            .foregroundStyle(accent)
            .underline(pattern: .dot)
            + Text(pieces.trailing)
    }

    private static func splitTemplate(_ template: String, targetName: String) -> (leading: String, link: String, trailing: String)? {
        let name = targetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        for phrase in candidatePhrases(for: name) {
            if let rawRange = template.range(of: phrase, options: [.caseInsensitive, .diacriticInsensitive]) {
                let range = extendedLinkRange(in: template, range: rawRange)
                let leading = String(template[..<range.lowerBound])
                let link = String(template[range])
                let trailing = String(template[range.upperBound...])
                return (leading, link, trailing)
            }
        }
        return nil
    }

    /// When the match is a singular (or shorter) substring before a plural suffix (`s` / `es`), extend the link so the underline covers the whole word (e.g. `elephant` → `elephants`, `bus` → `buses`).
    private static func extendedLinkRange(in template: String, range: Range<String.Index>) -> Range<String.Index> {
        let matched = String(template[range])
        let matchedLower = matched.lowercased()

        if matchedLower.hasSuffix("s") {
            return range
        }

        let upper = range.upperBound
        guard upper < template.endIndex else { return range }

        let tail = template[upper...]
        let tailLower = tail.lowercased()

        if tailLower.hasPrefix("es"), template.distance(from: upper, to: template.endIndex) >= 2 {
            let end = template.index(upper, offsetBy: 2)
            return range.lowerBound..<end
        }
        let first = template[upper]
        if first == "s" || first == "S" {
            return range.lowerBound..<template.index(after: upper)
        }

        return range
    }

    private static func candidatePhrases(for name: String) -> [String] {
        var phrases: [String] = [name]
        phrases.append(name + "s")
        phrases.append(name + "es")
        if name.lowercased().hasSuffix("y"), name.count > 1 {
            phrases.append(String(name.dropLast()) + "ies")
        }
        if name.lowercased().hasSuffix("s"), name.count > 1 {
            phrases.append(String(name.dropLast()))
        }
        return phrases
    }
}

#if DEBUG
#Preview("Blue whale fact card") {
    let taxonomy = AppTaxonomyStore()
    let vm = ConverterViewModel(taxonomy: taxonomy)
    let id = FactCardStore.devPreviewUnitID
    Group {
        if let unit = try? vm.currentRegistry.unit(id: id) {
            NavigationStack {
                FactCardSheet(unit: unit, viewModel: vm)
            }
            .presentationDetents([.medium, .large])
        } else {
            Text("Preview: registry missing unit “\(id)”.")
                .padding()
        }
    }
}
#endif
