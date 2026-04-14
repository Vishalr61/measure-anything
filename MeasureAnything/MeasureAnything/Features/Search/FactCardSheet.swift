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

    private var palette: CategoryPalette {
        ConverterCategoryPalette.palette(for: unit.category)
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

    private var unitIconSystemName: String {
        if let raw = unit.iconName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw
        }
        return SearchCategoryIcon.symbol(for: unit.category)
    }

    /// Tier 1 with comparisons draws 60pt inside the white band; everyone else needs tail spacer.
    private var needsTrailingBottomSpacer: Bool {
        guard curated != nil else { return true }
        return previewComparisons.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerBand
                funFactBand
                if let curated {
                    valueBand(entry: curated)
                    if !previewComparisons.isEmpty {
                        comparisonsBand
                    }
                }
                if needsTrailingBottomSpacer {
                    Color.clear.frame(height: 72)
                }
            }
        }
        .task(id: unit.id) {
            ensureSessionComparisonSlice()
        }
        .navigationBarBackButtonHidden(!isNavigationRoot)
        .toolbar(isNavigationRoot ? .automatic : .hidden, for: .navigationBar)
    }

    // MARK: - Band 1 — header (deep + pattern)

    private var headerBand: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back + close only — category sits on the next row so it isn’t squeezed beside the back control.
            HStack(alignment: .center, spacing: 0) {
                if !isNavigationRoot {
                    headerBackButton
                } else {
                    Color.clear
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 0)
                headerCloseButton
            }
            .padding(.top, 24)

            Text(unit.category.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.onDeepMuted)
                .textCase(.uppercase)
                .tracking(1.15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)

            HStack(alignment: .center, spacing: 14) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(palette.onDeep)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: unitIconSystemName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(palette.deep)
                    )

                Text(unit.name)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(palette.onDeep)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 18)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity)
        .background {
            ZStack(alignment: .topLeading) {
                palette.deep
                CategoryTilePattern(category: unit.category, color: palette.onDeep, patternOpacity: 0.18)
            }
        }
    }

    private var headerBackButton: some View {
        Button {
            if !navigationPath.isEmpty {
                navigationPath.removeLast()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(palette.onDeep.opacity(0.25))
                    .frame(width: 30, height: 30)
                Image(systemName: "chevron.backward")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.onDeep)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }

    private var headerCloseButton: some View {
        Button {
            dismiss()
        } label: {
            ZStack {
                Circle()
                    .fill(palette.onDeep.opacity(0.25))
                    .frame(width: 30, height: 30)
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.onDeep)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    // MARK: - Band 2 — fun fact (light)

    @ViewBuilder
    private var funFactBand: some View {
        if let raw = unit.funFact, !raw.isEmpty {
            Text(Self.resolvedFunFact(raw))
                .font(.system(size: 15))
                .foregroundStyle(Color.primary)
                .lineSpacing(5.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 26)
                .frame(maxWidth: .infinity)
                .background(palette.light)
        }
    }

    // MARK: - Band 3 — value (medium, Tier 1 only)

    private func valueBand(entry: FactCardEntry) -> some View {
        VStack(spacing: 10) {
            Text(entry.valueHeadline)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.deep)
                .textCase(.uppercase)
                .tracking(0.85)
                .multilineTextAlignment(.center)
            Text(entry.valueDisplay)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(palette.valueProclamation)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 24)
        .background(palette.medium)
    }

    // MARK: - Band 4 — comparisons (system background)

    private var comparisonsBand: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("About the same as")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)
                .tracking(0.85)
                .padding(.top, 22)

            VStack(alignment: .leading, spacing: 15) {
                ForEach(Array(previewComparisons.enumerated()), id: \.offset) { _, row in
                    comparisonSentence(row)
                }
            }
            .padding(.top, 12)
            .id(comparisonRowsAnimationIdentity)
            .transition(.opacity)

            if shouldShowComparisonShuffle {
                comparisonShuffleControl
                    .padding(.top, 20)
            }

            Color.clear.frame(height: 72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .background(Color(.systemBackground))
    }

    private var comparisonShuffleControl: some View {
        Button {
            Haptics.tap()
            withAnimation(.easeInOut(duration: 0.22)) {
                reshuffleSessionComparisons()
            }
        } label: {
            Text("↻ Shuffle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.deep)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.light)
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

    private func comparisonSentence(_ row: FactCardComparison) -> some View {
        let target = try? viewModel.currentRegistry.unit(id: row.targetUnitID)
        return ComparisonLeadingRailLayout {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(palette.deep)
            comparisonRowBody(row, target: target)
        }
    }

    @ViewBuilder
    private func comparisonRowBody(_ row: FactCardComparison, target: UnitDefinition?) -> some View {
        if let target {
            Button {
                navigationPath.append(row.targetUnitID)
            } label: {
                FactCardComparisonSentenceView(
                    template: row.template,
                    targetUnitName: target.name,
                    linkAccent: palette.deep
                )
                .font(.system(size: 15))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
        } else {
            Text(row.template)
                .font(.system(size: 15))
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

// MARK: - Comparison leading rail (Design 3)

/// 3pt rail + 11pt gap; rail height matches the comparison text block (including multi-line).
private struct ComparisonLeadingRailLayout: Layout {
    private let railWidth: CGFloat = 3
    private let gap: CGFloat = 11

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let maxTextW: CGFloat = {
            guard let w = proposal.width else { return .infinity }
            return max(0, w - railWidth - gap)
        }()
        let textSize = subviews[1].sizeThatFits(ProposedViewSize(width: maxTextW, height: proposal.height))
        let totalW = railWidth + gap + textSize.width
        if let cap = proposal.width {
            return CGSize(width: min(cap, totalW), height: textSize.height)
        }
        return CGSize(width: totalW, height: textSize.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let textW = max(0, bounds.width - railWidth - gap)
        let textSize = subviews[1].sizeThatFits(ProposedViewSize(width: textW, height: bounds.height))
        let h = textSize.height

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: railWidth, height: h)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + railWidth + gap, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: textW, height: h)
        )
    }
}

// MARK: - Comparison sentence (dotted link span)

private struct FactCardComparisonSentenceView: View {
    let template: String
    let targetUnitName: String
    let linkAccent: Color

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
            .foregroundStyle(linkAccent)
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
