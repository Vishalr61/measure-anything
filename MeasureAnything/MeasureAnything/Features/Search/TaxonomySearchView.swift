import SwiftUI
import MeasureAnythingCore
import MeasureAnythingTaxonomy

/// Browse filtered taxonomy/catalog rows or search when typing; same rows and `onPick` for both.
struct TaxonomySearchView: View {
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var taxonomyStore: AppTaxonomyStore

    @State private var query = ""
    @State private var filters = TaxonomySearchFilters()

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearchMode: Bool {
        !trimmedQuery.isEmpty
    }

    private var browseSections: [TaxonomyBrowseSection] {
        taxonomyStore.browseSections(filters: filters, limitPerSection: 200, maxSections: 50)
    }

    private var searchResults: [TaxonomyItemSearchResult] {
        taxonomyStore.searchItems(query: query, filters: filters, limit: 200)
    }

    private var browseIsEmpty: Bool {
        browseSections.isEmpty || browseSections.allSatisfy { $0.items.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Group {
                if taxonomyStore.loadFailureMessage != nil {
                    ContentUnavailableView(
                        "Taxonomy unavailable",
                        systemImage: "magnifyingglass",
                        description: Text("Browse and search need a loaded taxonomy registry.")
                    )
                } else {
                    List {
                        if isSearchMode {
                            ForEach(searchResults) { row in
                                taxonomyRow(row)
                            }
                        } else {
                            ForEach(browseSections) { section in
                                Section {
                                    ForEach(section.items) { row in
                                        taxonomyRow(row)
                                    }
                                } header: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(section.title)
                                            .font(.subheadline.weight(.semibold))
                                        if let subtitle = section.subtitle {
                                            Text(subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textCase(nil)
                                }
                            }
                        }
                    }
                    .overlay {
                        if isSearchMode, searchResults.isEmpty {
                            ContentUnavailableView.search(text: query)
                        } else if !isSearchMode, browseIsEmpty {
                            ContentUnavailableView(
                                "No items",
                                systemImage: "line.3.horizontal.decrease.circle",
                                description: Text("Nothing matches the current filters. Clear filters or pick another domain, category, or subgenre.")
                            )
                        }
                    }
                    .searchable(text: $query, prompt: "Search or browse with filters")
                }
            }
            .navigationTitle("Browse & search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Section("Domain") {
                            Button("All domains") {
                                var f = filters
                                f.domainId = nil
                                filters = f
                            }
                            ForEach(taxonomyStore.searchDomainFilterOptions) { opt in
                                Button(opt.title) {
                                    var f = filters
                                    f.domainId = opt.id
                                    filters = f
                                }
                            }
                        }
                        Section("Unit category") {
                            Button("All unit categories") {
                                var f = filters
                                f.unitCategory = nil
                                filters = f
                            }
                            ForEach(UnitCategory.allCases, id: \.self) { cat in
                                Button(cat.rawValue.capitalized) {
                                    var f = filters
                                    f.unitCategory = cat
                                    filters = f
                                }
                            }
                        }
                        Section("Subgenre") {
                            Button("All subgenres") {
                                var f = filters
                                f.subgenreId = nil
                                filters = f
                            }
                            ForEach(taxonomyStore.searchSubgenreFilterOptions) { opt in
                                Button(opt.title) {
                                    var f = filters
                                    f.subgenreId = opt.id
                                    filters = f
                                }
                            }
                        }
                    } label: {
                        Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .disabled(taxonomyStore.loadFailureMessage != nil)
                }
            }
        }
    }

    @ViewBuilder
    private func taxonomyRow(_ row: TaxonomyPathResult) -> some View {
        Button {
            onPick(row.id)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.itemTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(row.pathLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(row.itemTitle), \(row.pathLine)")
        .accessibilityHint("Apply this taxonomy item in the converter")
    }
}

#Preview {
    TaxonomySearchView { _ in }
        .environmentObject(AppTaxonomyStore())
}
