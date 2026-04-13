import Foundation

final class ConversionHistory {
    static let shared = ConversionHistory()

    private let key = "conversionPairFrequency"

    private var frequency: [String: Int] {
        get {
            (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    /// Sum of all recorded completed conversions (used for suggestion visibility threshold).
    var totalRecordedConversions: Int {
        frequency.values.reduce(0, +)
    }

    private let recencyKey = "recentToUnits"

    private let pairsKey = "recentConversionPairs"

    func record(from: String, to: String) {
        guard from != to else { return }
        let pairKey = "\(from)→\(to)"
        var next = frequency
        next[pairKey, default: 0] += 1
        frequency = next

        var recent = UserDefaults.standard.stringArray(forKey: recencyKey) ?? []
        recent.removeAll { $0 == to }
        recent.insert(to, at: 0)
        if recent.count > 20 { recent = Array(recent.prefix(20)) }
        UserDefaults.standard.set(recent, forKey: recencyKey)

        var pairs = UserDefaults.standard.array(forKey: pairsKey) as? [[String: String]] ?? []
        let newPair: [String: String] = ["from": from, "to": to]
        pairs.removeAll { $0["from"] == from && $0["to"] == to }
        pairs.insert(newPair, at: 0)
        if pairs.count > 20 { pairs = Array(pairs.prefix(20)) }
        UserDefaults.standard.set(pairs, forKey: pairsKey)
    }

    func recentToUnits(limit: Int) -> [String] {
        let raw = UserDefaults.standard.stringArray(forKey: recencyKey) ?? []
        return Array(raw.prefix(limit))
    }

    struct ConversionPair {
        let fromUnitID: String
        let toUnitID: String
    }

    func recentPairs(limit: Int) -> [ConversionPair] {
        let raw = UserDefaults.standard.array(forKey: pairsKey) as? [[String: String]] ?? []
        return raw.prefix(limit).compactMap { dict in
            guard let from = dict["from"], let to = dict["to"] else { return nil }
            return ConversionPair(fromUnitID: from, toUnitID: to)
        }
    }

    func clearRecentPairs() {
        UserDefaults.standard.removeObject(forKey: pairsKey)
        UserDefaults.standard.removeObject(forKey: recencyKey)
    }

    /// Top destination unit IDs for this `from` unit, excluding self-conversions (`from→from`).
    func suggestions(for fromUnit: String, limit: Int = 3) -> [String] {
        let prefix = "\(fromUnit)→"
        return Array(
            frequency
                .filter { $0.key.hasPrefix(prefix) }
                .sorted { $0.value > $1.value }
                .compactMap { pair -> String? in
                    let key = pair.key
                    guard let to = key.components(separatedBy: "→").last, to != fromUnit else { return nil }
                    return to
                }
                .prefix(limit)
        )
    }
}
