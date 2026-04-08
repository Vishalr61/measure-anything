import SwiftUI
import SwiftData
import MeasureAnythingCore

/// Create a custom multiplicative unit (local-only, v1).
struct CustomUnitFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var category: UnitCategory = .length
    @State private var factorText: String = "1"
    @State private var iconName: String = ""
    @State private var detail: String = ""
    @State private var saveError: String?

    private var canonicalBase: String {
        category.canonicalBaseUnit ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Unit")
                }

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(UnitCategory.customAllowed, id: \.self) { cat in
                            Text(cat.rawValue.capitalized).tag(cat)
                        }
                    }
                    HStack {
                        Text("Base unit")
                        Spacer()
                        Text(canonicalBase)
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }
                    .accessibilityElement(children: .combine)
                } header: {
                    Text("Measurement")
                } footer: {
                    Text("Factor is how many \(canonicalBase) equal **one** of your unit (same rule as built-in absurd units).")
                }

                Section {
                    TextField("Factor", text: $factorText)
                        .keyboardType(.decimalPad)
                        .font(.body.monospacedDigit())
                } header: {
                    Text("Factor")
                }

                Section {
                    TextField("SF Symbol name (optional)", text: $iconName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Description (optional)", text: $detail, axis: .vertical)
                        .lineLimit(3 ... 6)
                } header: {
                    Text("Optional")
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("New custom unit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        saveError = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            saveError = "Enter a name."
            return
        }
        let normalized = factorText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard let factor = Double(normalized), factor > 0, factor.isFinite else {
            saveError = "Enter a positive number for factor."
            return
        }
        guard let base = category.canonicalBaseUnit else {
            saveError = "This category cannot use custom units."
            return
        }

        let unit = CustomUnit(
            name: trimmedName,
            category: category,
            baseUnit: base,
            factor: factor,
            iconName: iconName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : iconName.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : detail.trimmingCharacters(in: .whitespacesAndNewlines)
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
}

#Preview {
    CustomUnitFormView()
        .modelContainer(for: CustomUnit.self, inMemory: true)
}
