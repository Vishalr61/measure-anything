import Foundation
import MeasureAnythingCore

// MARK: - Path (single breadcrumb builder)

/// Breadcrumb for a taxonomy or catalog row (`Domain / Subgenre / Title`).
public struct TaxonomyPathResult: Equatable, Sendable, Identifiable {
    public let id: String
    public let pathLine: String
    public let domainTitle: String
    public let subgenreTitle: String
    public let itemTitle: String

    public static let pathComponentSeparator = " / "
}

// MARK: - Normalized search row

/// Pre-normalized row for ranked search (built once at index creation).
public struct SearchableItem: Sendable {
    public let id: String
    public let title: String
    public let normalizedTitle: String
    public let synonyms: [String]
    public let normalizedSynonyms: [String]
    public let tags: [String]
    public let normalizedTags: [String]
    public let categoryId: String
    public let subcategoryId: String
    public let unitCategoryRaw: String?
    public let pathDomainTitle: String
    public let pathSubgenreTitle: String
    /// When set, selecting this row maps to this engine unit id (dedupe + routing).
    public let converterUnitId: String?
}

// MARK: - Match tier (lower = stronger)

public enum TaxonomySearchMatchTier: Int, Sendable, Comparable {
    case exactTitle = 0
    case prefixTitle = 1
    case exactSynonym = 2
    case prefixSynonym = 3
    case exactTag = 4
    case prefixTag = 5
    case tagContains = 6

