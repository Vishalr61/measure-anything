import Foundation
import MeasureAnythingCore
import SwiftData

/// User-defined multiplicative unit stored locally (v1: no temperature).
@Model
final class CustomUnit {
    /// Stable id used as `UnitDefinition.id` (UUID string).
    @Attribute(.unique) var id: String
    var name: String
    /// `UnitCategory.rawValue` — must not be `temperature` for v1.
    var categoryRaw: String
    /// Canonical base unit for the category (e.g. `meter`); must match `UnitCategory.canonicalBaseUnit`.
    var baseUnit: String
    /// Factor: value in base units for **one** of this custom unit.
    var factor: Double
    /// Normal unit id chosen at creation (e.g. `kilometer`) so Settings can show "12.4 km" instead of raw base units.
    var referenceUnitID: String?
    var iconName: String?
    /// Optional user-facing notes (SwiftData model avoids naming this `description`).
    var detail: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        category: UnitCategory,
        baseUnit: String,
        factor: Double,
        referenceUnitID: String? = nil,
        iconName: String? = nil,
        detail: String? = nil
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.baseUnit = baseUnit
        self.factor = factor
        self.referenceUnitID = referenceUnitID
        self.iconName = iconName
        self.detail = detail
    }
}
