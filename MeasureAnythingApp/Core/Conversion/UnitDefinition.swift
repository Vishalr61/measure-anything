import Foundation

/// A data-driven definition of a unit within a `UnitCategory`.
///
/// For non-temperature categories, conversions are strictly multiplicative:
/// - `baseValue = input * from.factor`
/// - `output = baseValue / to.factor`
///
/// Temperature is intentionally *not* represented with affine offsets here.
/// Keep it on a dedicated conversion path to avoid contaminating the core rule.
public struct UnitDefinition: Identifiable, Codable, Hashable, Sendable {
    public typealias ID = String

    public let id: ID
    public var name: String
    public var category: UnitCategory
    /// Canonical base unit name for the category (e.g., "meter").
    /// For non-temperature categories, this must match `category.canonicalBaseUnit`.
    public var baseUnit: String
    public var kind: UnitKind

    /// Multiplicative factor to convert *this* unit into the category base unit.
    /// Example: if `category = length` and `baseUnit = "meter"`:
    /// - kilometer.factor = 1000
    /// - banana.factor = 0.19
    public var factor: Double

    /// Optional SF Symbol name or app asset name for display layers.
    public var iconName: String?
    /// A short description of the assumption/source (kept deterministic).
    public var description: String?
    /// Deterministic meme line shown on the result card when enabled.
    public var exampleMeme: String?

    public init(
        id: ID,
        name: String,
        category: UnitCategory,
        baseUnit: String,
        kind: UnitKind,
        factor: Double,
        iconName: String? = nil,
        description: String? = nil,
        exampleMeme: String? = nil
    ) throws {
        self.id = id
        self.name = name
        self.category = category
        self.baseUnit = baseUnit
        self.kind = kind
        self.factor = factor
        self.iconName = iconName
        self.description = description
        self.exampleMeme = exampleMeme

        try validate()
    }
}

public extension UnitDefinition {
    enum ValidationError: Error, Equatable, LocalizedError {
        case emptyID
        case emptyName
        case nonPositiveFactor(Double)
        case temperatureNotAllowedInMultiplicativeDefinition
        case baseUnitMismatch(expected: String, actual: String)

        public var errorDescription: String? {
            switch self {
            case .emptyID:
                "UnitDefinition.id must not be empty."
            case .emptyName:
                "UnitDefinition.name must not be empty."
            case .nonPositiveFactor(let factor):
                "UnitDefinition.factor must be > 0 (got \(factor))."
            case .temperatureNotAllowedInMultiplicativeDefinition:
                "Temperature units must be handled via a dedicated conversion path (not UnitDefinition.factor)."
            case .baseUnitMismatch(let expected, let actual):
                "UnitDefinition.baseUnit mismatch (expected '\(expected)', got '\(actual)')."
            }
        }
    }

    /// Ensures the definition is safe for the multiplicative conversion engine.
    func validate() throws {
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.emptyID
        }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.emptyName
        }
        guard factor > 0 else {
            throw ValidationError.nonPositiveFactor(factor)
        }

        // Temperature is intentionally excluded from the multiplicative unit system.
        if category == .temperature {
            throw ValidationError.temperatureNotAllowedInMultiplicativeDefinition
        }

        if let expected = category.canonicalBaseUnit, expected != baseUnit {
            throw ValidationError.baseUnitMismatch(expected: expected, actual: baseUnit)
        }
    }
}

