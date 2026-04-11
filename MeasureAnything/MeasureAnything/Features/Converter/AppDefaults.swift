import Foundation
import MeasureAnythingCore

enum AppDefaults {
    static var isMetric: Bool {
        if #available(iOS 16.0, *) {
            Locale.current.measurementSystem == .metric
        } else {
            Locale.current.usesMetricSystem
        }
    }

    /// Default from/to unit IDs for the user’s locale (normal-mode registry IDs).
    static func defaultPair(for category: UnitCategory) -> (from: String, to: String) {
        switch category {
        case .length:
            return isMetric ? ("meter", "kilometer") : ("foot", "mile")
        case .mass:
            return isMetric ? ("kilogram", "gram") : ("pound", "ounce")
        case .time:
            return ("hour", "minute")
        case .temperature:
            return isMetric ? ("celsius", "fahrenheit") : ("fahrenheit", "celsius")
        case .volume:
            return isMetric ? ("liter", "milliliter") : ("cup_us", "gallon_us")
        }
    }
}
