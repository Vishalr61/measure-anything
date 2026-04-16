import SwiftData
import SwiftUI
import MeasureAnythingCore

/// Lists SwiftData custom units; delete via swipe. Opened from Settings.
struct CustomUnitsListView: View {
    @Environment(\.modelContext) private var modelContext
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
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 6
        nf.minimumFractionDigits = 0
        nf.locale = Locale(identifier: "en_US")
        let num = nf.string(from: NSNumber(value: unit.factor)) ?? String(unit.factor)
        return "\(num) \(def.baseUnitSymbol)"
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(customUnits[index])
        }
    }
}
