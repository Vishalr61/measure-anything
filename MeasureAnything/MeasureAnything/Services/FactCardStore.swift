import Foundation

/// Loads `FactCardContent.json` once; keyed by unit id (`UnitDefinition.id`).
final class FactCardStore {
    /// Loads on first access; `init` always succeeds so the static singleton is never left in a failed state.
    static let shared = FactCardStore(entries: FactCardStore.loadEntries())

    /// Hardcoded preview unit for DEBUG sheet shell (step 2).
    static let devPreviewUnitID = "blue_whale_mass"

    private let entries: [String: FactCardEntry]

    private init(entries: [String: FactCardEntry]) {
        self.entries = entries
    }

    private static func loadEntries() -> [String: FactCardEntry] {
        guard let url = Bundle.main.url(forResource: "FactCardContent", withExtension: "json") else {
            #if DEBUG
            print("FactCardStore: FactCardContent.json not in bundle")
            #endif
            return [:]
        }
        guard let data = try? Data(contentsOf: url) else {
            return [:]
        }
        guard let decoded = try? JSONDecoder().decode(FactCardContent.self, from: data) else {
            #if DEBUG
            print("FactCardStore: FactCardContent.json decode failed")
            #endif
            return [:]
        }
        return decoded.cards
    }

    func entry(for unitID: String) -> FactCardEntry? {
        entries[unitID]
    }
}
