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

    private var accent: Color {
        ConverterCategoryAccent.accent(for: category)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                customHeader

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
            }
            .navigationBarHidden(true)
        }
    }

    /// Custom header HStack — avoids iOS's toolbar pill background on the Cancel button.
    private var customHeader: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .buttonStyle(.plain)

            Spacer()

            Text("Reference unit")
                .font(.system(size: 18, weight: .semibold))

            Spacer()

            // Balance spacer so the title stays centred.
            Text("Cancel")
                .font(.system(size: 16, weight: .semibold))
                .opacity(0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }
}
