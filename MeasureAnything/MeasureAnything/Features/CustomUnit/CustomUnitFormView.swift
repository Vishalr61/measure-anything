import SwiftData
import SwiftUI
import UIKit
import MeasureAnythingCore

/// Holds the pre-edit snapshot of the decimal value field outside SwiftUI's `@State` so
/// capturing it on focus does NOT trigger a view rebuild during keyboard presentation.
private final class ValueEditSession {
    var snapshot: String?
}

/// Create a custom multiplicative unit (local-only, v1). Create-only — no edit mode.
struct CustomUnitFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var vm: ConverterViewModel

    @State private var name: String = ""
    @State private var selectedCategory: UnitCategory
    @State private var valueText: String = ""
    @State private var referenceUnitID: String
    @State private var detail: String = ""
    @State private var saveError: String?

    @State private var showUnitPicker = false
    @State private var previewLine1: String = ""
    @State private var previewLine2: String = ""
    @State private var previewTask: Task<Void, Never>?
    @State private var showTemperatureAlert = false
    @State private var valueEditSession = ValueEditSession()

    @FocusState private var valueFieldFocused: Bool

    init(initialCategory: UnitCategory = .length) {
        let allowed  = UnitCategory.customAllowed
        let resolved = allowed.contains(initialCategory) ? initialCategory : (allowed.first ?? .length)
        _selectedCategory = State(initialValue: resolved)
        _referenceUnitID  = State(initialValue: Self.canonicalReferenceUnitID(for: resolved))
    }

    private var accent: Color { ConverterCategoryAccent.accent(for: selectedCategory) }
    private var palette: CategoryPalette { ConverterCategoryPalette.palette(for: selectedCategory) }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var dynamicValueLabel: String { trimmedName.isEmpty ? "Your unit is" : "\(trimmedName) is" }

    private var canSave: Bool {
        guard !trimmedName.isEmpty else { return false }
        guard parsePositiveValue() != nil else { return false }
        guard let ref = try? vm.currentRegistry.unit(id: referenceUnitID),
              ref.category == selectedCategory,
              ref.kind == .normal
        else { return false }
        return true
    }

    private var referenceUnit: UnitDefinition? {
        try? vm.currentRegistry.unit(id: referenceUnitID)
    }

    // MARK: – Body

    var body: some View {
        NavigationStack {
            Form {
                whatSection
                howBigSection
                optionalSection

                if let err = saveError {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                // Live preview — shown only when there's something to show.
                // The temp card that appeared unconditionally has been removed.
                previewSection
            }
            .navigationTitle("Create a unit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(canSave ? accent : accent.opacity(0.4))
                        .disabled(!canSave)
                }
            }
        }
        .onAppear {
            schedulePreviewRefresh()
            if valueEditSession.snapshot == nil {
                valueEditSession.snapshot = valueText
            }
        }
        .onChange(of: name)           { _, _ in schedulePreviewRefresh() }
        .onChange(of: valueText)      { _, _ in schedulePreviewRefresh() }
        .onChange(of: referenceUnitID){ _, _ in schedulePreviewRefresh() }
        .onChange(of: valueFieldFocused) { _, isFocused in
            if isFocused { valueEditSession.snapshot = valueText }
        }
        .onChange(of: selectedCategory) { _, new in
            referenceUnitID = Self.canonicalReferenceUnitID(for: new)
            schedulePreviewRefresh()
        }
        .onDisappear {
            previewTask?.cancel()
            previewTask = nil
        }
        .sheet(isPresented: $showUnitPicker) {
            ReferenceUnitPickerSheet(
                category: selectedCategory,
                selectedUnitID: $referenceUnitID,
                registry: vm.currentRegistry
            )
        }
    }

    // MARK: – Sections

    private var whatSection: some View {
        Section {
            TextField("e.g. My commute, My dog, My lunch break", text: $name)
                .textInputAutocapitalization(.words)
        } header: {
            sectionHeader("What is it?")
        } footer: {
            Text("Give your unit a name you'll recognise.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var howBigSection: some View {
        Section {
            categoryChips

            VStack(alignment: .leading, spacing: 10) {
                Text(dynamicValueLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .center, spacing: 12) {
                    TextField("0", text: $valueText)
                        .keyboardType(.decimalPad)
                        .focused($valueFieldFocused)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .accessibilityLabel("Value in reference unit")

                    referenceUnitPill
                }
            }
            .padding(.vertical, 4)
        } header: {
            sectionHeader("How big is it?")
        } footer: {
            Text("Enter how many of the reference unit your unit equals.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(UnitCategory.customAllowed, id: \.self) { cat in
                    let selected   = selectedCategory == cat
                    let chipAccent = ConverterCategoryAccent.accent(for: cat)
                    Button {
                        Haptics.tap()
                        selectedCategory = cat
                    } label: {
                        Text(chipTitle(for: cat))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(selected ? chipAccent : Color(.systemGray5)))
                            .foregroundStyle(selected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(chipTitle(for: cat))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }

                temperatureComingSoonChip
            }
            .padding(.vertical, 4)
        }
        .alert("Temperature support coming soon", isPresented: $showTemperatureAlert) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("Temperature uses non-linear conversions (offsets, not just multipliers). Custom temperature units are on the roadmap for a future update.")
        }
    }

    private var temperatureComingSoonChip: some View {
        Button {
            Haptics.tap()
            showTemperatureAlert = true
        } label: {
            HStack(spacing: 6) {
                Text("Temperature")
                    .font(.subheadline.weight(.semibold))
                Text("SOON")
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(.systemGray3)))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color(.systemGray5).opacity(0.6)))
            .foregroundStyle(Color(.systemGray3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Temperature, coming soon")
        .accessibilityHint("Double-tap to learn more")
    }

    private var referenceUnitPill: some View {
        Button {
            Haptics.tap()
            valueFieldFocused = false
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
            DispatchQueue.main.async { showUnitPicker = true }
        } label: {
            HStack(spacing: 6) {
                Text(referenceUnit?.name ?? "—")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("▾")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var optionalSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Fun fact (optional)", text: $detail, axis: .vertical)
                    .lineLimit(3...6)
                Text("e.g. Takes 45 mins in traffic")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } header: {
            sectionHeader("Add a note")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(nil)   // keep sentence case — cleaner than all-caps here
    }

    // MARK: – Preview section
    // Appears only when name + value are both filled in.
    // The unconditional "temp card" that existed before is gone.

    @ViewBuilder
    private var previewSection: some View {
        // Only render when we have real content to show.
        if !trimmedName.isEmpty && parsePositiveValue() != nil
            && (!previewLine1.isEmpty || !previewLine2.isEmpty) {

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    if !previewLine1.isEmpty {
                        Text(previewLine1)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !previewLine2.isEmpty {
                        Text(previewLine2)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(0.1))
                )
                .listRowInsets(EdgeInsets(
                    top: 8,
                    leading: ConverterLayout.horizontalInset,
                    bottom: 8,
                    trailing: ConverterLayout.horizontalInset
                ))
            } header: {
                sectionHeader("Preview")
            }
        }
    }

    // MARK: – Save

    private func save() {
        saveError = nil
        guard canSave else { return }
        guard let base = selectedCategory.canonicalBaseUnit else {
            saveError = "This category cannot use custom units."
            return
        }
        guard let ref = try? vm.currentRegistry.unit(id: referenceUnitID),
              ref.category == selectedCategory,
              ref.kind == .normal,
              let v = parsePositiveValue()
        else {
            saveError = "Choose a valid reference unit."
            return
        }
        let refF = ref.factor ?? 1
        guard refF > 0 else { saveError = "Invalid reference unit."; return }
        let factor = v * refF

        let unit = CustomUnit(
            name: trimmedName,
            category: selectedCategory,
            baseUnit: base,
            factor: factor,
            referenceUnitID: referenceUnitID,
            iconName: Self.iconName(for: selectedCategory),
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : detail.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            _ = try unit.toUnitDefinition()
            modelContext.insert(unit)
            try modelContext.save()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: – Preview (debounced)

    private func schedulePreviewRefresh() {
        previewTask?.cancel()
        previewTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            refreshPreviewLines()
        }
    }

    private func refreshPreviewLines() {
        let n = trimmedName
        guard !n.isEmpty, let v = parsePositiveValue() else {
            previewLine1 = ""; previewLine2 = ""; return
        }
        guard let ref = try? vm.currentRegistry.unit(id: referenceUnitID),
              ref.category == selectedCategory,
              ref.kind == .normal
        else {
            previewLine1 = ""; previewLine2 = ""; return
        }
        let refF = ref.factor ?? 1
        guard refF > 0 else { previewLine1 = ""; previewLine2 = ""; return }
        let factor = v * refF

        let line1 = "1 \(n) = \(vm.formatNumberForDisplay(v)) \(referenceShortLabel(ref))"

        let absurdSorted = vm.currentRegistry
            .units(in: selectedCategory, includeKinds: [.absurd])
            .sorted { $0.id < $1.id }

        if let absurd = absurdPick(from: absurdSorted, seed: n + referenceUnitID + "\(v)") {
            let af = absurd.factor ?? 1
            if af > 0 {
                let count = factor / af
                previewLine1 = line1
                previewLine2 = absurdComparisonSecondLine(count: count, unitName: absurd.name)
                return
            }
        }

        let baseID  = Self.canonicalReferenceUnitID(for: selectedCategory)
        let baseDef = try? vm.currentRegistry.unit(id: baseID)
        let sym     = baseDef?.baseUnitSymbol ?? ""
        previewLine1 = line1
        previewLine2 = "= \(vm.formatNumberForDisplay(factor)) \(sym)"
    }

    private func absurdPick(from list: [UnitDefinition], seed: String) -> UnitDefinition? {
        guard !list.isEmpty else { return nil }
        var h = 0
        for u in seed.unicodeScalars { h = (h &* 31) &+ Int(u.value) }
        return list[abs(h) % list.count]
    }

    private func absurdComparisonSecondLine(count: Double, unitName: String) -> String {
        let exactOne = abs(count - 1.0) < 1e-9
        let displayNum: String
        let quantityForPlural: Double

        if exactOne {
            displayNum = "1"; quantityForPlural = 1
        } else {
            let nearest = round(count)
            if abs(count - nearest) <= 0.05 {
                let v = Int(nearest)
                displayNum = String(v); quantityForPlural = Double(v)
            } else {
                let r = (count * 10).rounded() / 10
                if abs(r - Double(Int(r))) < 1e-9 {
                    let intVal = Int(r)
                    displayNum = String(intVal); quantityForPlural = Double(intVal)
                } else {
                    displayNum = String(format: "%.1f", locale: Locale(identifier: "en_US"), arguments: [r])
                    quantityForPlural = r
                }
            }
        }

        let prefix = exactOne ? "=" : "≈"
        let label  = pluralizedAbsurdUnitName(unitName, quantity: quantityForPlural)
        return "\(prefix) \(displayNum) \(label)"
    }

    private func pluralizedAbsurdUnitName(_ name: String, quantity: Double) -> String {
        let isSingular = abs(quantity - 1.0) < 1e-9
        if isSingular { return name }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return name }
        if trimmed.lowercased().hasSuffix("s") { return name }
        return trimmed + "s"
    }

    // MARK: – Parsing & helpers

    private func parsePositiveValue() -> Double? {
        let normalized = valueText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let v = Double(normalized), v > 0, v.isFinite else { return nil }
        return v
    }

    private static func canonicalReferenceUnitID(for category: UnitCategory) -> String {
        category.canonicalBaseUnit ?? "meter"
    }

    private func chipTitle(for category: UnitCategory) -> String {
        switch category {
        case .length:      return "Length"
        case .mass:        return "Mass"
        case .time:        return "Time"
        case .volume:      return "Volume"
        case .temperature: return "Temperature"
        }
    }

    private func referenceShortLabel(_ u: UnitDefinition) -> String {
        switch u.id {
        case "kilometer":  return "km"
        case "meter":      return "m"
        case "centimeter": return "cm"
        case "millimeter": return "mm"
        case "micrometer": return "µm"
        case "nanometer":  return "nm"
        case "mile":       return "mi"
        case "inch":       return "in"
        case "foot":       return "ft"
        case "yard":       return "yd"
        case "kilogram":   return "kg"
        case "gram":       return "g"
        case "pound":      return "lb"
        case "ounce":      return "oz"
        case "second":     return "s"
        case "minute":     return "min"
        case "hour":       return "h"
        case "day":        return "d"
        case "liter":      return "L"
        case "milliliter": return "mL"
        default:           return u.name
        }
    }

    private static func iconName(for category: UnitCategory) -> String {
        switch category {
        case .length:  return "ruler"
        case .mass:    return "scalemass"
        case .time:    return "clock"
        case .volume:  return "drop"
        default:       return "star.circle"
        }
    }
}

#Preview {
    let taxonomy = AppTaxonomyStore()
    let vm = ConverterViewModel(taxonomy: taxonomy)
    CustomUnitFormView(initialCategory: .length)
        .environmentObject(vm)
        .modelContainer(for: CustomUnit.self, inMemory: true)
}
