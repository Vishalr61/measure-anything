import Foundation
import MeasureAnythingCore

extension FavoriteConversion {
    /// Whether both units still exist in the registry and match the saved category.
    func isRestorable(registry: UnitRegistry) -> Bool {
        guard let category = UnitCategory(rawValue: categoryRaw) else { return false }
        guard let from = try? registry.unit(id: fromUnitID),
              let to = try? registry.unit(id: toUnitID) else { return false }
        return from.category == category && to.category == category
    }

    /// One-line summary for lists.
    func displayTitle(registry: UnitRegistry) -> String {
        if let label = label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            return label
        }
        let fromName = (try? registry.unit(id: fromUnitID))?.name ?? "?"
        let toName = (try? registry.unit(id: toUnitID))?.name ?? "?"
        return "\(fromName) → \(toName)"
    }

    func displaySubtitle() -> String {
        if let c = UnitCategory(rawValue: categoryRaw) {
            return c.rawValue.capitalized
        }
        return categoryRaw
    }
}

extension FavoriteConversion {
    /// Smallest mode that includes both units.
    static func minimumMode(registry: UnitRegistry, category: UnitCategory, fromID: String, toID: String) -> UnitRegistry.Mode? {
        guard let from = try? registry.unit(id: fromID),
              let to = try? registry.unit(id: toID) else { return nil }
        guard from.category == category, to.category == category else { return nil }
        let kinds = Set([from.kind, to.kind])
        if kinds.contains(.absurd) { return .absurd }
        if kinds.contains(.custom) { return .custom }
        return .normal
    }
}
