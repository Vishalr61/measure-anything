import Foundation
import MeasureAnythingCore

/// Display helpers shared across views (Favorites cards, Custom Units list, etc.).
/// Single source of truth for the SF Symbol and human-readable name per category.
extension UnitCategory {
    /// SF Symbol name used for the icon tile.
    var symbolName: String {
        switch self {
        case .length:      return "ruler"
        case .mass:        return "scalemass"
        case .time:        return "clock"
        case .temperature: return "thermometer"
        case .volume:      return "drop.fill"
        }
    }

    /// Human-readable name used for category pills and tags.
    var displayName: String {
        switch self {
        case .length:      return "Length"
        case .mass:        return "Mass"
        case .time:        return "Time"
        case .temperature: return "Temperature"
        case .volume:      return "Volume"
        }
    }
}
