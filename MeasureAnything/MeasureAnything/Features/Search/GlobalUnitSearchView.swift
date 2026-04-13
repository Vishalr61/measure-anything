import SwiftUI
import MeasureAnythingCore

struct GlobalUnitSearchView: View {
    @ObservedObject var vm: ConverterViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private var allResults: [SearchResult] {
        var results: [SearchResult] = []
        for category in vm.categories {
            let normal = vm.units(for: category, mode: .normal)
            for unit in normal {
                results.append(SearchResult(unit: unit, category: category, mode: .normal))
            }
            let absurd = vm.units(for: category, mode: .absurd)
                .filter { $0.kind != .normal }
            for unit in absurd {
                results.append(SearchResult(unit: unit, category: category, mode: .absurd))
            }
        }
        return results
    }

    private var filteredResults: [SearchResult] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        return allResults
            .filter {
                $0.unit.name.lowercased().contains(query)
                    || ($0.unit.description?.lowercased().contains(query) ?? false)
            }
            .sorted {
                let aStarts = $0.unit.name.lowercased().hasPrefix(query)
                let bStarts = $1.unit.name.lowercased().hasPrefix(query)
                if aStarts != bStarts { return aStarts }
                return $0.unit.name < $1.unit.name
            }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                Divider()

                if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    emptyPrompt
                } else if filteredResults.isEmpty {
                    noResultsPrompt
                } else {
                    resultsList
                }
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

    // MARK: - Subviews

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
        .padding(.bottom, 12)
    }

    private var emptyPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: "#D3D1C7"))
            Text("Search for any unit")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Try \"banana\", \"light-year\", or \"bathtub\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }

    private var noResultsPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(Color(hex: "#D3D1C7"))
            Text("No units match \"\(searchText)\"")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }

    private var resultsList: some View {
        List(filteredResults, id: \.id) { result in
            Button {
                apply(result)
            } label: {
                SearchResultRow(result: result)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }

    // MARK: - Actions

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
}

// MARK: - Result Row

private struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(result.accent)
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(result.unit.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(result.categoryDisplayName)
                        .font(.system(size: 12))
                        .foregroundStyle(result.accent)
                    Text("\u{00B7}")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#B4B2A9"))
                    Text(result.modeTag)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#888780"))
                }
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "#D3D1C7"))
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
