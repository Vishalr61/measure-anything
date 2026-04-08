import Foundation

/// How a unit participates in conversion.
///
/// v1 rule:
/// - Most categories are multiplicative and use `UnitDefinition.factor`.
/// - Temperature is handled through a dedicated conversion path.
public enum ConversionStyle: String, CaseIterable, Codable, Hashable, Sendable {
    case multiplicative
    case temperature
}

