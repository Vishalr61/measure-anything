import Foundation

/// Where a unit definition originates from.
public enum UnitKind: String, CaseIterable, Codable, Hashable, Sendable {
    /// Built-in real-world units (e.g., meter, kilometer, pound).
    case normal
    /// Built-in meme units loaded from shipped JSON (e.g., banana).
    case absurd
    /// User-created units (persisted locally in v1).
    case custom
}

