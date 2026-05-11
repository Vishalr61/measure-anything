# Measure Anything — Claude Code Context

## What this app is
iOS unit converter with absurd/novelty real-world comparisons.
Five categories: Length, Mass, Time, Temperature, Volume.
Unified unit pool (Normal + Absurd + Custom) — no mode toggle in UI.
Note: data layer uses `UnitKind` enum (`.normal` / `.absurd` / `.custom`)
for internal differentiation and Explore filtering. UI treats them as one pool.
Status: v1 feature-complete, in polish/submission phase.

---

## Project structure
measure-anything/
├── MeasureAnything/
│   └── MeasureAnything/
│       ├── Features/
│       │   ├── Converter/
│       │   │   ├── ConverterWorkspaceBody.swift   # FROM/TO cards, input, keyboard
│       │   │   ├── ConverterView.swift             # Standalone preview wrapper only
│       │   │   ├── ConverterViewModel.swift        # All converter state + logic
│       │   │   ├── ToCard.swift                    # TO result card (copy/share/save/star)
│       │   │   ├── ShareCardView.swift             # Share card visual — fixed 390×693pt
│       │   │   ├── SharePreviewOverlay.swift       # Blur overlay shown on share tap
│       │   │   ├── DiceRollCard.swift
│       │   │   ├── DidYouKnowCard.swift            # Renders unit.funFact — active in v1
│       │   │   ├── UnitScaleGroups.swift           # Scale group hardcoding per unit ID
│       │   │   ├── UnitPickerSheet.swift
│       │   │   ├── UnitPickerPillButton.swift
│       │   │   ├── ActionButton.swift
│       │   │   ├── AppDefaults.swift
│       │   │   ├── ConversionHistory.swift
│       │   │   ├── DiceFaceView.swift
│       │   │   ├── OnShakeModifier.swift
│       │   │   └── UnitCategory+DiceTilt.swift
│       │   ├── Share/
│       │   │   └── ActivityView.swift             # Exists but unused — UIActivityViewController
│       │   │                                      # is presented directly, not via this wrapper
│       │   ├── CustomUnit/
│       │   │   ├── CustomUnitFormView.swift       # Create a unit — keyboard reference impl
│       │   │   └── ReferenceUnitPickerSheet.swift
│       │   ├── Design/
│       │   │   ├── ConverterCategoryAccent.swift  # Accent colour resolution — always use this
│       │   │   ├── ConverterCategoryPalette.swift
│       │   │   ├── ConverterControlStyles.swift
│       │   │   ├── ConverterLayout.swift          # Spacing constants
│       │   │   ├── Color+Hex.swift                # Color(hex:) extension
│       │   │   ├── Haptics.swift
│       │   │   ├── KeyboardObserver.swift
│       │   │   ├── TaxonomyDisplayModifiers.swift
│       │   │   └── UnitCategory+Display.swift     # symbolName / displayName extension
│       │   ├── Favorites/
│       │   │   └── FavoritesListView.swift        # Card style + Done button reference
│       │   ├── Home/
│       │   │   ├── HomeView.swift                 # Root tab, nav bar, scroll, share overlay
│       │   │   ├── BottomNav.swift
│       │   │   ├── CategoryChip.swift
│       │   │   ├── CustomUnitsListView.swift
│       │   │   └── SettingsTabView.swift
│       │   ├── Onboarding/
│       │   │   └── OnboardingOverlayView.swift
│       │   ├── OnboardingView.swift               # Lives at Features/ root, not Onboarding/
│       │   ├── LaunchAnimationView.swift
│       │   └── Search/
│       │       ├── ExploreView.swift
│       │       ├── GlobalUnitSearchView.swift     # Search results view
│       │       ├── CategoryBrowseCard.swift
│       │       ├── CategoryTile.swift
│       │       ├── CategoryTilePattern.swift
│       │       ├── ExplorePlaceholders.swift
│       │       ├── FactCardRowAffordance.swift
│       │       ├── FactCardSheet.swift
│       │       ├── RecentPairRow.swift
│       │       ├── SearchCategoryIcon.swift
│       │       ├── TryTheseSuggestions.swift
│       │       └── UnitBrowseRow.swift            # ⓘ button replacing chevron
│       ├── Persistence/
│       │   ├── CustomUnit.swift                   # SwiftData model
│       │   ├── CustomUnit+UnitDefinition.swift
│       │   ├── FavoriteConversion.swift           # SwiftData model
│       │   └── FavoriteConversion+Restore.swift
│       ├── Services/
│       │   ├── AppTaxonomyStore.swift
│       │   ├── CrashlyticsManager.swift
│       │   └── FactCardStore.swift
│       ├── Models/
│       │   └── FactCardContent.swift
│       └── MeasureAnythingApp.swift
├── MeasureAnythingApp/                            # Swift package: conversion engine
│   └── Core/
│       ├── Conversion/
│       │   ├── ConverterEngine.swift              # PROTECTED — do not touch
│       │   ├── UnitDefinition.swift
│       │   ├── UnitCategory.swift
│       │   ├── UnitKind.swift                     # .normal / .absurd / .custom
│       │   ├── UnitRegistry.swift                 # PROTECTED — do not touch
│       │   ├── TemperatureConverter.swift         # PROTECTED — offset-style conversion
│       │   ├── TemperatureUnit.swift
│       │   ├── ConversionStyle.swift
│       │   ├── ConversionResult.swift
│       │   ├── AbsurdUnitStore.swift
│       │   ├── NormalUnitStore.swift
│       │   └── SeedNormalUnits.swift
│       └── Taxonomy/
│           ├── TaxonomyModels.swift
│           ├── TaxonomyRegistry.swift
│           └── TaxonomySearch.swift
├── scripts/                                       # PROTECTED — Airtable pipeline
├── taxonomy/                                      # PROTECTED — Node.js taxonomy tooling
└── Tests/
├── MeasureAnythingCoreTests/
└── MeasureAnythingTaxonomyTests/

