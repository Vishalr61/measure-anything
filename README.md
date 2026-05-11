# Measure Anything

A unit conversion app for iOS that mixes real-world measurements with novelty units — Blue Whales, Bowling Balls, T-Rexes and more. Built with SwiftUI.

---

## Features

### Converter
Convert across five categories: **Length, Mass, Time, Temperature, Volume**. The FROM and TO cards update in real time as you type. Tap the swap button to reverse the direction instantly. Long-press the result to copy; tap COPY / SHARE / SAVE on the TO card for quick actions. Each unit category has its own accent colour that flows through the entire app.

### Novelty Units
100+ absurd units per category, each with a conversion factor, icon, fun fact, and contextual phrase. Examples: Refrigerators, Aircraft Carriers, Bananas, Eiffel Towers, Blue Whales, School Buses, T-Rexes, Bowling Balls.

### Custom Units
Define your own units by name, size, and reference unit. *My commute in kilometres*, *My dog in kilograms*, *My shower in minutes* — whatever makes sense to you. Custom units are saved locally and appear immediately in the converter and explore screens.

### Explore & Search
Browse all units by category or search by name. Tap any unit as **FROM**, then tap another as **TO** — they open directly in the converter. Tap the **ⓘ** button on any unit to open a fact card with interesting context and comparisons.

### Fact Cards
Each unit has a fact card with a headline value, example comparisons, and trivia. Accessible from the explore screen and from the converter result.

### Dice Card
The dice card sits on the converter screen and gives you four ways to land on a surprise conversion:
- **Tap** — roll a new TO unit in the current category
- **Long press** — roll both FROM and TO at once
- **Shake the device** — same as long press, hands-free
- **Swipe left** — enter **Chaos mode**

Each roll plays a slot-machine prelude in the FROM/TO pills that decelerates into the result, with a 3D-tilting die that pip-scrambles mid-spin.

### Chaos Mode
Swipe the dice card left to enter chaos mode. Rolls now pull from absurd units across **every category at once** — landing on a random pair switches the converter's category to match. The card switches to a dark theme with a purple CHAOS badge. Swipe right to exit.

A discovery hint pulses the page-indicator dots in the current category's accent colour and gently shakes the card on first launch — both retire permanently after first use.

### Share Card
Tap **SHARE** on the TO card to open an in-app preview of a 9:16 portrait share card with the conversion result, category-themed colours, and your category icon. Tap **Share image** to send via the system share sheet, or **Save to Photos**. Numbers are formatted intelligently — abbreviated for billions/millions, thousands-separated, and rendered with proper typographic superscripts for scientific notation.

### Favourites
Star any conversion pair from the nav bar or the TO card to save it. Tap the list icon to see all saved pairs and restore any one instantly. Tapping the star again removes the favourite — same star, two-way toggle.

### Settings
- **Precision mode** — show full decimal detail instead of smart rounding
- **My custom units** — view and delete saved units
- **What's in the app?** — a reference guide to every feature
- Rate on App Store / Send feedback

The app also prompts for a rating automatically at conversion milestones (10, 50, 150) — gated by iOS's 3-per-year system rate-limit and persisted thresholds so each tier shows at most once per install.

---

## Requirements

- iOS 17+
- Xcode 15+
- Portrait orientation only (portrait + portrait-upside-down on iPad)

---

## Project Structure

```
measure-anything/
├── MeasureAnything/          # App target (SwiftUI)
│   ├── Features/
│   │   ├── Converter/        # Converter UI, dice card, chaos mode, share card
│   │   ├── Home/             # Root shell, bottom nav, settings
│   │   ├── Search/           # Explore tab, browse, search, fact cards
│   │   ├── CustomUnit/       # Custom unit creation form
│   │   ├── Favorites/        # Saved conversion pairs
│   │   ├── Onboarding/       # Five-slide interactive tour with live mockups
│   │   └── Design/           # Colours, spacing, haptics, shared styles
│   ├── Persistence/          # SwiftData models (CustomUnit, FavoriteConversion)
│   └── Services/             # Taxonomy store, fact card store, Crashlytics
├── MeasureAnythingCore/      # SPM library — conversion engine, unit definitions
└── MeasureAnythingTaxonomy/  # SPM library — search index, taxonomy registry
```

**Key dependencies:** SwiftData · StoreKit · Photos · Firebase Crashlytics (optional)

---

## Architecture

- **SwiftUI** throughout, iOS 17 APIs. No UIKit bridging for input — all `TextField` + `@FocusState`.
- **SwiftData** for local persistence (custom units, favourites). All conversion state lives in memory.
- **ConverterViewModel** — central `ObservableObject` managing category, unit selections, input, conversion results, session state, dice roll mechanics, slot-machine overrides, and chaos mode.
- **AppTaxonomyStore** — loads and serves the unit registry and search index at startup.
- Unit data (normal + absurd) and fact card content loaded from bundled JSON.
- **PointerTargetKey** — SwiftUI `PreferenceKey` used in onboarding to anchor animated pointers to live UI elements; multiple keys for slides needing more than one pointer.
- **ShareCardView + ImageRenderer @3x** — fixed 390×693pt portrait card rendered at high resolution regardless of device, so iPhone and iPad produce identical share images.
- **UIActivityViewController** presented directly via UIKit with `popoverPresentationController` configured for iPad.
- Light colour scheme enforced app-wide; category accent colours drive all tinting. Each category has both a standard accent (used in the app) and a vibrant variant (used on share cards).

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
