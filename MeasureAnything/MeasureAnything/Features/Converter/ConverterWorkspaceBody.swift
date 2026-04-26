import SwiftUI
import SwiftData
import UIKit
import MeasureAnythingCore

/// Live conversion blocks (amount, units, result) shared by `HomeView` and standalone `ConverterView`.
struct ConverterWorkspaceBody: View {
    /// When `false`, category is controlled by the host (e.g. home pill bar).
    var showsCategoryPicker: Bool = true

    /// When set (e.g. on the home tab), “Did you know” opens the fact card sheet for the given unit id.
    var onOpenFactCard: ((String) -> Void)? = nil

    @Binding var showCustomUnitForm: Bool

    @Query(sort: \CustomUnit.name) private var customUnits: [CustomUnit]
    @Query(sort: \FavoriteConversion.createdAt, order: .reverse) private var favorites: [FavoriteConversion]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var taxonomyStore: AppTaxonomyStore

    @ObservedObject var vm: ConverterViewModel
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @FocusState private var valueFieldFocused: Bool
    @State private var showShareSheet = false
    @State private var shareActivityItems: [Any] = []
    @State private var swapRotation: Double = 0
    @State private var swapPillScale: CGFloat = 1
    @State private var isSwapPillAnimating: Bool = false
    @State private var showFromPicker = false
    @State private var customUnitSheetDetent: PresentationDetent = .medium

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
                .frame(height: showsCategoryPicker ? adaptiveMajorSpacing : ConverterLayout.rhythm12)

            conversionInputBlock
        }
        .padding(.horizontal, ConverterLayout.horizontalInset)
        .padding(.vertical, ConverterLayout.rhythm20)
        .sheet(isPresented: $showCustomUnitForm) {
            CustomUnitFormView(initialCategory: vm.selectedCategory)
                .environmentObject(vm)
                .presentationDetents([.medium, .large], selection: $customUnitSheetDetent)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showCustomUnitForm) { _, isPresented in
            if isPresented {
                customUnitSheetDetent = .medium
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: shareActivityItems)
        }
        .task(id: customUnitsSyncToken) {
            vm.sync(customUnits: customUnits)
        }
        .onShake {
            vm.requestSingleRollFromShake()
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

    private func presentShareResult() {
        guard canShareResult else { return }
        Haptics.share()
        if let image = vm.renderShareCardImage() {
            shareActivityItems = [image]
        } else {
            let text = shareTextLine()
            guard !text.isEmpty else { return }
            shareActivityItems = [text]
        }
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

    /// Reduces vertical gap between category chips and converter cards in compact height
    /// (e.g. iPhone SE landscape) so the key controls stay visible without scrolling.
    private var adaptiveMajorSpacing: CGFloat {
        verticalSizeClass == .compact ? ConverterLayout.rhythm12 : ConverterLayout.majorBlockSpacing
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

    /// Category chips (optional) when this body owns category selection.
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

    /// Block 2: amount and unit pickers — reference-style stacked white cards + floating swap.
    private var conversionInputBlock: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.rhythm16) {
            referenceConversionColumn
        }
    }

    /// From/To: left column = amounts (input / converted output), right column = white unit pills — same `HStack` template so edges align. Swap on the seam.
    private var referenceConversionColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                fromConversionCard

                ZStack {
                    referenceSwapButton
                }
                .padding(.vertical, 12)
                .zIndex(1)

                expandedToCard
            }

            if let err = vm.validationError {
                validationErrorView(message: err)
                    .padding(.top, ConverterLayout.rhythm12)
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
        // Resolve from the registry so labels stay correct when the selection is outside the current mode list until sanitise runs.
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
            unitPillScale: swapPillScale
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
                    .scaleEffect(swapPillScale, anchor: .center)
            }

            if ConversionHistory.shared.totalRecordedConversions >= 2 {
                // Over-fetch then drop current TO so pills stay useful; history never suggests from→from.
                let raw = ConversionHistory.shared.suggestions(for: vm.selectedFromUnitID, limit: 12)
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
            x: 0,
            y: ConverterLayout.referenceCardShadowY
        )
    }

    private func unitMenuPill(selection: Binding<UnitDefinition.ID>) -> some View {
        let name = vm.fromUnit?.name ?? "—"
        return UnitPickerPillButton(
            name: name,
            accent: categoryAccent
        ) {
            showFromPicker = true
        }
        .sheet(isPresented: $showFromPicker) {
            UnitPickerSheet(
                units: vm.availableUnits,
                selectedID: selection.wrappedValue,
                accent: categoryAccent
            ) { newID in
                selection.wrappedValue = newID
            }
        }
    }

    private var referenceSwapButton: some View {
        Button {
            guard !isSwapPillAnimating else { return }
            isSwapPillAnimating = true
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
            // Both pills scale to 0.85 then back to 1.0 (total feel ~0.25s). Swap at ~0.12s
            // when nearly at minimum; numbers update without implicit animation.
            let springDown = Animation.spring(response: 0.12, dampingFraction: 0.75)
            let springUp = Animation.spring(response: 0.13, dampingFraction: 0.75)
            withAnimation(springDown) {
                swapPillScale = 0.85
                swapRotation += 180
            }
            let swapMidpoint: TimeInterval = 0.12
            DispatchQueue.main.asyncAfter(deadline: .now() + swapMidpoint) {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    vm.swapUnits()
                }
                withAnimation(springUp) {
                    swapPillScale = 1.0
                }
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
            .strokeBorder(Color.primary.opacity(ConverterLayout.strokeOpacitySubtle * 0.85), lineWidth: ConverterLayout.strokeHairline)
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
    ConverterWorkspaceBody(showsCategoryPicker: true, onOpenFactCard: nil, showCustomUnitForm: .constant(false), vm: ConverterViewModel(taxonomy: taxonomy))
        .environmentObject(taxonomy)
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self], inMemory: true)
}
