import Foundation

/// Pure conversion engine. No UI or persistence dependencies.
public struct ConverterEngine: Sendable {
    public enum EngineError: Error, LocalizedError, Equatable {
        case categoryMismatch(from: UnitCategory, to: UnitCategory)
        case unsupportedConversionStyle(from: ConversionStyle, to: ConversionStyle)
        case unsupportedTemperatureUnitID(String)

        public var errorDescription: String? {
            switch self {
            case .categoryMismatch(let from, let to):
                "Cannot convert across categories (\(from.rawValue) -> \(to.rawValue))."
            case .unsupportedConversionStyle(let from, let to):
                "Unsupported conversion style pair (\(from.rawValue) -> \(to.rawValue))."
            case .unsupportedTemperatureUnitID(let id):
                "Unsupported temperature unit id: \(id)"
            }
        }
    }

    public let registry: UnitRegistry

    public init(registry: UnitRegistry) {
        self.registry = registry
    }

    public func convert(
        _ inputValue: Double,
        from fromUnitID: UnitDefinition.ID,
        to toUnitID: UnitDefinition.ID,
        includeMemeExplanation: Bool = false
    ) throws -> ConversionResult {
        let fromUnit = try registry.unit(id: fromUnitID)
        let toUnit = try registry.unit(id: toUnitID)

        guard fromUnit.category == toUnit.category else {
            throw EngineError.categoryMismatch(from: fromUnit.category, to: toUnit.category)
        }

        let meme = includeMemeExplanation ? (toUnit.exampleMeme ?? fromUnit.exampleMeme) : nil

        switch (fromUnit.conversionStyle, toUnit.conversionStyle) {
        case (.multiplicative, .multiplicative):
            let base = inputValue * (fromUnit.factor ?? 1)
            let output = base / (toUnit.factor ?? 1)
            return ConversionResult(
                category: fromUnit.category,
                inputValue: inputValue,
                fromUnitID: fromUnit.id,
                toUnitID: toUnit.id,
                baseValue: base,
                outputValue: output,
                memeExplanation: meme
            )

        case (.temperature, .temperature):
            guard
                let fromTemp = TemperatureUnit(rawValue: fromUnit.id),
                let toTemp = TemperatureUnit(rawValue: toUnit.id)
            else {
                throw EngineError.unsupportedTemperatureUnitID("\(fromUnit.id)->\(toUnit.id)")
            }
            let output = TemperatureConverter.convert(inputValue, from: fromTemp, to: toTemp)
            let base = TemperatureConverter.toKelvin(inputValue, from: fromTemp)
            return ConversionResult(
                category: .temperature,
                inputValue: inputValue,
                fromUnitID: fromUnit.id,
                toUnitID: toUnit.id,
                baseValue: base,
                outputValue: output,
                memeExplanation: meme
            )

        case (.temperatureAffine, .temperatureAffine):
            let k = try kelvin(affine: fromUnit, value: inputValue)
            let slopeTo = try affineSlope(toUnit)
            let output = (k - 273.15) / slopeTo
            return ConversionResult(
                category: .temperature,
                inputValue: inputValue,
                fromUnitID: fromUnit.id,
                toUnitID: toUnit.id,
                baseValue: k,
                outputValue: output,
                memeExplanation: meme
            )

        case (.temperatureAffine, .temperature):
            let k = try kelvin(affine: fromUnit, value: inputValue)
            guard let toTemp = TemperatureUnit(rawValue: toUnit.id) else {
                throw EngineError.unsupportedTemperatureUnitID("\(fromUnit.id)->\(toUnit.id)")
            }
            let output = TemperatureConverter.fromKelvin(k, to: toTemp)
            return ConversionResult(
                category: .temperature,
                inputValue: inputValue,
                fromUnitID: fromUnit.id,
                toUnitID: toUnit.id,
                baseValue: k,
                outputValue: output,
                memeExplanation: meme
            )

        case (.temperature, .temperatureAffine):
            guard let fromTemp = TemperatureUnit(rawValue: fromUnit.id) else {
                throw EngineError.unsupportedTemperatureUnitID("\(fromUnit.id)->\(toUnit.id)")
            }
            let k = TemperatureConverter.toKelvin(inputValue, from: fromTemp)
            let slopeTo = try affineSlope(toUnit)
            let output = (k - 273.15) / slopeTo
            return ConversionResult(
                category: .temperature,
                inputValue: inputValue,
                fromUnitID: fromUnit.id,
                toUnitID: toUnit.id,
                baseValue: k,
                outputValue: output,
                memeExplanation: meme
            )

        case let (fromStyle, toStyle):
            throw EngineError.unsupportedConversionStyle(from: fromStyle, to: toStyle)
        }
    }

    private func kelvin(affine unit: UnitDefinition, value: Double) throws -> Double {
        let slope = try affineSlope(unit)
        return 273.15 + slope * value
    }

    private func affineSlope(_ unit: UnitDefinition) throws -> Double {
        guard let f = unit.factor, f != 0 else {
            throw EngineError.unsupportedTemperatureUnitID(unit.id)
        }
        return f
    }
}
