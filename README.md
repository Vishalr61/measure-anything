# Measure Anything

**Measure Anything** is an iOS app for playful and practical unit conversion. Switch between everyday scales and deliberately absurd comparators—blue whales, Olympic pools, light-years — across length, mass, time, temperature, and volume. The app pairs a fast conversion workspace with **Explore** search, curated **fact cards**, favorites, and custom units.

---

## Features


| Area             | Description                                                                                                                                                      |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Convert**      | Category-scoped picker, live conversion, optional meme lines, and share-friendly output.                                                                         |
| **Explore**      | Global unit search, category browse, recent pairs, and tiered **fact cards** (headline, fun fact, value band, comparisons with optional rabbit-hole navigation). |
| **Favorites**    | SwiftData–backed saved from/to pairs per category.                                                                                                               |
| **Custom units** | User-defined absurd units with optional SF Symbol and validation against the engine.                                                                             |
| **Design**       | Per-category color ramps and repeating header patterns aligned with Explore tiles.                                                                               |


---

## Architecture

```text
measure-anything/
├── Package.swift                    # SPM: MeasureAnythingCore + MeasureAnythingTaxonomy
├── MeasureAnythingApp/
│   └── Core/
│       ├── Conversion/            # UnitDefinition, registry, JSON catalog (per category)
│       └── Taxonomy/              # Category metadata bundled as MeasureAnythingTaxonomy
├── MeasureAnything/               # Xcode iOS application target
│   └── MeasureAnything/
│       ├── Features/              # SwiftUI: Home, Converter, Explore, Search, Fact cards
│       ├── Resources/             # FactCardContent_<Category>.json (merged at runtime)
│       ├── Services/              # FactCardStore, taxonomy bridge
│       └── Persistence/           # SwiftData models (CustomUnit, FavoriteConversion)
└── MeasureAnythingTests/          # Unit tests (SPM targets)
```

- `**MeasureAnythingCore**` — Pure Swift conversion logic, `UnitDefinition`, absurd unit loading from JSON resources (`mass.json`, `length.json`, etc.), and temperature special cases.
- `**MeasureAnythingTaxonomy**` — Depends on Core; ships additional taxonomy resources.
- **Application target** — SwiftUI + SwiftData host; links local SPM products; hosts Explore UI and `FactCardStore` (merges per-category fact JSON into one lookup).

Fact card copy lives in `**MeasureAnything/MeasureAnything/Resources/FactCardContent_*.json`**; unit definitions live under `**MeasureAnythingApp/Core/Conversion/Resources/**`.

---

## Requirements

- **Xcode** with an iOS SDK matching the project’s deployment target (see `IPHONEOS_DEPLOYMENT_TARGET` in `MeasureAnything.xcodeproj`).
- **Swift** 5.10+ (see `Package.swift` `swift-tools-version`).
- **Apple Silicon or Intel** Mac for building; device or simulator for running.

The Swift package declares **iOS 17** / **macOS 14** as minimum platforms for the libraries; the app target may pin a newer SDK—always take the **stricter** of the two when planning CI or devices.

---

## Building the iOS app

1. Open `**MeasureAnything/MeasureAnything.xcodeproj`** in Xcode.
2. Select the **MeasureAnything** scheme and a simulator or connected device.
3. **Product → Build** (`⌘B`), then **Run** (`⌘R`).

The app entry point is `MeasureAnythingApp` (`HomeView` as root). Core packages are resolved as local Swift package dependencies.

---

## Running tests

From the repository root:

```bash
swift test
```

This runs `**MeasureAnythingCoreTests**` and `**MeasureAnythingTaxonomyTests**` defined in `Package.swift`.

Additional **MeasureAnythingTests** (app target) and **MeasureAnythingUITests** run from the Xcode project’s test actions for the **MeasureAnything** scheme.

---

## Content and assets

- **Unit catalogs** — JSON per `UnitCategory` under `MeasureAnythingApp/Core/Conversion/Resources/` (e.g. `mass.json`). Each unit may include `funFact`, `iconName` (SF Symbol), and conversion metadata.
- **Fact cards** — `FactCardContent_<Mass|Length|Volume|Time|Temperature>.json` in the app bundle; `FactCardStore` loads and merges them. Malformed files are skipped with a console log so the rest of the app still launches.

---

## Development notes

- **Icons** — Prefer `iconName` on `UnitDefinition` (SF Symbol). Explore/fact UI falls back to a single category glyph when absent.
- **Light mode** — The root scene currently prefers light appearance (`preferredColorScheme(.light)`); adjust in `MeasureAnythingApp.swift` if you add dark mode.

---

## Author

**Vishal Ramanathan** — personal / shipping project (`com.vishal.MeasureAnything`).

---

## License

Proprietary; all rights reserved unless otherwise noted in this repository.