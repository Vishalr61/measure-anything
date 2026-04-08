import Foundation
import MeasureAnythingCore

// MARK: - Path (single breadcrumb builder)

/// Breadcrumb for a taxonomy or catalog row (`Domain / Subgenre / Title`).
public struct TaxonomyPathResult: Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let pathLine: String
    public let domainTitle: String
    public let subgenreTitle: String
    public let itemTitle: String

    public static let pathComponentSeparator = " / "
}

/// Root-level domain row with counts.
public struct TaxonomyDomainSection: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let itemCount: Int

    public init(id: String, title: String, subtitle: String?, itemCount: Int) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.itemCount = itemCount
    }
}

/// Grouped rows inside a domain (subgenre, unit category, or one flat bucket).
public struct TaxonomyBrowseSection: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let itemCount: Int
    public let items: [TaxonomyPathResult]

    public init(id: String, title: String, subtitle: String?, itemCount: Int, items: [TaxonomyPathResult]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.itemCount = itemCount
        self.items = items
    }
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

    /// Same as `categoryId` (domain id from taxonomy JSON).
    public var domainId: String { categoryId }
    /// Same as `subcategoryId` (subgenre id from taxonomy JSON).
    public var subgenreId: String { subcategoryId }
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
    /// Domain ids in taxonomy JSON order (for browse root + stable sorting).
    private let orderedDomainIds: [String]

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
        self.orderedDomainIds = registry.domains.map(\.id)
    }

    /// Items in a domain (for filter validation in the app layer).
    public func entries(in domainId: String) -> [SearchableItem] {
        entries.filter { $0.categoryId == domainId }
    }

    /// Root: one row per domain with item counts (order follows `registry.domains` at index build).
    public func browseDomains() -> [TaxonomyDomainSection] {
        let grouped = Dictionary(grouping: entries, by: \.categoryId)
        var result: [TaxonomyDomainSection] = []
        result.reserveCapacity(grouped.count)
        for id in orderedDomainIds {
            guard let group = grouped[id], let first = group.first else { continue }
            result.append(
                TaxonomyDomainSection(
                    id: id,
                    title: first.pathDomainTitle,
                    subtitle: nil,
                    itemCount: group.count
                )
            )
        }
        let known = Set(orderedDomainIds)
        let extras = grouped.keys.filter { !known.contains($0) }.sorted()
        for id in extras {
            guard let group = grouped[id], let first = group.first else { continue }
            result.append(
                TaxonomyDomainSection(
                    id: id,
                    title: first.pathDomainTitle,
                    subtitle: nil,
                    itemCount: group.count
                )
            )
        }
        return result
    }

    /// Inside one domain: group by subgenre when multiple subgenres exist; else by unit category when multiple; else one section.
    public func browseSections(
        inDomain domainId: String,
        subcategoryId: String? = nil,
        unitCategoryRaw: String? = nil,
        limitPerSection: Int = 200,
        maxSections: Int = 100
    ) -> [TaxonomyBrowseSection] {
        var filtered = entries.filter { $0.categoryId == domainId }
        filtered = filtered.filter {
            Self.passesFilters($0, categoryId: nil, subcategoryId: subcategoryId, unitCategoryRaw: unitCategoryRaw)
        }
        guard !filtered.isEmpty else { return [] }

        let distinctSub = Set(filtered.map(\.subcategoryId))
        let distinctUnits = Set(filtered.compactMap(\.unitCategoryRaw))

        let sections: [TaxonomyBrowseSection]
        if distinctSub.count > 1 {
            sections = Self.sectionsGroupedBySubgenre(filtered: filtered, domainId: domainId, limitPerSection: limitPerSection)
        } else if distinctUnits.count > 1 {
            sections = Self.sectionsGroupedByUnitCategory(filtered: filtered, domainId: domainId, limitPerSection: limitPerSection)
        } else {
            sections = [
                Self.singleFlatSection(filtered: filtered, domainId: domainId, limitPerSection: limitPerSection)
            ]
        }
        if sections.count > maxSections {
            return Array(sections.prefix(maxSections))
        }
        return sections
    }

    public func pathResult(forItemId itemId: String) -> TaxonomyPathResult? {
        guard let entry = byId[itemId] else { return nil }
        return TaxonomyPathBuilder.pathResult(for: entry)
    }

    public func searchableItem(forItemId itemId: String) -> SearchableItem? {
        byId[itemId]
    }

    /// Flattened browse: if `categoryId` is set, that domain only; else walks domains in taxonomy order. Capped at `limit` total rows.
    public func browse(
        categoryId: String? = nil,
        subcategoryId: String? = nil,
        unitCategoryRaw: String? = nil,
        limit: Int = 500
    ) -> [TaxonomyPathResult] {
        if let cid = categoryId, !cid.isEmpty {
            return Self.flattenSections(
                browseSections(
                    inDomain: cid,
                    subcategoryId: subcategoryId,
                    unitCategoryRaw: unitCategoryRaw,
                    limitPerSection: limit,
                    maxSections: 100
                ),
                limit: limit
            )
        }
        var out: [TaxonomyPathResult] = []
        out.reserveCapacity(min(limit, 64))
        outer: for d in orderedDomainIds {
            let sections = browseSections(
                inDomain: d,
                subcategoryId: subcategoryId,
                unitCategoryRaw: unitCategoryRaw,
                limitPerSection: limit,
                maxSections: 100
            )
            for s in sections {
                for p in s.items {
                    if out.count >= limit { break outer }
                    out.append(p)
                }
            }
        }
        return out
    }

    /// Ranked search; blank query yields no results (use `browse` / `browseSections`).
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
            guard Self.passesFilters(e, categoryId: categoryId, subcategoryId: subcategoryId, unitCategoryRaw: unitCategoryRaw) else {
                continue
            }
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

    private static func flattenSections(_ sections: [TaxonomyBrowseSection], limit: Int) -> [TaxonomyPathResult] {
        var out: [TaxonomyPathResult] = []
        out.reserveCapacity(min(limit, 64))
        outer: for s in sections {
            for p in s.items {
                if out.count >= limit { break outer }
                out.append(p)
            }
        }
        return out
    }

    private static func sectionsGroupedBySubgenre(
        filtered: [SearchableItem],
        domainId: String,
        limitPerSection: Int
    ) -> [TaxonomyBrowseSection] {
        let grouped = Dictionary(grouping: filtered, by: \.subcategoryId)
        var sections: [TaxonomyBrowseSection] = []
        sections.reserveCapacity(grouped.count)
        for (subId, group) in grouped {
            guard let first = group.first else { continue }
            let sorted = group.sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            let paths = sorted.map { TaxonomyPathBuilder.pathResult(for: $0) }
            let capped = paths.count > limitPerSection ? Array(paths.prefix(limitPerSection)) : paths
            sections.append(
                TaxonomyBrowseSection(
                    id: "\(domainId).sub.\(subId)",
                    title: first.pathSubgenreTitle,
                    subtitle: first.pathDomainTitle,
                    itemCount: capped.count,
                    items: capped
                )
            )
        }
        sections.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return sections
    }

    private static func sectionsGroupedByUnitCategory(
        filtered: [SearchableItem],
        domainId: String,
        limitPerSection: Int
    ) -> [TaxonomyBrowseSection] {
        let grouped = Dictionary(grouping: filtered) { $0.unitCategoryRaw ?? "__none__" }
        var sections: [TaxonomyBrowseSection] = []
        sections.reserveCapacity(grouped.count)
        for (uRaw, group) in grouped {
            guard let first = group.first else { continue }
            let sorted = group.sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            let paths = sorted.map { TaxonomyPathBuilder.pathResult(for: $0) }
            let capped = paths.count > limitPerSection ? Array(paths.prefix(limitPerSection)) : paths
            let title: String
            if uRaw == "__none__" {
                title = "Other"
            } else {
                title = uRaw.capitalized
            }
            sections.append(
                TaxonomyBrowseSection(
                    id: "\(domainId).cat.\(uRaw)",
                    title: title,
                    subtitle: first.pathDomainTitle,
                    itemCount: capped.count,
                    items: capped
                )
            )
        }
        sections.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return sections
    }

    private static func singleFlatSection(
        filtered: [SearchableItem],
        domainId: String,
        limitPerSection: Int
    ) -> TaxonomyBrowseSection {
        let sorted = filtered.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
        let paths = sorted.map { TaxonomyPathBuilder.pathResult(for: $0) }
        let capped = paths.count > limitPerSection ? Array(paths.prefix(limitPerSection)) : paths
        guard let first = filtered.first else {
            return TaxonomyBrowseSection(
                id: "\(domainId).all",
                title: "All items",
                subtitle: nil,
                itemCount: 0,
                items: []
            )
        }
        return TaxonomyBrowseSection(
            id: "\(domainId).all",
            title: "All items",
            subtitle: first.pathDomainTitle,
            itemCount: capped.count,
            items: capped
        )
    }

    private static func normalizeQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func passesFilters(
        _ e: SearchableItem,
        categoryId: String?,
        subcategoryId: String?,
        unitCategoryRaw: String?
    ) -> Bool {
        if let cid = categoryId, !cid.isEmpty, e.categoryId != cid { return false }
        if let sid = subcategoryId, !sid.isEmpty, e.subcategoryId != sid { return false }
        if let ucr = unitCategoryRaw, e.unitCategoryRaw != ucr { return false }
        return true
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
