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
        case converterUnknownMeasurementDomain(String)
        case converterUnknownSubgenre(String)
        case converterSubgenreWrongDomain(subgenreId: String, expectedDomain: String, actualDomain: String)
        case converterDuplicateCategoryRaw(String)
        case converterDuplicateModeRaw(String)
        case converterEmptyNavigation(field: String)

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
            case .converterUnknownMeasurementDomain(let id): "converterNavigation references unknown domain \(id)"
            case .converterUnknownSubgenre(let id): "converterNavigation references unknown subgenre \(id)"
            case .converterSubgenreWrongDomain(let s, let exp, let act):
                "converterNavigation: subgenre \(s) must belong to domain \(exp) (is \(act))"
            case .converterDuplicateCategoryRaw(let raw): "Duplicate converterNavigation category \(raw)"
            case .converterDuplicateModeRaw(let raw): "Duplicate converterNavigation mode \(raw)"
            case .converterEmptyNavigation(let field): "converterNavigation.\(field) must not be empty"
            }
        }
    }

    public let domains: [Domain]
    public let subgenres: [Subgenre]
    public let items: [Item]
    /// Parsed optional bridge for converter UI ordering; `nil` if absent from JSON.
    public let converterNavigation: ConverterNavigation?

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
        self.converterNavigation = bundleDecoded.converterNavigation

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

        if let nav = bundle.converterNavigation {
            try validateConverterNavigation(nav, bundle: bundle)
        }
    }

    private static func validateConverterNavigation(_ nav: ConverterNavigation, bundle: TaxonomyBundle) throws {
        guard bundle.domains.contains(where: { $0.id == nav.measurementDomainId }) else {
            throw RegistryError.converterUnknownMeasurementDomain(nav.measurementDomainId)
        }
        guard !nav.categories.isEmpty else {
            throw RegistryError.converterEmptyNavigation(field: "categories")
        }
        guard !nav.modes.isEmpty else {
            throw RegistryError.converterEmptyNavigation(field: "modes")
        }

        var seenCategories = Set<String>()
        for row in nav.categories {
            guard seenCategories.insert(row.unitCategoryRaw).inserted else {
                throw RegistryError.converterDuplicateCategoryRaw(row.unitCategoryRaw)
            }
        }

        let subgenreById = Dictionary(uniqueKeysWithValues: bundle.subgenres.map { ($0.id, $0) })
        var seenModes = Set<String>()
        for row in nav.modes {
            guard seenModes.insert(row.modeRaw).inserted else {
                throw RegistryError.converterDuplicateModeRaw(row.modeRaw)
            }
            guard let sg = subgenreById[row.subgenreId] else {
                throw RegistryError.converterUnknownSubgenre(row.subgenreId)
            }
            guard sg.domainId == nav.measurementDomainId else {
                throw RegistryError.converterSubgenreWrongDomain(
                    subgenreId: row.subgenreId,
                    expectedDomain: nav.measurementDomainId,
                    actualDomain: sg.domainId
                )
            }
        }
    }
}
