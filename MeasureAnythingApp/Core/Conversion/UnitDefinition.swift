import Foundation

/// A data-driven definition of a unit within a `UnitCategory`.
///
/// For non-temperature categories, conversions are strictly multiplicative:
/// - `baseValue = input * from.factor`
/// - `output = baseValue / to.factor`
///
/// Normal temperature scales use `TemperatureConverter`. Absurd temperature comparators use
/// `temperatureAffine` (Kelvin = 273.15 + factor × input).
public struct UnitDefinition: Identifiable, Codable, Hashable, Sendable {
    public typealias ID = String

    public let id: ID
    public var name: String
    public var category: UnitCategory
    /// Canonical base unit name for the category (e.g., "meter").
    /// Must match `category.canonicalBaseUnit` for all categories in v1 (including temperature).
    public var baseUnit: String
    public var kind: UnitKind

    /// Controls which conversion path is used for this unit.
    ///
    /// - `.multiplicative`: uses `factor` with the canonical base unit
    /// - `.temperature`: participates in temperature conversion via `TemperatureConverter`
    /// - `.temperatureAffine`: absurd temperature; Kelvin = 273.15 + `factor` × value
    public var conversionStyle: ConversionStyle

    /// Multiplicative factor to convert *this* unit into the category base unit.
    /// Example: if `category = length` and `baseUnit = "meter"`:
    /// - kilometer.factor = 1000
    /// - banana.factor = 0.19
    ///
    /// Required when `conversionStyle == .multiplicative` or `.temperatureAffine` (non-zero).
    /// Ignored for `.temperature` scale units.
    public var factor: Double?

    /// Optional SF Symbol name or app asset name for display layers.
    public var iconName: String?
    /// A short description of the assumption/source (kept deterministic).
    public var description: String?
    /// Deterministic meme line shown on the result card when enabled.
    public var exampleMeme: String?
    /// Contextual "did you know" fact tied to this unit (may reference the live result via `{result}`).
    public var funFact: String?
    /// Dice-roll bias (1–10); higher = more likely when weighted. Absent in JSON defaults to 5 in the UI layer.
    public var interestScore: Int?

    public init(
        id: ID,
        name: String,
        category: UnitCategory,
        baseUnit: String,
        kind: UnitKind,
        conversionStyle: ConversionStyle = .multiplicative,
        factor: Double? = nil,
        iconName: String? = nil,
        description: String? = nil,
        exampleMeme: String? = nil,
        funFact: String? = nil,
        interestScore: Int? = nil
    ) throws {
        self.id = id
        self.name = name
        self.category = category
        self.baseUnit = baseUnit
        self.kind = kind
        self.conversionStyle = conversionStyle
        self.factor = factor
        self.iconName = iconName
        self.description = description
        self.exampleMeme = exampleMeme
        self.funFact = funFact
        self.interestScore = interestScore

        try validate()
    }
}

public extension UnitDefinition {
    enum ValidationError: Error, Equatable, LocalizedError {
        case emptyID
        case emptyName
        case missingFactorForMultiplicative
        case nonPositiveFactor(Double)
        case invalidStyleForCategory(expected: String, actual: ConversionStyle)
        case baseUnitMismatch(expected: String, actual: String)
        case missingAffineTemperatureFactor
        case zeroAffineTemperatureFactor

        public var errorDescription: String? {
            switch self {
            case .emptyID:
                "UnitDefinition.id must not be empty."
            case .emptyName:
                "UnitDefinition.name must not be empty."
            case .missingFactorForMultiplicative:
                "UnitDefinition.factor is required for multiplicative units."
            case .nonPositiveFactor(let factor):
                "UnitDefinition.factor must be > 0 (got \(factor))."
            case .invalidStyleForCategory(let expected, let actual):
                "UnitDefinition.conversionStyle mismatch (expected \(expected), got \(actual))."
            case .baseUnitMismatch(let expected, let actual):
                "UnitDefinition.baseUnit mismatch (expected '\(expected)', got '\(actual)')."
            case .missingAffineTemperatureFactor:
                "UnitDefinition.factor is required for temperatureAffine units."
            case .zeroAffineTemperatureFactor:
                "UnitDefinition.factor must be non-zero for temperatureAffine units."
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

        switch category {
        case .temperature:
            switch conversionStyle {
            case .temperature:
                break
            case .temperatureAffine:
                guard kind == .absurd else {
                    throw ValidationError.invalidStyleForCategory(
                        expected: "temperatureAffine only for absurd temperature units",
                        actual: conversionStyle
                    )
                }
                guard let factor else {
                    throw ValidationError.missingAffineTemperatureFactor
                }
                guard factor != 0 else {
                    throw ValidationError.zeroAffineTemperatureFactor
                }
            case .multiplicative:
                throw ValidationError.invalidStyleForCategory(
                    expected: "temperature or temperatureAffine",
                    actual: conversionStyle
                )
            }
        default:
            guard conversionStyle == .multiplicative else {
                throw ValidationError.invalidStyleForCategory(
                    expected: "multiplicative",
                    actual: conversionStyle
                )
            }
            guard let factor else {
                throw ValidationError.missingFactorForMultiplicative
            }
            guard factor > 0 else {
                throw ValidationError.nonPositiveFactor(factor)
            }
        }

        if let expected = category.canonicalBaseUnit, expected != baseUnit {
            throw ValidationError.baseUnitMismatch(expected: expected, actual: baseUnit)
        }
    }
}

