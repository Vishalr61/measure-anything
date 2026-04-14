import SwiftUI
import MeasureAnythingCore

// MARK: - Sheet wrapper (kept for reuse)

struct GlobalUnitSearchView: View {
    @ObservedObject var vm: ConverterViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GlobalUnitSearchBody(vm: vm, onUnitSelected: { dismiss() })
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Fact card sheet presentation

private struct FactCardSheetItem: Identifiable {
    var id: String { unitID }
    let unitID: String
}

// MARK: - Reusable body (works in sheet or full-screen tab)

struct GlobalUnitSearchBody: View {
    @ObservedObject var vm: ConverterViewModel
    let onUnitSelected: () -> Void
    /// Bump this value to reset the view back to the main browse state.
    var resetToken: Int = 0
    /// When `true`, Explore-only chrome (subtitle, rotating placeholder) is enabled.
    var isExploreTab: Bool = false

    @State private var searchText = ""
    @State private var searchPlaceholder = ExplorePlaceholders.defaultPlaceholder
    @State private var activeCategory: UnitCategory?
    @State private var showAllUnits = false
    @FocusState private var searchFocused: Bool

    // MARK: Two-step selection state (ephemeral, in-memory only)

    @State private var fromSelection: SearchResult?
    @State private var crossCategoryToast: String?

    @State private var factCardSheetItem: FactCardSheetItem?
    @State private var factSheetDetent: PresentationDetent = .large

    @Environment(\.scenePhase) private var scenePhase

    private let horizontalInset: CGFloat = 16

    // MARK: - Data

    private var allUnits: [SearchResult] {
        var results: [SearchResult] = []
        for category in vm.categories {
            for unit in vm.units(for: category, mode: .normal) {
                results.append(SearchResult(unit: unit, category: category, mode: .normal))
            }
            for unit in vm.units(for: category, mode: .absurd) where unit.kind != .normal {
                results.append(SearchResult(unit: unit, category: category, mode: .absurd))
            }
        }
        return results
    }

    private func allUnits(for category: UnitCategory) -> [UnitDefinition] {
        var units: [UnitDefinition] = []
        units.append(contentsOf: vm.units(for: category, mode: .normal))
        units.append(contentsOf: vm.units(for: category, mode: .absurd).filter { $0.kind != .normal })
        return units
    }

    private var filteredResults: [SearchResult] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }

        let pool: [SearchResult]
        if let cat = activeCategory {
            pool = allUnits.filter { $0.category == cat }
        } else {
            pool = allUnits
        }

