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
                        customUnitRow(unit)
                            .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .listRowSpacing(10)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("My custom units")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func customUnitRow(_ unit: CustomUnit) -> some View {
        let category = UnitCategory(rawValue: unit.categoryRaw) ?? .length
        let categoryAccent = ConverterCategoryAccent.accent(for: category)

        HStack(spacing: 14) {
            // Icon tile — same treatment as Favorites cards
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(categoryAccent.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: category.symbolName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(categoryAccent)
                )

            // Text info
            VStack(alignment: .leading, spacing: 2) {
                Text(unit.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(valueLine(for: unit))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Category pill
            Text(category.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(categoryAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(categoryAccent.opacity(0.1)))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        )
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
