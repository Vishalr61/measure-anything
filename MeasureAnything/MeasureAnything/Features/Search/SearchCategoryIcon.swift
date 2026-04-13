import MeasureAnythingCore

enum SearchCategoryIcon {
    static func symbol(for category: UnitCategory) -> String {
        switch category {
        case .length:      return "ruler"
        case .mass:        return "scalemass"
        case .time:        return "clock"
        case .temperature: return "thermometer.medium"
        case .volume:      return "drop"
        }
    }
}
