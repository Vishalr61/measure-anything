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
        let pairKey = "\(from)→\(to)"
        var next = frequency
        next[pairKey, default: 0] += 1
        frequency = next
    }

    func suggestions(for fromUnit: String, limit: Int = 3) -> [String] {
        frequency
            .filter { $0.key.hasPrefix("\(fromUnit)→") }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .compactMap { $0.key.components(separatedBy: "→").last }
    }
}
