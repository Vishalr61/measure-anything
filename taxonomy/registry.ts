import type {
  Domain,
  DomainId,
  Item,
  ItemId,
  Subgenre,
  SubgenreId,
  TaxonomyBundle,
  TaxonomyRegistry,
} from "./types";
import taxonomyJson from "./taxonomy.json";

export class TaxonomyValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "TaxonomyValidationError";
  }
}

/**
 * Validates structural rules and cross-references. Throws TaxonomyValidationError on violation.
 */
export function validateTaxonomy(bundle: TaxonomyBundle): TaxonomyBundle {
  const domainIds = new Set(bundle.domains.map((d) => d.id));
  if (domainIds.size !== bundle.domains.length) {
    throw new TaxonomyValidationError("Duplicate domain id");
  }

  const subgenreIds = new Set<SubgenreId>();
  for (const s of bundle.subgenres) {
    if (subgenreIds.has(s.id)) {
      throw new TaxonomyValidationError(`Duplicate subgenre id: ${s.id}`);
    }
    subgenreIds.add(s.id);
    if (!domainIds.has(s.domainId)) {
      throw new TaxonomyValidationError(
        `Subgenre "${s.id}" references unknown domainId "${s.domainId}"`,
      );
    }
  }

  const itemIds = new Set<ItemId>();
  const subgenreById = new Map<SubgenreId, Subgenre>(
    bundle.subgenres.map((s) => [s.id, s]),
  );

  for (const item of bundle.items) {
    if (itemIds.has(item.id)) {
      throw new TaxonomyValidationError(`Duplicate item id: ${item.id}`);
    }
    itemIds.add(item.id);

    if (!domainIds.has(item.domainId)) {
      throw new TaxonomyValidationError(
        `Item "${item.id}" references unknown domainId "${item.domainId}"`,
      );
    }

    const sg = subgenreById.get(item.subgenreId);
    if (!sg) {
      throw new TaxonomyValidationError(
        `Item "${item.id}" references unknown subgenreId "${item.subgenreId}"`,
      );
    }
    if (sg.domainId !== item.domainId) {
      throw new TaxonomyValidationError(
        `Item "${item.id}" domainId "${item.domainId}" does not match subgenre "${sg.id}" domainId "${sg.domainId}"`,
      );
    }
  }

  return bundle;
}

export function buildRegistry(bundle: TaxonomyBundle): TaxonomyRegistry {
  const domainById = new Map<DomainId, Domain>(
    bundle.domains.map((d) => [d.id, d]),
  );
  const subgenreById = new Map<SubgenreId, Subgenre>(
    bundle.subgenres.map((s) => [s.id, s]),
  );
  const itemById = new Map<ItemId, Item>(bundle.items.map((i) => [i.id, i]));

  const subgenresByDomainId = new Map<DomainId, Subgenre[]>();
  for (const s of bundle.subgenres) {
    const list = subgenresByDomainId.get(s.domainId) ?? [];
    list.push(s);
    subgenresByDomainId.set(s.domainId, list);
  }

  const itemsBySubgenreId = new Map<SubgenreId, Item[]>();
  for (const item of bundle.items) {
    const list = itemsBySubgenreId.get(item.subgenreId) ?? [];
    list.push(item);
    itemsBySubgenreId.set(item.subgenreId, list);
  }

  return {
    ...bundle,
    domainById,
    subgenreById,
    itemById,
    subgenresByDomainId,
    itemsBySubgenreId,
  };
}

/** Validated bundle + lookup maps (central registry entry point for TypeScript). */
export const taxonomyRegistry: TaxonomyRegistry = buildRegistry(
  validateTaxonomy(taxonomyJson as TaxonomyBundle),
);

export { taxonomyJson as rawTaxonomyJson };
