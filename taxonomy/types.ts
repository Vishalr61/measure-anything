/**
 * Strict hierarchical taxonomy: Domain → Subgenre → Item.
 * Every Item references exactly one Domain and one Subgenre; every Subgenre references exactly one Domain.
 */

export type DomainId = string;
export type SubgenreId = string;
export type ItemId = string;

export interface Domain {
  readonly id: DomainId;
  readonly name: string;
  readonly description: string;
}

export interface Subgenre {
  readonly id: SubgenreId;
  /** Must match an existing Domain.id */
  readonly domainId: DomainId;
  readonly name: string;
  readonly description: string;
}

export interface Item {
  readonly id: ItemId;
  /** Must match an existing Domain.id and align with Subgenre.domainId */
  readonly domainId: DomainId;
  /** Must match an existing Subgenre.id whose domainId equals this item's domainId */
  readonly subgenreId: SubgenreId;
  readonly name: string;
  readonly description: string;
  readonly synonyms?: readonly string[];
  readonly tags?: readonly string[];
  /** Optional `UnitCategory.rawValue` for app-side search filtering */
  readonly unitCategoryRaw?: string;
  /** Optional `UnitDefinition.id` in the conversion engine */
  readonly converterUnitId?: string;
}

export interface ConverterNavigation {
  readonly measurementDomainId: DomainId;
  readonly categories: readonly {
    readonly unitCategoryRaw: string;
    readonly displayName?: string;
    readonly description?: string;
  }[];
  readonly modes: readonly {
    readonly modeRaw: string;
    readonly subgenreId: SubgenreId;
  }[];
}

/** Full bundle loaded from the central registry JSON */
export interface TaxonomyBundle {
  readonly domains: readonly Domain[];
  readonly subgenres: readonly Subgenre[];
  readonly items: readonly Item[];
  readonly converterNavigation?: ConverterNavigation;
}

export interface TaxonomyRegistry extends TaxonomyBundle {
  readonly domainById: ReadonlyMap<DomainId, Domain>;
  readonly subgenreById: ReadonlyMap<SubgenreId, Subgenre>;
  readonly itemById: ReadonlyMap<ItemId, Item>;
  readonly subgenresByDomainId: ReadonlyMap<DomainId, readonly Subgenre[]>;
  readonly itemsBySubgenreId: ReadonlyMap<SubgenreId, readonly Item[]>;
}
