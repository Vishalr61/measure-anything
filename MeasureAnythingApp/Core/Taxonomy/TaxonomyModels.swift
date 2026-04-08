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

/// JSON envelope for `taxonomy.json`.
public struct TaxonomyBundle: Codable, Hashable, Sendable {
    public var domains: [Domain]
    public var subgenres: [Subgenre]
    public var items: [Item]
}
