import Combine
import Foundation
import SwiftUI
import MeasureAnythingCore
import MeasureAnythingTaxonomy

/// Resolved display strings for a converter category tab.
struct ConverterCategoryDisplay: Equatable {
    var displayName: String
    var description: String?
}

/// Resolved display strings for a converter mode tab (from taxonomy subgenres when available).
struct ConverterModeDisplay: Equatable {
    var displayName: String
    var description: String?
}

/// Display payload for search/browse rows: full taxonomy path without exposing registry types.
struct TaxonomySearchPathResult: Equatable, Sendable, Identifiable {
    let id: String
    /// e.g. `"Measurement / Normal units / Meter"`
    let pathLine: String
    let domainTitle: String
    let subgenreTitle: String
    let itemTitle: String

    static let pathComponentSeparator = " / "
}

/// One taxonomy item row returned from search (title + path + components).
struct TaxonomyItemSearchResult: Equatable, Sendable, Identifiable {
    var id: String { itemId }
    let itemId: String
    let itemTitle: String
    let pathLine: String
    let domainTitle: String
    let subgenreTitle: String
}

/// Subgenre choices for the taxonomy search filter menu.
struct TaxonomySubgenreFilterOption: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
}

// MARK: - Match ranking (lower = stronger)

private enum TaxonomySearchMatchTier: Int, Comparable {
    case exactTitle = 0
    case prefixTitle = 1
    case exactSynonym = 2
    case prefixSynonym = 3
    case exactTag = 4
    case prefixTag = 5

