import MeasureAnythingCore

/// Hardcoded Explore “Try these” rows when conversion history is empty.
enum TryTheseSuggestions {
    struct RowSpec {
        let fromID: String
        let toID: String
        let category: UnitCategory
        let mode: UnitRegistry.Mode
    }

    static let rows: [RowSpec] = [
        RowSpec(fromID: "blue_whale_mass", toID: "kilogram", category: .mass, mode: .absurd),
        RowSpec(fromID: "aircraft_carrier", toID: "meter", category: .length, mode: .absurd),
        RowSpec(fromID: "eyedrop", toID: "milliliter", category: .volume, mode: .absurd),
    ]
}
