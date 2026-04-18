import SwiftData
import SwiftUI
import MeasureAnythingCore

/// Lists SwiftData custom units; delete via swipe. Opened from Settings.
struct CustomUnitsListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var vm: ConverterViewModel
    @Query(sort: \CustomUnit.name) private var customUnits: [CustomUnit]

    var body: some View {
        Group {
            if customUnits.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No custom units yet. Tap + on the Convert page to create one.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
            } else {
                List {
                    ForEach(customUnits) { unit in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(unit.name)
                                .font(.body.weight(.medium))
                            Text(unit.categoryRaw.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(valueLine(for: unit))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("My custom units")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func valueLine(for unit: CustomUnit) -> String {
        guard let def = try? unit.toUnitDefinition() else { return "—" }
        if let refID = unit.referenceUnitID,
           let ref = try? vm.currentRegistry.unit(id: refID),
           ref.kind == .normal
        {
            let refF = ref.factor ?? 1
            guard refF > 0 else { return fallbackFactorLine(unit: unit, def: def) }
            let displayVal = unit.factor / refF
            let num = vm.formatNumberForDisplay(displayVal)
            let suffix = referenceShortLabel(ref)
            return "\(num) \(suffix)"
        }
        return fallbackFactorLine(unit: unit, def: def)
    }

    private func fallbackFactorLine(unit: CustomUnit, def: UnitDefinition) -> String {
        let num = vm.formatNumberForDisplay(unit.factor)
        return "\(num) \(def.baseUnitSymbol)"
    }

    private func referenceShortLabel(_ u: UnitDefinition) -> String {
        switch u.id {
        case "kilometer": return "km"
        case "meter": return "m"
        case "centimeter": return "cm"
        case "millimeter": return "mm"
        case "mile": return "mi"
        case "inch": return "in"
        case "foot": return "ft"
        case "kilogram": return "kg"
        case "gram": return "g"
        case "pound": return "lb"
        case "second": return "s"
        case "minute": return "min"
        case "hour": return "h"
        case "liter": return "L"
        case "milliliter": return "mL"
        default: return u.name
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(customUnits[index])
        }
    }
}
