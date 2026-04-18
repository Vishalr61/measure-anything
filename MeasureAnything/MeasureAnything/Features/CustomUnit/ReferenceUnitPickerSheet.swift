import SwiftUI
import MeasureAnythingCore

/// Picks a **standard** (`.normal`) reference unit for custom-unit sizing — never absurd or custom.
struct ReferenceUnitPickerSheet: View {
    let category: UnitCategory
    @Binding var selectedUnitID: String
    let registry: UnitRegistry

    @Environment(\.dismiss) private var dismiss

    private var units: [UnitDefinition] {
        registry.units(in: category, includeKinds: [.normal])
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(units, id: \.id) { unit in
                    Button {
                        selectedUnitID = unit.id
                        dismiss()
                    } label: {
                        HStack {
                            Text(unit.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if unit.id == selectedUnitID {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reference unit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
