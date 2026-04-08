import Foundation

/// The output of a conversion request, intentionally UI-agnostic and test-friendly.
public struct ConversionResult: Equatable, Hashable, Sendable {
    public let category: UnitCategory

    public let inputValue: Double
    public let fromUnitID: String
    public let toUnitID: String

    /// Value expressed in the category's canonical base unit.
    ///
    /// For temperature, this is expected to be Kelvin.
    public let baseValue: Double
    public let outputValue: Double

    /// Deterministic optional explanation line (e.g., from `UnitDefinition.exampleMeme`).
    public let memeExplanation: String?

    public init(
        category: UnitCategory,
        inputValue: Double,
        fromUnitID: String,
        toUnitID: String,
        baseValue: Double,
        outputValue: Double,
        memeExplanation: String? = nil
    ) {
        self.category = category
        self.inputValue = inputValue
        self.fromUnitID = fromUnitID
        self.toUnitID = toUnitID
        self.baseValue = baseValue
        self.outputValue = outputValue
        self.memeExplanation = memeExplanation
    }
}

