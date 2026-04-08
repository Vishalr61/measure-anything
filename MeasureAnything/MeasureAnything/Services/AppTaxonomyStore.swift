import Combine
import Foundation
import SwiftUI
import MeasureAnythingCore
import MeasureAnythingTaxonomy

/// App-owned entry point for taxonomy: loads `TaxonomyRegistry` once and exposes converter picker data.
///
/// Validation stays in `MeasureAnythingTaxonomy`; this type only reads resolved lists and surfaces load failures.
@MainActor
final class AppTaxonomyStore: ObservableObject {
    @Published private(set) var loadFailureMessage: String?

    private let registry: TaxonomyRegistry?

    init() {
        do {
            registry = try TaxonomyRegistry()
            loadFailureMessage = nil
        } catch {
            registry = nil
            loadFailureMessage = error.localizedDescription
        }
    }

    /// Non-`nil` when the bundled taxonomy loaded and validated.
    var taxonomyRegistry: TaxonomyRegistry? { registry }

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
}
