import Foundation
import MeasureAnythingCore
import Testing
@testable import MeasureAnything

struct ConversionHistoryTests {
    @Test func clearRecentPairsAlsoClearsSuggestionsAndCounts() {
        let suiteName = "ConversionHistoryTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }

        defaults.removePersistentDomain(forName: suiteName)
        let history = ConversionHistory(defaults: defaults)

        history.record(from: "meter", to: "kilometer", category: .length)
        history.record(from: "meter", to: "mile", category: .length)

        #expect(history.totalRecordedConversions == 2)
        #expect(history.hasRecentPairs)
        #expect(history.suggestions(for: "meter", limit: 5).count == 2)

        history.clearRecentPairs()

        #expect(history.totalRecordedConversions == 0)
        #expect(!history.hasRecentPairs)
        #expect(history.recentToUnits(limit: 5).isEmpty)
        #expect(history.recentPairs(limit: 5).isEmpty)
        #expect(history.suggestions(for: "meter", limit: 5).isEmpty)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func recordDeduplicatesRecentPairsButKeepsFrequency() {
        let suiteName = "ConversionHistoryTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }

        defaults.removePersistentDomain(forName: suiteName)
        let history = ConversionHistory(defaults: defaults)

        history.record(from: "meter", to: "kilometer", category: .length)
        history.record(from: "meter", to: "kilometer", category: .length)
        history.record(from: "meter", to: "mile", category: .length)

        let pairs = history.recentPairs(limit: 5)

        #expect(history.totalRecordedConversions == 3)
        #expect(pairs.count == 2)
        #expect(pairs.first?.toUnitID == "mile")
        #expect(history.suggestions(for: "meter", limit: 5) == ["kilometer", "mile"])

        defaults.removePersistentDomain(forName: suiteName)
    }
}
