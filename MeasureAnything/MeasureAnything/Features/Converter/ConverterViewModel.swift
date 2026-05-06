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
    /// Skips reactive defaults / `recompute` while restoring `UserDefaults` session in `init`.
    private var isRestoringSession = false
    /// Skips `selectedFromUnitID` / `selectedToUnitID` `didSet` → `recompute` while batching ID fixes (avoids re-entrancy).
    private var isSanitisingSelections = false
    /// While rebuilding registry from SwiftData, skip persisting “conversions” into `ConversionHistory`.
    private var isSyncingCustomUnitsCatalog = false
    private var sessionPersistenceEnabled = false

    private enum SessionKeys {
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let sessionCategory = "session.category"
        static let sessionFrom = "session.fromUnit"
        static let sessionTo = "session.toUnit"
        static let sessionMode = "session.mode"
        static let sessionInput = "session.inputValue"
        static let hasUsedLongPressRoll = "hasUsedLongPressRoll"
    }

    private static let precisionModeKey = "precisionModeEnabled"

    @Published var selectedCategory: UnitCategory = .length {
        didSet {
            guard oldValue != selectedCategory else { return }
            guard !isApplyingFavoriteRestore, !isRestoringSession else { return }
            applyDefaultsAfterCategoryChange()
            syncDiceTiltToCategory(animated: true)
        }
    }

    @Published var selectedMode: UnitRegistry.Mode = .normal {
        didSet {
            guard oldValue != selectedMode else { return }
            guard !isApplyingFavoriteRestore, !isRestoringSession else { return }
            reconcileSelectionsAfterModeChange()
        }
    }

    @Published var inputText: String = "1" {
        didSet {
            guard !isRestoringSession, !isApplyingFavoriteRestore else { return }
            recompute()
        }
    }

    private var inputEditSnapshot: String?

    func captureInputEditSnapshot() {
        if inputEditSnapshot == nil {
            inputEditSnapshot = inputText
        }
    }

    func restoreInputEditSnapshot() {
        if let snapshot = inputEditSnapshot {
            inputText = snapshot
        }
        inputEditSnapshot = nil
    }

    func clearInputEditSnapshot() {
        inputEditSnapshot = nil
    }

    @Published var selectedFromUnitID: UnitDefinition.ID = "meter" {
        didSet {
            guard !isApplyingFavoriteRestore, !isRestoringSession, !isSanitisingSelections else { return }
            recompute()
        }
    }

    @Published var selectedToUnitID: UnitDefinition.ID = "kilometer" {
        didSet {
            guard !isApplyingFavoriteRestore, !isRestoringSession, !isSanitisingSelections else { return }
            recompute()
        }
    }

    @Published var isMemeExplanationEnabled: Bool = false {
        didSet { recompute() }
    }

    /// When `true`, `formatNumberForDisplay` uses full decimal output (no smart shorthand / scientific).
    /// Default `false` is stored; missing key in UserDefaults is treated as off.
    @Published var precisionModeEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(precisionModeEnabled, forKey: Self.precisionModeKey)
        }
    }

    @Published private(set) var conversionResult: ConversionResult?
    @Published private(set) var validationError: String?

    // MARK: - Dice roll (random TO unit; long-press randomises both absurd units)

    @Published var isChaosMode: Bool = false
    @Published var isDiceRolling: Bool = false
    @Published var diceDisplayFace: Int = 5
    @Published var diceRotationDegrees: Double = UnitCategory.length.converterDiceRestDegrees
    @Published var showDiceSubtitle: Bool = false
    @Published var diceLandedUnitName: String = ""
    /// When `true`, `diceLandedUnitName` is the full subtitle (dual roll). When `false`, prefix `"landed on "` is shown before the name.
    @Published var diceSubtitleIsDualFormat: Bool = false
    // Long-press discoverability hint is driven by `DiceRollCard` + UserDefaults.
    /// Incremented when the user shakes the device so `DiceRollCard` can run the same path as a single tap (animations + `rollDice()`).
    @Published private(set) var shakeSingleRollRequest: UInt = 0

    private var diceFlashTimer: Timer?
    private var diceLongPressHintDismissWorkItem: DispatchWorkItem?
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

    private static let displayFallbackLocale = Locale(identifier: "en_US")

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

        sessionPersistenceEnabled = false
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: SessionKeys.hasLaunchedBefore)
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: SessionKeys.hasLaunchedBefore)
        }

        isRestoringSession = true
        let restored = performSessionRestore()
        isRestoringSession = false

        if !restored {
            if isFirstLaunch {
                applyRegionalDefaultPair()
            } else {
                applyDefaultsAfterCategoryChange()
            }
        }

        syncDiceTiltToCategory(animated: false)
        sessionPersistenceEnabled = true
        precisionModeEnabled = UserDefaults.standard.bool(forKey: Self.precisionModeKey)
        saveSession()
    }

    /// Rebuilds engine + registry when SwiftData custom rows change.
    func sync(customUnits: [CustomUnit]) {
        isSyncingCustomUnitsCatalog = true
        defer { isSyncingCustomUnitsCatalog = false }

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

    private var converterIncludeKinds: Set<UnitKind> { UnitRegistry.allKinds }

    var availableUnits: [UnitDefinition] {
        registry.units(in: selectedCategory, includeKinds: converterIncludeKinds)
    }

    func exploreUnitDefinitions(for category: UnitCategory) -> [UnitDefinition] {
        registry.units(in: category, includeKinds: converterIncludeKinds)
    }

    func units(for category: UnitCategory, mode: UnitRegistry.Mode) -> [UnitDefinition] {
        registry.units(in: category, includeKinds: mode.includedKinds)
    }

    var fromUnit: UnitDefinition? { try? registry.unit(id: selectedFromUnitID) }
    var toUnit: UnitDefinition? { try? registry.unit(id: selectedToUnitID) }

    // MARK: - Session persistence

    private func saveSession() {
        guard sessionPersistenceEnabled else { return }
        let d = UserDefaults.standard
        d.set(selectedCategory.rawValue, forKey: SessionKeys.sessionCategory)
        d.set(selectedFromUnitID, forKey: SessionKeys.sessionFrom)
        d.set(selectedToUnitID, forKey: SessionKeys.sessionTo)
        d.set(selectedMode.rawValue, forKey: SessionKeys.sessionMode)
        d.set(inputText, forKey: SessionKeys.sessionInput)
    }

    /// Restores category, units, mode, and input when session keys exist. Returns whether any session row was applied.
    private func performSessionRestore() -> Bool {
        let d = UserDefaults.standard
        guard let catRaw = d.string(forKey: SessionKeys.sessionCategory),
              let cat = UnitCategory(rawValue: catRaw),
              categories.contains(cat) else { return false }

        selectedCategory = cat

        if let modeRaw = d.string(forKey: SessionKeys.sessionMode),
           let mode = UnitRegistry.Mode(rawValue: modeRaw),
           modes.contains(mode) {
            selectedMode = mode
        }

        let units = registry.units(in: selectedCategory, includeKinds: converterIncludeKinds)
        let idSet = Set(units.map(\.id))

        if let from = d.string(forKey: SessionKeys.sessionFrom), idSet.contains(from) {
            selectedFromUnitID = from
        }
        if let to = d.string(forKey: SessionKeys.sessionTo), idSet.contains(to) {
            selectedToUnitID = to
        }
        if let saved = d.string(forKey: SessionKeys.sessionInput) {
            inputText = saved
        }

        if !idSet.contains(selectedFromUnitID) || !idSet.contains(selectedToUnitID) {
            applyDefaultsAfterCategoryChange()
        } else {
            ensureDistinctFromTo(in: availableUnits)
            recompute()
        }
        return true
    }

    private func applyRegionalDefaultPair() {
        let units = availableUnits
        guard !units.isEmpty else {
            validationError = "No units for this category and mode."
            conversionResult = nil
            return
        }

        let ids = Set(units.map(\.id))
        let pair = AppDefaults.defaultPair(for: selectedCategory)

        if ids.contains(pair.from), ids.contains(pair.to) {
            selectedFromUnitID = pair.from
            selectedToUnitID = pair.to
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

    var shouldShowLongPressDiscoverabilityHint: Bool {
        !UserDefaults.standard.bool(forKey: SessionKeys.hasUsedLongPressRoll)
    }

    func setHasUsedLongPressRoll() {
        UserDefaults.standard.set(true, forKey: SessionKeys.hasUsedLongPressRoll)
    }

    /// Exposed for favorites UI (read-only snapshot of the live registry).
    var currentRegistry: UnitRegistry { registry }

    func swapUnits() {
        let tmp = selectedFromUnitID
        selectedFromUnitID = selectedToUnitID
        selectedToUnitID = tmp
    }

    /// Called when the user shakes the device on the converter; `DiceRollCard` mirrors a single tap (including die UI).
    func requestSingleRollFromShake() {
        shakeSingleRollRequest &+= 1
    }

    func rollDice() {
        // Make dice roll interruptible so the user can spam taps.
        diceRollToken = UUID()
        let token = diceRollToken
        diceFlashTimer?.invalidate()
        diceFlashTimer = nil

        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        isDiceRolling = true
        // Fade out subtitle instantly (no animation).
        showDiceSubtitle = false
        diceLandedUnitName = ""
        diceSubtitleIsDualFormat = false

        // Pre-select outcome before animation starts.
        let newFace = Int.random(in: 1...6)
        let pool = diceToUnitPool()
        let newUnit: UnitDefinition? = {
            guard !pool.isEmpty else { return nil }
            // Never land on the same unit as FROM (and avoid repeating current TO when other options exist).
            let notFrom = pool.filter { $0.id != selectedFromUnitID }
            guard !notFrom.isEmpty else { return nil }
            let avoidTo = notFrom.filter { $0.id != selectedToUnitID }
            let candidates = avoidTo.isEmpty ? notFrom : avoidTo
            return Self.weightedRandomUnit(from: candidates)
        }()

        // Keep dice resting tilt stable; the dice face animation is decorative and handled in `DiceRollCard`.
        syncDiceTiltToCategory(animated: true)

        // Land.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            MainActor.assumeIsolated {
                guard self.diceRollToken == token else { return }
                self.diceDisplayFace = newFace

                // `newUnit` was chosen at roll start; mode/category may have changed since — never apply a stale ID.
                let allowed = Set(self.availableUnits.map(\.id))
                let resolvedTo: UnitDefinition? = {
                    if let u = newUnit,
                       u.category == self.selectedCategory,
                       allowed.contains(u.id),
                       u.id != self.selectedFromUnitID {
                        return u
                    }
                    let pool = self.diceToUnitPool().filter {
                        $0.category == self.selectedCategory && allowed.contains($0.id)
                    }
                    let candidates = pool.filter { $0.id != self.selectedFromUnitID }
                    return Self.weightedRandomUnit(from: candidates)
                }()

                if let u = resolvedTo {
                    self.selectedToUnitID = u.id
                    self.diceLandedUnitName = u.name
                    self.diceSubtitleIsDualFormat = false
                } else {
                    self.diceLandedUnitName = ""
                }

                withAnimation(.easeIn(duration: 0.25)) {
                    self.showDiceSubtitle = (self.diceLandedUnitName.isEmpty == false)
                }
                self.isDiceRolling = false
            }
        }
    }

    /// Long-press (~0.25s `minimumDuration` on `DiceRollCard`): randomises both FROM and TO to distinct absurd units in the current category.
    func rollDiceDual() {
        func absurdPoolForDual() -> [UnitDefinition] {
            registry.units(in: selectedCategory, includeKinds: [.absurd])
                .filter { $0.category == selectedCategory }
        }

        let pool = absurdPoolForDual()
        // Silent no-op: must not cancel an in-flight single roll or invalidate timers.
        guard pool.count >= 2 else { return }

        diceRollToken = UUID()
        let token = diceRollToken
        diceFlashTimer?.invalidate()
        diceFlashTimer = nil
        diceLongPressHintDismissWorkItem?.cancel()
        diceLongPressHintDismissWorkItem = nil

        isDiceRolling = true
        showDiceSubtitle = false
        diceLandedUnitName = ""
        diceSubtitleIsDualFormat = false
        inputText = "1"

        let newFace = Int.random(in: 1...6)
        let pickedFrom: UnitDefinition? = Self.weightedRandomUnit(from: pool)
        let pickedTo: UnitDefinition? = {
            guard let f = pickedFrom else { return nil }
            let rest = pool.filter { $0.id != f.id }
            return Self.weightedRandomUnit(from: rest)
        }()

        // Keep dice resting tilt stable; the dice face animation is decorative and handled in `DiceRollCard`.
        syncDiceTiltToCategory(animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            MainActor.assumeIsolated {
                guard self.diceRollToken == token else { return }
                self.diceDisplayFace = newFace

                let allowedAbsurd = absurdPoolForDual()
                guard allowedAbsurd.count >= 2 else {
                    self.isDiceRolling = false
                    return
                }

                let resolvedFrom: UnitDefinition? = {
                    if let f = pickedFrom,
                       f.category == self.selectedCategory,
                       allowedAbsurd.contains(where: { $0.id == f.id }) {
                        return f
                    }
                    return Self.weightedRandomUnit(from: allowedAbsurd)
                }()

                let resolvedTo: UnitDefinition? = {
                    guard let from = resolvedFrom else { return nil }
                    let candidates = allowedAbsurd.filter { $0.id != from.id }
                    if let t = pickedTo,
                       t.category == self.selectedCategory,
                       candidates.contains(where: { $0.id == t.id }) {
                        return t
                    }
                    return Self.weightedRandomUnit(from: candidates)
                }()

                if let from = resolvedFrom, let to = resolvedTo, from.id != to.id {
                    self.selectedFromUnitID = from.id
                    self.selectedToUnitID = to.id
                    self.diceSubtitleIsDualFormat = true
                    self.diceLandedUnitName = "rolled both — \(from.name) → \(to.name)"

                    // Haptics for long-press completion are driven by `DiceRollCard` when the hold completes.
                } else {
                    self.diceLandedUnitName = ""
                    self.diceSubtitleIsDualFormat = false
                }

                withAnimation(.easeIn(duration: 0.25)) {
                    self.showDiceSubtitle = !self.diceLandedUnitName.isEmpty
                }
                self.isDiceRolling = false
            }
        }
    }

    // MARK: – Chaos roll
    //
    // Pulls absurd units from EVERY category, picks a random FROM and TO,
    // switches the converter's selectedCategory to match, and labels the
    // result with a "CATEGORY · fromName ⇄ toName" subtitle. Used by the
    // dice card when isChaosMode is true.
    func rollDiceChaos() {
        // Pool: all absurd units across ALL categories
        func chaosPool() -> [UnitDefinition] {
            UnitCategory.allCases.flatMap { cat in
                registry.units(in: cat, includeKinds: [.absurd])
            }
        }

        let pool = chaosPool()
        guard pool.count >= 2 else { return }

        diceRollToken = UUID()
        let token = diceRollToken
        diceFlashTimer?.invalidate()
        diceFlashTimer = nil

        isDiceRolling = true
        showDiceSubtitle = false
        diceLandedUnitName = ""
        diceSubtitleIsDualFormat = false
        inputText = "1"

        // Pre-select outcome before animation
        let pickedFrom = Self.weightedRandomUnit(from: pool)
        let pickedTo: UnitDefinition? = {
            guard let f = pickedFrom else { return nil }
            let rest = pool.filter { $0.id != f.id }
            return Self.weightedRandomUnit(from: rest)
        }()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            MainActor.assumeIsolated {
                guard self.diceRollToken == token else { return }

                let freshPool = chaosPool()
                guard freshPool.count >= 2 else {
                    self.isDiceRolling = false
                    return
                }

                let resolvedFrom: UnitDefinition? = {
                    if let f = pickedFrom,
                       freshPool.contains(where: { $0.id == f.id }) {
                        return f
                    }
                    return Self.weightedRandomUnit(from: freshPool)
                }()

                let resolvedTo: UnitDefinition? = {
                    guard let from = resolvedFrom else { return nil }
                    let candidates = freshPool.filter { $0.id != from.id }
                    if let t = pickedTo,
                       candidates.contains(where: { $0.id == t.id }) {
                        return t
                    }
                    return Self.weightedRandomUnit(from: candidates)
                }()

                guard let from = resolvedFrom,
                      let to = resolvedTo,
                      from.id != to.id else {
                    self.isDiceRolling = false
                    return
                }

                // Switch category to match the landed FROM unit. Wrap with
                // isApplyingFavoriteRestore guard so the published-property
                // didSet observers don't fire reactive recompute mid-update.
                self.isApplyingFavoriteRestore = true
                self.selectedCategory = from.category
                self.selectedFromUnitID = from.id
                self.selectedToUnitID = to.id
                self.isApplyingFavoriteRestore = false
                self.syncDiceTiltToCategory(animated: true)
                self.recompute()

                // Edge case 8: if the user exited chaos mid-roll, don't
                // pollute the normal-mode badge with the chaos-format string.
                guard self.isChaosMode else {
                    self.isDiceRolling = false
                    return
                }

                // Build result label: "TEMP·Surface of Venus⇄Baked bread"
                let categoryPrefix = from.category.displayName.uppercased()
                self.diceLandedUnitName = "\(categoryPrefix)·\(from.name)⇄\(to.name)"
                self.diceSubtitleIsDualFormat = true

                withAnimation(.easeIn(duration: 0.25)) {
                    self.showDiceSubtitle = true
                }
                self.isDiceRolling = false

                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
        }
    }

    // Long-press discoverability hint logic is handled by `DiceRollCard`.

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
        func inSelectedCategory(_ u: UnitDefinition) -> Bool {
            u.category == selectedCategory
        }

        // Prefer absurd units in the *selected* category only (defense against stale registry edges).
        let absurdOnly = registry.units(in: selectedCategory, includeKinds: [.absurd]).filter(inSelectedCategory)
        if !absurdOnly.isEmpty { return absurdOnly }

        let fromAvailable = availableUnits.filter { inSelectedCategory($0) && $0.kind == .absurd }
        if !fromAvailable.isEmpty { return fromAvailable }

        return availableUnits.filter(inSelectedCategory)
    }

    /// Weighted pick for dice: `interestScore` (default 5) adds proportional weight; clamped to 1…10.
    private static func weightedRandomUnit(from candidates: [UnitDefinition]) -> UnitDefinition? {
        guard !candidates.isEmpty else { return nil }
        var weighted: [UnitDefinition] = []
        weighted.reserveCapacity(candidates.count * 10)
        for u in candidates {
            let raw = u.interestScore ?? 5
            let w = max(1, min(10, raw))
            for _ in 0..<w {
                weighted.append(u)
            }
        }
        return weighted.randomElement()
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

    /// Batch-applies a recently-used pair from the Explore page.
    func applyExplorePairSelection(
        category: UnitCategory,
        mode: UnitRegistry.Mode,
        fromID: String,
        toID: String
    ) {
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

    /// Explore “Try these”: pre-fill units with empty input, then record the pair in history (no conversion run).
    func applyTryThesePair(
        category: UnitCategory,
        mode: UnitRegistry.Mode,
        fromID: String,
        toID: String
    ) {
        isApplyingFavoriteRestore = true
        selectedCategory = category
        selectedMode = mode
        selectedFromUnitID = fromID
        selectedToUnitID = toID
        inputText = ""
        isApplyingFavoriteRestore = false
        reconcileSelectionsAfterModeChange()
        syncDiceTiltToCategory(animated: true)
        recompute()
        ConversionHistory.shared.record(from: fromID, to: toID, category: category)
        objectWillChange.send()
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

        if let recentFrom = ConversionHistory.shared.mostRecentFromUnit(in: selectedCategory),
           ids.contains(recentFrom) {
            selectedFromUnitID = recentFrom
            selectedToUnitID = firstDistinctToUnit(from: recentFrom, in: units)
        } else {
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

    /// Keeps from/to IDs inside the current category + mode list so menus and labels stay valid (e.g. after a delayed dice land or rapid mode toggles).
    private func sanitiseUnitSelectionsIfNeeded() {
        let units = availableUnits
        guard !units.isEmpty else { return }
        let ids = Set(units.map(\.id))
        let fromOK = ids.contains(selectedFromUnitID)
        let toOK = ids.contains(selectedToUnitID)
        guard !fromOK || !toOK else {
            ensureDistinctFromTo(in: units)
            return
        }

        isSanitisingSelections = true
        defer { isSanitisingSelections = false }

        if !fromOK {
            selectedFromUnitID = units[0].id
        }
        if !toOK {
            selectedToUnitID = firstDistinctToUnit(from: selectedFromUnitID, in: units)
        }
        ensureDistinctFromTo(in: units)
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
        sanitiseUnitSelectionsIfNeeded()

        validationError = nil
        conversionResult = nil
        defer {
            if sessionPersistenceEnabled {
                saveSession()
            }
        }

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
            if sessionPersistenceEnabled, !isSyncingCustomUnitsCatalog {
                ConversionHistory.shared.record(
                    from: selectedFromUnitID,
                    to: selectedToUnitID,
                    category: selectedCategory
                )
            }
        } catch {
            validationError = "Conversion couldn’t be completed."
        }
    }

    func formatNumberForDisplay(_ value: Double) -> String {
        guard !value.isNaN else { return "—" }
        guard value.isFinite else { return "—" }
        guard value != 0 else { return "0" }

        if precisionModeEnabled {
            return formatFullDecimalMagnitude(value)
        }

        let absValue = abs(value)
        // Smart: ordinary decimals in [0.001, 1_000_000) with up to 2 fraction digits + grouping;
        // otherwise scientific with ×10^ for attributed superscript styling.
        if absValue >= 0.001 && absValue < 1_000_000 {
            return formatDecimalCompact(value, maxFractionDigits: 2)
        }
        return formatScientificForDisplay(value)
    }

    /// Full decimal, grouped, up to 20 fraction digits, never scientific.
    private func formatFullDecimalMagnitude(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Self.displayFallbackLocale
        formatter.usesGroupingSeparator = true
        formatter.roundingMode = .halfUp
        formatter.maximumFractionDigits = 20
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value))
            ?? String(format: "%f", locale: Self.displayFallbackLocale, value)
    }

    /// Grouped decimal with a capped fraction width; `maximumFractionDigits` 2 for smart mode.
    private func formatDecimalCompact(_ value: Double, maxFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Self.displayFallbackLocale
        formatter.usesGroupingSeparator = true
        formatter.roundingMode = .halfUp
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value))
            ?? String(format: "%g", locale: Self.displayFallbackLocale, value)
    }

    /// Scientific string using `×10^` so `attributedAdaptiveNumber` can style the exponent.
    private func formatScientificForDisplay(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .scientific
        formatter.maximumSignificantDigits = 4
        formatter.minimumSignificantDigits = 1
        formatter.locale = Self.displayFallbackLocale
        if let raw = formatter.string(from: NSNumber(value: value)) {
            return raw
                .replacingOccurrences(of: "E", with: "×10^")
                .replacingOccurrences(of: "e", with: "×10^")
        }
        return String(format: "%g", locale: Self.displayFallbackLocale, value)
    }

    /// Main result line with optional superscript exponent when scientific notation is used.
    var formattedResultAttributed: AttributedString {
        guard validationError == nil, let r = conversionResult else { return AttributedString("—") }
        return Self.attributedAdaptiveNumber(formatNumberForDisplay(r.outputValue))
    }

    /// Converts `3.336×10^-9`-style output into an `AttributedString` with a raised exponent.
    static func attributedAdaptiveNumber(_ raw: String) -> AttributedString {
        guard raw.contains("×10^") else { return AttributedString(raw) }
        let parts = raw.components(separatedBy: "×10^")
        guard parts.count == 2 else { return AttributedString(raw) }

        var result = AttributedString(parts[0] + "×10")
        var exponent = AttributedString(parts[1])
        exponent.font = .system(size: 20, weight: .bold)
        exponent.baselineOffset = 10
        result.append(exponent)
        return result
    }

    /// Live formatted converted value for UI copy/share footnotes (`"—"` when invalid or missing).
    var formattedResult: String {
        guard validationError == nil, let r = conversionResult else { return "—" }
        return formatNumberForDisplay(r.outputValue)
    }

    /// Copies formatted result and “to” unit name to the pasteboard; success haptic when valid.
    func copyResult() {
        guard validationError == nil,
              conversionResult != nil,
              let name = toUnit?.name else { return }
        let text = "\(formattedResult) \(name)"
        UIPasteboard.general.string = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Single-line conversion text for a share sheet (no meme appendix). Empty when invalid.
    func shareConversionPlainText() -> String {
        guard validationError == nil,
              let r = conversionResult,
              let fromN = fromUnit?.name,
              let toN = toUnit?.name else { return "" }
        let i = formatNumberForDisplay(r.inputValue)
        let o = formatNumberForDisplay(r.outputValue)
        return "\(i) \(fromN) = \(o) \(toN)"
    }

    /// Footer line for the share card when the destination unit has no fun fact.
    /// Returns `nil` for temperature because "1 °C = 33.8 °F" is misleading (it converts the
    /// number 1, not a physically meaningful zero reference).
    func shareCardFormulaLine() -> String? {
        guard selectedCategory != .temperature else { return nil }
        guard let fromU = fromUnit, let toU = toUnit,
              let one = try? engine.convert(1, from: selectedFromUnitID, to: selectedToUnitID, includeMemeExplanation: false)
        else { return nil }
        return "1 \(fromU.name) = \(formatNumberForDisplay(one.outputValue)) \(toU.name)"
    }

}
