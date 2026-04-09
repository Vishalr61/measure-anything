import SwiftUI
import SwiftData
import UIKit
import MeasureAnythingCore

/// Live conversion blocks (mode, amount, units, result) shared by `HomeView` and standalone `ConverterView`.
struct ConverterWorkspaceBody: View {
    /// When `false`, category is controlled by the host (e.g. home pill bar); only mode + result tone appear here.
    var showsCategoryPicker: Bool = true

    @Binding var showCustomUnitForm: Bool

    @Query(sort: \CustomUnit.name) private var customUnits: [CustomUnit]
    @Query(sort: \FavoriteConversion.createdAt, order: .reverse) private var favorites: [FavoriteConversion]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var taxonomyStore: AppTaxonomyStore

    @ObservedObject var vm: ConverterViewModel
    @FocusState private var valueFieldFocused: Bool
    @State private var showShareSheet = false
    @State private var shareActivityItems: [Any] = []
    @State private var swapRotation: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let msg = taxonomyStore.loadFailureMessage {
                Text("Couldn’t load taxonomy (\(msg)). Using built-in category and mode order.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Taxonomy load warning: \(msg)")
                    .padding(.bottom, ConverterLayout.rhythm12)
            }

            categoryModeBlock

            Spacer()
                .frame(height: ConverterLayout.majorBlockSpacing)

            conversionInputBlock

            Spacer()
                .frame(height: ConverterLayout.majorBlockSpacing)

