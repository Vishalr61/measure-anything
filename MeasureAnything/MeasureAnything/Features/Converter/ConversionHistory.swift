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

    func record(from: String, to: String) {
        guard from != to else { return }
        let pairKey = "\(from)→\(to)"
        var next = frequency
        next[pairKey, default: 0] += 1
        frequency = next
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
