import Foundation
import MeasureAnythingCore

/// Loads per-category `FactCardContent_<Category>.json` files and merges into one lookup keyed by `UnitDefinition.id`.
final class FactCardStore {
    /// Loads on first access; `init` always succeeds so the static singleton is never left in a failed state.
    static let shared = FactCardStore(entries: FactCardStore.loadEntries())

    /// Hardcoded preview unit for DEBUG sheet shell (step 2).
    static let devPreviewUnitID = "blue_whale_mass"

    private static let resourceSpecs: [(resourceName: String, category: UnitCategory)] = [
        ("FactCardContent_Mass", .mass),
        ("FactCardContent_Length", .length),
        ("FactCardContent_Volume", .volume),
        ("FactCardContent_Time", .time),
        ("FactCardContent_Temperature", .temperature),
    ]

    private let entries: [String: FactCardEntry]

    private init(entries: [String: FactCardEntry]) {
        self.entries = entries
    }

    private static func loadEntries() -> [String: FactCardEntry] {
        var merged: [String: FactCardEntry] = [:]
        let decoder = JSONDecoder()

        for spec in resourceSpecs {
            guard let url = Bundle.main.url(forResource: spec.resourceName, withExtension: "json") else {
                print("FactCardStore: missing bundle resource \(spec.resourceName).json (category \(spec.category.rawValue))")
                continue
            }
            guard let data = try? Data(contentsOf: url) else {
                print("FactCardStore: could not read data from \(spec.resourceName).json")
                continue
            }
            do {
                let decoded = try decoder.decode(FactCardContent.self, from: data)
                for (unitID, entry) in decoded.cards {
                    if merged[unitID] != nil {
                        print("FactCardStore: duplicate card id '\(unitID)' in \(spec.resourceName).json — keeping first loaded entry")
                        continue
                    }
                    merged[unitID] = entry
                }
            } catch {
                print("FactCardStore: decode failed for \(spec.resourceName).json (\(spec.category.rawValue)): \(error.localizedDescription)")
            }
        }

        return merged
    }

    func entry(for unitID: String) -> FactCardEntry? {
        entries[unitID]
    }
}