    public static func < (lhs: TaxonomySearchMatchTier, rhs: TaxonomySearchMatchTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Path builder

public enum TaxonomyPathBuilder {
    public static func pathResult(for item: SearchableItem) -> TaxonomyPathResult {
        let pathLine = [item.pathDomainTitle, item.pathSubgenreTitle, item.title]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: TaxonomyPathResult.pathComponentSeparator)
        return TaxonomyPathResult(
            id: item.id,
            pathLine: pathLine,
            domainTitle: item.pathDomainTitle,
            subgenreTitle: item.pathSubgenreTitle,
            itemTitle: item.title
        )
    }

    /// Builds a searchable row from a bundled taxonomy `Item`, or `nil` if parents are missing or titles are empty.
    public static func makeSearchableItem(item: Item, registry: TaxonomyRegistry) -> SearchableItem? {
        guard let domain = registry.domainById[item.domainId],
              let sub = registry.subgenreById[item.subgenreId] else { return nil }
        let title = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let pathDomainTitle = domain.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathSubgenreTitle = sub.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pathDomainTitle.isEmpty, !pathSubgenreTitle.isEmpty else { return nil }

        let synRaw = item.synonyms.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let tagRaw = item.tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let trimmedUnit = item.converterUnitId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let convId = (trimmedUnit?.isEmpty == false) ? trimmedUnit : nil

        return SearchableItem(
            id: item.id,
            title: title,
            normalizedTitle: normalize(title),
            synonyms: synRaw,
            normalizedSynonyms: synRaw.map { normalize($0) },
            tags: tagRaw,
            normalizedTags: tagRaw.map { normalize($0) },
            categoryId: item.categoryId,
            subcategoryId: item.subcategoryId,
            unitCategoryRaw: item.unitCategoryRaw,
            pathDomainTitle: pathDomainTitle,
            pathSubgenreTitle: pathSubgenreTitle,
            converterUnitId: convId
        )
    }

    /// Synthetic row from a conversion `UnitDefinition` under the measurement domain (skips if nav/subgenres missing).
    public static func makeSearchableItem(unit: UnitDefinition, registry: TaxonomyRegistry) -> SearchableItem? {
        guard let measurementDomainId = registry.converterNavigation?.measurementDomainId,
              let domain = registry.domainById[measurementDomainId],
              domain.id == measurementDomainId else { return nil }
        let subId = subgenreId(for: unit.kind)
        guard let sub = registry.subgenreById[subId], sub.domainId == measurementDomainId else { return nil }

        let title = unit.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let pathDomainTitle = domain.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathSubgenreTitle = sub.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pathDomainTitle.isEmpty, !pathSubgenreTitle.isEmpty else { return nil }

        let catRaw = unit.category.rawValue
        let kindRaw = unit.kind.rawValue
        let tagRaw = [catRaw, kindRaw]
        let id = "unit:\(unit.id)"

        return SearchableItem(
            id: id,
            title: title,
            normalizedTitle: normalize(title),
            synonyms: [],
            normalizedSynonyms: [],
            tags: tagRaw,
            normalizedTags: tagRaw.map { normalize($0) },
            categoryId: measurementDomainId,
            subcategoryId: subId,
            unitCategoryRaw: catRaw,
            pathDomainTitle: pathDomainTitle,
            pathSubgenreTitle: pathSubgenreTitle,
            converterUnitId: unit.id
        )
    }

    private static func subgenreId(for kind: UnitKind) -> String {
        switch kind {
        case .normal: "measurement.normal"
        case .absurd: "measurement.absurd"
        case .custom: "measurement.custom"
        }
    }

    private static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

// MARK: - Index + search

/// Search index over taxonomy items plus optional unit-catalog rows (deduped by `converterUnitId`).
public struct TaxonomySearchIndex: Sendable {
    private let entries: [SearchableItem]
    private let byId: [String: SearchableItem]

    public init(registry: TaxonomyRegistry, unitCatalog: [UnitDefinition] = []) {
        var list: [SearchableItem] = []
        list.reserveCapacity(registry.items.count + unitCatalog.count)
        var seenConverterIds = Set<String>()

        for it in registry.items {
            guard let row = TaxonomyPathBuilder.makeSearchableItem(item: it, registry: registry) else { continue }
            list.append(row)
            if let c = row.converterUnitId, !c.isEmpty { seenConverterIds.insert(c) }
        }

        for u in unitCatalog {
            guard !seenConverterIds.contains(u.id) else { continue }
            guard let row = TaxonomyPathBuilder.makeSearchableItem(unit: u, registry: registry) else { continue }
            list.append(row)
            seenConverterIds.insert(u.id)
        }

        self.entries = list
        self.byId = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }

    public func pathResult(forItemId itemId: String) -> TaxonomyPathResult? {
        guard let entry = byId[itemId] else { return nil }
        return TaxonomyPathBuilder.pathResult(for: entry)
    }

    public func searchableItem(forItemId itemId: String) -> SearchableItem? {
        byId[itemId]
    }

    /// Ranked search; blank / whitespace-only query yields no results.
    public func search(
        query: String,
        categoryId: String? = nil,
        subcategoryId: String? = nil,
        unitCategoryRaw: String? = nil,
        limit: Int = 50
    ) -> [TaxonomyPathResult] {
        let q = Self.normalizeQuery(query)
        guard !q.isEmpty else { return [] }

        struct Scored {
            let tier: TaxonomySearchMatchTier
            let path: TaxonomyPathResult
        }

        var scored: [Scored] = []
        scored.reserveCapacity(min(entries.count, 32))

        for e in entries {
            if let cid = categoryId, !cid.isEmpty, e.categoryId != cid { continue }
            if let sid = subcategoryId, !sid.isEmpty, e.subcategoryId != sid { continue }
            if let ucr = unitCategoryRaw, e.unitCategoryRaw != ucr { continue }
            guard let tier = Self.matchTier(entry: e, normalizedQuery: q) else { continue }
            scored.append(Scored(tier: tier, path: TaxonomyPathBuilder.pathResult(for: e)))
        }

        scored.sort { a, b in
            if a.tier != b.tier { return a.tier < b.tier }
            return a.path.itemTitle.localizedStandardCompare(b.path.itemTitle) == .orderedAscending
        }

        if scored.count <= limit {
            return scored.map(\.path)
        }
        return Array(scored.prefix(limit).map(\.path))
    }

    private static func normalizeQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func matchTier(entry: SearchableItem, normalizedQuery q: String) -> TaxonomySearchMatchTier? {
        if entry.normalizedTitle == q { return .exactTitle }
        if entry.normalizedTitle.hasPrefix(q) { return .prefixTitle }

        for sl in entry.normalizedSynonyms {
            if sl == q { return .exactSynonym }
            if sl.hasPrefix(q) { return .prefixSynonym }
        }

        var bestTagTier: TaxonomySearchMatchTier?
        for tl in entry.normalizedTags {
            let candidate: TaxonomySearchMatchTier? = {
                if tl == q { return .exactTag }
                if tl.hasPrefix(q) { return .prefixTag }
                if q.count >= 2, tl.contains(q) { return .tagContains }
                return nil
            }()
            if let c = candidate {
                if bestTagTier == nil || c < bestTagTier! {
                    bestTagTier = c
                }
            }
        }
        return bestTagTier
    }
}
