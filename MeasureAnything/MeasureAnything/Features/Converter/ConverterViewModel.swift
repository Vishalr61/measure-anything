import Combine
import Foundation
import MeasureAnythingCore

@MainActor
final class ConverterViewModel: ObservableObject {
    // Inputs (owned by VM)
    @Published var selectedCategory: UnitCategory = .length {
        didSet { handleCategoryOrModeChanged() }
    }
    @Published var selectedMode: UnitRegistry.Mode = .normal {
        didSet { handleCategoryOrModeChanged() }
    }
    @Published var inputText: String = "1" {
        didSet { recompute() }
    }
    @Published var selectedFromUnitID: UnitDefinition.ID = "meter" {
        didSet { recompute() }
    }
    @Published var selectedToUnitID: UnitDefinition.ID = "kilometer" {
        didSet { recompute() }
    }
    @Published var isMemeExplanationEnabled: Bool = false {
        didSet { recompute() }
    }

    // Outputs
    @Published private(set) var conversionResult: ConversionResult?
    @Published private(set) var validationError: String?

    // Engine
    private let registry: UnitRegistry
    private let engine: ConverterEngine

    init() {
        // Prefer full registry (normal + absurd). If resources fail to load,
        // fall back to normal-only so the app remains usable.
        let loadedRegistry: UnitRegistry
        do {
            loadedRegistry = try UnitRegistry.v1Default()
        } catch {
            loadedRegistry = (try? UnitRegistry(units: SeedNormalUnits.all)) ?? (try! UnitRegistry(units: []))
        }

        self.registry = loadedRegistry
        self.engine = ConverterEngine(registry: loadedRegistry)

        // Ensure safe defaults for initial category/mode
        applyDefaultsForCurrentCategory()
        recompute()
    }

    var categories: [UnitCategory] { UnitCategory.allCases }
    var modes: [UnitRegistry.Mode] { UnitRegistry.Mode.allCases }

    var availableUnits: [UnitDefinition] {
        registry.units(in: selectedCategory, includeKinds: selectedMode.includedKinds)
    }

    var fromUnit: UnitDefinition? { try? registry.unit(id: selectedFromUnitID) }
    var toUnit: UnitDefinition? { try? registry.unit(id: selectedToUnitID) }

    func swapUnits() {
        let tmp = selectedFromUnitID
        selectedFromUnitID = selectedToUnitID
        selectedToUnitID = tmp
    }

    // MARK: - Internal

    private func handleCategoryOrModeChanged() {
        // If the current selection becomes incompatible, reset to safe defaults.
        let validIDs = Set(availableUnits.map(\.id))
        if !validIDs.contains(selectedFromUnitID) || !validIDs.contains(selectedToUnitID) {
            applyDefaultsForCurrentCategory()
        } else {
            // Keep selections but recompute result because the mode might have changed
            recompute()
        }
    }

    private func applyDefaultsForCurrentCategory() {
        let units = availableUnits

        // Prefer canonical base unit as "from", and a sensible second unit as "to".
        if let baseID = selectedCategory.canonicalBaseUnit,
           units.contains(where: { $0.id == baseID }) {
            selectedFromUnitID = baseID
        } else {
            selectedFromUnitID = units.first?.id ?? selectedFromUnitID
        }

        selectedToUnitID = defaultToUnitID(for: selectedCategory, from: selectedFromUnitID, units: units)
        recompute()
    }

    private func defaultToUnitID(for category: UnitCategory, from fromID: UnitDefinition.ID, units: [UnitDefinition]) -> UnitDefinition.ID {
        // App-launch requested defaults: length meter -> kilometer
        if category == .length, fromID == "meter", units.contains(where: { $0.id == "kilometer" }) {
            return "kilometer"
        }

        // Category-specific “nice” defaults when available.
        let preferred: [UnitCategory: UnitDefinition.ID] = [
            .mass: "pound",
            .time: "minute",
            .volume: "milliliter",
            .temperature: "fahrenheit"
        ]
        if let preferredID = preferred[category],
           preferredID != fromID,
           units.contains(where: { $0.id == preferredID }) {
            return preferredID
        }

        // Otherwise pick the first unit that isn’t the from-unit.
        return units.first(where: { $0.id != fromID })?.id ?? fromID
    }

    private func recompute() {
        validationError = nil
        conversionResult = nil

        guard let inputValue = Double(inputText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            validationError = "Enter a number."
            return
        }

        guard let toUnit else {
            validationError = "Pick a target unit."
            return
        }

        let includeMeme = isMemeExplanationEnabled && (toUnit.kind == .absurd)
        do {
            conversionResult = try engine.convert(
                inputValue,
                from: selectedFromUnitID,
                to: selectedToUnitID,
                includeMemeExplanation: includeMeme
            )
        } catch {
            validationError = "Conversion failed."
        }
    }

    func formatNumber(_ value: Double, maxFractionDigits: Int = 3) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = maxFractionDigits
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }
}