    static func < (lhs: TaxonomySearchMatchTier, rhs: TaxonomySearchMatchTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// App-owned entry point for taxonomy: loads `TaxonomyRegistry` once and exposes converter picker data.
///
/// Validation stays in `MeasureAnythingTaxonomy`; this type only reads resolved lists and surfaces load failures.
@MainActor
final class AppTaxonomyStore: ObservableObject {
    @Published private(set) var loadFailureMessage: String?

    private let registry: TaxonomyRegistry?

    /// Production: load bundled taxonomy.
    init() {
        do {
            registry = try TaxonomyRegistry()
            loadFailureMessage = nil
        } catch {
            registry = nil
            loadFailureMessage = error.localizedDescription
        }
    }

    /// Tests and previews: inject a registry or simulate load failure without reading the bundle.
    init(injectedRegistry: TaxonomyRegistry?, loadFailureMessage: String?) {
        self.registry = injectedRegistry
        self.loadFailureMessage = loadFailureMessage
    }

    /// Category tabs, ordered as in `converterNavigation` (or `UnitCategory.allCases` if absent or load failed).
    var converterCategories: [UnitCategory] {
        guard let nav = registry?.converterNavigation else {
            return Array(UnitCategory.allCases)
        }
        let parsed = nav.categories.compactMap { UnitCategory(rawValue: $0.unitCategoryRaw) }
        guard parsed.count == nav.categories.count, !parsed.isEmpty else {
            return Array(UnitCategory.allCases)
        }
        return parsed
    }

    /// Mode tabs, ordered as in `converterNavigation` (or `Mode.allCases` if absent, invalid rows, or load failed).
    var converterModes: [UnitRegistry.Mode] {
        guard let nav = registry?.converterNavigation else {
            return Array(UnitRegistry.Mode.allCases)
        }
        let parsed = nav.modes.compactMap { UnitRegistry.Mode(rawValue: $0.modeRaw) }
        guard parsed.count == nav.modes.count, !parsed.isEmpty else {
            return Array(UnitRegistry.Mode.allCases)
        }
        return parsed
    }

    /// Custom-unit form categories: `customAllowed` members in taxonomy category order.
    var customFormCategories: [UnitCategory] {
        let allowed = Set(UnitCategory.customAllowed)
        let ordered = converterCategories.filter { allowed.contains($0) }
        return ordered.isEmpty ? Array(UnitCategory.customAllowed) : ordered
    }

    /// Subgenres available for optional search filtering (empty when taxonomy did not load).
    var searchSubgenreFilterOptions: [TaxonomySubgenreFilterOption] {
        guard let reg = registry else { return [] }
        return reg.subgenres
            .map { TaxonomySubgenreFilterOption(id: $0.id, title: $0.name) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Display metadata for a category row: optional JSON overrides, else `rawValue.capitalized`.
    func categoryDisplay(for category: UnitCategory) -> ConverterCategoryDisplay {
        let fallbackName = category.rawValue.capitalized
        guard let nav = registry?.converterNavigation else {
            return ConverterCategoryDisplay(displayName: fallbackName, description: nil)
        }
        guard let row = nav.categories.first(where: { UnitCategory(rawValue: $0.unitCategoryRaw) == category }) else {
            return ConverterCategoryDisplay(displayName: fallbackName, description: nil)
        }
        let name: String
        if let d = row.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
            name = d
        } else {
            name = fallbackName
        }
        let desc = row.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = (desc?.isEmpty == false) ? desc : nil
        return ConverterCategoryDisplay(displayName: name, description: description)
    }

    /// Display metadata for a mode tab: resolved via `converterNavigation` → `subgenreId` → `Subgenre` name/description.
    func modeDisplay(for mode: UnitRegistry.Mode) -> ConverterModeDisplay {
        let fallbackName = mode.rawValue.capitalized
        guard let nav = registry?.converterNavigation, let reg = registry else {
            return ConverterModeDisplay(displayName: fallbackName, description: nil)
        }
        guard let row = nav.modes.first(where: { $0.modeRaw == mode.rawValue }) else {
            return ConverterModeDisplay(displayName: fallbackName, description: nil)
        }
        guard let sub = reg.subgenreById[row.subgenreId] else {
            return ConverterModeDisplay(displayName: fallbackName, description: nil)
        }
        let subName = sub.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = subName.isEmpty ? fallbackName : subName
        let desc = sub.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return ConverterModeDisplay(displayName: name, description: desc.isEmpty ? nil : desc)
    }

    /// Resolves `Domain / Subgenre / Item` titles for a taxonomy item id. `nil` if registry is missing or ids are unknown.
    func searchPathResult(forItemId itemId: String) -> TaxonomySearchPathResult? {
        guard let reg = registry,
              let item = reg.itemById[itemId],
              let domain = reg.domainById[item.domainId],
              let sub = reg.subgenreById[item.subgenreId] else {
            return nil
        }
        return Self.makePathResult(itemId: itemId, item: item, domain: domain, sub: sub)
    }

    /// Search taxonomy items by title, synonyms, and tags. Ranking: exact title → prefix title → exact synonym → prefix synonym → exact tag → prefix tag.
    /// Returns `[]` when the query is empty, taxonomy failed to load, or nothing matches.
    func searchItems(
        query: String,
        unitCategoryFilter: UnitCategory? = nil,
        subgenreIdFilter: String? = nil,
        limit: Int = 50
    ) -> [TaxonomyItemSearchResult] {
        guard let reg = registry else { return [] }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        struct Scored {
            let tier: TaxonomySearchMatchTier
            let result: TaxonomyItemSearchResult
        }

        var scored: [Scored] = []
        scored.reserveCapacity(reg.items.count)

        for item in reg.items {
            guard passesSearchFilters(item: item, unitCategory: unitCategoryFilter, subgenreId: subgenreIdFilter) else {
                continue
            }
            guard let tier = matchTier(item: item, normalizedQuery: q) else { continue }
            guard let path = Self.makePathResult(
                itemId: item.id,
                item: item,
                domain: reg.domainById[item.domainId],
                sub: reg.subgenreById[item.subgenreId]
            ) else { continue }

            let row = TaxonomyItemSearchResult(
                itemId: path.id,
                itemTitle: path.itemTitle,
                pathLine: path.pathLine,
                domainTitle: path.domainTitle,
                subgenreTitle: path.subgenreTitle
            )
            scored.append(Scored(tier: tier, result: row))
        }

        scored.sort { a, b in
            if a.tier != b.tier { return a.tier < b.tier }
            return a.result.itemTitle.localizedStandardCompare(b.result.itemTitle) == .orderedAscending
        }

        if scored.count <= limit {
            return scored.map(\.result)
        }
        return Array(scored.prefix(limit).map(\.result))
    }

    private static func makePathResult(
        itemId: String,
        item: Item,
        domain: Domain?,
        sub: Subgenre?
    ) -> TaxonomySearchPathResult? {
        guard let domain, let sub else { return nil }
        let domainTitle = domain.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subgenreTitle = sub.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let itemTitle = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !domainTitle.isEmpty, !subgenreTitle.isEmpty, !itemTitle.isEmpty else {
            return nil
        }
        let pathLine = [domainTitle, subgenreTitle, itemTitle].joined(separator: TaxonomySearchPathResult.pathComponentSeparator)
        return TaxonomySearchPathResult(
            id: itemId,
            pathLine: pathLine,
            domainTitle: domainTitle,
            subgenreTitle: subgenreTitle,
            itemTitle: itemTitle
        )
    }

    private func passesSearchFilters(
        item: Item,
        unitCategory: UnitCategory?,
        subgenreId: String?
    ) -> Bool {
        if let sid = subgenreId, !sid.isEmpty, item.subgenreId != sid {
            return false
        }
        if let cat = unitCategory {
            guard let raw = item.unitCategoryRaw, raw == cat.rawValue else {
                return false
            }
        }
        return true
    }

    private func matchTier(item: Item, normalizedQuery q: String) -> TaxonomySearchMatchTier? {
        let title = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if title == q { return .exactTitle }
        if title.hasPrefix(q) { return .prefixTitle }

        for s in item.synonyms {
            let sl = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if sl == q { return .exactSynonym }
            if sl.hasPrefix(q) { return .prefixSynonym }
        }
        for t in item.tags {
            let tl = t.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if tl == q { return .exactTag }
            if tl.hasPrefix(q) { return .prefixTag }
        }
        return nil
    }
}
