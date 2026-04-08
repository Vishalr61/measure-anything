import Foundation

/// Validated taxonomy with O(1) lookups. Mirrors the TypeScript `taxonomy/registry.ts` rules.
public struct TaxonomyRegistry: Sendable {
    public enum RegistryError: Error, Equatable, LocalizedError {
        case duplicateDomainId(String)
        case duplicateSubgenreId(String)
        case duplicateItemId(String)
        case subgenreUnknownDomain(subgenreId: String, domainId: String)
        case itemUnknownDomain(itemId: String, domainId: String)
        case itemUnknownSubgenre(itemId: String, subgenreId: String)
        case itemDomainMismatch(itemId: String, itemDomainId: String, subgenreId: String, subgenreDomainId: String)
        case resourceNotFound(String)

        public var errorDescription: String? {
            switch self {
            case .duplicateDomainId(let id): "Duplicate domain id: \(id)"
            case .duplicateSubgenreId(let id): "Duplicate subgenre id: \(id)"
            case .duplicateItemId(let id): "Duplicate item id: \(id)"
            case .subgenreUnknownDomain(let s, let d): "Subgenre \(s) references unknown domain \(d)"
            case .itemUnknownDomain(let i, let d): "Item \(i) references unknown domain \(d)"
            case .itemUnknownSubgenre(let i, let s): "Item \(i) references unknown subgenre \(s)"
            case .itemDomainMismatch(let i, let idom, let s, let sdom):
                "Item \(i) domainId \(idom) does not match subgenre \(s) domainId \(sdom)"
            case .resourceNotFound(let name): "Missing bundled resource: \(name)"
            }
        }
    }

    public let domains: [Domain]
    public let subgenres: [Subgenre]
    public let items: [Item]

    public let domainById: [Domain.ID: Domain]
    public let subgenreById: [Subgenre.ID: Subgenre]
    public let itemById: [Item.ID: Item]
    public let subgenresByDomainId: [Domain.ID: [Subgenre]]
    public let itemsBySubgenreId: [Subgenre.ID: [Item]]

    /// Loads and validates `taxonomy.json` from the `MeasureAnythingTaxonomy` resource bundle.
    public init() throws {
        try self.init(bundle: Bundle.module)
    }

    /// Loads and validates `taxonomy.json` from the given bundle (for tests or alternate packaging).
    public init(bundle: Bundle) throws {
        guard let url = bundle.url(forResource: "taxonomy", withExtension: "json") else {
            throw RegistryError.resourceNotFound("taxonomy.json")
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let bundleDecoded = try decoder.decode(TaxonomyBundle.self, from: data)
        try Self.validate(bundleDecoded)
        self.domains = bundleDecoded.domains
        self.subgenres = bundleDecoded.subgenres
        self.items = bundleDecoded.items

        var dMap: [Domain.ID: Domain] = [:]
        for d in domains {
            dMap[d.id] = d
        }
        self.domainById = dMap

        var sMap: [Subgenre.ID: Subgenre] = [:]
        var sByD: [Domain.ID: [Subgenre]] = [:]
        for s in subgenres {
            sMap[s.id] = s
            sByD[s.domainId, default: []].append(s)
        }
        self.subgenreById = sMap
        self.subgenresByDomainId = sByD

        var iMap: [Item.ID: Item] = [:]
        var iByS: [Subgenre.ID: [Item]] = [:]
        for item in items {
            iMap[item.id] = item
            iByS[item.subgenreId, default: []].append(item)
        }
        self.itemById = iMap
        self.itemsBySubgenreId = iByS
    }

    public static func validate(_ bundle: TaxonomyBundle) throws {
        var seenDomains = Set<Domain.ID>()
        for d in bundle.domains {
            guard seenDomains.insert(d.id).inserted else {
                throw RegistryError.duplicateDomainId(d.id)
            }
        }

        var seenSubgenres = Set<Subgenre.ID>()
        for s in bundle.subgenres {
            guard seenSubgenres.insert(s.id).inserted else {
                throw RegistryError.duplicateSubgenreId(s.id)
            }
            guard seenDomains.contains(s.domainId) else {
                throw RegistryError.subgenreUnknownDomain(subgenreId: s.id, domainId: s.domainId)
            }
        }

        let subgenreById = Dictionary(uniqueKeysWithValues: bundle.subgenres.map { ($0.id, $0) })

        var seenItems = Set<Item.ID>()
        for item in bundle.items {
            guard seenItems.insert(item.id).inserted else {
                throw RegistryError.duplicateItemId(item.id)
            }
            guard seenDomains.contains(item.domainId) else {
                throw RegistryError.itemUnknownDomain(itemId: item.id, domainId: item.domainId)
            }
            guard let sg = subgenreById[item.subgenreId] else {
                throw RegistryError.itemUnknownSubgenre(itemId: item.id, subgenreId: item.subgenreId)
            }
            guard sg.domainId == item.domainId else {
                throw RegistryError.itemDomainMismatch(
                    itemId: item.id,
                    itemDomainId: item.domainId,
                    subgenreId: sg.id,
                    subgenreDomainId: sg.domainId
                )
            }
        }
    }
}
