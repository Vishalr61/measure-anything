# Measure Anything

A unit conversion app for iOS that mixes real-world measurements with novelty units — Blue Whales, Bowling Balls, T-Rexes and more. Built with SwiftUI.

---

## Features

### Converter
Convert across five categories: **Length, Mass, Time, Temperature, Volume**. Switch between three modes — **Normal** (standard + imperial), **Absurd** (novelty units), and **Custom** (your own). The FROM and TO cards update in real time. Tap the swap button to reverse the direction instantly.

### Novelty Units
100+ absurd units per category, each with a conversion factor, icon, fun fact, and contextual phrase. Examples: Refrigerators, Aircraft Carriers, Bananas, Eiffel Towers, Blue Whales, School Buses, T-Rexes.

### Custom Units
Define your own units by name, size, and reference unit. *My commute in kilometres*, *My dog in kilograms*, *My shower in minutes* — whatever makes sense to you. Custom units are saved locally and appear immediately in the converter and explore screens.

### Explore & Search
Browse all units by category or search by name. Tap any unit as **FROM**, then tap another as **TO** — they open directly in the converter. Tap the **ⓘ** button on any unit to open a fact card with interesting context and comparisons.

### Fact Cards
Each unit has a fact card with a headline value, example comparisons, and trivia. Accessible from the explore screen and from the converter result.

### Dice Roll & Shake
Tap the dice card to roll a random unit in the current category. Long-press for a dual roll that picks both FROM and TO. Shake the device to roll at any time.

### Favourites
Star any conversion pair to save it. Tap the list icon to see all saved pairs and restore any one instantly.

### Share
Tap the share button on any result to generate a card image — FROM value, TO value, category colour, and meme text — ready to send to anyone.

### Settings
- **Precision mode** — show full decimal detail instead of smart rounding
- **My custom units** — view and delete saved units
- **What's in the app?** — a reference guide to every feature
- Rate on App Store / Send feedback

---

## Requirements

- iOS 17+
- Xcode 15+

---

## Project Structure

```
measure-anything/
├── MeasureAnything/          # App target (SwiftUI)
│   ├── Features/
│   │   ├── Converter/        # Converter UI, dice roll, share
│   │   ├── Home/             # Root shell, bottom nav, settings
│   │   ├── Search/           # Explore tab, browse, search, fact cards
│   │   ├── CustomUnit/       # Custom unit creation form
│   │   ├── Favorites/        # Saved conversion pairs
│   │   ├── Onboarding/       # Four-slide interactive tour
│   │   └── Design/           # Colours, spacing, haptics, shared styles
│   ├── Persistence/          # SwiftData models (CustomUnit, FavoriteConversion)
│   └── Services/             # Taxonomy store, fact card store, Crashlytics
├── MeasureAnythingCore/      # SPM library — conversion engine, unit definitions
└── MeasureAnythingTaxonomy/  # SPM library — search index, taxonomy registry
```

**Key dependencies:** SwiftData · StoreKit · Firebase Crashlytics (optional)

---

## Architecture

- **SwiftUI** throughout, iOS 17 APIs
- **SwiftData** for local persistence (custom units, favourites)
- **ConverterViewModel** — central ObservableObject managing category, mode, unit selections, input, results, session state, and dice roll
- **AppTaxonomyStore** — loads and serves the unit registry and search index
- Unit data (normal + absurd) and fact card content loaded from bundled JSON at startup
- `NoAccessoryTextField` — UIViewRepresentable that suppresses the iOS keyboard input accessory bar
- `PointerTargetKey` — SwiftUI PreferenceKey used in onboarding to anchor animated pointers to live UI elements
- Light colour scheme enforced app-wide; category accent colours drive all tinting

---

## Building

1. Open `MeasureAnything/MeasureAnything.xcodeproj` in Xcode.
2. Select the **MeasureAnything** scheme and a simulator or connected device.
3. **Product → Build** (`⌘B`), then **Run** (`⌘R`).

---

## Running Tests

```bash
swift test
```

Runs `MeasureAnythingCoreTests` and `MeasureAnythingTaxonomyTests`. App-level and UI tests run via the Xcode test action for the MeasureAnything scheme.

---

## Author

**Vishal Ramanathan** — `com.vishal.MeasureAnything`

---

## License

Proprietary — all rights reserved.
