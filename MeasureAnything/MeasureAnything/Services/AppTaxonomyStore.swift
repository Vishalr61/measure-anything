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
}
