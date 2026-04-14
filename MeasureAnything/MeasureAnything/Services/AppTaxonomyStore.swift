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

/// Explicit navigation depth for taxonomy browsing (independent of search query).
enum TaxonomyBrowseLevel: Equatable {
    case root
    case domain(String)
}

/// Filter option id + label (domains, subgenres).
struct TaxonomyFilterOption: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
}

/// Filters applied to search and to domain-scoped browse.
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
    let resolvedCategory: Bool
    let resolvedMode: Bool
    let hasConverterUnitMapping: Bool

    var hasAnyResolvableInput: Bool {
        category != nil
            || preferredFromUnitId != nil
            || (mode != nil && resolvedCategory)
    }
}

/// App-owned entry point for taxonomy: loads `TaxonomyRegistry` once and exposes converter picker data.
@MainActor
final class AppTaxonomyStore: ObservableObject {
    @Published private(set) var loadFailureMessage: String?

    private let registry: TaxonomyRegistry?
    private var searchIndex: TaxonomySearchIndex?

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

    init(injectedRegistry: TaxonomyRegistry?, loadFailureMessage: String?) {
        self.registry = injectedRegistry
        self.loadFailureMessage = loadFailureMessage
        if let reg = injectedRegistry {
            searchIndex = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        } else {
            searchIndex = nil
        }
    }

    func attachUnitCatalog(_ units: [UnitDefinition]) {
        guard let reg = registry else {
            searchIndex = nil
            return
        }
        searchIndex = TaxonomySearchIndex(registry: reg, unitCatalog: units)
    }

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

    var customFormCategories: [UnitCategory] {
        let allowed = Set(UnitCategory.customAllowed)
        let ordered = converterCategories.filter { allowed.contains($0) }
        return ordered.isEmpty ? Array(UnitCategory.customAllowed) : ordered
    }

    /// Domains from taxonomy JSON order (for root + menus).
    func availableDomains() -> [TaxonomyFilterOption] {
        guard let reg = registry else { return [] }
        return reg.domains
            .map { TaxonomyFilterOption(id: $0.id, title: $0.name) }
    }

    /// Subgenres belonging to `domainId` when set; otherwise all subgenres.
    func availableSubgenres(for domainId: String?) -> [TaxonomyFilterOption] {
        guard let reg = registry else { return [] }
        let subs: [Subgenre]
        if let did = domainId, !did.isEmpty {
            subs = reg.subgenres.filter { $0.domainId == did }
        } else {
            subs = reg.subgenres
        }
        return subs
            .map { TaxonomyFilterOption(id: $0.id, title: $0.name) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Unit categories present on indexed items for `domainId`. When nil, returns converter navigation order of all categories.
    func availableUnitCategories(for domainId: String?) -> [UnitCategory] {
        guard let index = searchIndex else { return Array(UnitCategory.allCases) }
        guard let did = domainId, !did.isEmpty else {
            return converterCategories
        }
        let raws = Set(index.entries(in: did).compactMap(\.unitCategoryRaw))
        let cats = raws.compactMap { UnitCategory(rawValue: $0) }
        let ordered = converterCategories.filter { cats.contains($0) }
        return ordered.isEmpty ? cats.sorted { $0.rawValue < $1.rawValue } : ordered
    }

    /// Clears subgenre / unit category when they cannot apply to the current domain or index.
    func normalizedFilters(_ filters: TaxonomySearchFilters) -> TaxonomySearchFilters {
        guard let reg = registry, let index = searchIndex else { return filters }
        var f = filters

        if let sid = f.subgenreId, !sid.isEmpty {
            if let sub = reg.subgenreById[sid] {
                if let did = f.domainId, !did.isEmpty, sub.domainId != did {
                    f.subgenreId = nil
                }
            } else {
                f.subgenreId = nil
            }
        }

        if let did = f.domainId, !did.isEmpty, let uc = f.unitCategory {
            let has = index.entries(in: did).contains { $0.unitCategoryRaw == uc.rawValue }
            if !has { f.unitCategory = nil }
        }

        return f
    }

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

    func searchPathResult(forItemId itemId: String) -> TaxonomyPathResult? {
        searchIndex?.pathResult(forItemId: itemId)
    }

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

    // MARK: - Browse (hierarchical)

    func browseDomains() -> [TaxonomyDomainSection] {
        searchIndex?.browseDomains() ?? []
    }

    /// Sections inside one domain (subgenre / unit category / flat), after filter normalization.
    func browseSections(
        in domainId: String,
        filters: TaxonomySearchFilters? = nil,
        limitPerSection: Int = 200,
        maxSections: Int = 100
    ) -> [TaxonomyBrowseSection] {
        guard let index = searchIndex else { return [] }
        var merged = filters ?? TaxonomySearchFilters()
        merged.domainId = domainId
        let nf = normalizedFilters(merged)
        return index.browseSections(
            inDomain: domainId,
            subcategoryId: nf.subgenreId,
            unitCategoryRaw: nf.unitCategory?.rawValue,
            limitPerSection: limitPerSection,
            maxSections: maxSections
        )
    }

    /// Ranked search and flattened browse use the same normalized filters.
    func searchItems(
        query: String,
        filters: TaxonomySearchFilters? = nil,
        limit: Int = 100
    ) -> [TaxonomyItemSearchResult] {
        guard let index = searchIndex else { return [] }
        let nf = normalizedFilters(filters ?? TaxonomySearchFilters())
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return index.browse(
                categoryId: nf.domainId,
                subcategoryId: nf.subgenreId,
                unitCategoryRaw: nf.unitCategory?.rawValue,
                limit: limit
            )
        }
        return index.search(
            query: query,
            categoryId: nf.domainId,
            subcategoryId: nf.subgenreId,
            unitCategoryRaw: nf.unitCategory?.rawValue,
            limit: limit
        )
    }

    // MARK: - Legacy filter option names (call sites)

    var searchDomainFilterOptions: [TaxonomyFilterOption] { availableDomains() }
    var searchSubgenreFilterOptions: [TaxonomyFilterOption] { availableSubgenres(for: nil) }

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
