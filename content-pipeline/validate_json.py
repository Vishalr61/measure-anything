#!/usr/bin/env python3
"""
Validate Measure Anything JSON files locally without Airtable.

Checks:
    - All unit IDs are unique across categories
    - All fact card unitIDs exist in unit definitions
    - All comparison targetUnitIDs exist in unit definitions
    - Required fields are present on every unit
    - No orphaned fact cards pointing to non-existent units
    - Cross-category reference audit

Usage:
    # If unit JSON + fact cards live in the same folder:
    python validate_json.py --json-dir /path/to/json/files

    # If they live in different folders (this repo):
    python validate_json.py --units-dir /path/to/units --facts-dir /path/to/facts
"""

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

UNIT_FILES = ["length.json", "mass.json", "time.json", "temperature.json", "volume.json"]
FACT_CARD_FILES = [
    "FactCardContent_Length.json",
    "FactCardContent_Mass.json",
    "FactCardContent_Time.json",
    "FactCardContent_Temperature.json",
    "FactCardContent_Volume.json",
]
REQUIRED_FIELDS = ["id", "name", "category", "baseUnit", "kind", "conversionStyle", "factor"]


def load_json(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        return json.load(f)


def main():
    parser = argparse.ArgumentParser(description="Validate Measure Anything JSON files")
    parser.add_argument(
        "--json-dir",
        type=Path,
        help="Path containing BOTH unit JSON files and FactCardContent files",
    )
    parser.add_argument(
        "--units-dir",
        type=Path,
        help="Path containing unit JSON files (length.json, mass.json, ...)",
    )
    parser.add_argument(
        "--facts-dir",
        type=Path,
        help="Path containing FactCardContent_*.json files",
    )
    args = parser.parse_args()

    if args.json_dir:
        units_dir = args.json_dir
        facts_dir = args.json_dir
    else:
        if not args.units_dir or not args.facts_dir:
            print("Error: provide --json-dir OR both --units-dir and --facts-dir")
            sys.exit(2)
        units_dir = args.units_dir
        facts_dir = args.facts_dir

    errors = []
    warnings = []

    # === Load all units ===
    all_units = {}  # id → unit dict
    units_by_category = defaultdict(list)

    for filename in UNIT_FILES:
        filepath = units_dir / filename
        if not filepath.exists():
            warnings.append(f"File not found: {filename}")
            continue

        try:
            units = load_json(filepath)
        except json.JSONDecodeError as e:
            errors.append(f"Invalid JSON in {filename}: {e}")
            continue

        if not isinstance(units, list):
            errors.append(f"{filename}: expected a JSON array, got {type(units).__name__}")
            continue

        for unit in units:
            uid = unit.get("id", "MISSING_ID")

            # Check for duplicates
            if uid in all_units:
                existing_cat = all_units[uid].get("category", "?")
                new_cat = unit.get("category", "?")
                errors.append(f"Duplicate unit ID '{uid}' (in {existing_cat} and {new_cat})")
                continue

            # Check required fields
            for field in REQUIRED_FIELDS:
                if field not in unit or unit[field] is None or unit[field] == "":
                    errors.append(f"Unit '{uid}': missing required field '{field}'")

            # Check factor is numeric
            factor = unit.get("factor")
            if factor is not None and not isinstance(factor, (int, float)):
                errors.append(f"Unit '{uid}': factor is not a number: {factor}")

            # Check funFact presence
            if not unit.get("funFact"):
                warnings.append(f"Unit '{uid}' ({unit.get('name', '?')}): no funFact")

            all_units[uid] = unit
            units_by_category[unit.get("category", "unknown")].append(unit)

    print(f"Loaded {len(all_units)} units across {len(units_by_category)} categories\n")

    # === Load all fact cards ===
    all_cards = {}  # unitID → card data
    total_comparisons = 0

    for filename in FACT_CARD_FILES:
        filepath = facts_dir / filename
        if not filepath.exists():
            continue

        try:
            data = load_json(filepath)
        except json.JSONDecodeError as e:
            errors.append(f"Invalid JSON in {filename}: {e}")
            continue

        cards = data.get("cards", {})
        for unit_id, card in cards.items():
            # Check unit exists
            if unit_id not in all_units:
                errors.append(f"Fact card '{unit_id}' in {filename}: unit does not exist")
                continue

            # Check for duplicate cards
            if unit_id in all_cards:
                errors.append(f"Duplicate fact card for '{unit_id}'")
                continue

            # Validate comparisons
            comparisons = card.get("comparisons", [])
            total_comparisons += len(comparisons)

            target_ids_seen = set()
            for i, comp in enumerate(comparisons):
                target_id = comp.get("targetUnitID", "")

                if not target_id:
                    errors.append(f"Card '{unit_id}' comp {i+1}: empty targetUnitID")
                    continue

                if target_id not in all_units:
                    errors.append(f"Card '{unit_id}' comp {i+1}: targetUnitID '{target_id}' does not exist")

                if target_id in target_ids_seen:
                    warnings.append(f"Card '{unit_id}': duplicate target '{target_id}'")
                target_ids_seen.add(target_id)

                if not comp.get("template", "").strip():
                    errors.append(f"Card '{unit_id}' comp {i+1}: empty template")

                # Check cross-category references
                if target_id in all_units:
                    source_cat = all_units[unit_id].get("category")
                    target_cat = all_units[target_id].get("category")
                    if source_cat != target_cat:
                        warnings.append(
                            f"Card '{unit_id}' ({source_cat}) → '{target_id}' ({target_cat}): cross-category reference"
                        )

            all_cards[unit_id] = card

    # === Print results ===

    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)

    for cat in sorted(units_by_category.keys()):
        cat_units = units_by_category[cat]
        cat_cards = sum(1 for uid in all_cards if all_units.get(uid, {}).get("category") == cat)
        cat_with_facts = sum(1 for u in cat_units if u.get("funFact"))
        cat_absurd = sum(1 for u in cat_units if u.get("kind") == "absurd")
        cat_normal = sum(1 for u in cat_units if u.get("kind") == "normal")
        print(
            f"  {cat.capitalize():12s}: {len(cat_units):3d} units "
            f"({cat_normal} normal, {cat_absurd} absurd), "
            f"{cat_cards:2d} curated cards, "
            f"{cat_with_facts:3d} with funFacts"
        )

    print(f"\n  Total: {len(all_units)} units, {len(all_cards)} curated cards, {total_comparisons} comparisons")

    # Rabbit-hole density check
    curated_targets = set()
    for uid, card in all_cards.items():
        for comp in card.get("comparisons", []):
            target = comp.get("targetUnitID", "")
            if target in all_cards:
                curated_targets.add(target)

    if all_cards:
        density = len(curated_targets) / len(all_cards) * 100
        print(f"\n  Rabbit-hole density: {density:.0f}% of curated cards are reachable from other curated cards")

    print()

    if errors:
        print(f"ERRORS ({len(errors)}):")
        for e in errors:
            print(f"  ✗ {e}")

    if warnings:
        print(f"\nWARNINGS ({len(warnings)}):")
        shown = warnings[:30]
        for w in shown:
            print(f"  ⚠ {w}")
        if len(warnings) > 30:
            print(f"  ... and {len(warnings) - 30} more warnings")

    if not errors:
        print("\n✓ No errors found — JSON is valid for app bundling")
    else:
        print(f"\n✗ {len(errors)} errors found — fix before bundling")
        sys.exit(1)


if __name__ == "__main__":
    main()