        return pool
            .filter { $0.unit.name.lowercased().contains(query) }
            .sorted {
                let aPrefix = $0.unit.name.lowercased().hasPrefix(query)
                let bPrefix = $1.unit.name.lowercased().hasPrefix(query)
                if aPrefix != bPrefix { return aPrefix }
                return $0.unit.name < $1.unit.name
            }
    }

    private var isSearchEmpty: Bool {
        searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Whether we're in a sub-state (category or all units).
    var isExpanded: Bool { activeCategory != nil || showAllUnits }

    // MARK: - Two-step selection logic

    private func handleUnitTap(_ result: SearchResult) {
        guard let from = fromSelection else {
            withAnimation(.easeInOut(duration: 0.15)) {
                fromSelection = result
            }
            Haptics.tap()
            return
        }

        if from.unit.id == result.unit.id {
            withAnimation(.easeInOut(duration: 0.15)) {
                fromSelection = nil
            }
            Haptics.tap()
            return
        }

        if from.category != result.category {
            crossCategoryToast = "Can't convert \(from.category.rawValue) to \(result.category.rawValue)"
            Haptics.tap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeOut(duration: 0.25)) {
                    if crossCategoryToast != nil { crossCategoryToast = nil }
                }
            }
            return
        }

        let mode: UnitRegistry.Mode = (from.mode == .absurd || result.mode == .absurd) ? .absurd : .normal
        let fromID = from.unit.id
        let toID = result.unit.id
        let category = from.category

        withAnimation(.easeInOut(duration: 0.15)) {
            fromSelection = nil
        }

        vm.applyExplorePairSelection(
            category: category,
            mode: mode,
            fromID: fromID,
            toID: toID
        )
        Haptics.tap()
        onUnitSelected()
    }

    private func clearSelection() {
        withAnimation(.easeInOut(duration: 0.15)) {
            fromSelection = nil
            crossCategoryToast = nil
        }
    }

    // MARK: - Color helpers

    private func lightShade(for category: UnitCategory) -> Color {
        tileConfigs.first { $0.category == category }?.tileBg ?? Color(.systemGray6)
    }

    private func darkShade(for category: UnitCategory) -> Color {
        ConverterCategoryAccent.accent(for: category)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                searchBar
                Divider()
                if let from = fromSelection {
                    selectionHintStrip(from: from)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                mainContent
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isExpanded {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activeCategory = nil
                                showAllUnits = false
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    if let cat = activeCategory {
                        let config = tileConfigs.first { $0.category == cat }
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(config?.tileBg ?? Color(.systemGray6))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: SearchCategoryIcon.symbol(for: cat))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(config?.iconCircleBg ?? Color.secondary)
                                )
                            Text(cat.rawValue.capitalized)
                                .font(.system(size: 17, weight: .semibold))
                        }
                    } else if showAllUnits {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(.systemGray6))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.secondary)
                                )
                            Text("All units")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    } else if isExploreTab {
                        VStack(spacing: 2) {
                            Text("Explore")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Meters, whales, and everything between.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Explore")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
#if DEBUG
                if isExploreTab {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Card") {
                            factCardSheetItem = FactCardSheetItem(unitID: FactCardStore.devPreviewUnitID)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .accessibilityLabel("Open fact card design preview")
                    }
                }
#endif
            }
            .onChange(of: resetToken) { _, _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    activeCategory = nil
                    showAllUnits = false
                    searchText = ""
                    fromSelection = nil
                    crossCategoryToast = nil
                    factCardSheetItem = nil
                    factSheetDetent = .large
                }
            }
            .onChange(of: activeCategory) { old, new in
                if old != nil && new == nil {
                    clearSelection()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    clearSelection()
                }
            }

            // Cross-category toast overlay
            if let toast = crossCategoryToast {
                crossCategoryToastView(toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .sheet(item: $factCardSheetItem) { item in
            FactCardNavigationShell(initialUnitID: item.unitID, viewModel: vm)
                .presentationDetents([.medium, .large], selection: $factSheetDetent)
                .presentationDragIndicator(.visible)
        }
        .animation(.easeInOut(duration: 0.2), value: crossCategoryToast != nil)
    }

    // MARK: - Selection hint strip

    private func selectionHintStrip(from: SearchResult) -> some View {
        let bg = lightShade(for: from.category)
        let dark = darkShade(for: from.category)

        return HStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("From: \(from.unit.name)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(dark)
                Text(" — now pick a 'to' unit")
                    .font(.system(size: 13))
                    .foregroundStyle(dark.opacity(0.7))
            }
            .lineLimit(1)

            Spacer(minLength: 8)

            Button {
                clearSelection()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(dark.opacity(0.5))
                    .frame(width: 44, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, horizontalInset)
        .frame(height: 28)
        .background(bg)
    }

    // MARK: - Cross-category toast

    private func crossCategoryToastView(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.systemGray2))
            )
            .padding(.top, 8)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(hex: "#B4B2A9"))
                .font(.system(size: 15))
            TextField(
                "",
                text: $searchText,
                prompt: Text(isExploreTab ? searchPlaceholder : ExplorePlaceholders.defaultPlaceholder)
            )
                .font(.system(size: 16))
                .autocorrectionDisabled()
                .focused($searchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(hex: "#B4B2A9"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(hex: "#F0F0F3"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, horizontalInset)
        .padding(.top, (isExploreTab && !isExpanded) ? 12 : 8)
        .padding(.bottom, 8)
    }

    // MARK: - Main content (states)

    @ViewBuilder
    private var mainContent: some View {
        if !isSearchEmpty && filteredResults.isEmpty {
            noResultsState
        } else if !isSearchEmpty {
            searchResultsState
        } else if let cat = activeCategory {
            categoryExpandedState(cat)
        } else if showAllUnits {
            allUnitsState
        } else {
            browseBody
        }
    }

    // MARK: - Tile config

    private struct TileConfig: Identifiable {
        let category: UnitCategory?
        let icon: String
        let shortName: String
        let fullName: String
        let tileBg: Color
        let iconCircleBg: Color
        let tileIcon: Color
        let tileBorder: Color
        let tileText: Color
        let countText: Color

        var id: String { fullName }
    }

    private var tileConfigs: [TileConfig] {[
        TileConfig(
            category: .length, icon: "ruler", shortName: "Length", fullName: "Length",
            tileBg: Color(hex: "#E1F5EE"), iconCircleBg: Color(hex: "#1A5F73"),
            tileIcon: .white, tileBorder: Color(hex: "#9FE1CB"),
            tileText: Color(hex: "#085041"), countText: Color(hex: "#0F6E56")
        ),
        TileConfig(
            category: .mass, icon: "scalemass", shortName: "Mass", fullName: "Mass",
            tileBg: Color(hex: "#EAF3DE"), iconCircleBg: Color(hex: "#3D6B4A"),
            tileIcon: .white, tileBorder: Color(hex: "#C0DD97"),
            tileText: Color(hex: "#173404"), countText: Color(hex: "#3B6D11")
        ),
        TileConfig(
            category: .time, icon: "clock", shortName: "Time", fullName: "Time",
            tileBg: Color(hex: "#EEEDFE"), iconCircleBg: Color(hex: "#3D3580"),
            tileIcon: .white, tileBorder: Color(hex: "#CECBF6"),
            tileText: Color(hex: "#26215C"), countText: Color(hex: "#534AB7")
        ),
        TileConfig(
            category: .temperature, icon: "thermometer.medium", shortName: "Temp", fullName: "Temperature",
            tileBg: Color(hex: "#FAECE7"), iconCircleBg: Color(hex: "#8B3A2A"),
            tileIcon: .white, tileBorder: Color(hex: "#F5C4B3"),
            tileText: Color(hex: "#4A1B0C"), countText: Color(hex: "#993C1D")
        ),
        TileConfig(
            category: .volume, icon: "drop", shortName: "Volume", fullName: "Volume",
            tileBg: Color(hex: "#FAEEDA"), iconCircleBg: Color(hex: "#AF7D2A"),
            tileIcon: .white, tileBorder: Color(hex: "#FAC775"),
            tileText: Color(hex: "#412402"), countText: Color(hex: "#854F0B")
        ),
        TileConfig(
            category: nil, icon: "magnifyingglass", shortName: "All", fullName: "All units",
            tileBg: Color(.systemGray6), iconCircleBg: Color(.systemGray4),
            tileIcon: Color.secondary, tileBorder: Color.primary.opacity(0.08),
            tileText: Color.primary, countText: Color.secondary
        ),
    ]}

    // MARK: - State A: Browse

    private var browseBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Categories")
                    categoryGrid
                }

                exploreBrowseListSection
            }
            .padding(.horizontal, horizontalInset)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .onAppear {
            refreshExplorePlaceholderIfNeeded()
        }
    }

    @ViewBuilder
    private var exploreBrowseListSection: some View {
        let pairs = resolvedPairs()
        if ConversionHistory.shared.hasRecentPairs {
            if !pairs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Recently used")
                    VStack(spacing: 8) {
                        ForEach(Array(pairs.prefix(3).enumerated()), id: \.offset) { _, item in
                            RecentPairRow(
                                fromUnit: item.fromUnit,
                                toUnit: item.toUnit,
                                category: item.category,
                                accent: ConverterCategoryAccent.accent(for: item.category)
                            ) {
                                applyPair(item)
                            }
                        }
                    }
                }
            }
        } else {
            tryTheseBrowseSection
        }
    }

    @ViewBuilder
    private var tryTheseBrowseSection: some View {
        let rows = tryTheseDisplayRows()
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Try these")
                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        RecentPairRow(
                            fromUnit: row.pair.fromUnit,
                            toUnit: row.pair.toUnit,
                            category: row.pair.category,
                            accent: ConverterCategoryAccent.accent(for: row.pair.category)
                        ) {
                            applyTryTheseRow(spec: row.spec, pair: row.pair)
                        }
                    }
                }
            }
        }
    }

    private struct TryTheseDisplayRow: Identifiable {
        var id: String { "\(spec.fromID)→\(spec.toID)" }
        let spec: TryTheseSuggestions.RowSpec
        let pair: ResolvedPair
    }

    private func tryTheseDisplayRows() -> [TryTheseDisplayRow] {
        TryTheseSuggestions.rows.compactMap { spec in
            guard
                let fr = allUnits.first(where: { $0.unit.id == spec.fromID && $0.category == spec.category }),
                let t = allUnits.first(where: { $0.unit.id == spec.toID && $0.category == spec.category })
            else { return nil }
            let pair = ResolvedPair(
                fromUnit: fr.unit,
                toUnit: t.unit,
                category: spec.category,
                mode: spec.mode
            )
            return TryTheseDisplayRow(spec: spec, pair: pair)
        }
    }

    private func refreshExplorePlaceholderIfNeeded() {
        guard isExploreTab else { return }
        guard activeCategory == nil, !showAllUnits else { return }
        ExplorePlaceholders.refreshPlaceholder(searchPlaceholder: &searchPlaceholder)
    }

    private func applyTryTheseRow(spec: TryTheseSuggestions.RowSpec, pair: ResolvedPair) {
        vm.applyTryThesePair(
            category: spec.category,
            mode: spec.mode,
            fromID: pair.fromUnit.id,
            toID: pair.toUnit.id
        )
        Haptics.tap()
        onUnitSelected()
    }

    private var categoryGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            ForEach(tileConfigs) { config in
                let count = config.category.map { cat in
                    allUnits.filter { $0.category == cat }.count
                } ?? allUnits.count

                CategoryTile(
                    icon: config.icon,
                    name: config.shortName,
                    fullName: config.fullName,
                    count: count,
                    tileBg: config.tileBg,
                    iconCircleBg: config.iconCircleBg,
                    tileIcon: config.tileIcon,
                    tileBorder: config.tileBorder,
                    tileText: config.tileText,
                    countText: config.countText,
                    patternCategory: config.category,
                    showsPattern: true
                ) {
                    Haptics.tap()
                    if let cat = config.category {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeCategory = cat
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAllUnits = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - State B: Category expanded

    private func categoryExpandedState(_ category: UnitCategory) -> some View {
        let accent = ConverterCategoryAccent.accent(for: category)
        let light = lightShade(for: category)
        let allForCategory = allUnits.filter { $0.category == category }
        let normalUnits = allForCategory.filter { $0.unit.kind == .normal }
        let absurdUnits = allForCategory.filter { $0.unit.kind != .normal }
        let grouped = UnitScaleGroups.grouped(absurdUnits.map(\.unit))

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !normalUnits.isEmpty {
                    scaleHeader("Standard")
                        .padding(.horizontal, horizontalInset)
                        .padding(.top, 18)
                        .padding(.bottom, 4)
                    ForEach(Array(normalUnits.enumerated()), id: \.element.id) { idx, result in
                        let nextIsSelected = idx + 1 < normalUnits.count
                            && fromSelection?.unit.id == normalUnits[idx + 1].unit.id
                        UnitBrowseRow(
                            unit: result.unit,
                            accent: accent,
                            isSelected: fromSelection?.unit.id == result.unit.id,
                            nextRowSelected: nextIsSelected,
                            selectionLightShade: light,
                            horizontalInset: horizontalInset,
                            onTap: { handleUnitTap(result) },
                            onOpenFactCard: {
                                factCardSheetItem = FactCardSheetItem(unitID: result.unit.id)
                                Haptics.tap()
                            }
                        )
                    }
                }

                ForEach(grouped, id: \.title) { group in
                    scaleHeader(group.title)
                        .padding(.horizontal, horizontalInset)
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                    ForEach(Array(group.units.enumerated()), id: \.element.id) { idx, unit in
                        if let result = allForCategory.first(where: { $0.unit.id == unit.id }) {
                            let nextIsSelected = idx + 1 < group.units.count
                                && fromSelection?.unit.id == group.units[idx + 1].id
                            UnitBrowseRow(
                                unit: unit,
                                accent: accent,
                                isSelected: fromSelection?.unit.id == unit.id,
                                nextRowSelected: nextIsSelected,
                                selectionLightShade: light,
                                horizontalInset: horizontalInset,
                                onTap: { handleUnitTap(result) },
                                onOpenFactCard: {
                                    factCardSheetItem = FactCardSheetItem(unitID: unit.id)
                                    Haptics.tap()
                                }
                            )
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - State B2: All units (flat)

    private var allUnitsState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(vm.categories, id: \.self) { cat in
                    let accent = ConverterCategoryAccent.accent(for: cat)
                    let light = lightShade(for: cat)
                    let catResults = allUnits.filter { $0.category == cat }
                    let normalUnits = catResults.filter { $0.unit.kind == .normal }
                    let absurdUnits = catResults.filter { $0.unit.kind != .normal }
                    let grouped = UnitScaleGroups.grouped(absurdUnits.map(\.unit))

                    scaleHeader(cat.rawValue.capitalized)
                        .padding(.horizontal, horizontalInset)
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                    ForEach(Array(normalUnits.enumerated()), id: \.element.id) { idx, result in
                        let nextIsSelected = idx + 1 < normalUnits.count
                            && fromSelection?.unit.id == normalUnits[idx + 1].unit.id
                        UnitBrowseRow(
                            unit: result.unit,
                            accent: accent,
                            isSelected: fromSelection?.unit.id == result.unit.id,
                            nextRowSelected: nextIsSelected,
                            selectionLightShade: light,
                            horizontalInset: horizontalInset,
                            onTap: { handleUnitTap(result) },
                            onOpenFactCard: {
                                factCardSheetItem = FactCardSheetItem(unitID: result.unit.id)
                                Haptics.tap()
                            }
                        )
                    }

                    ForEach(grouped, id: \.title) { group in
                        ForEach(Array(group.units.enumerated()), id: \.element.id) { idx, unit in
                            if let result = catResults.first(where: { $0.unit.id == unit.id }) {
                                let nextIsSelected = idx + 1 < group.units.count
                                    && fromSelection?.unit.id == group.units[idx + 1].id
                                UnitBrowseRow(
                                    unit: unit,
                                    accent: accent,
                                    isSelected: fromSelection?.unit.id == unit.id,
                                    nextRowSelected: nextIsSelected,
                                    selectionLightShade: light,
                                    horizontalInset: horizontalInset,
                                    onTap: { handleUnitTap(result) },
                                    onOpenFactCard: {
                                        factCardSheetItem = FactCardSheetItem(unitID: unit.id)
                                        Haptics.tap()
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - State C: Search results

    private var searchResultsState: some View {
        VStack(spacing: 0) {
            resultCountBadge
            List {
                ForEach(filteredResults, id: \.id) { result in
                    Button { handleUnitTap(result) } label: {
                        searchResultRow(result, query: searchText)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        fromSelection?.unit.id == result.unit.id
                            ? lightShade(for: result.category).opacity(0.5)
                            : Color.clear
                    )
                }

                searchDisclaimer
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
    }

    private var resultCountBadge: some View {
        HStack {
            Text("Results")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
            Text("\(filteredResults.count) unit\(filteredResults.count == 1 ? "" : "s")")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(hex: "#F0F0F3"))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var searchDisclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            Text("Showing name matches only.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#F0F0F3"))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.top, 8)
    }

    private func searchResultRow(_ result: SearchResult, query: String) -> some View {
        let isSelected = fromSelection?.unit.id == result.unit.id
        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(result.accent)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                highlightedText(
                    result.unit.name,
                    query: query,
                    lineWeight: isSelected ? .semibold : .medium
                )

                HStack(spacing: 4) {
                    Text(result.categoryDisplayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(result.accent)
                    Text("\u{00B7}")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(result.factorDisplayString)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(result.accent)
            } else {
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    // MARK: - No results

    private var noResultsState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No units match \"\(searchText)\"")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
            Text("Try a different spelling or browse by category above")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }

    private func scaleHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color(hex: "#888780"))
            .textCase(.uppercase)
            .tracking(0.7)
            .padding(.top, 4)
    }

    /// Search highlight without `Text` + `Text` (deprecated on newer SDKs); uses `AttributedString` runs.
    private func highlightedText(_ text: String, query: String, lineWeight: Font.Weight) -> Text {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        var attributed = AttributedString(text)

        guard !trimmed.isEmpty,
              let matchRange = attributed.range(of: trimmed, options: .caseInsensitive)
        else {
            return Text(text).foregroundStyle(Color.primary)
        }

        let start = attributed.startIndex
        let end = attributed.endIndex

        if matchRange.lowerBound > start {
            let beforeRange = start..<matchRange.lowerBound
            attributed[beforeRange].foregroundColor = .secondary
            attributed[beforeRange].font = .system(size: 14, weight: lineWeight)
        }

        attributed[matchRange].foregroundColor = .primary
        attributed[matchRange].font = .system(size: 14, weight: .semibold)

        if matchRange.upperBound < end {
            let afterRange = matchRange.upperBound..<end
            attributed[afterRange].foregroundColor = .secondary
            attributed[afterRange].font = .system(size: 14, weight: lineWeight)
        }

        return Text(attributed)
    }

    // MARK: - Recent pairs

    private struct ResolvedPair {
        let fromUnit: UnitDefinition
        let toUnit: UnitDefinition
        let category: UnitCategory
        let mode: UnitRegistry.Mode
    }

    private func resolvedPairs() -> [ResolvedPair] {
        var seen = Set<String>()
        return ConversionHistory.shared.recentPairs(limit: 20).compactMap { pair in
            let dedup = "\(pair.fromUnitID)→\(pair.toUnitID)"
            guard !seen.contains(dedup) else { return nil }
            seen.insert(dedup)

            guard let from = allUnits.first(where: { $0.unit.id == pair.fromUnitID }),
                  let to = allUnits.first(where: { $0.unit.id == pair.toUnitID })
            else { return nil }

            let category = pair.category ?? from.category
            return ResolvedPair(
                fromUnit: from.unit,
                toUnit: to.unit,
                category: category,
                mode: from.mode
            )
        }
    }

    private func applyPair(_ pair: ResolvedPair) {
        vm.applyExplorePairSelection(
            category: pair.category,
            mode: pair.mode,
            fromID: pair.fromUnit.id,
            toID: pair.toUnit.id
        )
        Haptics.tap()
        onUnitSelected()
    }
}

// MARK: - Search Result Model

struct SearchResult: Identifiable {
    let unit: UnitDefinition
    let category: UnitCategory
    let mode: UnitRegistry.Mode

    var id: String { "\(category.rawValue)-\(mode.rawValue)-\(unit.id)" }
    var categoryDisplayName: String { category.rawValue.capitalized }
    var modeTag: String { mode == .absurd ? "Absurd" : "Standard" }
    var accent: Color { ConverterCategoryAccent.accent(for: category) }

    var factorDisplayString: String {
        guard let factor = unit.factor else { return unit.baseUnit }
        let absVal = abs(factor)
        if absVal < 0.001 || absVal > 9_999_999 {
            let f = NumberFormatter()
            f.numberStyle = .scientific
            f.maximumSignificantDigits = 3
            f.locale = Locale(identifier: "en_US")
            let raw = f.string(from: NSNumber(value: factor)) ?? "\(factor)"
            return raw
                .replacingOccurrences(of: "E", with: "\u{00D7}10^")
                .replacingOccurrences(of: "e", with: "\u{00D7}10^")
                + " " + unit.baseUnit
        }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 3
        f.minimumFractionDigits = 0
        f.locale = Locale(identifier: "en_US")
        return (f.string(from: NSNumber(value: factor)) ?? "\(factor)") + " " + unit.baseUnit
    }
}