            resultCard
        }
        .padding(.horizontal, ConverterLayout.horizontalInset)
        .padding(.vertical, ConverterLayout.rhythm20)
        .sheet(isPresented: $showCustomUnitForm) {
            CustomUnitFormView()
                .environmentObject(taxonomyStore)
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: shareActivityItems)
        }
        .task(id: customUnitsSyncToken) {
            vm.sync(customUnits: customUnits)
        }
    }

    private var canShareResult: Bool {
        vm.conversionResult != nil
            && vm.validationError == nil
            && vm.fromUnit != nil
            && vm.toUnit != nil
    }

    private func shareTextLine() -> String {
        guard let r = vm.conversionResult,
              let fromName = vm.fromUnit?.name,
              let toName = vm.toUnit?.name else { return "" }
        let input = vm.formatNumberForDisplay(r.inputValue)
        let output = vm.formatNumberForDisplay(r.outputValue)
        var s = "\(input) \(fromName) = \(output) \(toName)"
        if let m = r.memeExplanation, !m.isEmpty {
            s += "\n\n\(m)"
        }
        return s
    }

    private func presentShareText() {
        let text = shareTextLine()
        guard !text.isEmpty else { return }
        Haptics.share()
        shareActivityItems = [text]
        showShareSheet = true
    }

    private func copyResultToPasteboard() {
        let text = shareTextLine()
        guard !text.isEmpty else { return }
        UIPasteboard.general.string = text
        Haptics.tap()
    }

    private func presentShareImage() {
        guard let r = vm.conversionResult,
              let fromName = vm.fromUnit?.name,
              let toName = vm.toUnit?.name else { return }
        let input = vm.formatNumberForDisplay(r.inputValue)
        let output = vm.formatNumberForDisplay(r.outputValue)
        guard let image = ShareImageRenderer.renderCard(
            inputFormatted: input,
            fromName: fromName,
            outputFormatted: output,
            toName: toName,
            meme: r.memeExplanation
        ) else { return }
        Haptics.share()
        shareActivityItems = [image]
        showShareSheet = true
    }

    private var isCurrentPairAlreadyFavorite: Bool {
        favorites.contains {
            $0.categoryRaw == vm.selectedCategory.rawValue
                && $0.fromUnitID == vm.selectedFromUnitID
                && $0.toUnitID == vm.selectedToUnitID
        }
    }

    private var canSaveFavoriteTap: Bool {
        vm.canSaveCurrentPairAsFavorite && !isCurrentPairAlreadyFavorite
    }

    private func saveCurrentPairAsFavorite() {
        guard vm.canSaveCurrentPairAsFavorite, !isCurrentPairAlreadyFavorite else { return }
        let fav = FavoriteConversion(
            categoryRaw: vm.selectedCategory.rawValue,
            fromUnitID: vm.selectedFromUnitID,
            toUnitID: vm.selectedToUnitID
        )
        modelContext.insert(fav)
        try? modelContext.save()
        Haptics.favorite()
    }

    private var customUnitsSyncToken: String {
        customUnits
            .map { "\($0.id)|\($0.factor)|\($0.name)|\($0.categoryRaw)" }
            .sorted()
            .joined(separator: ";")
    }

    private var categoryAccent: Color {
        ConverterCategoryAccent.accent(for: vm.selectedCategory)
    }

    private enum ConverterResultVisualState {
        case empty
        case error
        case successStandard
        case successMeme
    }

    private var converterResultVisualState: ConverterResultVisualState {
        if vm.validationError != nil { return .error }
        guard vm.conversionResult != nil else { return .empty }
        if let m = vm.conversionResult?.memeExplanation, !m.isEmpty { return .successMeme }
        return .successStandard
    }

    /// Block 1: category (optional) + mode (secondary surface).
    private var categoryModeBlock: some View {
        secondarySurface {
            VStack(alignment: .leading, spacing: ConverterLayout.rhythm12) {
                sectionLabel(showsCategoryPicker ? "Category & mode" : "Mode")
                if showsCategoryPicker {
                    categoryAndModeContent
                } else {
                    modeControls
                }
            }
        }
    }

    private var categoryAndModeContent: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.rhythm16) {
            Picker("Category", selection: $vm.selectedCategory) {
                ForEach(vm.categories, id: \.self) { category in
                    let d = taxonomyStore.categoryDisplay(for: category)
                    Text(d.displayName).tag(category)
                        .taxonomyPickerSegmentAccessibility(displayName: d.displayName, description: d.description)
                }
            }
            .pickerStyle(.segmented)
            .tint(categoryAccent)

            modeControls
        }
    }

    private var modeControls: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.rhythm12) {
            modePillToggle
                .disabled(!supportsAbsurdMode)
        }
    }

    private var supportsAbsurdMode: Bool {
        vm.modes.contains(.absurd)
    }

    private var supportsCustomMode: Bool {
        vm.modes.contains(.custom)
    }

    private var modePillToggle: some View {
        let selection = effectiveTopModeBinding.wrappedValue
        return HStack(spacing: 0) {
            modePillOption(title: "Normal", selection: selection, option: .normal) {
                withAnimation(.easeOut(duration: 0.18)) {
                    effectiveTopModeBinding.wrappedValue = .normal
                }
            }
            modePillOption(title: "Absurd", selection: selection, option: .absurd) {
                withAnimation(.easeOut(duration: 0.18)) {
                    effectiveTopModeBinding.wrappedValue = .absurd
                }
            }
        }
        .background(
            Capsule(style: .continuous)
                .fill(Color(.systemGray5))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: ConverterLayout.strokeHairline)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mode")
        .accessibilityValue(selection == .normal ? "Normal" : "Absurd")
    }

    private func modePillOption(title: String, selection: UnitRegistry.Mode, option: UnitRegistry.Mode, action: @escaping () -> Void) -> some View {
        let selected = selection == option
        let textColor: Color = {
            if selected {
                return option == .absurd ? Color.white : Color.primary
            }
            return Color.secondary
        }()

        let fill: Color = {
            guard selected else { return Color.clear }
            // Match reference: Normal selected is white; Absurd selected is a slightly deeper tint.
            if option == .normal { return Color(.systemBackground) }
            return categoryAccent.opacity(0.92)
        }()

        return Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            selected ? Color.white.opacity(option == .absurd ? 0.18 : 0.0) : Color.clear,
                            lineWidth: ConverterLayout.strokeHairline
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Top mode control is always normal/absurd. If the VM is in `.custom`, treat it as `.absurd` at the top level.
    private var effectiveTopModeBinding: Binding<UnitRegistry.Mode> {
        Binding(
            get: {
                switch vm.selectedMode {
                case .custom: return .absurd
                default: return vm.selectedMode
                }
            },
            set: { next in
                // When leaving absurd, always go to normal (not custom).
                if next == .normal {
                    vm.selectedMode = .normal
                    return
                }
                // Entering absurd prefers `.absurd`, unless the user explicitly chose custom via submode.
                vm.selectedMode = .absurd
            }
        )
    }

    // Custom mode is entered via the + button in the top bar while Absurd is selected.

    /// Block 2: amount and unit pickers — reference-style stacked white cards + floating swap.
    private var conversionInputBlock: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.rhythm16) {
            referenceConversionColumn
            if vm.selectedMode == .custom {
                secondarySurface {
                    customUnitsSection
                }
            }
        }
    }

    /// From/To: left column = amounts (input / converted output), right column = white unit pills — same `HStack` template so edges align. Swap on the seam.
    private var referenceConversionColumn: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.rhythm16) {
            VStack(spacing: 0) {
                conversionAmountRow(isFrom: true)
                    .overlay(alignment: .bottom) {
                        referenceSwapButton
                            .offset(y: 27)
                    }
                    .padding(.bottom, 27)
                    .zIndex(1)

                conversionAmountRow(isFrom: false)
                    .padding(.top, -27)
            }

            if effectiveTopModeBinding.wrappedValue == .absurd {
                DiceRollCard(vm: vm, accent: categoryAccent)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            referenceMetaInfoPair
        }
    }

    private var toRowDisplayString: String {
        if vm.validationError != nil { return "—" }
        guard let r = vm.conversionResult else { return "—" }
        return vm.formatNumberForDisplay(r.outputValue)
    }

    private var toRowUsesPlaceholder: Bool {
        vm.validationError != nil || vm.conversionResult == nil
    }

    private func conversionAmountRow(isFrom: Bool) -> some View {
        VStack(alignment: .leading, spacing: ConverterLayout.rhythm8) {
            Text(isFrom ? "From" : "To")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.55)

            HStack(alignment: .center, spacing: ConverterLayout.rhythm12) {
                Group {
                    if isFrom {
                        TextField("", text: $vm.inputText, prompt: Text("0").foregroundStyle(.tertiary))
                            .keyboardType(.decimalPad)
                            .focused($valueFieldFocused)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") {
                                        valueFieldFocused = false
                                    }
                                    .fontWeight(.semibold)
                                }
                            }
                            .accessibilityLabel("Amount to convert")
                    } else {
                        Text(toRowDisplayString)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(toRowUsesPlaceholder ? Color.secondary.opacity(0.55) : Color.primary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .accessibilityLabel("Converted amount, \(toRowDisplayString)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                unitMenuPill(selection: isFrom ? $vm.selectedFromUnitID : $vm.selectedToUnitID)
            }
        }
        .padding(ConverterLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(referenceUnitCardFill)
        .overlay(referenceUnitCardStroke)
        .shadow(
            color: .black.opacity(ConverterLayout.referenceCardShadowOpacity),
            radius: ConverterLayout.referenceCardShadowRadius,
            x: 0,
            y: ConverterLayout.referenceCardShadowY
        )
    }

    private func unitMenuPill(selection: Binding<UnitDefinition.ID>) -> some View {
        let name = vm.availableUnits.first { $0.id == selection.wrappedValue }?.name ?? "—"
        return Picker(selection: selection) {
            ForEach(vm.availableUnits, id: \.id) { u in
                Text(u.name).tag(u.id)
            }
        } label: {
            HStack(spacing: 8) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(categoryAccent.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(categoryAccent.opacity(0.65))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: ConverterLayout.strokeHairline)
            )
            .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .pickerStyle(.menu)
        .tint(categoryAccent)
        .accessibilityLabel("\(name) unit, opens menu")
        .accessibilityHint("Choose a unit")
    }

    private var referenceMetaInfoPair: some View {
        HStack(alignment: .top, spacing: ConverterLayout.rhythm12) {
            metaInfoCard(title: "Formula", body: formulaMetaLine)
                .frame(maxWidth: .infinity, alignment: .leading)
            metaInfoCard(title: "Precision", body: precisionMetaLine)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var formulaMetaLine: String {
        guard let r = vm.conversionResult,
              vm.validationError == nil,
              let fromName = vm.fromUnit?.name,
              let toName = vm.toUnit?.name,
              let line = equivalenceLine(result: r, fromName: fromName, toName: toName),
              !line.isEmpty
        else {
            return "Shown for linear conversions (not temperature)."
        }
        return line
    }

    private var precisionMetaLine: String {
        "Adapts to magnitude (up to 6 decimal places)."
    }

    private func metaInfoCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: ConverterLayout.rhythm8) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(body)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ConverterLayout.secondaryBlockPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ConverterLayout.secondaryBlockCornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ConverterLayout.secondaryBlockCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(ConverterLayout.strokeOpacitySubtle), lineWidth: ConverterLayout.strokeHairline)
        )
    }

    private var referenceSwapButton: some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                swapRotation += 180
                vm.swapUnits()
            }
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Circle().fill(categoryAccent))
                .shadow(color: categoryAccent.opacity(0.4), radius: 10, x: 0, y: 5)
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                .rotationEffect(.degrees(swapRotation))
        }
        .buttonStyle(ConverterPressingButtonStyle())
        .accessibilityLabel("Swap from and to units")
    }

    private var referenceUnitCardFill: some View {
        RoundedRectangle(cornerRadius: ConverterLayout.referenceCardCornerRadius, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    private var referenceUnitCardStroke: some View {
        RoundedRectangle(cornerRadius: ConverterLayout.referenceCardCornerRadius, style: .continuous)
            .strokeBorder(Color.primary.opacity(ConverterLayout.strokeOpacitySubtle * 0.85), lineWidth: ConverterLayout.strokeHairline)
    }

    private func unitDisplaySymbol(_ unit: UnitDefinition?) -> String {
        guard let unit else { return "—" }
        if let s = Self.commonUnitSymbols[unit.id] { return s }
        let parts = unit.name.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2, let f = parts.first?.first {
            let second = parts[1].first.map { String($0) } ?? ""
            return String(f).uppercased() + second.lowercased()
        }
        if unit.name.count <= 5 { return unit.name }
        return String(unit.name.prefix(4)) + "…"
    }

    private static let commonUnitSymbols: [String: String] = [
        // Length (SI / scientific)
        "picometer": "pm",
        "angstrom": "Å",
        "nanometer": "nm",
        "micrometer": "µm",
        "decimeter": "dm",
        "hectometer": "hm",
        "megameter": "Mm",
        "meter": "m",
        "kilometer": "km",
        "centimeter": "cm",
        "millimeter": "mm",
        "inch": "in",
        "foot": "ft",
        "yard": "yd",
        "mile": "mi",

        // Length (imperial / historical)
        "thou": "thou",
        "fathom": "ftm",
        "chain": "ch",
        "rod": "rd",
        "furlong": "fur",
        "league": "lea",
        "hand": "hh",
        "cubit": "cubit",
        "pace": "pace",
        "nautical_mile": "nmi",

        // Length (astronomy)
        "astronomical_unit": "AU",
        "light_year": "ly",
        "parsec": "pc",
        "light_second": "ls",

        "kilogram": "kg",
        "gram": "g",
        "milligram": "mg",
        "pound": "lb",
        "ounce": "oz",
        "second": "s",
        "minute": "min",
        "hour": "h",
        "day": "d",
        "liter": "L",
        "milliliter": "mL",
        "cubic_meter": "m³",
        "gallon_us": "gal",
        "quart_us": "qt",
        "pint_us": "pt",
        "cup_us": "cup",
        "celsius": "°C",
        "fahrenheit": "°F",
        "kelvin": "K"
    ]

    private func secondarySurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(ConverterLayout.secondaryBlockPadding)
            .background(
                RoundedRectangle(cornerRadius: ConverterLayout.secondaryBlockCornerRadius, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ConverterLayout.secondaryBlockCornerRadius, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(ConverterLayout.strokeOpacitySubtle),
                        lineWidth: ConverterLayout.strokeHairline
                    )
            )
    }

    private var customUnitsSection: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.rhythm12) {
            Divider()
            sectionLabel("My custom units")

            if customUnits.isEmpty {
                emptyCustomUnitsPlaceholder
            } else {
                ForEach(customUnits) { unit in
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: ConverterLayout.rhythm8) {
                            Text(unit.name)
                                .font(.body.weight(.medium))
                            Text(unit.categoryRaw.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            Haptics.tap()
                            modelContext.delete(unit)
                        } label: {
                            Image(systemName: "trash")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.red)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete \(unit.name)")
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, ConverterLayout.rhythm8)
    }

    private var emptyCustomUnitsPlaceholder: some View {
        HStack(alignment: .top, spacing: ConverterLayout.rhythm12) {
            Image(systemName: "square.dashed")
                .font(.title2)
                .foregroundStyle(.tertiary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: ConverterLayout.rhythm8) {
                Text("No custom units yet")
                    .font(.subheadline.weight(.medium))
                Text("Tap + above to add one. It will appear in Custom mode for that category.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    /// Block 3: conversion output (primary elevated surface).
    private var resultCard: some View {
        let state = converterResultVisualState
        return VStack(alignment: .leading, spacing: ConverterLayout.rhythm16) {
            Group {
                if let err = vm.validationError {
                    Text("Result")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(resultTitleStyle(for: state))
                    validationErrorView(message: err)
                } else if let result = vm.conversionResult,
                          let fromUnit = vm.fromUnit,
                          let toUnit = vm.toUnit {
                    referenceResultCard(result: result, fromUnit: fromUnit, toUnit: toUnit)
                } else {
                    Text("Result")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(resultTitleStyle(for: state))
                    resultEmptyPlaceholder
                }
            }
            .animation(.easeOut(duration: 0.24), value: resultBodyAnimationKey)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ConverterLayout.resultHeroPadding)
        .background(
            RoundedRectangle(cornerRadius: ConverterLayout.resultHeroCornerRadius, style: .continuous)
                .fill(resultCardFill(for: state))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ConverterLayout.resultHeroCornerRadius, style: .continuous)
                .strokeBorder(resultCardStroke(for: state), lineWidth: ConverterLayout.strokeHairline)
        )
        .overlay(alignment: .leading) {
            resultLeadingAccentBar(state: state)
        }
        .shadow(color: .black.opacity(resultCardShadowOpacity(for: state)), radius: 20, x: 0, y: 8)
    }

    private func referenceResultCard(result: ConversionResult, fromUnit: UnitDefinition, toUnit: UnitDefinition) -> some View {
        let input = vm.formatNumberForDisplay(result.inputValue)
        let output = vm.formatNumberForDisplay(result.outputValue)
        let fromSym = unitDisplaySymbol(fromUnit)
        let toSym = unitDisplaySymbol(toUnit)

        return VStack(alignment: .center, spacing: ConverterLayout.rhythm16) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    Text("Live conversion rate")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.7)

                    referenceRateLine(input: input, fromSym: fromSym, output: output, toSym: toSym)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, ConverterLayout.rhythm8)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Button {
                    saveCurrentPairAsFavorite()
                } label: {
                    Image(systemName: isCurrentPairAlreadyFavorite ? "star.fill" : "star")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isCurrentPairAlreadyFavorite ? categoryAccent : Color.secondary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground).opacity(0.7))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: ConverterLayout.strokeHairline)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(ConverterPressingButtonStyle())
                .disabled(!canSaveFavoriteTap)
                .accessibilityLabel(isCurrentPairAlreadyFavorite ? "Already a favorite" : "Save as favorite")
            }

            if let meme = result.memeExplanation, !meme.isEmpty {
                Text(meme)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(ConverterLayout.rhythm16)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: ConverterLayout.secondaryBlockCornerRadius, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ConverterLayout.secondaryBlockCornerRadius, style: .continuous)
                            .strokeBorder(categoryAccent.opacity(0.18), lineWidth: ConverterLayout.strokeHairline)
                    )
            }

            referenceResultButtons
        }
    }

    private func referenceRateLine(input: String, fromSym: String, output: String, toSym: String) -> some View {
        // Prefer fully visible text (wrap) over truncation. Fallback to a slightly smaller font when needed.
        ViewThatFits(in: .horizontal) {
            referenceRateLineText(input: input, fromSym: fromSym, output: output, toSym: toSym, size: 28)
            referenceRateLineText(input: input, fromSym: fromSym, output: output, toSym: toSym, size: 24)
            referenceRateLineText(input: input, fromSym: fromSym, output: output, toSym: toSym, size: 20)
            referenceRateLineText(input: input, fromSym: fromSym, output: output, toSym: toSym, size: 18)
        }
    }

    private func referenceRateLineText(input: String, fromSym: String, output: String, toSym: String, size: CGFloat) -> some View {
        let combined = Text("\(input) \(fromSym) = \(output) \(toSym)")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .monospacedDigit()
            .lineLimit(4)
            .minimumScaleFactor(0.32)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .allowsTightening(true)
            .layoutPriority(1)

        return Group {
            if #available(iOS 17.0, *) {
                combined.contentTransition(ContentTransition.numericText())
            } else {
                combined
            }
        }
    }

    private var referenceResultButtons: some View {
        HStack(spacing: ConverterLayout.rhythm12) {
            Button {
                copyResultToPasteboard()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                    Text("Copy")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.systemGray5))
                )
            }
            .buttonStyle(ConverterPressingButtonStyle())
            .accessibilityLabel("Copy")

            Menu {
                Button("Copy") { copyResultToPasteboard() }
                Button("Share as Text") { presentShareText() }
                Button("Share as Image") { presentShareImage() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                    Text("Share")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(categoryAccent)
                )
            }
            .buttonStyle(ConverterPressingButtonStyle())
            .accessibilityLabel("Share")
        }
    }

    private func resultTitleStyle(for state: ConverterResultVisualState) -> Color {
        switch state {
        case .empty: return Color.secondary.opacity(0.85)
        case .error: return Color.red.opacity(0.75)
        case .successStandard, .successMeme: return Color.secondary
        }
    }

    private func resultCardFill(for state: ConverterResultVisualState) -> Color {
        switch state {
        case .empty:
            return Color(.secondarySystemGroupedBackground)
        case .error:
            return Color(.systemBackground)
        case .successStandard, .successMeme:
            return categoryAccent.opacity(0.1)
        }
    }

    private func resultCardStroke(for state: ConverterResultVisualState) -> Color {
        switch state {
        case .empty:
            return Color.primary.opacity(ConverterLayout.strokeOpacitySubtle)
        case .error:
            return Color.red.opacity(0.28)
        case .successStandard:
            return categoryAccent.opacity(0.2)
        case .successMeme:
            return categoryAccent.opacity(0.24)
        }
    }

    private func resultCardShadowOpacity(for state: ConverterResultVisualState) -> Double {
        switch state {
        case .empty: return 0.06
        case .error: return 0.1
        case .successStandard: return 0.12
        case .successMeme: return 0.14
        }
    }

    @ViewBuilder
    private func resultLeadingAccentBar(state: ConverterResultVisualState) -> some View {
        switch state {
        case .empty, .successStandard, .successMeme:
            EmptyView()
        case .error:
            Capsule(style: .continuous)
                .fill(Color.red.opacity(0.55))
                .frame(width: ConverterLayout.accentBarWidth)
                .padding(.leading, ConverterLayout.rhythm12)
                .padding(.vertical, ConverterLayout.rhythm24)
        }
    }

    private var resultBodyAnimationKey: String {
        if let err = vm.validationError { return "e:\(err)" }
        if let r = vm.conversionResult {
            return "r:\(r.outputValue):\(r.inputValue):\(vm.inputText):\(vm.isMemeExplanationEnabled):\(r.memeExplanation ?? "")"
        }
        return "empty"
    }

    private var resultCardTrailingChrome: some View {
        HStack(spacing: 0) {
            Button {
                copyResultToPasteboard()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(categoryAccent.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ConverterPressingButtonStyle())
            .accessibilityLabel("Copy result")

            Menu {
                Button("Copy") {
                    copyResultToPasteboard()
                }
                Button("Share as Text") {
                    presentShareText()
                }
                Button("Share as Image") {
                    presentShareImage()
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(categoryAccent.opacity(0.75))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ConverterPressingButtonStyle())
            .accessibilityLabel("Share result")
        }
    }

    private var resultReferenceActionPills: some View {
        HStack(spacing: ConverterLayout.rhythm12) {
            Button {
                saveCurrentPairAsFavorite()
            } label: {
                Text(isCurrentPairAlreadyFavorite ? "Saved" : "Favorite")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        isCurrentPairAlreadyFavorite ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(categoryAccent)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule(style: .continuous)
                            .fill(categoryAccent.opacity(isCurrentPairAlreadyFavorite ? 0.08 : 0.16))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(categoryAccent.opacity(0.22), lineWidth: ConverterLayout.strokeHairline)
                    )
            }
            .buttonStyle(ConverterPressingButtonStyle())
            .disabled(!vm.canSaveCurrentPairAsFavorite || isCurrentPairAlreadyFavorite)
            .accessibilityLabel(isCurrentPairAlreadyFavorite ? "Already saved as favorite" : "Save as favorite")

            Button {
                presentShareText()
            } label: {
                Text("Share")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(.systemGray5))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: ConverterLayout.strokeHairline)
                    )
            }
            .buttonStyle(ConverterPressingButtonStyle())
            .accessibilityLabel("Share as text")
        }
    }

    /// Linear factor line; omitted for temperature and degenerate cases.
    private func equivalenceLine(result: ConversionResult, fromName: String, toName: String) -> String? {
        guard result.category != .temperature,
              result.fromUnitID != result.toUnitID else { return nil }
        let inp = result.inputValue
        guard inp != 0, abs(inp) > 1e-12 else { return nil }
        let ratio = result.outputValue / inp
        let r = vm.formatNumberForDisplay(ratio)
        return "1 \(fromName) ≈ \(r) \(toName)"
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.55)
    }

    private func validationErrorView(message: String) -> some View {
        HStack(alignment: .top, spacing: ConverterLayout.rhythm12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.body)
                .foregroundStyle(.red.opacity(0.9))
                .accessibilityHidden(true)
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ConverterLayout.rhythm12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ConverterLayout.secondaryBlockCornerRadius, style: .continuous)
                .fill(Color.red.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ConverterLayout.secondaryBlockCornerRadius, style: .continuous)
                .strokeBorder(Color.red.opacity(0.22), lineWidth: ConverterLayout.strokeHairline)
        )
    }

    private var resultEmptyPlaceholder: some View {
        HStack(alignment: .top, spacing: ConverterLayout.rhythm12) {
            Image(systemName: "function")
                .font(.title3)
                .foregroundStyle(.quaternary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: ConverterLayout.rhythm8) {
                Text("No result yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Enter an amount and choose units.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(ConverterLayout.rhythm16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ConverterLayout.secondaryBlockCornerRadius, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(ConverterLayout.strokeOpacitySubtle),
                    style: StrokeStyle(lineWidth: ConverterLayout.strokeHairline, dash: [6, 5])
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("Invalid input appears in red below when present.")
    }
}

#Preview {
    let taxonomy = AppTaxonomyStore()
    ConverterWorkspaceBody(showsCategoryPicker: true, showCustomUnitForm: .constant(false), vm: ConverterViewModel(taxonomy: taxonomy))
        .environmentObject(taxonomy)
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self], inMemory: true)
}
