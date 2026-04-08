import SwiftUI
import MeasureAnythingCore
import MeasureAnythingTaxonomy

/// Root → domain → grouped items; search overlays ranked results. Same `onPick` everywhere.
struct TaxonomySearchView: View {
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var taxonomyStore: AppTaxonomyStore

    @State private var query = ""
    @State private var browseLevel: TaxonomyBrowseLevel = .root
    @State private var filters = TaxonomySearchFilters()

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearchMode: Bool {
        !trimmedQuery.isEmpty
    }

    /// Search and filter menus respect current domain when drilled in.
    private var effectiveFilters: TaxonomySearchFilters {
        var f = filters
        if case .domain(let id) = browseLevel {
            f.domainId = id
        }
        return taxonomyStore.normalizedFilters(f)
    }

    private var domainRows: [TaxonomyDomainSection] {
        taxonomyStore.browseDomains()
    }

    private var domainScopedSections: [TaxonomyBrowseSection] {
        guard case .domain(let domainId) = browseLevel else { return [] }
        return taxonomyStore.browseSections(in: domainId, filters: filters, limitPerSection: 200, maxSections: 50)
    }

    private var searchResults: [TaxonomyItemSearchResult] {
        taxonomyStore.searchItems(query: query, filters: effectiveFilters, limit: 200)
    }

    private var browseIsEmpty: Bool {
        switch browseLevel {
        case .root:
            return domainRows.isEmpty
        case .domain:
            return domainScopedSections.isEmpty || domainScopedSections.allSatisfy { $0.items.isEmpty }
        }
    }

    private var navigationTitle: String {
        if isSearchMode {
            return "Search"
        }
        switch browseLevel {
        case .root:
            return "Browse"
        case .domain(let id):
            return domainRows.first { $0.id == id }?.title ?? "Browse"
        }
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
                            switch browseLevel {
                            case .root:
                                ForEach(domainRows) { domain in
                                    Button {
                                        browseLevel = .domain(domain.id)
                                        var f = filters
                                        f.domainId = domain.id
                                        filters = taxonomyStore.normalizedFilters(f)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(domain.title)
                                                    .font(.body.weight(.semibold))
                                                    .foregroundStyle(.primary)
                                                if let sub = domain.subtitle {
                                                    Text(sub)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            Spacer()
                                            Text("\(domain.itemCount)")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(domain.title), \(domain.itemCount) items")
                                }
                            case .domain:
                                ForEach(domainScopedSections) { section in
                                    Section {
                                        ForEach(section.items) { row in
                                            taxonomyRow(row)
                                        }
                                    } header: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(section.title)
                                                    .font(.subheadline.weight(.semibold))
                                                Spacer()
                                                Text("\(section.itemCount)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
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
                    }
                    .overlay {
                        if isSearchMode, searchResults.isEmpty {
                            ContentUnavailableView.search(text: query)
                        } else if !isSearchMode, browseIsEmpty {
                            ContentUnavailableView(
                                "No items",
                                systemImage: "line.3.horizontal.decrease.circle",
                                description: Text("Nothing matches the current filters. Clear filters or go back.")
                            )
                        }
                    }
                    .searchable(text: $query, prompt: "Search taxonomy")
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isSearchMode {
                        if case .domain = browseLevel {
                            Button {
                                browseLevel = .root
                                var f = filters
                                f.domainId = nil
                                filters = taxonomyStore.normalizedFilters(f)
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            .accessibilityLabel("Back to domains")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        filterMenu
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var filterMenu: some View {
        Menu {
            let domainScope: String? = {
                if case .domain(let id) = browseLevel { return id }
                return filters.domainId
            }()

            Section("Domain") {
                if browseLevel != .root {
                    Button("All domains (global)") {
                        browseLevel = .root
                        var f = filters
                        f.domainId = nil
                        filters = taxonomyStore.normalizedFilters(f)
                    }
                }
                ForEach(taxonomyStore.availableDomains()) { opt in
                    Button(opt.title) {
                        browseLevel = .domain(opt.id)
                        var f = filters
                        f.domainId = opt.id
                        filters = taxonomyStore.normalizedFilters(f)
                    }
                }
            }
            Section("Unit category") {
                Button("All unit categories") {
                    var f = filters
                    f.unitCategory = nil
                    filters = taxonomyStore.normalizedFilters(f)
                }
                ForEach(taxonomyStore.availableUnitCategories(for: domainScope), id: \.self) { cat in
                    Button(cat.rawValue.capitalized) {
                        var f = filters
                        f.unitCategory = cat
                        filters = taxonomyStore.normalizedFilters(f)
                    }
                }
            }
            Section("Subgenre") {
                Button("All subgenres") {
                    var f = filters
                    f.subgenreId = nil
                    filters = taxonomyStore.normalizedFilters(f)
                }
                ForEach(taxonomyStore.availableSubgenres(for: domainScope)) { opt in
                    Button(opt.title) {
                        var f = filters
                        f.subgenreId = opt.id
                        filters = taxonomyStore.normalizedFilters(f)
                    }
                }
            }
        } label: {
            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
        }
        .disabled(taxonomyStore.loadFailureMessage != nil)
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
