import Foundation

/// Top-level taxonomy bucket (e.g. Measurement, Lifestyle).
public struct Domain: Codable, Hashable, Sendable, Identifiable {
    public typealias ID = String

    public let id: ID
    public var name: String
    public var description: String
}

/// Grouping within a domain. Always references exactly one `Domain`.
public struct Subgenre: Codable, Hashable, Sendable, Identifiable {
    public typealias ID = String

    public let id: ID
    public var domainId: Domain.ID
    public var name: String
    public var description: String
}

/// Leaf content node. References exactly one domain and one subgenre in that domain.
public struct Item: Codable, Hashable, Sendable, Identifiable {
    public typealias ID = String

    public let id: ID
    public var domainId: Domain.ID
    public var subgenreId: Subgenre.ID
    public var name: String
    public var description: String
}

/// Binds the converter’s `UnitCategory` / `Mode` pickers to taxonomy rows (order + subgenre anchors).
///
/// Validated by `TaxonomyRegistry` when present: domain and subgenre IDs must exist and subgenres must
/// belong to `measurementDomainId`. The app resolves `unitCategoryRaw` / `modeRaw` to core enums.
public struct ConverterNavigation: Codable, Hashable, Sendable {
    public var measurementDomainId: Domain.ID
    public var categories: [CategoryRow]
    public var modes: [ModeRow]

    public struct CategoryRow: Codable, Hashable, Sendable {
        public var unitCategoryRaw: String
    }

    public struct ModeRow: Codable, Hashable, Sendable {
        public var modeRaw: String
        public var subgenreId: Subgenre.ID
    }
}

/// JSON envelope for `taxonomy.json`.
public struct TaxonomyBundle: Codable, Hashable, Sendable {
    public var domains: [Domain]
    public var subgenres: [Subgenre]
    public var items: [Item]
    /// When omitted, apps fall back to `CaseIterable` ordering for categories and modes.
    public var converterNavigation: ConverterNavigation?
}
