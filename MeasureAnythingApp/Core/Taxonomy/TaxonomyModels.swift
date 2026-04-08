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
public struct Item: Hashable, Sendable, Identifiable {
    public typealias ID = String

    public let id: ID
    public var domainId: Domain.ID
    public var subgenreId: Subgenre.ID
    public var name: String
    public var description: String
    /// Alternate names for search (optional in JSON; defaults to empty).
    public var synonyms: [String]
    /// Free-form labels for search (optional in JSON; defaults to empty).
    public var tags: [String]
    /// When set, enables `UnitCategory`-based filtering in app search (`UnitCategory.rawValue`).
    public var unitCategoryRaw: String?
    /// When set, maps this taxonomy item to a `UnitDefinition.id` in the conversion engine.
    public var converterUnitId: String?

    enum CodingKeys: String, CodingKey {
        case id, domainId, subgenreId, name, description, synonyms, tags, unitCategoryRaw, converterUnitId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ID.self, forKey: .id)
        domainId = try c.decode(Domain.ID.self, forKey: .domainId)
        subgenreId = try c.decode(Subgenre.ID.self, forKey: .subgenreId)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decode(String.self, forKey: .description)
        synonyms = try c.decodeIfPresent([String].self, forKey: .synonyms) ?? []
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        unitCategoryRaw = try c.decodeIfPresent(String.self, forKey: .unitCategoryRaw)
        converterUnitId = try c.decodeIfPresent(String.self, forKey: .converterUnitId)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(domainId, forKey: .domainId)
        try c.encode(subgenreId, forKey: .subgenreId)
        try c.encode(name, forKey: .name)
        try c.encode(description, forKey: .description)
        if !synonyms.isEmpty {
            try c.encode(synonyms, forKey: .synonyms)
        }
        if !tags.isEmpty {
            try c.encode(tags, forKey: .tags)
        }
        try c.encodeIfPresent(unitCategoryRaw, forKey: .unitCategoryRaw)
        try c.encodeIfPresent(converterUnitId, forKey: .converterUnitId)
    }
}

extension Item: Codable {}

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
        /// When set, shown instead of `unitCategoryRaw.capitalized`.
        public var displayName: String?
        /// Optional picker hint or accessibility detail.
        public var description: String?
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
