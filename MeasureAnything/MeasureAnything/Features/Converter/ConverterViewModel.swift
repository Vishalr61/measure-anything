import Combine
import CoreGraphics
import Foundation
import SwiftUI
import UIKit
import MeasureAnythingCore

@MainActor
final class ConverterViewModel: ObservableObject {
    /// Skips category/mode defaulting and per-field `recompute` while applying a saved favorite.
    private var isApplyingFavoriteRestore = false

    @Published var selectedCategory: UnitCategory = .length {
        didSet {
            guard oldValue != selectedCategory else { return }
            guard !isApplyingFavoriteRestore else { return }
            applyDefaultsAfterCategoryChange()
            syncDiceTiltToCategory(animated: true)
        }
    }

    @Published var selectedMode: UnitRegistry.Mode = .normal {
        didSet {
            guard oldValue != selectedMode else { return }
            guard !isApplyingFavoriteRestore else { return }
            reconcileSelectionsAfterModeChange()
        }
    }

    @Published var inputText: String = "1" {
        didSet { recompute() }
    }

    @Published var selectedFromUnitID: UnitDefinition.ID = "meter" {
        didSet {
            guard !isApplyingFavoriteRestore else { return }
            recompute()
        }
    }

    @Published var selectedToUnitID: UnitDefinition.ID = "kilometer" {
        didSet {
            guard !isApplyingFavoriteRestore else { return }
            recompute()
        }
    }

    @Published var isMemeExplanationEnabled: Bool = false {
        didSet { recompute() }
    }

    @Published private(set) var conversionResult: ConversionResult?
    @Published private(set) var validationError: String?

    // MARK: - Dice roll (Absurd-mode TO randomiser)

    @Published var isDiceRolling: Bool = false
    @Published var diceDisplayFace: Int = 5
    @Published var diceRotationDegrees: Double = UnitCategory.length.converterDiceRestDegrees
    @Published var showDiceSubtitle: Bool = false
    @Published var diceLandedUnitName: String = ""

    private var diceFlashTimer: Timer?
    private var diceRollToken: UUID = UUID()

    private func syncDiceTiltToCategory(animated: Bool) {
        let rest = selectedCategory.converterDiceRestDegrees
        if animated {
            withAnimation(.easeOut(duration: 0.22)) {
                diceRotationDegrees = rest
            }
        } else {
            diceRotationDegrees = rest
        }
    }

    private var registry: UnitRegistry
    private var engine: ConverterEngine
    private let taxonomy: AppTaxonomyStore

