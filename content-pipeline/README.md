## Measure Anything — Content pipeline (Airtable ⇄ JSON)

This folder contains scripts to:

- **Import (one-time)** existing bundled content into Airtable.
- **Export (ongoing)** Airtable content back into the app’s JSON resources.
- **Validate (local)** JSON files without Airtable.

### Setup

1. Create an Airtable base named **Measure Anything Content** with these tables:
   - `Units`
   - `Fact Cards`
   - `Comparisons`

2. Create a Personal Access Token with scopes:
   - `data.records:read`
   - `data.records:write`
   - `schema.bases:read`

3. Create a `.env` file in this folder:

```bash
cp .env.example .env
```

4. Install deps:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### One-time import

Imports:
- **Absurd units** from `MeasureAnythingApp/Core/Conversion/Resources/*.json`
- **Normal units** parsed from `MeasureAnythingApp/Core/Conversion/SeedNormalUnits.swift`
- **Fact cards** from `MeasureAnything/MeasureAnything/Resources/FactCardContent_*.json`

```bash
python import_to_airtable.py
```

### Ongoing export

Writes directly into the repo (overwriting generated resources):
- `MeasureAnythingApp/Core/Conversion/Resources/{length,mass,time,volume,temperature}.json`
- `MeasureAnythingApp/Core/Conversion/Resources/normal_{length,mass,time,volume,temperature}.json`
- `MeasureAnything/MeasureAnything/Resources/FactCardContent_{Category}.json`

```bash
python export_from_airtable.py --write-to-repo
```

To preview outputs without touching the repo, export to a directory:

```bash
python export_from_airtable.py --output-dir /tmp/measure-anything-export
```

### Local JSON validation (no Airtable)

```bash
python validate_json.py \
  --units-dir MeasureAnythingApp/Core/Conversion/Resources \
  --facts-dir MeasureAnything/MeasureAnything/Resources
```

