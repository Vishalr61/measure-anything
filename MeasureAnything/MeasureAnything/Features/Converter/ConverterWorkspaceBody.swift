import SwiftUI
import SwiftData
import UIKit
import MeasureAnythingCore

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: ConverterWorkspaceBody
// ─────────────────────────────────────────────────────────────────────────────

/// Live conversion blocks (amount, units, result) shared by `HomeView` and standalone `ConverterView`.
struct ConverterWorkspaceBody: View {
    var showsCategoryPicker: Bool = true
    var onOpenFactCard: ((String) -> Void)? = nil

    @Binding var showCustomUnitForm: Bool
    @Binding var isKeyboardActive: Bool

    @Query(sort: \CustomUnit.name) private var customUnits: [CustomUnit]
    @Query(sort: \FavoriteConversion.createdAt, order: .reverse) private var favorites: [FavoriteConversion]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var taxonomyStore: AppTaxonomyStore

    @ObservedObject var vm: ConverterViewModel
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @FocusState private var valueFieldFocused: Bool
    @State private var amountSnapshotBeforeEditing: String?
    @State private var swapRotation: Double = 0
    @State private var swapPillScale: CGFloat = 1
    @State private var isSwapPillAnimating: Bool = false
    @State private var showFromPicker = false
    @State private var customUnitSheetDetent: PresentationDetent = .medium

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let msg = taxonomyStore.loadFailureMessage {
                Text("Couldn't load taxonomy (\(msg)). Using built-in category and mode order.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Taxonomy load warning: \(msg)")
                    .padding(.bottom, ConverterLayout.rhythm12)
            }

            if !(isKeyboardActive && showsCategoryPicker) {
                categoryModeBlock
            }

            Spacer()
                .frame(height: categoryToConverterSpacing)

