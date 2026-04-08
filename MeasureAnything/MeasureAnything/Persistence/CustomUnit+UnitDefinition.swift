import Foundation
import MeasureAnythingCore

enum CustomUnitMappingError: Error, LocalizedError {
    case unsupportedCategory(String)
    case invalidBaseUnit(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedCategory(let raw):
            "Unsupported category: \(raw)"
        case .invalidBaseUnit(let expected, let actual):
            "Base unit must be \(expected) for this category (got \(actual))."
        }
    }
}

extension CustomUnit {
    /// Maps a persisted row to a runtime `UnitDefinition` for the engine.
    func toUnitDefinition() throws -> UnitDefinition {
        guard let category = UnitCategory(rawValue: categoryRaw) else {
            throw CustomUnitMappingError.unsupportedCategory(categoryRaw)
        }
        guard category != .temperature else {
            throw CustomUnitMappingError.unsupportedCategory(categoryRaw)
        }
        guard let expected = category.canonicalBaseUnit, baseUnit == expected else {
            throw CustomUnitMappingError.invalidBaseUnit(expected: category.canonicalBaseUnit ?? "", actual: baseUnit)
        }
        return try UnitDefinition(
            id: id,
            name: name,
            category: category,
            baseUnit: baseUnit,
            kind: .custom,
            conversionStyle: .multiplicative,
            factor: factor,
            iconName: iconName,
            description: detail,
            exampleMeme: nil
        )
    }
}

extension UnitCategory {
    /// Categories that support v1 custom multiplicative units.
    static var customAllowed: [UnitCategory] {
        [.length, .mass, .time, .volume]
    }
}
