import SwiftUI
import MeasureAnythingCore

struct GlobalUnitSearchView: View {
    @ObservedObject var vm: ConverterViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var activeCategory: UnitCategory?
    @FocusState private var searchFocused: Bool

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

    private var recentUnits: [SearchResult] {
        let ids = ConversionHistory.shared.recentToUnits(limit: 3)
        return ids.compactMap { id in allUnits.first { $0.unit.id == id } }
    }

    private var isSearchEmpty: Bool {
        searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                categoryChips
                Divider()
                mainContent
            }
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
        .onAppear { searchFocused = true }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(hex: "#B4B2A9"))
                .font(.system(size: 15))
            TextField("Search units...", text: $searchText)
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
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Category chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.categories, id: \.self) { category in
                    let accent = ConverterCategoryAccent.accent(for: category)
                    let isActive = activeCategory == category
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeCategory = isActive ? nil : category
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(category.rawValue.capitalized)
                            if isActive {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isActive ? .white : accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isActive ? accent : accent.opacity(0.08))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(accent.opacity(isActive ? 0 : 0.3), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Main content (3 states)

    @ViewBuilder
    private var mainContent: some View {
        if isSearchEmpty && activeCategory == nil {
            discoveryState
        } else if isSearchEmpty, let cat = activeCategory {
            categoryBrowseState(cat)
        } else if !isSearchEmpty && filteredResults.isEmpty {
            noResultsState
        } else {
            searchResultsState
        }
    }

    // MARK: - State 1: Discovery

    private var discoveryState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                featuredSection
                if !recentUnits.isEmpty {
                    recentSection
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: Featured units

    private struct FeaturedEntry {
        let unitID: String
        let fact: String
    }

    private let featuredEntries: [FeaturedEntry] = [
        FeaturedEntry(unitID: "blue_whale", fact: "Only ~25,000 remain on Earth"),
        FeaturedEntry(unitID: "t_rex", fact: "Tiny arms, enormous appetite"),
        FeaturedEntry(unitID: "human_lifespan", fact: "\u{2248} 2.27 billion seconds"),
        FeaturedEntry(unitID: "olympic_pool_vol", fact: "Takes 2 full days to fill"),
    ]

    private var featuredResults: [(result: SearchResult, fact: String)] {
        featuredEntries.compactMap { entry in
            guard let result = allUnits.first(where: { $0.unit.id == entry.unitID })
            else { return nil }
            return (result, entry.fact)
        }
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Interesting units")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
                .padding(.horizontal, 16)

            let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(featuredResults, id: \.result.id) { item in
                    FeaturedUnitCard(
                        name: item.result.unit.name,
                        category: item.result.categoryDisplayName,
                        fact: item.fact,
                        accent: item.result.accent
                    ) {
                        apply(item.result)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Recently used

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recently used")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(recentUnits, id: \.id) { result in
                    Button { apply(result) } label: {
                        recentUnitRow(result)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - State 2: Category browse

    private func categoryBrowseState(_ category: UnitCategory) -> some View {
        let accent = ConverterCategoryAccent.accent(for: category)
        let allForCategory = allUnits.filter { $0.category == category }
        let normalUnits = allForCategory.filter { $0.unit.kind == .normal }
        let absurdUnits = allForCategory.filter { $0.unit.kind != .normal }
        let grouped = UnitScaleGroups.grouped(absurdUnits.map(\.unit))

        return List {
            if !normalUnits.isEmpty {
                Section {
                    ForEach(normalUnits, id: \.id) { result in
                        Button { apply(result) } label: {
                            categoryBrowseRow(result, accent: accent)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    scaleHeader("Standard")
                }
            }
            ForEach(grouped, id: \.title) { group in
                Section {
                    ForEach(group.units, id: \.id) { unit in
                        if let result = allForCategory.first(where: { $0.unit.id == unit.id }) {
                            Button { apply(result) } label: {
                                categoryBrowseRow(result, accent: accent)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                        }
                    }
                } header: {
                    scaleHeader(group.title)
                }
            }
        }
        .listStyle(.plain)
    }

    private func categoryBrowseRow(_ result: SearchResult, accent: Color) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.unit.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                Text(result.factorDisplayString)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    // MARK: - State 3: Search results

    private var searchResultsState: some View {
        VStack(spacing: 0) {
            resultCountBadge
            List {
                ForEach(filteredResults, id: \.id) { result in
                    Button { apply(result) } label: {
                        searchResultRow(result, query: searchText)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
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
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(result.accent)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                highlightedText(result.unit.name, query: query)
                    .font(.system(size: 14, weight: .medium))

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

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    private func recentUnitRow(_ result: SearchResult) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(result.accent)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.unit.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text(result.categoryDisplayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(result.accent)
                    Text("\u{00B7}")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(result.unit.kind == .normal ? "Standard unit" : "Comparator")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
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

    private func scaleHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color(hex: "#888780"))
            .textCase(.uppercase)
            .tracking(0.7)
            .padding(.top, 4)
    }

    private func highlightedText(_ text: String, query: String) -> Text {
        let queryLower = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !queryLower.isEmpty,
              let range = text.lowercased().range(of: queryLower)
        else {
            return Text(text).foregroundStyle(Color.primary)
        }
        let before = String(text[text.startIndex..<range.lowerBound])
        let match = String(text[range])
        let after = String(text[range.upperBound...])

        return Text(before).foregroundStyle(Color.secondary)
            + Text(match).foregroundStyle(Color.primary).fontWeight(.semibold)
            + Text(after).foregroundStyle(Color.secondary)
    }

    private func apply(_ result: SearchResult) {
        vm.selectedCategory = result.category
        vm.selectedMode = result.mode
        vm.selectedToUnitID = result.unit.id
        Haptics.tap()
        dismiss()
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

// MARK: - Featured Unit Card

private struct FeaturedUnitCard: View {
    let name: String
    let category: String
    let fact: String
    let accent: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(accent.opacity(0.9))
                Text(category)
                    .font(.system(size: 10))
                    .foregroundStyle(accent.opacity(0.6))
                Text(fact)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#888780"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(accent.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