            conversionInputBlock
        }
        .padding(.horizontal, ConverterLayout.horizontalInset)
        .padding(.vertical, verticalPagePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
        .sheet(isPresented: $showCustomUnitForm) {
            CustomUnitFormView(initialCategory: vm.selectedCategory)
                .environmentObject(vm)
                .presentationDetents([.medium, .large], selection: $customUnitSheetDetent)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showCustomUnitForm) { _, isPresented in
            if isPresented { customUnitSheetDetent = .medium }
        }
        .task(id: customUnitsSyncToken) {
            vm.sync(customUnits: customUnits)
        }
        .onShake {
            vm.requestSingleRollFromShake()
        }
        .onAppear {
            if amountSnapshotBeforeEditing == nil {
                amountSnapshotBeforeEditing = vm.inputText
            }
        }
        .onChange(of: valueFieldFocused) { _, isFocused in
            isKeyboardActive = isFocused
            if isFocused {
                vm.captureInputEditSnapshot()
                amountSnapshotBeforeEditing = vm.inputText
            } else {
                vm.clearInputEditSnapshot()
                amountSnapshotBeforeEditing = nil
            }
        }
        // Limit the input to 9 numeric digits (one decimal point allowed alongside).
        .onChange(of: vm.inputText) { _, newValue in
            let digits = newValue.filter { $0.isNumber }
            guard digits.count > 9 else { return }
            var digitCount = 0
            let trimmed = newValue.filter { char in
                if char.isNumber {
                    digitCount += 1
                    return digitCount <= 9
                }
                return char == "."
            }
            if trimmed != newValue {
                vm.inputText = trimmed
            }
        }
    }

    // MARK: – Internal helpers (unchanged)

    private func dismissAmountFieldKeyboard() { valueFieldFocused = false }

    private func cancelAmountFieldEdit() {
        if let snapshot = amountSnapshotBeforeEditing { vm.inputText = snapshot }
        dismissAmountFieldKeyboard()
    }

    private func prepareUnitPickerPresentation() { dismissAmountFieldKeyboard() }

    private var canShareResult: Bool {
        vm.conversionResult != nil && vm.validationError == nil
            && vm.fromUnit != nil && vm.toUnit != nil
    }

    private var canCopyResult: Bool {
        vm.conversionResult != nil && vm.validationError == nil && vm.toUnit != nil
    }

    private func presentShareResult() {
        guard canShareResult else { return }
        guard let r = vm.conversionResult,
              let fromName = vm.fromUnit?.name,
              let toName = vm.toUnit?.name else { return }
        Haptics.share()

        let topVC = topMostViewController()
        guard let topVC else { return }

        let fromVal = vm.formatNumberForDisplay(r.inputValue)
        let toVal = vm.formatNumberForDisplay(r.outputValue)
        let categoryTag = shareCategoryTag(for: vm.selectedCategory)
        let equation = "\(fromVal) \(fromName) converted into something you can actually picture."

        ShareCardPresenter.present(
            from: topVC,
            fromValue: fromVal,
            fromUnit: fromName,
            toValue: toVal,
            toUnit: toName,
            category: categoryTag,
            isPrecisionMode: vm.precisionModeEnabled,
            equationText: equation
        )
    }

    /// Maps `UnitCategory` to the all-caps tag used by the share card background switch.
    private func shareCategoryTag(for category: UnitCategory) -> String {
        switch category {
        case .length:      return "LENGTH"
        case .mass:        return "MASS"
        case .time:        return "TIME"
        case .temperature: return "TEMP"
        case .volume:      return "VOLUME"
        }
    }

    /// Walks up from the connected scene's root to the top-most presented VC,
    /// so `UIActivityViewController` can be presented without losing the topmost sheet/popover.
    private func topMostViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
                ?? scene.windows.first?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    private var isCurrentPairAlreadyFavorite: Bool {
        favorites.contains {
            $0.categoryRaw   == vm.selectedCategory.rawValue
                && $0.fromUnitID == vm.selectedFromUnitID
                && $0.toUnitID   == vm.selectedToUnitID
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
            .sorted().joined(separator: ";")
    }

    private var categoryAccent: Color {
        ConverterCategoryAccent.accent(for: vm.selectedCategory)
    }

    private var adaptiveMajorSpacing: CGFloat {
        verticalSizeClass == .compact ? ConverterLayout.rhythm12 : ConverterLayout.majorBlockSpacing
    }

    /// Tighter gaps while editing so ScrollView content sits near the keyboard (avoids a grey “dead band”).
    private var categoryToConverterSpacing: CGFloat {
        if isKeyboardActive {
            return showsCategoryPicker ? ConverterLayout.rhythm8 : 4
        }
        return showsCategoryPicker ? adaptiveMajorSpacing : ConverterLayout.rhythm12
    }

    private var verticalPagePadding: CGFloat {
        isKeyboardActive ? 8 : ConverterLayout.rhythm20
    }

    private var toRowFootnoteText: String? {
        guard vm.validationError == nil,
              let r     = vm.conversionResult,
              let fromU = vm.fromUnit,
              let toU   = vm.toUnit else { return nil }
        let inStr  = vm.formatNumberForDisplay(r.inputValue)
        let outStr = vm.formatNumberForDisplay(r.outputValue)
        return "\(inStr) \(fromU.name) = \(outStr) \(toU.name)"
    }

    // MARK: – Category chips

    private var categoryModeBlock: some View {
        Group {
            if showsCategoryPicker {
                VStack(alignment: .leading, spacing: ConverterLayout.rhythm12) {
                    categoryChipScroll
                }
            }
        }
    }

    private var categoryChipScroll: some View {
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
    }

    // MARK: – Conversion input block

    private var conversionInputBlock: some View {
        VStack(alignment: .leading, spacing: isKeyboardActive ? ConverterLayout.rhythm8 : ConverterLayout.rhythm16) {
            referenceConversionColumn
        }
    }

    private var referenceConversionColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                fromConversionCard

                ZStack {
                    referenceSwapButton
                }
                .padding(.vertical, isKeyboardActive ? 6 : 12)
                .zIndex(1)

                expandedToCard
            }

            if let err = vm.validationError {
                validationErrorView(message: err)
                    .padding(.top, isKeyboardActive ? ConverterLayout.rhythm8 : ConverterLayout.rhythm12)
            }

            DiceRollCard(vm: vm, accent: categoryAccent)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.top, 10)

            if let toUnit = vm.toUnit, toUnit.funFact != nil {
                DidYouKnowCard(
                    unit: toUnit,
                    accent: categoryAccent,
                    onOpenFactCard: onOpenFactCard.map { cb in { cb(toUnit.id) } }
                )
                .id(toUnit.id)
                .transition(.opacity)
                .animation(.easeIn(duration: 0.25), value: toUnit.id)
                .padding(.top, 10)
            }
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

    private var expandedToCard: some View {
        let toName = vm.toUnit?.name ?? "—"
        return ToCard(
            toUnitName: toName,
            resultText: toRowDisplayString,
            resultAttributed: vm.formattedResultAttributed,
            formulaLine: toRowFootnoteText,
            accent: categoryAccent,
            isSaved: isCurrentPairAlreadyFavorite,
            copyEnabled: canCopyResult,
            shareEnabled: canShareResult,
            saveEnabled: vm.canSaveCurrentPairAsFavorite,
            usesPlaceholderResult: toRowUsesPlaceholder,
            onCopy: { vm.copyResult() },
            onShare: { presentShareResult() },
            onSave: { saveCurrentPairAsFavorite() },
            selectedToUnitID: $vm.selectedToUnitID,
            availableUnits: vm.availableUnits,
            unitPillScale: swapPillScale,
            onPrepareUnitPicker: { prepareUnitPickerPresentation() }
        )
    }

    // MARK: – FROM card
    // Plain SwiftUI TextField + @FocusState — same setup as CustomUnitFormView.

    private var fromConversionCard: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.rhythm8) {
            Text("From")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.55)

            HStack(alignment: .center, spacing: ConverterLayout.rhythm12) {
                TextField("0", text: $vm.inputText)
                    .keyboardType(.decimalPad)
                    .focused($valueFieldFocused)
                    .font(.system(size: 40, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .accessibilityLabel("Amount to convert")

                unitMenuPill(selection: $vm.selectedFromUnitID)
                    .scaleEffect(swapPillScale, anchor: .center)
            }

            if ConversionHistory.shared.totalRecordedConversions >= 2 {
                let raw         = ConversionHistory.shared.suggestions(for: vm.selectedFromUnitID, limit: 12)
                let suggestions = raw.filter { $0 != vm.selectedToUnitID }
                if !suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Text("→")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: "#B4B2A9"))
                            ForEach(Array(suggestions.prefix(3)), id: \.self) { unitId in
                                if let unit = vm.availableUnits.first(where: { $0.id == unitId }) {
                                    Button {
                                        Haptics.tap()
                                        vm.selectedToUnitID = unit.id
                                    } label: {
                                        Text(unit.name)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(categoryAccent)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(categoryAccent.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
        .padding(ConverterLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(referenceUnitCardFill)
        .overlay(referenceUnitCardStroke)
        .shadow(
            color: .black.opacity(ConverterLayout.referenceCardShadowOpacity),
            radius: ConverterLayout.referenceCardShadowRadius,
            x: 0, y: ConverterLayout.referenceCardShadowY
        )
        .contentShape(Rectangle())
        // Tapping anywhere on the card focuses the text field.
        .onTapGesture {
            valueFieldFocused = true
        }
    }

    private func unitMenuPill(selection: Binding<UnitDefinition.ID>) -> some View {
        let name = vm.fromUnit?.name ?? "—"
        return UnitPickerPillButton(name: name, accent: categoryAccent) {
            prepareUnitPickerPresentation()
            DispatchQueue.main.async { showFromPicker = true }
        }
        .sheet(isPresented: $showFromPicker) {
            UnitPickerSheet(
                units: vm.availableUnits,
                selectedID: selection.wrappedValue,
                accent: categoryAccent
            ) { newID in selection.wrappedValue = newID }
        }
    }

    private var referenceSwapButton: some View {
        Button {
            guard !isSwapPillAnimating else { return }
            isSwapPillAnimating = true
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
            let springDown = Animation.spring(response: 0.12, dampingFraction: 0.75)
            let springUp   = Animation.spring(response: 0.13, dampingFraction: 0.75)
            withAnimation(springDown) {
                swapPillScale = 0.85
                swapRotation += 180
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) { vm.swapUnits() }
                withAnimation(springUp) { swapPillScale = 1.0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isSwapPillAnimating = false
                }
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
        .allowsHitTesting(!isSwapPillAnimating)
        .accessibilityLabel("Swap from and to units")
    }

    private var referenceUnitCardFill: some View {
        RoundedRectangle(cornerRadius: ConverterLayout.referenceCardCornerRadius, style: .continuous)
            .fill(Color(hex: "#F0F0F3"))
    }

    private var referenceUnitCardStroke: some View {
        RoundedRectangle(cornerRadius: ConverterLayout.referenceCardCornerRadius, style: .continuous)
            .strokeBorder(
                Color.primary.opacity(ConverterLayout.strokeOpacitySubtle * 0.85),
                lineWidth: ConverterLayout.strokeHairline
            )
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
    ConverterWorkspaceBody(
        showsCategoryPicker: true,
        onOpenFactCard: nil,
        showCustomUnitForm: .constant(false),
        isKeyboardActive: .constant(false),
        vm: ConverterViewModel(taxonomy: taxonomy)
    )
    .environmentObject(taxonomy)
    .modelContainer(for: [CustomUnit.self, FavoriteConversion.self], inMemory: true)
}
