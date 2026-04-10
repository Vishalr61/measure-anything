import Combine
import Foundation
import MeasureAnythingCore

@MainActor
final class ConverterViewModel: ObservableObject {
    @Published var selectedCategory: UnitCategory = .length {
        didSet {
            guard oldValue != selectedCategory else { return }
            applyDefaultsAfterCategoryChange()
        }
    }

    @Published var selectedMode: UnitRegistry.Mode = .normal {
        didSet {
            guard oldValue != selectedMode else { return }
            reconcileSelectionsAfterModeChange()
        }
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

    @Published private(set) var conversionResult: ConversionResult?
    @Published private(set) var validationError: String?

    private let registry: UnitRegistry
    private let engine: ConverterEngine

    private let displayFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        f.usesGroupingSeparator = true
        f.roundingMode = .halfUp
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 6
        return f
    }()

    private static let displayFallbackLocale = Locale(identifier: "en_US")

    init() {
        let loadedRegistry: UnitRegistry
        do {
            loadedRegistry = try UnitRegistry.v1Default()
        } catch {
            loadedRegistry = (try? UnitRegistry(units: SeedNormalUnits.all)) ?? (try! UnitRegistry(units: []))
        }

        self.registry = loadedRegistry
        self.engine = ConverterEngine(registry: loadedRegistry)

        applyDefaultsAfterCategoryChange()
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

    private func preferredDefaultPair(for category: UnitCategory) -> (from: UnitDefinition.ID, to: UnitDefinition.ID) {
        switch category {
        case .length: ("meter", "kilometer")
        case .mass: ("kilogram", "pound")
        case .time: ("hour", "minute")
        case .volume: ("liter", "milliliter")
        case .temperature: ("celsius", "fahrenheit")
        }
    }

    private func applyDefaultsAfterCategoryChange() {
        let units = availableUnits
        guard !units.isEmpty else {
            validationError = "No units for this category and mode."
            conversionResult = nil
            return
        }

        let ids = Set(units.map(\.id))
        let preferred = preferredDefaultPair(for: selectedCategory)

        if ids.contains(preferred.from), ids.contains(preferred.to) {
            selectedFromUnitID = preferred.from
            selectedToUnitID = preferred.to
        } else if let base = selectedCategory.canonicalBaseUnit, ids.contains(base) {
            selectedFromUnitID = base
            selectedToUnitID = firstDistinctToUnit(from: base, in: units)
        } else {
            selectedFromUnitID = units[0].id
            selectedToUnitID = firstDistinctToUnit(from: units[0].id, in: units)
        }

        ensureDistinctFromTo(in: units)
        recompute()
    }

    private func reconcileSelectionsAfterModeChange() {
        let units = availableUnits
        guard !units.isEmpty else {
            validationError = "No units for this category and mode."
            conversionResult = nil
            return
        }

        let ids = Set(units.map(\.id))
        let fromOK = ids.contains(selectedFromUnitID)
        let toOK = ids.contains(selectedToUnitID)

        if fromOK, toOK {
            ensureDistinctFromTo(in: units)
            recompute()
            return
        }

        applyDefaultsAfterCategoryChange()
    }

    private func firstDistinctToUnit(from fromID: UnitDefinition.ID, in units: [UnitDefinition]) -> UnitDefinition.ID {
        if let other = units.first(where: { $0.id != fromID }) {
            return other.id
        }
        return fromID
    }

    private func ensureDistinctFromTo(in units: [UnitDefinition]) {
        guard units.count > 1, selectedFromUnitID == selectedToUnitID else { return }
        selectedToUnitID = firstDistinctToUnit(from: selectedFromUnitID, in: units)
    }

    private func parsedInput() -> Double? {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    private func recompute() {
        validationError = nil
        conversionResult = nil

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            validationError = "Enter a number."
            return
        }

        guard let inputValue = parsedInput() else {
            validationError = "That doesn’t look like a valid number."
            return
        }

        guard let fromUnit, let toUnit else {
            validationError = "Pick units to convert."
            return
        }

        guard fromUnit.category == selectedCategory, toUnit.category == selectedCategory else {
            validationError = "Units don’t match the selected category."
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
            validationError = "Conversion couldn’t be completed."
        }
    }

    func formatNumberForDisplay(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        if value == 0 { return "0" }

        let magnitude = abs(value)
        let f = displayFormatter

        switch magnitude {
        case let m where m >= 10_000_000:
            f.maximumFractionDigits = 2
            f.minimumFractionDigits = 0
        case let m where m >= 1:
            f.maximumFractionDigits = magnitude < 10 ? 3 : 2
            f.minimumFractionDigits = 0
        case let m where m >= 0.0001:
            f.maximumFractionDigits = 4
            f.minimumFractionDigits = 0
        default:
            f.maximumFractionDigits = 6
            f.minimumFractionDigits = 0
        }

        if let s = f.string(from: NSNumber(value: value)) {
            return s
        }
        return String(format: "%g", locale: Self.displayFallbackLocale, value)
    }
}