    private let displayFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = .current
        f.usesGroupingSeparator = true
        f.roundingMode = .halfUp
        f.minimumFractionDigits = 0
        return f
    }()

    init(taxonomy: AppTaxonomyStore) {
        self.taxonomy = taxonomy
        let pair = Self.makeRegistry(customUnits: [])
        self.registry = pair.registry
        self.engine = pair.engine
        taxonomy.attachUnitCatalog(pair.registry.allUnits)
        let cats = taxonomy.converterCategories
        if !cats.isEmpty, !cats.contains(selectedCategory) {
            selectedCategory = cats[0]
        }
        let modes = taxonomy.converterModes
        if !modes.isEmpty, !modes.contains(selectedMode) {
            selectedMode = modes[0]
        }
        applyDefaultsAfterCategoryChange()
        syncDiceTiltToCategory(animated: false)
        recompute()
    }

    /// Rebuilds engine + registry when SwiftData custom rows change.
    func sync(customUnits: [CustomUnit]) {
        let pair = Self.makeRegistry(customUnits: customUnits)
        registry = pair.registry
        engine = pair.engine
        taxonomy.attachUnitCatalog(pair.registry.allUnits)
        reconcileSelectionsAfterModeChange()
        recompute()
    }

    private static func makeRegistry(customUnits: [CustomUnit]) -> (registry: UnitRegistry, engine: ConverterEngine) {
        let defs = customUnits.compactMap { try? $0.toUnitDefinition() }
        do {
            let reg = try UnitRegistry.v1Default(customUnits: defs)
            return (reg, ConverterEngine(registry: reg))
        } catch {
            let fallback = (try? UnitRegistry.v1Default()) ?? (try! UnitRegistry(units: SeedNormalUnits.all))
            return (fallback, ConverterEngine(registry: fallback))
        }
    }

    var categories: [UnitCategory] { taxonomy.converterCategories }
    var modes: [UnitRegistry.Mode] { taxonomy.converterModes }

    var availableUnits: [UnitDefinition] {
        registry.units(in: selectedCategory, includeKinds: selectedMode.includedKinds)
    }

    var fromUnit: UnitDefinition? { try? registry.unit(id: selectedFromUnitID) }
    var toUnit: UnitDefinition? { try? registry.unit(id: selectedToUnitID) }

    /// Exposed for favorites UI (read-only snapshot of the live registry).
    var currentRegistry: UnitRegistry { registry }

    func swapUnits() {
        let tmp = selectedFromUnitID
        selectedFromUnitID = selectedToUnitID
        selectedToUnitID = tmp
    }

    func rollDice() {
        // Make dice roll interruptible so the user can spam taps.
        diceRollToken = UUID()
        let token = diceRollToken
        diceFlashTimer?.invalidate()
        diceFlashTimer = nil

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        isDiceRolling = true
        // Fade out subtitle instantly (no animation).
        showDiceSubtitle = false
        diceLandedUnitName = ""

        // Pre-select outcome before animation starts.
        let newFace = Int.random(in: 1...6)
        let pool = diceToUnitPool()
        let newUnit: UnitDefinition? = {
            guard !pool.isEmpty else { return nil }
            let candidates = pool.filter { $0.id != selectedToUnitID }
            return (candidates.isEmpty ? pool : candidates).randomElement()
        }()

        let rest = selectedCategory.converterDiceRestDegrees
        // Snap to category rest angle, then spin two full turns from there.
        withAnimation(.linear(duration: 0)) {
            diceRotationDegrees = rest
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) {
            MainActor.assumeIsolated {
                guard self.diceRollToken == token else { return }
                withAnimation(.interpolatingSpring(mass: 1, stiffness: 80, damping: 14, initialVelocity: 8)) {
                    self.diceRotationDegrees = rest + 720
                }
            }
        }

        // Flash loop.
        var flashCount = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { t in
            MainActor.assumeIsolated {
                guard self.diceRollToken == token else {
                    t.invalidate()
                    return
                }
                self.diceDisplayFace = Int.random(in: 1...6)
                flashCount += 1
                if flashCount >= 9 { t.invalidate() }
            }
        }
        diceFlashTimer = timer

        // Land.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            MainActor.assumeIsolated {
                guard self.diceRollToken == token else { return }
                timer.invalidate()
                if self.diceFlashTimer === timer {
                    self.diceFlashTimer = nil
                }
                self.diceDisplayFace = newFace

                if let u = newUnit {
                    self.selectedToUnitID = u.id
                    self.diceLandedUnitName = u.name
                } else {
                    self.diceLandedUnitName = ""
                }

                withAnimation(.easeIn(duration: 0.25)) {
                    self.showDiceSubtitle = (self.diceLandedUnitName.isEmpty == false)
                }
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.success)
                self.isDiceRolling = false
            }
        }
    }

    /// Randomly chooses both `selectedFromUnitID` and `selectedToUnitID` from `availableUnits`.
    /// Keeps them distinct and stays within the current category + mode set.
    func randomizeUnitPair() {
        let units = availableUnits
        guard units.count >= 2 else { return }

        guard let from = units.randomElement() else { return }
        let toCandidates = units.filter { $0.id != from.id }
        guard let to = toCandidates.randomElement() else { return }

        selectedFromUnitID = from.id
        selectedToUnitID = to.id
    }

    /// `false` when there are fewer than two units available in the current category/mode.
    var canRandomizeUnitPair: Bool {
        availableUnits.count >= 2
    }

    private func diceToUnitPool() -> [UnitDefinition] {
        // In normal mode: keep it within the current mode's available units.
        if selectedMode == .normal {
            return availableUnits
        }

        // In absurd/custom: prefer "true absurd" units scoped to the current category (not comparators/custom).
        let absurdOnly = registry.units(in: selectedCategory, includeKinds: [.absurd])
        if !absurdOnly.isEmpty { return absurdOnly }

        // Fallback: use any absurd units already present in the current mode's list.
        let fromAvailable = availableUnits.filter { $0.kind == .absurd }
        if !fromAvailable.isEmpty { return fromAvailable }

        return availableUnits
    }

    /// Whether the current from/to pair can be stored as a favorite (pair metadata only).
    var canSaveCurrentPairAsFavorite: Bool {
        guard selectedFromUnitID != selectedToUnitID else { return false }
        guard let f = fromUnit, let t = toUnit else { return false }
        return f.category == selectedCategory && t.category == selectedCategory
    }

    /// Restores category, mode, and unit IDs when both units still exist in the registry.
    func applyFavoriteRestore(categoryRaw: String, fromID: String, toID: String) {
        guard let category = UnitCategory(rawValue: categoryRaw) else { return }
        guard let mode = FavoriteConversion.minimumMode(registry: registry, category: category, fromID: fromID, toID: toID) else { return }
        isApplyingFavoriteRestore = true
        selectedCategory = category
        selectedMode = mode
        selectedFromUnitID = fromID
        selectedToUnitID = toID
        isApplyingFavoriteRestore = false
        reconcileSelectionsAfterModeChange()
        syncDiceTiltToCategory(animated: true)
        recompute()
    }

    /// Applies taxonomy search selection: category/mode from taxonomy JSON, optional `converterUnitId` when that unit exists for the current registry.
    func applyTaxonomyRoute(_ route: TaxonomyConverterRoute) {
        guard route.hasAnyResolvableInput else { return }
        isApplyingFavoriteRestore = true
        defer {
            isApplyingFavoriteRestore = false
            reconcileSelectionsAfterModeChange()
            syncDiceTiltToCategory(animated: true)
            recompute()
        }

        var targetCategory = route.category
        if targetCategory == nil, let uid = route.preferredFromUnitId, let def = try? registry.unit(id: uid) {
            targetCategory = def.category
        }
        if let c = targetCategory {
            selectedCategory = c
        }

        var targetMode = route.mode
        if targetMode == nil, let uid = route.preferredFromUnitId {
            let cat = targetCategory ?? selectedCategory
            targetMode = inferredModeSupportingUnit(category: cat, unitId: uid)
        }
        if let m = targetMode {
            selectedMode = m
        }

        let units = registry.units(in: selectedCategory, includeKinds: selectedMode.includedKinds)
        if let uid = route.preferredFromUnitId, units.contains(where: { $0.id == uid }) {
            selectedFromUnitID = uid
            selectedToUnitID = firstDistinctToUnit(from: uid, in: units)
        } else {
            applyDefaultsAfterCategoryChange()
        }
        let refreshed = registry.units(in: selectedCategory, includeKinds: selectedMode.includedKinds)
        ensureDistinctFromTo(in: refreshed)
    }

    private func inferredModeSupportingUnit(category: UnitCategory, unitId: String) -> UnitRegistry.Mode? {
        for mode in taxonomy.converterModes {
            let list = registry.units(in: category, includeKinds: mode.includedKinds)
            if list.contains(where: { $0.id == unitId }) {
                return mode
            }
        }
        return nil
    }

    // MARK: - Defaults & selection safety

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

    // MARK: - Parsing & conversion

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

        return f.string(from: NSNumber(value: value)) ?? String(format: "%g", value)
    }

    var formattedResult: String {
        guard let r = conversionResult else { return "—" }
        return formatNumberForDisplay(r.outputValue)
    }
}
