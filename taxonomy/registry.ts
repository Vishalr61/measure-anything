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

  if (bundle.converterNavigation) {
    validateConverterNavigation(bundle.converterNavigation, bundle);
  }

  return bundle;
}

function validateConverterNavigation(
  nav: NonNullable<TaxonomyBundle["converterNavigation"]>,
  bundle: TaxonomyBundle,
): void {
  if (!bundle.domains.some((d) => d.id === nav.measurementDomainId)) {
    throw new TaxonomyValidationError(
      `converterNavigation.measurementDomainId "${nav.measurementDomainId}" is not a domain id`,
    );
  }
  if (nav.categories.length === 0) {
    throw new TaxonomyValidationError("converterNavigation.categories must not be empty");
  }
  if (nav.modes.length === 0) {
    throw new TaxonomyValidationError("converterNavigation.modes must not be empty");
  }

  const seenCat = new Set<string>();
  for (const row of nav.categories) {
    if (seenCat.has(row.unitCategoryRaw)) {
      throw new TaxonomyValidationError(
        `Duplicate converterNavigation category: ${row.unitCategoryRaw}`,
      );
    }
    seenCat.add(row.unitCategoryRaw);
  }

  const subgenreById = new Map<SubgenreId, Subgenre>(
    bundle.subgenres.map((s) => [s.id, s]),
  );
  const seenMode = new Set<string>();
  for (const row of nav.modes) {
    if (seenMode.has(row.modeRaw)) {
      throw new TaxonomyValidationError(`Duplicate converterNavigation mode: ${row.modeRaw}`);
    }
    seenMode.add(row.modeRaw);
    const sg = subgenreById.get(row.subgenreId);
    if (!sg) {
      throw new TaxonomyValidationError(
        `converterNavigation mode "${row.modeRaw}" references unknown subgenreId "${row.subgenreId}"`,
      );
    }
    if (sg.domainId !== nav.measurementDomainId) {
      throw new TaxonomyValidationError(
        `converterNavigation: subgenre "${row.subgenreId}" must belong to domain "${nav.measurementDomainId}" (is "${sg.domainId}")`,
      );
    }
  }
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
