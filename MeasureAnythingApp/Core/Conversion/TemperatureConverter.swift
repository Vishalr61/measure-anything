import Foundation

/// Dedicated conversion path for temperature.
///
/// Internal canonical base for temperature is Kelvin.
public enum TemperatureConverter {
    public static func toKelvin(_ value: Double, from unit: TemperatureUnit) -> Double {
        switch unit {
        case .kelvin:
            value
        case .celsius:
            value + 273.15
        case .fahrenheit:
            (value - 32) * (5.0 / 9.0) + 273.15
        }
    }

    public static func fromKelvin(_ kelvin: Double, to unit: TemperatureUnit) -> Double {
        switch unit {
        case .kelvin:
            kelvin
        case .celsius:
            kelvin - 273.15
        case .fahrenheit:
            (kelvin - 273.15) * (9.0 / 5.0) + 32
        }
    }

    public static func convert(_ value: Double, from: TemperatureUnit, to: TemperatureUnit) -> Double {
        let k = toKelvin(value, from: from)
        return fromKelvin(k, to: to)
    }
}

