import SwiftUI
import MeasureAnythingCore
import MeasureAnythingTaxonomy

/// Browse taxonomy items by title, synonym, or tag; selecting a row applies converter state via `onPick`.
struct TaxonomySearchView: View {
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var taxonomyStore: AppTaxonomyStore

    @State private var query = ""
    @State private var domainFilter: String?
    @State private var categoryFilter: UnitCategory?
    @State private var subgenreFilter: String?

    var body: some View {
        NavigationStack {
            Group {
                if taxonomyStore.loadFailureMessage != nil {
                    ContentUnavailableView(
                        "Taxonomy unavailable",
                        systemImage: "magnifyingglass",
                        description: Text("Search needs a loaded taxonomy registry.")
                    )
                } else {
                    List {
                        ForEach(searchResults) { row in
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
                    .overlay {
                        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !q.isEmpty, searchResults.isEmpty {
                            ContentUnavailableView.search(text: query)
                        }
                    }
                    .searchable(text: $query, prompt: "Units, titles, synonyms, tags")
                }
            }
            .navigationTitle("Search taxonomy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Section("Domain") {
                            Button("All domains") {
                                domainFilter = nil
                            }
                            ForEach(taxonomyStore.searchDomainFilterOptions) { opt in
                                Button(opt.title) {
                                    domainFilter = opt.id
                                }
                            }
                        }
                        Section("Unit category") {
                            Button("All unit categories") {
                                categoryFilter = nil
                            }
                            ForEach(UnitCategory.allCases, id: \.self) { cat in
                                Button(cat.rawValue.capitalized) {
                                    categoryFilter = cat
                                }
                            }
                        }
                        Section("Subgenre") {
                            Button("All subgenres") {
                                subgenreFilter = nil
                            }
                            ForEach(taxonomyStore.searchSubgenreFilterOptions) { opt in
                                Button(opt.title) {
                                    subgenreFilter = opt.id
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

    private var searchResults: [TaxonomyItemSearchResult] {
        taxonomyStore.searchItems(
            query: query,
            domainIdFilter: domainFilter,
            subgenreIdFilter: subgenreFilter,
            unitCategoryFilter: categoryFilter,
            limit: 100
        )
    }
}

#Preview {
    TaxonomySearchView { _ in }
        .environmentObject(AppTaxonomyStore())
}
