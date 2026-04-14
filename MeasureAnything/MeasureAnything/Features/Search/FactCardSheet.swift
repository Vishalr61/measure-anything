import SwiftUI
import MeasureAnythingCore

/// Hosts the fact card stack inside the Explore sheet (`NavigationStack(path: [String])`).
struct FactCardNavigationShell: View {
    let initialUnitID: String
    @ObservedObject var viewModel: ConverterViewModel

    @State private var path: [String] = []
    /// Shuffled comparison rows per unit for this sheet session only (cleared when the sheet is dismissed).
    @State private var sessionComparisonSlices: [String: [FactCardComparison]] = [:]

    var body: some View {
        Group {
            if let root = try? viewModel.currentRegistry.unit(id: initialUnitID) {
                NavigationStack(path: $path) {
                    FactCardSheet(
                        unit: root,
                        viewModel: viewModel,
                        navigationPath: $path,
                        sessionComparisonSlices: $sessionComparisonSlices,
                        isNavigationRoot: true
                    )
                    .navigationDestination(for: String.self) { pushedID in
                        if let u = try? viewModel.currentRegistry.unit(id: pushedID) {
                            FactCardSheet(
                                unit: u,
                                viewModel: viewModel,
                                navigationPath: $path,
                                sessionComparisonSlices: $sessionComparisonSlices,
                                isNavigationRoot: false
                            )
                        } else {
                            Text("This unit isn’t in the catalog.")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .padding(24)
                        }
                    }
                }
            } else {
                Text("This unit isn’t available in the catalog.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .padding(24)
            }
        }
    }
}

/// Single fact card page (root or pushed). `navigationPath` is shared across the stack; comparisons append a unit id.
struct FactCardSheet: View {
    let unit: UnitDefinition
    @ObservedObject var viewModel: ConverterViewModel
    @Binding var navigationPath: [String]
    @Binding var sessionComparisonSlices: [String: [FactCardComparison]]
    /// `true` for the shell’s root page only (no back chevron in header).
    var isNavigationRoot: Bool

    @Environment(\.dismiss) private var dismiss

    private var accent: Color {
        ConverterCategoryAccent.accent(for: unit.category)
    }

    private var curated: FactCardEntry? {
        FactCardStore.shared.entry(for: unit.id)
    }

    private var previewComparisons: [FactCardComparison] {
        sessionComparisonSlices[unit.id] ?? []
    }

    /// Tier 1 only: pool larger than the visible slice — reroll can change which four appear.
    private var shouldShowComparisonShuffle: Bool {
        guard let curated else { return false }
        return curated.comparisons.count > 4
    }

    private var comparisonRowsAnimationIdentity: String {
        previewComparisons.map { "\($0.targetUnitID)\u{1e}\($0.template)" }.joined(separator: "\u{1f}")
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
                }
                Color.clear.frame(height: 60)
            }
        }
        .task(id: unit.id) {
            ensureSessionComparisonSlice()
        }
        .navigationBarBackButtonHidden(!isNavigationRoot)
        .toolbar(isNavigationRoot ? .automatic : .hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            if !isNavigationRoot {
                Button {
                    if !navigationPath.isEmpty {
                        navigationPath.removeLast()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }

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
            .id(comparisonRowsAnimationIdentity)
            .transition(.opacity)

            if shouldShowComparisonShuffle {
                comparisonShufflePill
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    private var comparisonShufflePill: some View {
        Button {
            Haptics.tap()
            withAnimation(.easeInOut(duration: 0.22)) {
                reshuffleSessionComparisons()
            }
        } label: {
            Text("↻ Shuffle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(accent.opacity(0.92))
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(accent.opacity(0.09))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(accent.opacity(0.38), lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shuffle comparisons")
    }

    /// Fisher–Yates shuffle, then keep up to four comparisons. Stored once per unit id for this sheet session.
    private func ensureSessionComparisonSlice() {
        guard let curated else { return }
        let all = curated.comparisons
        guard !all.isEmpty, sessionComparisonSlices[unit.id] == nil else { return }
        var next = sessionComparisonSlices
        next[unit.id] = Self.shuffledPrefix(all, take: 4)
        sessionComparisonSlices = next
    }

    private static func shuffledPrefix(_ items: [FactCardComparison], take: Int) -> [FactCardComparison] {
        var copy = items
        guard copy.count > 1 else { return Array(copy.prefix(take)) }
        for i in stride(from: copy.count - 1, through: 1, by: -1) {
            copy.swapAt(i, Int.random(in: 0...i))
        }
        return Array(copy.prefix(min(take, copy.count)))
    }

    /// New random four from the full pool; avoids repeating the same multiset when the pool has more than four.
    private func reshuffleSessionComparisons() {
        guard let curated, curated.comparisons.count > 4 else { return }
        let pool = curated.comparisons
        let previous = sessionComparisonSlices[unit.id] ?? []
        var nextSlice = Self.shuffledPrefix(pool, take: 4)
        var attempts = 0
        while nextSlice == previous && attempts < 64 {
            nextSlice = Self.shuffledPrefix(pool, take: 4)
            attempts += 1
        }
        var next = sessionComparisonSlices
        next[unit.id] = nextSlice
        sessionComparisonSlices = next
    }

    @ViewBuilder
    private func comparisonSentence(_ row: FactCardComparison) -> some View {
        let target = try? viewModel.currentRegistry.unit(id: row.targetUnitID)
        if let target {
            Button {
                navigationPath.append(row.targetUnitID)
            } label: {
                FactCardComparisonSentenceView(
                    template: row.template,
                    targetUnitName: target.name,
                    accent: accent
                )
                .font(.system(size: 14))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
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
    FactCardNavigationShell(initialUnitID: id, viewModel: vm)
        .presentationDetents([.medium, .large])
}
#endif