---

## Architecture

- **SwiftUI + SwiftData** throughout. No UIKit except where explicitly necessary.
- **Light mode only** — forced via `.preferredColorScheme(.light)` on root. No dark mode for v1.
- **Keyboard** — plain SwiftUI `TextField` + `@FocusState` only. No UIKit bridging.
  Canonical reference: `CustomUnitFormView`. Always match its pattern.
- **Temperature** — `conversionStyle: "offset"`, `baseUnit: "celsius"`. Not multiplicative.
- **Input limit** — 9 digits max + 1 decimal point (10 chars total).
  Enforced via `.onChange` in both `ConverterWorkspaceBody` and `CustomUnitFormView`.
- **Share card** — fixed render size 390×693pt, `ImageRenderer` at scale 3.0.
  Preview shown as blur overlay (`SharePreviewOverlay`) on home page — not a new sheet.
  `UIActivityViewController` presented directly. `ActivityView.swift` is unused.

---

## Category colour system

Never hardcode category colours inline.
Always resolve through `ConverterCategoryAccent.swift`.

| Category    | App accent | Share card (vibrant) |
|-------------|------------|----------------------|
| Length      | #1A5F73    | #1A6E87              |
| Mass        | #3D6B4A    | #3D7A52              |
| Time        | #3D3580    | #4A3FA0              |
| Temperature | #8B3A2A    | #A84232              |
| Volume      | #AF7D2A    | #C48E2E              |

---

## Design system rules

**Toolbar / nav bar buttons — plain text only, no pill or capsule:**
- All action buttons (Save, Done, Cancel, Close): current category accent colour
- Destructive (Delete): `Color.red`
- Font: `.system(size: 16, weight: .semibold)`
- Reference implementation: `FavoritesListView` Done button

**Unit list rows:**
- Icon tile: `categoryAccent.opacity(0.12)` bg, category SF Symbol in accent colour
- `FavoritesListView` uses 42×42pt tiles at `opacity(0.12)`
- `CustomUnitsListView` uses 44×44pt tiles at `opacity(0.1)`
- These two do not currently match — do not assume either is the reference for the other
- Category pill: `categoryAccent.opacity(0.12)` bg, accent text, `Capsule`, no border
- Chevrons replaced by ⓘ button throughout unit browse lists (`UnitBrowseRow`)

**Hint banners (Tap two units to convert):**
- Category browse screen: `categoryAccent.opacity(0.1)` bg, accent icon + text
- All Units page, Search results, Explore home: neutral —
  `#F0F0F0` bg, `#1A1A1A` text, `#6E6E6E` body, `#B0B0B0` dismiss X

**Favourite toggle:**
- Both the nav bar star and the TO card SAVE button toggle the pair
- Filled star + "SAVED" = favourited (accent colour)
- Empty star + "SAVE" = unfavourited (default colour)
- `isCurrentPairFavourited` recomputes automatically when fromUnit or toUnit changes

**Did You Know card:**
- Actively renders `unit.funFact` in v1 via `DidYouKnowCard`
- Style: `DID YOU KNOW` badge header in accent colour, no divider,
  circular arrow button, fact text with `.fixedSize(horizontal: false, vertical: true)`,
  no line limit, no fixed height constraint

