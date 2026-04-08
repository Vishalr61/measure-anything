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

/// One search/browse row: same shape as `TaxonomyPathResult` from the taxonomy package.
typealias TaxonomyItemSearchResult = TaxonomyPathResult

/// Domain filter option for taxonomy search (parallel to subgenre options).
struct TaxonomyDomainFilterOption: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
}

/// Subgenre choices for the taxonomy search filter menu.
struct TaxonomySubgenreFilterOption: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
}

/// Filters applied to both browse (empty query) and search modes.
struct TaxonomySearchFilters: Equatable {
    var domainId: String?
    var unitCategory: UnitCategory?
    var subgenreId: String?

    init(domainId: String? = nil, unitCategory: UnitCategory? = nil, subgenreId: String? = nil) {
        self.domainId = domainId
        self.unitCategory = unitCategory
        self.subgenreId = subgenreId
    }
}

/// Bridge from a taxonomy item id to converter-facing state (`MeasureAnythingCore` enums + optional unit id).
struct TaxonomyConverterRoute: Equatable {
    let category: UnitCategory?
    let mode: UnitRegistry.Mode?
    let preferredFromUnitId: String?
    /// `UnitCategory(rawValue: item.unitCategoryRaw)` succeeded.
    let resolvedCategory: Bool
    /// A `converterNavigation.modes` row matched `item.subgenreId`.
    let resolvedMode: Bool
    /// Item carried a non-empty `converterUnitId` in JSON (existence in the live registry is checked in `ConverterViewModel`).
    let hasConverterUnitMapping: Bool

    /// `true` when `applyTaxonomyRoute` should run: category and/or unit id, or a mode that is anchored to a resolved category.
    var hasAnyResolvableInput: Bool {
        category != nil
            || preferredFromUnitId != nil
            || (mode != nil && resolvedCategory)
    }
}

/// App-owned entry point for taxonomy: loads `TaxonomyRegistry` once and exposes converter picker data.
///
/// Validation stays in `MeasureAnythingTaxonomy`; search uses `TaxonomySearchIndex` built from bundled items plus the live unit catalog.
@MainActor
final class AppTaxonomyStore: ObservableObject {
    @Published private(set) var loadFailureMessage: String?

    private let registry: TaxonomyRegistry?
    private var searchIndex: TaxonomySearchIndex?

    /// Production: load bundled taxonomy.
    init() {
        do {
            let reg = try TaxonomyRegistry()
            registry = reg
            searchIndex = TaxonomySearchIndex(registry: reg, unitCatalog: [])
            loadFailureMessage = nil
        } catch {
            registry = nil
            searchIndex = nil
            loadFailureMessage = error.localizedDescription
        }
    }

    /// Tests and previews: inject a registry or simulate load failure without reading the bundle.
    init(injectedRegistry: TaxonomyRegistry?, loadFailureMessage: String?) {
        self.registry = injectedRegistry
        self.loadFailureMessage = loadFailureMessage
        if let reg = injectedRegistry {
            searchIndex = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        } else {
            searchIndex = nil
        }
    }

    /// Rebuilds the search index with taxonomy items plus every unit in the conversion registry (deduped by `converterUnitId`).
    func attachUnitCatalog(_ units: [UnitDefinition]) {
        guard let reg = registry else {
            searchIndex = nil
            return
        }
        searchIndex = TaxonomySearchIndex(registry: reg, unitCatalog: units)
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

    /// Domains for optional search filtering (empty when taxonomy did not load).
    var searchDomainFilterOptions: [TaxonomyDomainFilterOption] {
        guard let reg = registry else { return [] }
        return reg.domains
            .map { TaxonomyDomainFilterOption(id: $0.id, title: $0.name) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
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

    /// Resolves `Domain / Subgenre / Item` titles for an id (bundled item or synthetic `unit:…` row).
    func searchPathResult(forItemId itemId: String) -> TaxonomyPathResult? {
        searchIndex?.pathResult(forItemId: itemId)
    }

    /// Maps a taxonomy or catalog search id to converter pickers and optional primary unit id.
    func converterRoute(forTaxonomyItemId itemId: String) -> TaxonomyConverterRoute? {
        guard let reg = registry else { return nil }

        if let item = reg.itemById[itemId] {
            return Self.converterRoute(item: item, registry: reg)
        }

        guard let entry = searchIndex?.searchableItem(forItemId: itemId),
              let uid = entry.converterUnitId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !uid.isEmpty else {
            return nil
        }

        let category = entry.unitCategoryRaw.flatMap { UnitCategory(rawValue: $0) }
        let resolvedCategory = category != nil
        var mode: UnitRegistry.Mode?
        var resolvedMode = false
        if let nav = reg.converterNavigation,
           let row = nav.modes.first(where: { $0.subgenreId == entry.subcategoryId }),
           let m = UnitRegistry.Mode(rawValue: row.modeRaw) {
            mode = m
            resolvedMode = true
        }

        return TaxonomyConverterRoute(
            category: category,
            mode: mode,
            preferredFromUnitId: uid,
            resolvedCategory: resolvedCategory,
            resolvedMode: resolvedMode,
            hasConverterUnitMapping: true
        )
    }

    /// Subgenre-grouped browse (same filters as search). Empty when taxonomy did not load.
    func browseSections(
        filters: TaxonomySearchFilters = TaxonomySearchFilters(),
        limitPerSection: Int = 200,
        maxSections: Int = 50
    ) -> [TaxonomyBrowseSection] {
        guard let index = searchIndex else { return [] }
        return index.browseSections(
            categoryId: filters.domainId,
            subcategoryId: filters.subgenreId,
            unitCategoryRaw: filters.unitCategory?.rawValue,
            limitPerSection: limitPerSection,
            maxSections: maxSections
        )
    }

    /// Browse when `query` is blank/whitespace (flattened section order); ranked search when non-empty.
    func searchItems(
        query: String,
        filters: TaxonomySearchFilters = TaxonomySearchFilters(),
        limit: Int = 100
    ) -> [TaxonomyItemSearchResult] {
        guard let index = searchIndex else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return index.browse(
                categoryId: filters.domainId,
                subcategoryId: filters.subgenreId,
                unitCategoryRaw: filters.unitCategory?.rawValue,
                limit: limit
            )
        }
        return index.search(
            query: query,
            categoryId: filters.domainId,
            subcategoryId: filters.subgenreId,
            unitCategoryRaw: filters.unitCategory?.rawValue,
            limit: limit
        )
    }

    private static func converterRoute(item: Item, registry: TaxonomyRegistry) -> TaxonomyConverterRoute {
        let category = item.unitCategoryRaw.flatMap { UnitCategory(rawValue: $0) }
        let resolvedCategory = category != nil

        var mode: UnitRegistry.Mode?
        var resolvedMode = false
        if let nav = registry.converterNavigation,
           let row = nav.modes.first(where: { $0.subgenreId == item.subgenreId }),
           let m = UnitRegistry.Mode(rawValue: row.modeRaw) {
            mode = m
            resolvedMode = true
        }

        let trimmedUnit = item.converterUnitId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let unitId = (trimmedUnit?.isEmpty == false) ? trimmedUnit : nil

        return TaxonomyConverterRoute(
            category: category,
            mode: mode,
            preferredFromUnitId: unitId,
            resolvedCategory: resolvedCategory,
            resolvedMode: resolvedMode,
            hasConverterUnitMapping: unitId != nil
        )
    }
}
