#!/usr/bin/env python3
"""
Import Measure Anything content into Airtable.

This is intended as a one-time migration, but it is implemented as an **upsert**
so it can be rerun safely while iterating.

Imports:
  - Absurd unit JSON: MeasureAnythingApp/Core/Conversion/Resources/{length,mass,time,volume,temperature}.json
  - Normal unit seed (Swift): MeasureAnythingApp/Core/Conversion/SeedNormalUnits.swift
  - Fact cards JSON: MeasureAnything/MeasureAnything/Resources/FactCardContent_*.json

Usage:
  python import_to_airtable.py
  python import_to_airtable.py --dry-run
  python import_to_airtable.py --repo-root /path/to/measure-anything
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

try:
    from dotenv import load_dotenv  # type: ignore

    load_dotenv()
except Exception:
    # Allow running without python-dotenv installed (env vars still work).
    pass

AIRTABLE_PAT = os.getenv("AIRTABLE_PAT")
AIRTABLE_BASE_ID = os.getenv("AIRTABLE_BASE_ID")

# Airtable table names — must match what you created in the base
UNITS_TABLE = "Units"
FACT_CARDS_TABLE = "Fact Cards"
COMPARISONS_TABLE = "Comparisons"

# Airtable API rate limit: 5 requests per second
RATE_LIMIT_DELAY = 0.22

ABSURD_UNIT_FILES = ["length.json", "mass.json", "time.json", "temperature.json", "volume.json"]
FACT_CARD_FILES = [
    "FactCardContent_Length.json",
    "FactCardContent_Mass.json",
    "FactCardContent_Time.json",
    "FactCardContent_Temperature.json",
    "FactCardContent_Volume.json",
]


def load_json(filepath: Path) -> Any:
    with open(filepath, "r", encoding="utf-8") as f:
        return json.load(f)


def chunked(seq: List[Any], size: int) -> List[List[Any]]:
    return [seq[i : i + size] for i in range(0, len(seq), size)]


def safe_str(v: Any) -> str:
    if v is None:
        return ""
    return str(v)


def rate_limit_pause() -> None:
    time.sleep(RATE_LIMIT_DELAY)


def batch_create(table, records: List[Dict[str, Any]], batch_size: int = 10):
    created = []
    for batch in chunked(records, batch_size):
        created.extend(table.batch_create([r["fields"] for r in batch]))
        rate_limit_pause()
    return created


def batch_update(table, records: List[Dict[str, Any]], batch_size: int = 10):
    updated = []
    for batch in chunked(records, batch_size):
        updated.extend(table.batch_update(batch))
        rate_limit_pause()
    return updated


@dataclass(frozen=True)
class RepoPaths:
    repo_root: Path

    @property
    def absurd_units_dir(self) -> Path:
        return self.repo_root / "MeasureAnythingApp" / "Core" / "Conversion" / "Resources"

    @property
    def fact_cards_dir(self) -> Path:
        return self.repo_root / "MeasureAnything" / "MeasureAnything" / "Resources"

    @property
    def seed_normal_units_swift(self) -> Path:
        return self.repo_root / "MeasureAnythingApp" / "Core" / "Conversion" / "SeedNormalUnits.swift"


def parse_seed_normal_units(seed_file: Path) -> List[Dict[str, Any]]:
    """
    Parse `SeedNormalUnits.swift` into Airtable-ready unit dictionaries.

    This parser is intentionally pragmatic: it extracts the common patterns used in the file:
      - single-line `UnitDefinition(id: "...", name: "...", category: .x, baseUnit: "...", kind: .normal, factor: <number>)`
      - multi-line `UnitDefinition(` with `id: "..."` etc, including optional `funFact: "..."`
      - temperature scale units expressed as `TemperatureUnit.<x>.unitID` and `conversionStyle: .temperature`
    """
    text = seed_file.read_text(encoding="utf-8")

    # Remove Swift comments (line comments only; good enough here).
    text_no_comments = re.sub(r"//.*", "", text)

    units: List[Dict[str, Any]] = []

    # Pattern A: single-line UnitDefinition(...)
    single_line = re.compile(
        r"""UnitDefinition\(
            \s*id:\s*"(?P<id>[^"]+)"\s*,\s*
            name:\s*"(?P<name>[^"]+)"\s*,\s*
            category:\s*\.(?P<category>[a-zA-Z_]+)\s*,\s*
            baseUnit:\s*"(?P<baseUnit>[^"]+)"\s*,\s*
            kind:\s*\.(?P<kind>[a-zA-Z_]+)\s*,\s*
            factor:\s*(?P<factor>[^,\)]+)
            """,
        re.VERBOSE,
    )

    for m in single_line.finditer(text_no_comments):
        units.append(
            {
                "id": m.group("id"),
                "name": m.group("name"),
                "category": m.group("category"),
                "baseUnit": m.group("baseUnit"),
                "kind": m.group("kind"),
                "conversionStyle": "multiplicative",
                "factor": _parse_swift_number(m.group("factor")),
            }
        )

    # Pattern B: multi-line UnitDefinition( ... ) blocks
    # We capture each UnitDefinition(...) call body non-greedily.
    block = re.compile(r"UnitDefinition\(\s*(?P<body>[\s\S]*?)\)\s*,?", re.MULTILINE)
    key_string = re.compile(r'(?P<key>[a-zA-Z_]+)\s*:\s*"(?P<value>[^"]*)"')
    key_enum = re.compile(r"(?P<key>[a-zA-Z_]+)\s*:\s*\.(?P<value>[a-zA-Z_]+)")
    key_temp_unit = re.compile(r"id\s*:\s*TemperatureUnit\.(?P<value>[a-zA-Z_]+)\.unitID")
    key_factor = re.compile(r"factor\s*:\s*(?P<value>[^,\n\)]+)")

    for m in block.finditer(text_no_comments):
        body = m.group("body")

        # Temperature blocks are special: conversionStyle: .temperature, no factor.
        temp_id = None
        temp_id_match = key_temp_unit.search(body)
        if temp_id_match:
            temp_id = temp_id_match.group("value")

        # Pull common fields from block.
        fields: Dict[str, Any] = {}
        for sm in key_string.finditer(body):
            fields[sm.group("key")] = sm.group("value")
        for em in key_enum.finditer(body):
            # only keep enums we care about
            if em.group("key") in {"category", "kind", "conversionStyle"}:
                fields[em.group("key")] = em.group("value")

        # If it's a temperature scale unit, build directly.
        if temp_id is not None and fields.get("conversionStyle") == "temperature":
            units.append(
                {
                    "id": temp_id,
                    "name": fields.get("name", temp_id.capitalize()),
                    "category": "temperature",
                    "baseUnit": fields.get("baseUnit", "kelvin"),
                    "kind": fields.get("kind", "normal"),
                    "conversionStyle": "temperature",
                    "factor": None,
                }
            )
            continue

        # Otherwise, we only want normal multiplicative units from this file.
        if fields.get("kind") != "normal":
            continue
        if "category" not in fields or "id" not in fields or "name" not in fields or "baseUnit" not in fields:
            continue

        factor_match = key_factor.search(body)
        if not factor_match:
            # Non-temperature normal units always have a factor in this file.
            continue

        unit = {
            "id": fields["id"],
            "name": fields["name"],
            "category": fields["category"],
            "baseUnit": fields["baseUnit"],
            "kind": "normal",
            "conversionStyle": "multiplicative",
            "factor": _parse_swift_number(factor_match.group("value")),
        }

        # Optional funFact.
        if "funFact" in fields and fields["funFact"].strip():
            unit["funFact"] = fields["funFact"].strip()

        units.append(unit)

    # Deduplicate by id, keep first
    seen = set()
    out: List[Dict[str, Any]] = []
    for u in units:
        uid = u.get("id")
        if not uid or uid in seen:
            continue
        seen.add(uid)
        out.append(u)
    return out


def _parse_swift_number(expr: str) -> Optional[float]:
    """
    Parse Swift numeric literals used in SeedNormalUnits.swift (e.g. 1e-12, 0.0254, 1.495978707e+11).
    Returns float or None if it cannot parse.
    """
    s = expr.strip()
    # Remove trailing tokens sometimes present.
    s = re.sub(r"[,\)]$", "", s).strip()
    # Swift allows underscores in numeric literals; remove them.
    s = s.replace("_", "")
    try:
        return float(s)
    except ValueError:
        return None


def load_absurd_units(absurd_dir: Path) -> List[Dict[str, Any]]:
    all_units: List[Dict[str, Any]] = []
    for filename in ABSURD_UNIT_FILES:
        filepath = absurd_dir / filename
        if not filepath.exists():
            print(f"  Warning: {filepath} not found, skipping")
            continue
        units = load_json(filepath)
        if not isinstance(units, list):
            raise ValueError(f"{filepath} expected a JSON array")
        all_units.extend(units)
        print(f"  Loaded {len(units)} absurd units from {filename}")
    return all_units


def load_fact_cards(fact_dir: Path) -> Dict[str, Dict[str, Any]]:
    all_cards: Dict[str, Dict[str, Any]] = {}
    for filename in FACT_CARD_FILES:
        filepath = fact_dir / filename
        if not filepath.exists():
            print(f"  Warning: {filepath} not found, skipping")
            continue
        data = load_json(filepath)
        cards = data.get("cards", {})
        if not isinstance(cards, dict):
            raise ValueError(f"{filepath} expected object with 'cards'")
        all_cards.update(cards)
        print(f"  Loaded {len(cards)} fact cards from {filename}")
    return all_cards


def build_units_payload(units: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    payload: List[Dict[str, Any]] = []
    for unit in units:
        fields: Dict[str, Any] = {
            "id": safe_str(unit.get("id", "")).strip(),
            "name": safe_str(unit.get("name", "")).strip(),
            "category": safe_str(unit.get("category", "")).strip(),
            "baseUnit": safe_str(unit.get("baseUnit", "")).strip(),
            "kind": safe_str(unit.get("kind", "") or "absurd").strip(),
            "conversionStyle": safe_str(unit.get("conversionStyle", "") or "multiplicative").strip(),
            "factor": unit.get("factor", None),
            "iconName": safe_str(unit.get("iconName", "")).strip(),
            "description": safe_str(unit.get("description", "")).strip(),
            "funFact": safe_str(unit.get("funFact", "")).strip(),
            "exampleMeme": safe_str(unit.get("exampleMeme", "")).strip(),
            "interestScore": unit.get("interestScore", None),
        }

        offset = unit.get("offset", None)
        if offset is not None:
            fields["offset"] = offset

        payload.append({"fields": fields})
    return payload


def upsert_units(units_table, units: List[Dict[str, Any]], dry_run: bool) -> Dict[str, str]:
    """
    Upsert Units by the `id` field (primary key).
    Returns mapping: unit_id_string -> airtable_record_id
    """
    print("Fetching existing Units…")
    existing = units_table.all(fields=["id"])
    rate_limit_pause()
    existing_by_unit_id = {}
    for r in existing:
        uid = r.get("fields", {}).get("id")
        if uid:
            existing_by_unit_id[uid] = r["id"]

    records = build_units_payload(units)

    to_create = []
    to_update = []
    for rec in records:
        uid = rec["fields"].get("id")
        if not uid:
            continue
        existing_id = existing_by_unit_id.get(uid)
        if existing_id:
            to_update.append({"id": existing_id, "fields": rec["fields"]})
        else:
            to_create.append(rec)

    print(f"Units upsert: {len(to_update)} update, {len(to_create)} create")
    if dry_run:
        # Return best-effort map for downstream dry-run checks
        out = dict(existing_by_unit_id)
        for rec in to_create:
            out[rec["fields"]["id"]] = f"DRYRUN_{rec['fields']['id']}"
        return out

    if to_update:
        batch_update(units_table, to_update)
    created = []
    if to_create:
        created = batch_create(units_table, to_create)

    # Refresh mapping from Airtable (so links always work)
    all_now = units_table.all(fields=["id"])
    rate_limit_pause()
    out: Dict[str, str] = {}
    for r in all_now:
        uid = r.get("fields", {}).get("id")
        if uid:
            out[uid] = r["id"]
    print(f"Units table: {len(out)} total records")
    return out


def upsert_fact_cards(cards_table, cards: Dict[str, Dict[str, Any]], unit_id_map: Dict[str, str], dry_run: bool) -> Dict[str, str]:
    """
    Upsert Fact Cards keyed by linked `unitID` (one-to-one).
    Returns mapping: unit_id_string -> fact_card_record_id
    """
    print("Fetching existing Fact Cards…")
    existing = cards_table.all(fields=["unitID"])
    rate_limit_pause()

    existing_by_unit_record_id: Dict[str, str] = {}
    for r in existing:
        links = r.get("fields", {}).get("unitID", [])
        if isinstance(links, list) and links:
            existing_by_unit_record_id[links[0]] = r["id"]

    to_create = []
    to_update = []

    for unit_id, card in cards.items():
        unit_record_id = unit_id_map.get(unit_id)
        if not unit_record_id:
            print(f"  Warning: skipping card for unknown unit '{unit_id}'")
            continue
        fields = {
            "unitID": [unit_record_id],
            "valueHeadline": safe_str(card.get("valueHeadline", "")).strip(),
            "valueDisplay": safe_str(card.get("valueDisplay", "")).strip(),
        }
        existing_id = existing_by_unit_record_id.get(unit_record_id)
        if existing_id:
            to_update.append({"id": existing_id, "fields": fields})
        else:
            to_create.append({"fields": fields})

    print(f"Fact Cards upsert: {len(to_update)} update, {len(to_create)} create")
    if dry_run:
        out: Dict[str, str] = {}
        for unit_id, unit_record_id in unit_id_map.items():
            # fill with placeholders only for units that have cards
            pass
        for unit_id, card in cards.items():
            unit_record_id = unit_id_map.get(unit_id)
            if not unit_record_id:
                continue
            existing_id = existing_by_unit_record_id.get(unit_record_id)
            out[unit_id] = existing_id or f"DRYRUN_CARD_{unit_id}"
        return out

    if to_update:
        batch_update(cards_table, to_update)
    if to_create:
        batch_create(cards_table, to_create)

    # Rebuild mapping after upsert
    refreshed = cards_table.all(fields=["unitID"])
    rate_limit_pause()
    out: Dict[str, str] = {}
    for r in refreshed:
        links = r.get("fields", {}).get("unitID", [])
        if isinstance(links, list) and links:
            unit_record_id = links[0]
            # reverse lookup: find the unit_id string for this unit record id
            # (unit_id_map is string->record_id; invert once)
            pass

    inv_unit_map = {v: k for k, v in unit_id_map.items()}
    for r in refreshed:
        links = r.get("fields", {}).get("unitID", [])
        if isinstance(links, list) and links:
            unit_record_id = links[0]
            unit_id = inv_unit_map.get(unit_record_id)
            if unit_id:
                out[unit_id] = r["id"]

    print(f"Fact Cards table: {len(out)} linked records")
    return out


def upsert_comparisons(comp_table, cards: Dict[str, Dict[str, Any]], unit_id_map: Dict[str, str], card_id_map: Dict[str, str], dry_run: bool) -> None:
    """
    Upsert Comparisons keyed by (cardUnit, sortOrder).
    This matches the app output ordering.
    """
    print("Fetching existing Comparisons…")
    existing = comp_table.all(fields=["cardUnit", "sortOrder"])
    rate_limit_pause()

    existing_by_key: Dict[Tuple[str, int], str] = {}
    for r in existing:
        f = r.get("fields", {})
        card_links = f.get("cardUnit", [])
        sort_order = f.get("sortOrder")
        if isinstance(card_links, list) and card_links and isinstance(sort_order, int):
            existing_by_key[(card_links[0], sort_order)] = r["id"]

    to_create = []
    to_update = []
    skipped = 0

    for unit_id, card in cards.items():
        card_record_id = card_id_map.get(unit_id)
        if not card_record_id:
            continue
        comparisons = card.get("comparisons", []) or []
        for sort_order, comp in enumerate(comparisons, 1):
            target_id = safe_str(comp.get("targetUnitID", "")).strip()
            target_record_id = unit_id_map.get(target_id)
            if not target_record_id:
                skipped += 1
                continue
            fields = {
                "cardUnit": [card_record_id],
                "targetUnitID": [target_record_id],
                "template": safe_str(comp.get("template", "")).strip(),
                "sortOrder": sort_order,
            }
            key = (card_record_id, sort_order)
            existing_id = existing_by_key.get(key)
            if existing_id:
                to_update.append({"id": existing_id, "fields": fields})
            else:
                to_create.append({"fields": fields})

    print(f"Comparisons upsert: {len(to_update)} update, {len(to_create)} create, {skipped} skipped (missing targets)")
    if dry_run:
        return
    if to_update:
        batch_update(comp_table, to_update)
    if to_create:
        batch_create(comp_table, to_create)


def main() -> None:
    parser = argparse.ArgumentParser(description="Import Measure Anything content to Airtable (upsert)")
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Path to the measure-anything repo root (defaults to parent of this script)",
    )
    parser.add_argument("--dry-run", action="store_true", help="Parse inputs but do not write to Airtable")
    args = parser.parse_args()

    if not args.repo_root.exists():
        print(f"Error: repo root {args.repo_root} does not exist")
        sys.exit(1)

    paths = RepoPaths(repo_root=args.repo_root)

    absurd_units = load_absurd_units(paths.absurd_units_dir)
    normal_units = parse_seed_normal_units(paths.seed_normal_units_swift)
    fact_cards = load_fact_cards(paths.fact_cards_dir)

    # Merge units (prefer normal definitions if collision happens; collisions should be rare but possible).
    merged_by_id: Dict[str, Dict[str, Any]] = {}
    for u in absurd_units + normal_units:
        uid = u.get("id")
        if not uid:
            continue
        if uid in merged_by_id:
            # Keep existing; log once.
            continue
        merged_by_id[uid] = u
    merged_units = list(merged_by_id.values())

    print(f"\nLoaded {len(absurd_units)} absurd units, {len(normal_units)} normal units, {len(fact_cards)} fact cards")

    if args.dry_run:
        print("\n=== DRY RUN — no Airtable writes ===")
        # Basic reference sanity.
        unit_ids = set(merged_by_id.keys())
        missing_cards = [uid for uid in fact_cards.keys() if uid not in unit_ids]
        if missing_cards:
            print(f"  ERROR: {len(missing_cards)} fact cards reference missing units (sample: {missing_cards[:10]})")
        else:
            print("  ✓ All fact-card unitIDs exist in merged unit set")
        return

    if not AIRTABLE_PAT or not AIRTABLE_BASE_ID:
        print("Error: Set AIRTABLE_PAT and AIRTABLE_BASE_ID in content-pipeline/.env")
        sys.exit(1)

    from pyairtable import Api

    api = Api(AIRTABLE_PAT)
    units_table = api.table(AIRTABLE_BASE_ID, UNITS_TABLE)
    cards_table = api.table(AIRTABLE_BASE_ID, FACT_CARDS_TABLE)
    comps_table = api.table(AIRTABLE_BASE_ID, COMPARISONS_TABLE)

    print("\n=== Step 1: Upserting Units ===")
    unit_id_map = upsert_units(units_table, merged_units, dry_run=False)

    print("\n=== Step 2: Upserting Fact Cards ===")
    card_id_map = upsert_fact_cards(cards_table, fact_cards, unit_id_map, dry_run=False)

    print("\n=== Step 3: Upserting Comparisons ===")
    upsert_comparisons(comps_table, fact_cards, unit_id_map, card_id_map, dry_run=False)

    print("\n=== Import complete ===")
    print(f"Units: {len(unit_id_map)}")
    print(f"Fact Cards: {len(card_id_map)}")


if __name__ == "__main__":
    main()

