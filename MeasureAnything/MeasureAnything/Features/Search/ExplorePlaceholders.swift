import Foundation

/// Rotating search placeholders for the Explore tab (first visit uses `defaultPlaceholder`).
enum ExplorePlaceholders {
    static let defaultPlaceholder = "Search units…"

    /// UserDefaults: first Explore `onAppear` shows `defaultPlaceholder`; afterward we rotate.
    static let hasSeenExploreOnceKey = "hasSeenExploreOnce"

    /// UserDefaults: last chosen rotating placeholder (avoids immediate repetition).
    static let lastRotatingPlaceholderKey = "exploreSearchPlaceholderLast"

    private static let pool: [String] = [
        "Try \"blue whale\"",
        "Try \"parsec\"",
        "Try \"aircraft carrier\"",
        "Try \"grain of rice\"",
        "Try \"light year\"",
        "Try \"furlong\"",
        "Try \"eye drop\"",
        "Try \"smoot\"",
        "Try \"fortnight\"",
        "Try \"deep space\"",
    ]

    /// Call from Explore browse `onAppear` to refresh `searchPlaceholder` in place.
    static func refreshPlaceholder(searchPlaceholder: inout String) {
        let d = UserDefaults.standard
        if !d.bool(forKey: hasSeenExploreOnceKey) {
            searchPlaceholder = defaultPlaceholder
            d.set(true, forKey: hasSeenExploreOnceKey)
            return
        }

        let last = d.string(forKey: lastRotatingPlaceholderKey)
        var pick = pool.randomElement() ?? defaultPlaceholder
        if pick == last, pool.count > 1 {
            pick = pool.randomElement() ?? defaultPlaceholder
        }
        d.set(pick, forKey: lastRotatingPlaceholderKey)
        searchPlaceholder = pick
    }
}
