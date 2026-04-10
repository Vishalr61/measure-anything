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

    private var canCopyResult: Bool {
        vm.conversionResult != nil
            && vm.validationError == nil
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

    private var isCurrentPairAlreadyFavorite: Bool {
        favorites.contains {
            $0.categoryRaw == vm.selectedCategory.rawValue
                && $0.fromUnitID == vm.selectedFromUnitID
                && $0.toUnitID == vm.selectedToUnitID
        }
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

    /// Live “1 m = … km” style line under the TO amount (hidden when invalid / no result).
    private var toRowFootnoteText: String? {
        guard vm.validationError == nil,
              let r = vm.conversionResult,
              let fromU = vm.fromUnit,
              let toU = vm.toUnit else { return nil }
        let inStr = vm.formatNumberForDisplay(r.inputValue)
        let outStr = vm.formatNumberForDisplay(r.outputValue)
        return "\(inStr) \(fromU.name) = \(outStr) \(toU.name)"
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ConverterLayout.rhythm8) {
                    ForEach(vm.categories, id: \.self) { category in
                        let d = taxonomyStore.categoryDisplay(for: category)
                        CategoryChip(
                            category: category,
                            displayName: d.displayName,
                            accent: ConverterCategoryAccent.accent(for: category),
                            isSelected: vm.selectedCategory == category,
                            onTap: {
                                Haptics.tap()
                                vm.selectedCategory = category
                            }
                        )
                        .accessibilityHint(d.description ?? "")
                    }
                }
            }

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
    /// Absurd pill treats `.custom` like absurd for dice visibility.
    private var showsDiceCard: Bool {
        switch vm.selectedMode {
        case .normal: return false
        case .absurd, .custom: return true
        }
    }

    private var referenceConversionColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                fromConversionCard
                    .overlay(alignment: .bottom) {
                        referenceSwapButton
                            .offset(y: 27)
                    }
                    .padding(.bottom, 27)
                    .zIndex(1)

                expandedToCard
                    .padding(.top, -27)
            }

            if let err = vm.validationError {
                validationErrorView(message: err)
                    .padding(.top, ConverterLayout.rhythm12)
            }

            if showsDiceCard {
                DiceRollCard(vm: vm, accent: categoryAccent)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.top, 10)
            }

            if let toUnit = vm.toUnit, toUnit.funFact != nil {
                DidYouKnowCard(unit: toUnit, accent: categoryAccent)
                    .id(toUnit.id)
                    .transition(.opacity)
                    .animation(.easeIn(duration: 0.25), value: toUnit.id)
                    .padding(.top, 10)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showsDiceCard)
    }

    private var toRowDisplayString: String {
        if vm.validationError != nil { return "—" }
        guard let r = vm.conversionResult else { return "—" }
        return vm.formatNumberForDisplay(r.outputValue)
    }

    private var toRowUsesPlaceholder: Bool {
        vm.validationError != nil || vm.conversionResult == nil
    }

    private var expandedToCard: some View {
        let toName = vm.availableUnits.first { $0.id == vm.selectedToUnitID }?.name ?? "—"
        return ToCard(
            toUnitName: toName,
            resultText: toRowDisplayString,
            formulaLine: toRowFootnoteText,
            accent: categoryAccent,
            isSaved: isCurrentPairAlreadyFavorite,
            copyEnabled: canCopyResult,
            shareEnabled: canShareResult,
            saveEnabled: vm.canSaveCurrentPairAsFavorite,
            usesPlaceholderResult: toRowUsesPlaceholder,
            onCopy: { vm.copyResult() },
            onShare: { presentShareText() },
            onSave: { saveCurrentPairAsFavorite() },
            selectedToUnitID: $vm.selectedToUnitID,
            availableUnits: vm.availableUnits
        )
    }

    private var fromConversionCard: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.rhythm8) {
            Text("From")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.55)

            HStack(alignment: .center, spacing: ConverterLayout.rhythm12) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)

                unitMenuPill(selection: $vm.selectedFromUnitID)
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
}

#Preview {
    let taxonomy = AppTaxonomyStore()
    ConverterWorkspaceBody(showsCategoryPicker: true, showCustomUnitForm: .constant(false), vm: ConverterViewModel(taxonomy: taxonomy))
        .environmentObject(taxonomy)
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self], inMemory: true)
}
