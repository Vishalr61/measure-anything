#!/usr/bin/env python3
"""
Export Measure Anything content from Airtable to app-ready JSON files.

Generates:
  - MeasureAnythingApp/Core/Conversion/Resources/{length,mass,time,volume,temperature}.json
  - MeasureAnything/MeasureAnything/Resources/FactCardContent_{Length,Mass,Time,Temperature,Volume}.json

Includes validation:
  - Unit ids unique
  - Required fields present per conversion rules (special-cased temperature)
  - Fact card unit exists
  - Comparison target exists and template non-empty
  - Warn (not fail) on cross-category comparisons

Usage:
  python export_from_airtable.py --output-dir /tmp/out
  python export_from_airtable.py --write-to-repo
  python export_from_airtable.py --validate-only
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List, Tuple

try:
    from dotenv import load_dotenv  # type: ignore

    load_dotenv()
except Exception:
    # Allow running without python-dotenv installed (env vars still work).
    pass

AIRTABLE_PAT = os.getenv("AIRTABLE_PAT")
AIRTABLE_BASE_ID = os.getenv("AIRTABLE_BASE_ID")

UNITS_TABLE = "Units"
FACT_CARDS_TABLE = "Fact Cards"
COMPARISONS_TABLE = "Comparisons"

RATE_LIMIT_DELAY = 0.22

VALID_CATEGORIES = {"length", "mass", "time", "temperature", "volume"}
VALID_KINDS = {"normal", "absurd", "custom"}

# For Airtable, we allow both representations, but we export temperature absurd as "offset".
VALID_CONVERSION_STYLES = {"multiplicative", "temperature", "offset", "temperatureAffine"}


def rate_limit_pause() -> None:
    time.sleep(RATE_LIMIT_DELAY)


def fetch_all_records(table):
    records = list(table.all())
    rate_limit_pause()
    return records


def _is_empty(v: Any) -> bool:
    return v is None or (isinstance(v, str) and v.strip() == "")


def validate_units(units_by_id: Dict[str, Dict[str, Any]]) -> Tuple[List[str], List[str]]:
    errors: List[str] = []
    warnings: List[str] = []

    for uid, unit in units_by_id.items():
        # Always required
        for field in ["id", "name", "category", "baseUnit", "kind", "conversionStyle"]:
            if _is_empty(unit.get(field)):
                errors.append(f"Unit '{uid}': missing required field '{field}'")

        cat = unit.get("category")
        if cat and cat not in VALID_CATEGORIES:
            errors.append(f"Unit '{uid}': invalid category '{cat}'")

        kind = unit.get("kind")
        if kind and kind not in VALID_KINDS:
            errors.append(f"Unit '{uid}': invalid kind '{kind}'")

        style = unit.get("conversionStyle")
        if style and style not in VALID_CONVERSION_STYLES:
            errors.append(f"Unit '{uid}': invalid conversionStyle '{style}'")

        factor = unit.get("factor")
        offset = unit.get("offset")

        # Conditional required fields based on style/category.
        if cat == "temperature":
            if style == "temperature":
                # Normal temperature units should not require factor.
                pass
            elif style == "offset":
                if factor is None or not isinstance(factor, (int, float)):
                    errors.append(f"Unit '{uid}': temperature offset unit requires numeric factor")
                if offset is None or not isinstance(offset, (int, float)):
                    errors.append(f"Unit '{uid}': temperature offset unit requires numeric offset")
            else:
                errors.append(f"Unit '{uid}': invalid temperature conversionStyle '{style}'")
        else:
            if style != "multiplicative":
                errors.append(f"Unit '{uid}': non-temperature unit must be multiplicative (got '{style}')")
            if factor is None or not isinstance(factor, (int, float)):
                errors.append(f"Unit '{uid}': multiplicative unit requires numeric factor")

        # Enforce category/kind/style coherence for export targets.
        # AbsurdUnitStore expects:
        # - non-temperature absurd: multiplicative with factor
        # - temperature absurd: offset with factor+offset
        if kind == "absurd":
            if cat == "temperature" and style != "offset":
                errors.append(f"Unit '{uid}': absurd temperature units must use conversionStyle 'offset'")
            if cat != "temperature" and style != "multiplicative":
                errors.append(f"Unit '{uid}': absurd non-temperature units must be multiplicative")

        # NormalUnitStore expects:
        # - non-temperature normal: multiplicative with factor
        # - temperature normal: temperature (no factor)
        if kind == "normal":
            if cat == "temperature" and style != "temperature":
                errors.append(f"Unit '{uid}': normal temperature units must use conversionStyle 'temperature'")
            if cat != "temperature" and style != "multiplicative":
                errors.append(f"Unit '{uid}': normal non-temperature units must be multiplicative")

        if factor is not None and isinstance(factor, (int, float)) and cat != "temperature":
            if factor <= 0:
                errors.append(f"Unit '{uid}': multiplicative factor must be > 0 (got {factor})")

        if _is_empty(unit.get("funFact")):
            warnings.append(f"Unit '{uid}': no funFact (Explore will have less context)")

    return errors, warnings


def validate_fact_cards(fact_cards: Dict[str, Dict[str, Any]], units_by_id: Dict[str, Dict[str, Any]]) -> Tuple[List[str], List[str]]:
    errors: List[str] = []
    warnings: List[str] = []

    for unit_id, card in fact_cards.items():
        if unit_id not in units_by_id:
            errors.append(f"Fact card '{unit_id}': references non-existent unit")
            continue

        if _is_empty(card.get("valueHeadline")):
            warnings.append(f"Fact card '{unit_id}': missing valueHeadline")
        if _is_empty(card.get("valueDisplay")):
            warnings.append(f"Fact card '{unit_id}': missing valueDisplay")

        comparisons = card.get("comparisons", []) or []
        if not comparisons:
            warnings.append(f"Fact card '{unit_id}': no comparisons")

        seen_targets = set()
        source_cat = units_by_id[unit_id].get("category")
        for idx, comp in enumerate(comparisons, 1):
            target_id = comp.get("targetUnitID", "")
            if _is_empty(target_id):
                errors.append(f"Fact card '{unit_id}' comparison {idx}: missing targetUnitID link")
                continue
            if target_id not in units_by_id:
                errors.append(f"Fact card '{unit_id}' comparison {idx}: targetUnitID '{target_id}' does not exist")
                continue

            if target_id in seen_targets:
                warnings.append(f"Fact card '{unit_id}': duplicate targetUnitID '{target_id}'")
            seen_targets.add(target_id)

            if _is_empty(comp.get("template")):
                errors.append(f"Fact card '{unit_id}' comparison {idx}: empty template")

            target_cat = units_by_id[target_id].get("category")
            if source_cat and target_cat and source_cat != target_cat:
                warnings.append(
                    f"Fact card '{unit_id}' ({source_cat}) → '{target_id}' ({target_cat}): cross-category reference"
                )

    return errors, warnings


def build_unit_json(unit: Dict[str, Any]) -> Dict[str, Any]:
    """
    Build a unit dict matching the app's shipped JSON shape.

    Note: For temperature absurd comparators, the shipped format uses `conversionStyle: "offset"` + `offset`.
    """
    out: Dict[str, Any] = {
        "id": unit["id"],
        "name": unit["name"],
        "category": unit["category"],
        "baseUnit": unit["baseUnit"],
        "kind": unit["kind"],
        "conversionStyle": unit["conversionStyle"],
    }

    # Factor is included for multiplicative and offset and temperatureAffine.
    if unit.get("factor") is not None:
        out["factor"] = unit["factor"]

    # Optional fields
    for field in ["iconName", "description", "funFact", "exampleMeme", "interestScore"]:
        val = unit.get(field)
        if val is not None and val != "":
            out[field] = val

    if unit.get("offset") is not None:
        out["offset"] = unit["offset"]

    return out


def build_fact_card_entry(card: Dict[str, Any]) -> Dict[str, Any]:
    entry = {
        "valueHeadline": card.get("valueHeadline", ""),
        "valueDisplay": card.get("valueDisplay", ""),
        "comparisons": [],
    }
    for comp in card.get("comparisons", []) or []:
        entry["comparisons"].append(
            {
                "targetUnitID": comp["targetUnitID"],
                "template": comp["template"],
            }
        )
    return entry


def export_json(
    output_dir: Path,
    units_by_id: Dict[str, Dict[str, Any]],
    fact_cards: Dict[str, Dict[str, Any]],
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    units_by_category_and_kind: Dict[Tuple[str, str], List[Dict[str, Any]]] = defaultdict(list)
    for unit in units_by_id.values():
        units_by_category_and_kind[(unit["category"], unit["kind"])].append(unit)

    def write_units(filename: str, units: List[Dict[str, Any]]) -> None:
        units_sorted = sorted(units, key=lambda u: (str(u.get("name", "")), str(u.get("id", ""))))
        json_units = [build_unit_json(u) for u in units_sorted]
        filepath = output_dir / filename
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(json_units, f, indent=2, ensure_ascii=False)
        print(f"  Wrote {filepath} ({len(json_units)} units)")

    # Units export strategy:
    # - Absurd catalogs: keep using {category}.json (matches AbsurdUnitStore)
    # - Normal catalogs: write normal_{category}.json (consumed by NormalUnitStore)
    for category in sorted(VALID_CATEGORIES):
        absurd_units = units_by_category_and_kind.get((category, "absurd"), [])
        write_units(f"{category}.json", absurd_units)

        normal_units = units_by_category_and_kind.get((category, "normal"), [])
        write_units(f"normal_{category}.json", normal_units)

    # Fact cards: group by category using source unit category
    cards_by_category: Dict[str, Dict[str, Dict[str, Any]]] = defaultdict(dict)
    for unit_id, card in fact_cards.items():
        unit = units_by_id.get(unit_id)
        if not unit:
            continue
        cards_by_category[unit["category"]][unit_id] = card

    for category in sorted(VALID_CATEGORIES):
        filename = f"FactCardContent_{category.capitalize()}.json"
        filepath = output_dir / filename
        cards = cards_by_category.get(category, {})
        # stable order by unit_id
        json_cards = {uid: build_fact_card_entry(cards[uid]) for uid in sorted(cards.keys())}
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump({"cards": json_cards}, f, indent=2, ensure_ascii=False)
        print(f"  Wrote {filepath} ({len(json_cards)} cards)")


def main() -> None:
    parser = argparse.ArgumentParser(description="Export Airtable content to app JSON")
    parser.add_argument("--output-dir", type=Path, help="Directory to write generated JSON files")
    parser.add_argument(
        "--write-to-repo",
        action="store_true",
        help="Write outputs directly into the repo Resources folders (overwrites tracked files)",
    )
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1], help="Repo root path")
    parser.add_argument("--validate-only", action="store_true", help="Validate data without writing files")
    args = parser.parse_args()

    if not AIRTABLE_PAT or not AIRTABLE_BASE_ID:
        print("Error: Set AIRTABLE_PAT and AIRTABLE_BASE_ID in content-pipeline/.env")
        sys.exit(1)

    if args.write_to_repo:
        out_dir = args.repo_root / "content-pipeline" / ".export-tmp"
    else:
        if not args.output_dir:
            print("Error: provide --output-dir (or use --write-to-repo)")
            sys.exit(1)
        out_dir = args.output_dir

    from pyairtable import Api

    api = Api(AIRTABLE_PAT)
    units_table = api.table(AIRTABLE_BASE_ID, UNITS_TABLE)
    cards_table = api.table(AIRTABLE_BASE_ID, FACT_CARDS_TABLE)
    comps_table = api.table(AIRTABLE_BASE_ID, COMPARISONS_TABLE)

    print("Fetching data from Airtable…\n")
    unit_records = fetch_all_records(units_table)
    card_records = fetch_all_records(cards_table)
    comp_records = fetch_all_records(comps_table)

    # Build unit maps
    units_by_id: Dict[str, Dict[str, Any]] = {}
    airtable_id_to_unit_id: Dict[str, str] = {}
    for r in unit_records:
        fields = r.get("fields", {})
        uid = fields.get("id")
        if uid:
            units_by_id[uid] = fields
            airtable_id_to_unit_id[r["id"]] = uid

    # Card Airtable id -> unit_id string
    card_to_unit_id: Dict[str, str] = {}
    for r in card_records:
        fields = r.get("fields", {})
        links = fields.get("unitID", [])
        if isinstance(links, list) and links:
            unit_record_id = links[0]
            unit_id = airtable_id_to_unit_id.get(unit_record_id)
            if unit_id:
                card_to_unit_id[r["id"]] = unit_id

    # Comparisons grouped by card (resolve target)
    comparisons_by_card: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for r in comp_records:
        fields = r.get("fields", {})
        card_links = fields.get("cardUnit", [])
        target_links = fields.get("targetUnitID", [])
        if not (isinstance(card_links, list) and card_links):
            continue
        card_id = card_links[0]
        target_unit_id = ""
        if isinstance(target_links, list) and target_links:
            target_unit_id = airtable_id_to_unit_id.get(target_links[0], "")
        comparisons_by_card[card_id].append(
            {
                "targetUnitID": target_unit_id,
                "template": fields.get("template", ""),
                "sortOrder": fields.get("sortOrder", 999),
            }
        )

    # Assemble fact cards keyed by unit_id
    fact_cards: Dict[str, Dict[str, Any]] = {}
    for r in card_records:
        card_id = r["id"]
        unit_id = card_to_unit_id.get(card_id)
        if not unit_id:
            continue
        fields = r.get("fields", {})
        comps = comparisons_by_card.get(card_id, [])
        comps_sorted = sorted(comps, key=lambda c: (int(c.get("sortOrder", 999)), c.get("targetUnitID", "")))
        # Strip sortOrder for exported format
        for c in comps_sorted:
            c.pop("sortOrder", None)
        fact_cards[unit_id] = {
            "valueHeadline": fields.get("valueHeadline", ""),
            "valueDisplay": fields.get("valueDisplay", ""),
            "comparisons": comps_sorted,
        }

    print("=== Validation ===\n")
    unit_errors, unit_warnings = validate_units(units_by_id)
    card_errors, card_warnings = validate_fact_cards(fact_cards, units_by_id)
    errors = unit_errors + card_errors
    warnings = unit_warnings + card_warnings

    if errors:
        print(f"ERRORS ({len(errors)}):")
        for e in errors:
            print(f"  ✗ {e}")
    if warnings:
        print(f"\nWARNINGS ({len(warnings)}):")
        for w in warnings[:25]:
            print(f"  ⚠ {w}")
        if len(warnings) > 25:
            print(f"  ... and {len(warnings) - 25} more warnings")

    print(f"\nSummary: {len(units_by_id)} units, {len(fact_cards)} fact cards")
    if errors:
        sys.exit(1)
    if args.validate_only:
        print("\nValidation only — no files written")
        return

    print(f"\n=== Exporting to {out_dir} ===\n")
    export_json(out_dir, units_by_id, fact_cards)

    if args.write_to_repo:
        # Copy into the repo's canonical paths.
        conv_dir = args.repo_root / "MeasureAnythingApp" / "Core" / "Conversion" / "Resources"
        facts_dir = args.repo_root / "MeasureAnything" / "MeasureAnything" / "Resources"

        # Unit catalogs (absurd + normal)
        for cat in sorted(VALID_CATEGORIES):
            src = out_dir / f"{cat}.json"
            dst = conv_dir / f"{cat}.json"
            if src.exists():
                dst.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
                print(f"  Updated {dst}")

            src_normal = out_dir / f"normal_{cat}.json"
            dst_normal = conv_dir / f"normal_{cat}.json"
            if src_normal.exists():
                dst_normal.write_text(src_normal.read_text(encoding="utf-8"), encoding="utf-8")
                print(f"  Updated {dst_normal}")

        # Fact cards
        for cat in sorted(VALID_CATEGORIES):
            src = out_dir / f"FactCardContent_{cat.capitalize()}.json"
            dst = facts_dir / f"FactCardContent_{cat.capitalize()}.json"
            if src.exists():
                dst.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
                print(f"  Updated {dst}")

        print("\n✓ Wrote outputs into repo Resources paths")


if __name__ == "__main__":
    main()

