import SwiftUI
import MeasureAnythingCore

/// Browse taxonomy items by title, synonym, or tag; selecting a row applies converter state via `onPick`.
struct TaxonomySearchView: View {
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var taxonomyStore: AppTaxonomyStore

    @State private var query = ""
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
                                onPick(row.itemId)
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
                    .searchable(text: $query, prompt: "Title, synonym, or tag")
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
                        Section("Category") {
                            Button("All categories") {
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
            unitCategoryFilter: categoryFilter,
            subgenreIdFilter: subgenreFilter,
            limit: 100
        )
    }
}

#Preview {
    TaxonomySearchView { _ in }
        .environmentObject(AppTaxonomyStore())
}
