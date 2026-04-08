import SwiftUI
import SwiftData
import MeasureAnythingCore

struct ConverterView: View {
    @Query(sort: \CustomUnit.name) private var customUnits: [CustomUnit]
    @Query(sort: \FavoriteConversion.createdAt, order: .reverse) private var favorites: [FavoriteConversion]
    @Environment(\.modelContext) private var modelContext

    @StateObject private var vm = ConverterViewModel()
    @FocusState private var valueFieldFocused: Bool
    @State private var showCustomUnitForm = false
    @State private var showFavorites = false
    @State private var showShareSheet = false
    @State private var shareActivityItems: [Any] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    inputs
                    if vm.selectedMode == .custom {
                        customUnitsSection
                    }
                    resultCard
                }
                .padding()
            }
            .navigationTitle("Measure Anything")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Favorites", systemImage: "list.star") {
                        showFavorites = true
                    }
                    .accessibilityLabel("View favorites")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        saveCurrentPairAsFavorite()
                    } label: {
                        Image(systemName: isCurrentPairAlreadyFavorite ? "star.fill" : "star")
                    }
                    .disabled(!canSaveFavoriteTap)
                    .accessibilityLabel(isCurrentPairAlreadyFavorite ? "Already a favorite" : "Save as favorite")

                    if vm.selectedMode == .custom {
                        Button("Add unit", systemImage: "plus") {
                            showCustomUnitForm = true
                        }
                        .accessibilityLabel("Add custom unit")
                    }
                }
            }
            .sheet(isPresented: $showCustomUnitForm) {
                CustomUnitFormView()
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
    }

    /// Changes when rows are inserted, updated, or deleted.
    private var customUnitsSyncToken: String {
        customUnits
            .map { "\($0.id)|\($0.factor)|\($0.name)|\($0.categoryRaw)" }
            .sorted()
            .joined(separator: ";")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Category", selection: $vm.selectedCategory) {
                ForEach(vm.categories, id: \.self) { category in
                    Text(category.rawValue.capitalized).tag(category)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Picker("Mode", selection: $vm.selectedMode) {
                    ForEach(vm.modes, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Explain like a meme", isOn: $vm.isMemeExplanationEnabled)
            }
        }
    }

    private var inputs: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

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

            HStack(alignment: .top, spacing: 12) {
                unitPickerColumn(title: "From", selection: $vm.selectedFromUnitID)
                swapButton
                unitPickerColumn(title: "To", selection: $vm.selectedToUnitID)
            }
        }
    }

    private var customUnitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("My custom units")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if customUnits.isEmpty {
                Text("None yet. Tap + to create one for this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(customUnits) { unit in
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(unit.name)
                                .font(.body.weight(.medium))
                            Text(unit.categoryRaw.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
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
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    private var swapButton: some View {
        Button(action: { vm.swapUnits() }) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Swap from and to units")
        .padding(.top, 22)
    }

    private func unitPickerColumn(title: String, selection: Binding<UnitDefinition.ID>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Result")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
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
                    }
                    .accessibilityLabel("Share result")
                }
            }

            if let err = vm.validationError {
                Text(err)
                    .font(.body)
                    .foregroundStyle(.red)
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
                Text("Choose units and enter a value.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview {
    ConverterView()
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self], inMemory: true)
}
