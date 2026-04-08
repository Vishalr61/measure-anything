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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ConverterLayout.sectionSpacing) {
                    if let msg = taxonomyStore.loadFailureMessage {
                        Text("Couldn’t load taxonomy (\(msg)). Using built-in category and mode order.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Taxonomy load warning: \(msg)")
                    }
                    header
                    inputs
                    if vm.selectedMode == .custom {
                        customUnitsSection
                    }
                    resultCard
                }
                .padding(.horizontal, ConverterLayout.horizontalInset)
                .padding(.vertical, 8)
            }
            .navigationTitle("Measure Anything")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Favorites", systemImage: "list.star") {
                        Haptics.tap()
                        showFavorites = true
                    }
                    .accessibilityLabel("View favorites")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        showTaxonomySearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search taxonomy")

                    Button {
                        saveCurrentPairAsFavorite()
                    } label: {
                        Image(systemName: isCurrentPairAlreadyFavorite ? "star.fill" : "star")
                    }
                    .disabled(!canSaveFavoriteTap)
                    .accessibilityLabel(isCurrentPairAlreadyFavorite ? "Already a favorite" : "Save as favorite")

                    if vm.selectedMode == .custom {
                        Button("Add unit", systemImage: "plus") {
                            Haptics.tap()
                            showCustomUnitForm = true
                        }
                        .accessibilityLabel("Add custom unit")
                    }
                }
            }
            .sheet(isPresented: $showTaxonomySearch) {
                TaxonomySearchView()
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

    private var header: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.blockSpacing) {
            Picker("Category", selection: $vm.selectedCategory) {
                ForEach(vm.categories, id: \.self) { category in
                    let d = taxonomyStore.categoryDisplay(for: category)
                    Text(d.displayName).tag(category)
                        .taxonomyPickerSegmentAccessibility(displayName: d.displayName, description: d.description)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 12) {
                Picker("Mode", selection: $vm.selectedMode) {
                    ForEach(vm.modes, id: \.self) { mode in
                        let d = taxonomyStore.modeDisplay(for: mode)
                        Text(d.displayName).tag(mode)
                            .taxonomyPickerSegmentAccessibility(displayName: d.displayName, description: d.description)
                    }
                }
                .pickerStyle(.segmented)

                taxonomySelectionContextLines

                Toggle("Explain like a meme", isOn: $vm.isMemeExplanationEnabled)
                    .font(.subheadline)
            }
        }
    }

    /// Minimal on-screen context for the current category and mode when taxonomy supplies descriptions.
    private var taxonomySelectionContextLines: some View {
        let cat = taxonomyStore.categoryDisplay(for: vm.selectedCategory)
        let mode = taxonomyStore.modeDisplay(for: vm.selectedMode)
        return VStack(alignment: .leading, spacing: 4) {
            if let t = cat.description, !t.isEmpty {
                Text(t)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Category: \(t)")
            }
            if let t = mode.description, !t.isEmpty {
                Text(t)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Mode: \(t)")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var inputs: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.blockSpacing) {
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

            HStack(alignment: .center, spacing: 12) {
                unitPickerColumn(title: "From", selection: $vm.selectedFromUnitID)
                swapButton
                unitPickerColumn(title: "To", selection: $vm.selectedToUnitID)
            }
        }
    }

    private var customUnitsSection: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.tightSpacing) {
            sectionLabel("My custom units")

            if customUnits.isEmpty {
                emptyCustomUnitsPlaceholder
            } else {
                ForEach(customUnits) { unit in
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
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
        .padding(ConverterLayout.cardPadding - 4)
        .background(
            RoundedRectangle(cornerRadius: ConverterLayout.insetCornerRadius, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    private var emptyCustomUnitsPlaceholder: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "square.dashed")
                .font(.title2)
                .foregroundStyle(.tertiary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
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
            vm.swapUnits()
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ConverterLayout.insetCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Swap from and to units")
    }

    private func unitPickerColumn(title: String, selection: Binding<UnitDefinition.ID>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(vm.availableUnits, id: \.id) { unit in
                    Text(unit.name).tag(unit.id)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.blockSpacing) {
            HStack(alignment: .center) {
                sectionLabel("Result")
                Spacer(minLength: 8)
                if canShareResult {
                    Menu {
                        Button("Share as Text") {
                            presentShareText()
                        }
                        Button("Share as Image") {
                            presentShareImage()
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Share result")
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
                        meme: result.memeExplanation
                    )
                } else {
                    resultEmptyPlaceholder
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ConverterLayout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: ConverterLayout.cardCornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ConverterLayout.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.55)
    }

    private func validationErrorView(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.body)
                .foregroundStyle(.red.opacity(0.9))
                .accessibilityHidden(true)
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
    }

    private var resultEmptyPlaceholder: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "function")
                .font(.title2)
                .foregroundStyle(.tertiary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("No result yet")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Enter a number and pick units above. Invalid input is called out in red.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let taxonomy = AppTaxonomyStore()
    ConverterView(vm: ConverterViewModel(taxonomy: taxonomy))
        .environmentObject(taxonomy)
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self], inMemory: true)
}