**Onboarding pointer system:**
- Base position resolved via `anchorPreference` / `overlayPreferenceValue` — never hardcoded
- Per-slide `pointerXOffset` / `pointerYOffset` fields exist on `OnboardingSlide` as a
  deliberate fine-tuning layer on top of the anchor system (e.g. exploreSlide uses offset adjustments)
- Page accent colours: Length teal, Mass green, Time purple, Temp terracotta

---

## Locked decisions

- Light mode only — no dark mode for v1
- No Android, no web
- No subscription or paywall for v1 — free ship
- No unit pool mode toggle in the UI
- `swift test` exits with signal 11 after suites pass — not a real failure, ignore it

---

## Protected files — always ask before modifying

- `ConverterEngine.swift`
- `TemperatureConverter.swift`
- `TemperatureUnit.swift`
- `UnitRegistry.swift`
- `UnitScaleGroups.swift`
- `AppTaxonomyStore.swift`
- `MeasureAnythingApp.swift`
- Anything in `scripts/` or `taxonomy/`

---

## Git rules

- **Always ask before committing.** Never commit autonomously.
- **Never include Claude in commit messages.** No "Generated by Claude", no "Claude suggested".
- Never push without explicit instruction.
- Never modify `.gitignore` without asking.

---

## Prompting workflow

1. Read the relevant file(s) before proposing any change.
2. State what you found and what you plan to do.
3. Make the smallest change that solves the problem — no opportunistic refactoring.
4. Flag compile risks before applying changes.
5. After each change, state what was modified and what to test.
6. Never touch files not mentioned in the prompt.

---

## Keeping CLAUDE.md accurate

This file is a living contract between the codebase and Claude Code.
Code and doc must never silently diverge.

**Claude Code's responsibility:**
After any implementation change that affects a rule, pattern, file path,
colour value, or architectural decision documented here, Claude Code must:
1. Flag it explicitly: "This change affects CLAUDE.md — specifically [section/line]."
2. State what the doc currently says vs what the code now does.
3. Ask: "Should I update CLAUDE.md to match?"
4. Wait for confirmation before updating the doc.

**Never silently let code and doc diverge.**
If Claude Code is unsure whether a change affects the doc, it flags it anyway.
False positives are fine. Silent drift is not.

**Developer responsibility:**
When making changes outside of Claude Code sessions (manual edits, Xcode refactors,
direct commits), update CLAUDE.md in the same commit if any documented rule changes.
Treat CLAUDE.md like a type signature — if the implementation changes, the contract changes.

**Re-audit trigger:**
Run a full accuracy check before any major feature push or App Store submission.
The audit process: compare all file paths against filesystem, cross-check all
design rules and colour values against actual code, verify all edge case rules
against current implementation.

---

## Edge cases — always account for these

**Input:**
- Max 9 digits + 1 decimal point. Filter via `.onChange`, not `onCommit`.
- Negative results are valid — especially Temperature (e.g. Absolute zero conversions).
- Empty input must show placeholder, not crash or show zero unexpectedly.

**Share card number formatting:**
- Raw Swift Double strings may arrive as scientific notation (`1.235e+08`).
  Always parse via `Double(value)` — never compare strings directly.
- ≥1B → `1.2B`, ≥1M → `1.2M`, ≥10,000 → thousands-separated integer.
- Below 10,000 → 4 significant figures.
- Precision mode ON: `=` + `PRECISION` badge replaces `≈`.
- Exponents rendered via `ExponentTextView` — never use `^` notation.
- Unit names truncated to 20 chars with `…` on share card (FROM chip and result unit).
- `formatForCard()` must be applied in both the preview overlay and `ImageRenderer` capture.
  Never pass the unformatted value to either — always wrap `vm.formatNumberForDisplay(r.outputValue)` through `formatForCard()` first,
  where `r` is `vm.conversionResult`.
  
**Category theming:**
- All accent-coloured elements update simultaneously on category switch.
- Share card uses vibrant colour variants, not the app accent colours.

**Keyboard:**
- Never introduce UIKit for keyboard handling.
- `isConverterKeyboardActive` drives nav bar icon swap (✕/✓ replace star/+).
- Home page VStack bottom padding: 120pt when keyboard active, `ConverterLayout.rhythm24` otherwise.
- Chrome background stays `#F0F0F3` regardless of keyboard state — no conditional white flip.

**iPad:**
- `UIActivityViewController` always needs `popoverPresentationController` configured.
- `ImageRenderer` captures at fixed 390×693pt regardless of device screen size.

**SwiftData:**
- Never modify `CustomUnit` or `FavoriteConversion` model schema without explicit instruction.
- Always use the existing `modelContext` patterns from the surrounding file.
