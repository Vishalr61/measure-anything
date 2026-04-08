import Foundation

/// Pure conversion engine. No UI or persistence dependencies.
public struct ConverterEngine: Sendable {
    public enum EngineError: Error, LocalizedError, Equatable {
        case categoryMismatch(from: UnitCategory, to: UnitCategory)
        case unsupportedConversionStyle(ConversionStyle)
        case unsupportedTemperatureUnitID(String)

        public var errorDescription: String? {
            switch self {
            case .categoryMismatch(let from, let to):
                "Cannot convert across categories (\(from.rawValue) -> \(to.rawValue))."
            case .unsupportedConversionStyle(let style):
                "Unsupported conversion style: \(style)"
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

        switch fromUnit.conversionStyle {
        case .multiplicative:
            guard toUnit.conversionStyle == .multiplicative else {
                throw EngineError.unsupportedConversionStyle(toUnit.conversionStyle)
            }
            let base = inputValue * (fromUnit.factor ?? 1)
            let output = base / (toUnit.factor ?? 1)
            return ConversionResult(
                category: fromUnit.category,
                inputValue: inputValue,
                fromUnitID: fromUnit.id,
                toUnitID: toUnit.id,
                baseValue: base,
                outputValue: output,
                memeExplanation: includeMemeExplanation ? (toUnit.exampleMeme ?? fromUnit.exampleMeme) : nil
            )

        case .temperature:
            guard toUnit.conversionStyle == .temperature else {
                throw EngineError.unsupportedConversionStyle(toUnit.conversionStyle)
            }
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
                memeExplanation: includeMemeExplanation ? (toUnit.exampleMeme ?? fromUnit.exampleMeme) : nil
            )
        }
    }
}

