import Foundation

/// Supported normal temperature units in v1.
public enum TemperatureUnit: String, CaseIterable, Codable, Hashable, Sendable {
    case celsius
    case fahrenheit
    case kelvin

    public var unitID: String { rawValue }
}

