import SwiftUI
import SwiftData
import MeasureAnythingCore

struct ConverterView: View {
    @Query(sort: \CustomUnit.name) private var customUnits: [CustomUnit]
    @Query(sort: \FavoriteConversion.createdAt, order: .reverse) private var favorites: [FavoriteConversion]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var taxonomyStore: AppTaxonomyStore

    @ObservedObject var vm: ConverterViewModel
    @FocusState private var valueFieldFocused: Bool
    @State private var showCustomUnitForm = false
    @State private var showFavorites = false
    @State private var showShareSheet = false
    @State private var shareActivityItems: [Any] = []
    @State private var showTaxonomySearch = false
    @State private var swapRotation: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
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
                .padding(.vertical, ConverterLayout.rhythm16)
            }
            .navigationTitle("Measure Anything")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.tap()
                        showFavorites = true
                    } label: {
                        Image(systemName: "list.star")
                            .font(.body.weight(.regular))
                            .imageScale(.medium)
                    }
                    .buttonStyle(ConverterPressingButtonStyle())
                    .accessibilityLabel("View favorites")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        showTaxonomySearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.body.weight(.regular))
                            .imageScale(.medium)
                    }
                    .buttonStyle(ConverterPressingButtonStyle())
                    .accessibilityLabel("Search taxonomy")

                    Button {
                        saveCurrentPairAsFavorite()
                    } label: {
                        Image(systemName: isCurrentPairAlreadyFavorite ? "star.fill" : "star")
                            .font(.body.weight(.regular))
                            .imageScale(.medium)
                            .foregroundStyle(isCurrentPairAlreadyFavorite ? categoryAccent.opacity(0.95) : Color.secondary)
                    }
                    .disabled(!canSaveFavoriteTap)
                    .buttonStyle(ConverterPressingButtonStyle())
                    .accessibilityLabel(isCurrentPairAlreadyFavorite ? "Already a favorite" : "Save as favorite")

                    if vm.selectedMode == .custom {
                        Button {
                            Haptics.tap()
                            showCustomUnitForm = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.regular))
                                .imageScale(.medium)
                        }
                        .buttonStyle(ConverterPressingButtonStyle())
                        .accessibilityLabel("Add custom unit")
                    }
                }
            }
            .sheet(isPresented: $showTaxonomySearch) {
                TaxonomySearchView { itemId in
                    if let route = taxonomyStore.converterRoute(forTaxonomyItemId: itemId) {
                        vm.applyTaxonomyRoute(route)
                    }
                    showTaxonomySearch = false
                }
                .environmentObject(taxonomyStore)
            }
            .sheet(isPresented: $showCustomUnitForm) {
                CustomUnitFormView()
                    .environmentObject(taxonomyStore)
            }
            .sheet(isPresented: $showFavorites) {
                FavoritesListView(registry: vm.currentRegistry) { fav in
                    vm.applyFavoriteRestore(
                        categoryRaw: fav.categoryRaw,
                        fromID: fav.fromUnitID,
                        toID: fav.toUnitID
                    )
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityView(activityItems: shareActivityItems)
            }
            .task(id: customUnitsSyncToken) {
                vm.sync(customUnits: customUnits)
            }
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

    /// Block 1: category and mode (secondary surface).
    private var categoryModeBlock: some View {
        secondarySurface {
            VStack(alignment: .leading, spacing: ConverterLayout.rhythm12) {
                sectionLabel("Category & mode")
                categoryModeContent
            }
        }
    }

    private var categoryModeContent: some View {
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

            VStack(alignment: .leading, spacing: ConverterLayout.rhythm12) {
                Picker("Mode", selection: $vm.selectedMode) {
                    ForEach(vm.modes, id: \.self) { mode in
                        let d = taxonomyStore.modeDisplay(for: mode)
                        Text(d.displayName).tag(mode)
                            .taxonomyPickerSegmentAccessibility(displayName: d.displayName, description: d.description)
                    }
                }
                .pickerStyle(.segmented)
                .tint(Color.primary.opacity(0.38))

                memeOutputStyleControl
            }
        }
    }

    /// Compact output-style control (same binding as former meme toggle).
    private var memeOutputStyleControl: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.rhythm8) {
            Text("Result tone")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Explanation style", selection: $vm.isMemeExplanationEnabled) {
                Text("Standard").tag(false)
                Text("Meme").tag(true)
            }
            .pickerStyle(.segmented)
            .tint(Color.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Result explanation style")
        .accessibilityHint("Standard keeps the result concise. Meme adds a playful explanation when available.")
    }

    /// Block 2: amount and unit pickers (secondary surface).
    private var conversionInputBlock: some View {
        secondarySurface {
            VStack(alignment: .leading, spacing: ConverterLayout.rhythm16) {
                inputs
                if vm.selectedMode == .custom {
                    customUnitsSection
                }
            }
        }
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

    private var inputs: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.rhythm12) {
            sectionLabel("Amount")

            TextField("e.g. 10 or 3.5", text: $vm.inputText)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .focused($valueFieldFocused)
                .font(.body.monospacedDigit())
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            valueFieldFocused = false
                        }
                        .fontWeight(.semibold)
                    }
                }

            conversionUnitRow
        }
    }

    /// Single horizontal conversion control: source pill, swap, target pill.
    private var conversionUnitRow: some View {
        HStack(alignment: .center, spacing: ConverterLayout.rhythm8) {
            unitPickerPill(accessibilityTitle: "From unit", selection: $vm.selectedFromUnitID, accent: categoryAccent)
            swapButton
            unitPickerPill(accessibilityTitle: "To unit", selection: $vm.selectedToUnitID, accent: categoryAccent)
        }
        .animation(.easeOut(duration: 0.22), value: unitSelectionAnimationKey)
    }

    private var unitSelectionAnimationKey: String {
        "\(vm.selectedFromUnitID)|\(vm.selectedToUnitID)"
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

    private var swapButton: some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                swapRotation += 180
                vm.swapUnits()
            }
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(categoryAccent.opacity(0.92))
                .frame(width: 40, height: 40)
                .background(
                    ZStack {
                        Circle().fill(.thinMaterial)
                        Circle().fill(categoryAccent.opacity(0.14))
                    }
                )
                .overlay(
                    Circle()
                        .strokeBorder(categoryAccent.opacity(0.28), lineWidth: ConverterLayout.strokeHairline)
                )
                .rotationEffect(.degrees(swapRotation))
        }
        .buttonStyle(ConverterPressingButtonStyle())
        .accessibilityLabel("Swap from and to units")
    }

    private func unitPickerPill(accessibilityTitle: String, selection: Binding<UnitDefinition.ID>, accent: Color) -> some View {
        let name = vm.availableUnits.first { $0.id == selection.wrappedValue }?.name ?? "—"
        return Picker(selection: selection) {
            ForEach(vm.availableUnits, id: \.id) { unit in
                Text(unit.name).tag(unit.id)
            }
        } label: {
            HStack(spacing: 6) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.14))
            )
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.42))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(accent.opacity(0.42), lineWidth: ConverterLayout.strokeHairline)
            )
        }
        .pickerStyle(.menu)
        .accessibilityLabel("\(accessibilityTitle), \(name)")
        .accessibilityHint("Opens a menu to choose a unit")
    }

    /// Block 3: conversion output (primary elevated surface).
    private var resultCard: some View {
        let state = converterResultVisualState
        return VStack(alignment: .leading, spacing: ConverterLayout.rhythm16) {
            ZStack(alignment: .topTrailing) {
                Text("Result")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(resultTitleStyle(for: state))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if canShareResult {
                    shareMenuDiminutive
                }
            }

            Group {
                if let err = vm.validationError {
                    validationErrorView(message: err)
                } else if let result = vm.conversionResult,
                          let fromName = vm.fromUnit?.name,
                          let toName = vm.toUnit?.name {
                    let input = vm.formatNumberForDisplay(result.inputValue)
                    let output = vm.formatNumberForDisplay(result.outputValue)

                    ResultCardContent(
                        inputFormatted: input,
                        fromName: fromName,
                        outputFormatted: output,
                        toName: toName,
                        meme: result.memeExplanation,
                        prominent: true,
                        equivalenceLine: equivalenceLine(result: result, fromName: fromName, toName: toName),
                        categoryAccent: categoryAccent
                    )
                } else {
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
            return Color(.systemBackground)
        }
    }

    private func resultCardStroke(for state: ConverterResultVisualState) -> Color {
        switch state {
        case .empty:
            return Color.primary.opacity(ConverterLayout.strokeOpacitySubtle)
        case .error:
            return Color.red.opacity(0.28)
        case .successStandard:
            return categoryAccent.opacity(0.26)
        case .successMeme:
            return categoryAccent.opacity(0.34)
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
        case .empty:
            EmptyView()
        case .error:
            Capsule(style: .continuous)
                .fill(Color.red.opacity(0.55))
                .frame(width: ConverterLayout.accentBarWidth)
                .padding(.leading, ConverterLayout.rhythm12)
                .padding(.vertical, ConverterLayout.rhythm24)
        case .successStandard:
            Capsule(style: .continuous)
                .fill(categoryAccent.opacity(0.88))
                .frame(width: ConverterLayout.accentBarWidth)
                .padding(.leading, ConverterLayout.rhythm12)
                .padding(.vertical, ConverterLayout.rhythm24)
        case .successMeme:
            Capsule(style: .continuous)
                .fill(categoryAccent.opacity(0.95))
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

    private var shareMenuDiminutive: some View {
        Menu {
            Button("Share as Text") {
                presentShareText()
            }
            Button("Share as Image") {
                presentShareImage()
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.quaternary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ConverterPressingButtonStyle())
        .accessibilityLabel("Share result")
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
    ConverterView(vm: ConverterViewModel(taxonomy: taxonomy))
        .environmentObject(taxonomy)
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self], inMemory: true)
}
