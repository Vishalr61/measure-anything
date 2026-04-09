import Foundation

/// Built-in normal unit definitions shipped with the app.
public enum SeedNormalUnits {
    public static var all: [UnitDefinition] {
        (length + mass + time + volume + temperature)
    }

    public static var length: [UnitDefinition] {
        [
            // Sub-atomic / atomic
            try! UnitDefinition(id: "picometer", name: "Picometer", category: .length, baseUnit: "meter", kind: .normal, factor: 1e-12),
            try! UnitDefinition(id: "angstrom", name: "Angstrom", category: .length, baseUnit: "meter", kind: .normal, factor: 1e-10),
            try! UnitDefinition(id: "nanometer", name: "Nanometer", category: .length, baseUnit: "meter", kind: .normal, factor: 1e-9),

            // Microscopic / engineering
            try! UnitDefinition(id: "micrometer", name: "Micrometer", category: .length, baseUnit: "meter", kind: .normal, factor: 0.000001),
            try! UnitDefinition(id: "thou", name: "Thou", category: .length, baseUnit: "meter", kind: .normal, factor: 0.0000254),

            // Metric / SI
            try! UnitDefinition(id: "millimeter", name: "Millimeter", category: .length, baseUnit: "meter", kind: .normal, factor: 0.001),
            try! UnitDefinition(id: "centimeter", name: "Centimeter", category: .length, baseUnit: "meter", kind: .normal, factor: 0.01),
            try! UnitDefinition(id: "decimeter", name: "Decimeter", category: .length, baseUnit: "meter", kind: .normal, factor: 0.1),
            try! UnitDefinition(id: "meter", name: "Meter", category: .length, baseUnit: "meter", kind: .normal, factor: 1),
            try! UnitDefinition(id: "hectometer", name: "Hectometer", category: .length, baseUnit: "meter", kind: .normal, factor: 100),
            try! UnitDefinition(id: "kilometer", name: "Kilometer", category: .length, baseUnit: "meter", kind: .normal, factor: 1000),
            try! UnitDefinition(id: "megameter", name: "Megameter", category: .length, baseUnit: "meter", kind: .normal, factor: 1000000),

            // Imperial / US customary
            try! UnitDefinition(id: "inch", name: "Inch", category: .length, baseUnit: "meter", kind: .normal, factor: 0.0254),
            try! UnitDefinition(id: "foot", name: "Foot", category: .length, baseUnit: "meter", kind: .normal, factor: 0.3048),
            try! UnitDefinition(id: "yard", name: "Yard", category: .length, baseUnit: "meter", kind: .normal, factor: 0.9144),
            try! UnitDefinition(id: "fathom", name: "Fathom", category: .length, baseUnit: "meter", kind: .normal, factor: 1.8288),
            try! UnitDefinition(id: "rod", name: "Rod", category: .length, baseUnit: "meter", kind: .normal, factor: 5.0292),
            try! UnitDefinition(id: "chain", name: "Chain", category: .length, baseUnit: "meter", kind: .normal, factor: 20.1168),
            try! UnitDefinition(id: "furlong", name: "Furlong", category: .length, baseUnit: "meter", kind: .normal, factor: 201.168),
            try! UnitDefinition(id: "mile", name: "Mile", category: .length, baseUnit: "meter", kind: .normal, factor: 1609.344),
            try! UnitDefinition(id: "league", name: "League", category: .length, baseUnit: "meter", kind: .normal, factor: 4828.032),
            try! UnitDefinition(id: "nautical_mile", name: "Nautical mile", category: .length, baseUnit: "meter", kind: .normal, factor: 1852),

            // Human-scale historical
            try! UnitDefinition(id: "hand", name: "Hand", category: .length, baseUnit: "meter", kind: .normal, factor: 0.1016),
            try! UnitDefinition(id: "cubit", name: "Cubit", category: .length, baseUnit: "meter", kind: .normal, factor: 0.4572),
            try! UnitDefinition(id: "pace", name: "Pace", category: .length, baseUnit: "meter", kind: .normal, factor: 0.762),

            // Astronomy
            try! UnitDefinition(id: "light_second", name: "Light-second", category: .length, baseUnit: "meter", kind: .normal, factor: 299792458),
            try! UnitDefinition(id: "astronomical_unit", name: "Astronomical unit", category: .length, baseUnit: "meter", kind: .normal, factor: 1.495978707e+11),
            try! UnitDefinition(id: "light_year", name: "Light-year", category: .length, baseUnit: "meter", kind: .normal, factor: 9.4607304725808e+15),
            try! UnitDefinition(id: "parsec", name: "Parsec", category: .length, baseUnit: "meter", kind: .normal, factor: 3.085677581e+16)
        ]
    }

