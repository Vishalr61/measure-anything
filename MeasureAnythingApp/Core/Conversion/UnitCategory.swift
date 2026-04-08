import Foundation

/// High-level measurement domains supported by the conversion engine.
///
/// Note: `temperature` is included as a category, but is intentionally handled
/// via a dedicated conversion path (not the multiplicative `factor` rule).
public enum UnitCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case length
    case mass
    case time
    case temperature
    case volume
}

public extension UnitCategory {
    /// Canonical base unit per category. Non-temperature categories must not deviate.
    var canonicalBaseUnit: String? {
        switch self {
        case .length: "meter"
        case .mass: "kilogram"
        case .time: "second"
        case .volume: "liter"
        case .temperature: nil
        }
    }
}