    public static var mass: [UnitDefinition] {
        [
            try! UnitDefinition(id: "kilogram", name: "Kilogram", category: .mass, baseUnit: "kilogram", kind: .normal, factor: 1),
            try! UnitDefinition(id: "gram", name: "Gram", category: .mass, baseUnit: "kilogram", kind: .normal, factor: 0.001),
            try! UnitDefinition(id: "milligram", name: "Milligram", category: .mass, baseUnit: "kilogram", kind: .normal, factor: 0.000001),
            try! UnitDefinition(id: "pound", name: "Pound", category: .mass, baseUnit: "kilogram", kind: .normal, factor: 0.45359237),
            try! UnitDefinition(id: "ounce", name: "Ounce", category: .mass, baseUnit: "kilogram", kind: .normal, factor: 0.028349523125)
        ]
    }

    public static var time: [UnitDefinition] {
        [
            try! UnitDefinition(id: "second", name: "Second", category: .time, baseUnit: "second", kind: .normal, factor: 1),
            try! UnitDefinition(id: "minute", name: "Minute", category: .time, baseUnit: "second", kind: .normal, factor: 60),
            try! UnitDefinition(id: "hour", name: "Hour", category: .time, baseUnit: "second", kind: .normal, factor: 3600),
            try! UnitDefinition(id: "day", name: "Day", category: .time, baseUnit: "second", kind: .normal, factor: 86400)
        ]
    }

    public static var volume: [UnitDefinition] {
        [
            try! UnitDefinition(id: "liter", name: "Liter", category: .volume, baseUnit: "liter", kind: .normal, factor: 1),
            try! UnitDefinition(id: "milliliter", name: "Milliliter", category: .volume, baseUnit: "liter", kind: .normal, factor: 0.001),
            try! UnitDefinition(id: "cubic_meter", name: "Cubic meter", category: .volume, baseUnit: "liter", kind: .normal, factor: 1000),
            try! UnitDefinition(id: "gallon_us", name: "US gallon", category: .volume, baseUnit: "liter", kind: .normal, factor: 3.785411784),
            try! UnitDefinition(id: "quart_us", name: "US quart", category: .volume, baseUnit: "liter", kind: .normal, factor: 0.946352946),
            try! UnitDefinition(id: "pint_us", name: "US pint", category: .volume, baseUnit: "liter", kind: .normal, factor: 0.473176473),
            try! UnitDefinition(id: "cup_us", name: "US cup", category: .volume, baseUnit: "liter", kind: .normal, factor: 0.2365882365)
        ]
    }

    public static var temperature: [UnitDefinition] {
        [
            try! UnitDefinition(
                id: TemperatureUnit.celsius.unitID,
                name: "Celsius",
                category: .temperature,
                baseUnit: "kelvin",
                kind: .normal,
                conversionStyle: .temperature
            ),
            try! UnitDefinition(
                id: TemperatureUnit.fahrenheit.unitID,
                name: "Fahrenheit",
                category: .temperature,
                baseUnit: "kelvin",
                kind: .normal,
                conversionStyle: .temperature
            ),
            try! UnitDefinition(
                id: TemperatureUnit.kelvin.unitID,
                name: "Kelvin",
                category: .temperature,
                baseUnit: "kelvin",
                kind: .normal,
                conversionStyle: .temperature
            )
        ]
    }
}

