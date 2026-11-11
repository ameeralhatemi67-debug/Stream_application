# Lantern and Arch: how to build a screen

Lantern and Arch is the third design of the app (ADR-026). This file is the working guide for anyone who adds or changes a Lantern screen.

## The one rule

The two older designs, gold & black and Hedayah, must look and behave exactly as before. A Lantern widget is never built when one of them is active. `test/lantern_isolation_test.dart` checks this in two ways: every public widget class in a `lantern/` folder must say `implements LanternSkinWidget`, and no widget with that mark may be in the tree of an older design's screen.

So, when you touch a file that the older designs use, the only change allowed is a branch that runs for Lantern alone:

```dart
@override
Widget build(BuildContext context) {
  if (context.isLanternSkin) return LanternLessonView(/* state and callbacks */);
  // ... the existing code, unchanged ...
}
```

## Where things live

| What | Where |
|---|---|
| Tokens (colours for day and night, shapes, timings, text styles) | `lib/core/theme/lantern/lantern_tokens.dart` |
| Material theme | `lib/core/theme/lantern/lantern_theme.dart` |
| The kit (import `lantern.dart`) | `lib/core/widgets/lantern/` |
| A feature's Lantern screens | `lib/features/<feature>/presentation/lantern/` |
| Strings | `brief/tools/lantern_i18n/<area>.json`, merged by `python brief/tools/merge_lantern_i18n.py` (run from the repository root) |
| Icons | `brief/tools/lantern_icons.json`, built by `node brief/tools/make_lantern_icons.mjs` |
| Test helpers | `test/support/lantern_harness.dart` |

## How a Lantern screen is made

1. Keep the logic where it is. The existing screen's `State` (or controller) keeps every load, timer and action. At the top of its `build`, hand the values and callbacks to a Lantern view. Do not copy logic into the view. `WelcomeScreen` → `HedayahWelcomeView` is the older example of this shape.
2. Write the view in `lib/features/<feature>/presentation/lantern/`. Every public widget class `implements LanternSkinWidget`.
3. Wrap a full page in `LanternSurface(child: ...)`. It gives day or night as chosen in Settings and applies calm motion. Use `LanternSurface(night: true)` for pages that are always night (rooms, the opening screen), or `LNightBand` for a night band inside a day page.
4. Read colours with `context.lt` (for example `context.lt.fg`, `context.lt.surface`). Never write a hex colour in a screen. Fixed brand colours are on `LanternTokens` (`LanternTokens.gold`, `.onGold`, `.nightGround`).
5. Text: `Lantern.displayStyle(size, color: ...)` for headings (Readex Pro) and `Lantern.textStyle(size, color: ...)` for everything else (IBM Plex Sans Arabic). Arabic needs more line height: for a heading use `height: context.lanternArabic ? 1.45 : 1.25`.
6. Layout: the website layout starts at 1024 px (`context.lanternWide`). Below it is the phone layout. Content column 1200 px with 32 px gutters on the website layout; 16 px gutters on phones. Side columns: `Lantern.sideChat` 400, `sideFilters` 300, `sideStudio` 480, `sideSettings` 260, `sideAdmin` 270.
7. Direction: use `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `start`/`end`. Never left/right. Arabic mirrors through `Directionality` alone.
8. Pushed pages on a phone use `LanternPageBar(title: ...)`; on the website layout use `LanternWebHeader()` above the page and `LanternWebFooter()` at the end of the scroll. The three tabs get their frame from `LanternTabShell`; a tab's content leaves room for the floating navigation by honouring `MediaQuery.paddingOf(context).bottom`.

## The kit

`LButton` (primary, secondary, tonal, ghost, danger, dark; small, medium, large; icon, loading), `LHoldButton` (press and hold to confirm), `LIconButton`, `LChip`, `LSegmented`, `LSwitch`, `LField`, `LCard`, `LRow`, `LSectionHead`, `LLink`, `LStarDivider`, `LAvatar` (rings: live, audio, mod, admin; `org` for a rounded square; `verified`), `LBadge` (live, audio, soon, now, off, glass), `LTag` (tones: gold, neutral, live, audio, ok, warn, mod), `LBanner`, `lanternToast`, `LSkeleton`, `LEmptyState`, `LProgress`, `LMeter`, `showLanternDialog`, `showLanternSheet`, `LIcon(LGlyph.x)`, `LStar`, `LStarLoader`, `LArchBorder`, `lanternArchPath`, `LLattice`, `LNightBand`, `LLogo`, `LGiltLine`, `LanternPageBar`, `LanternWebHeader`, `LanternWebFooter`, `LPressable` (hover, press and focus for a custom tappable).

If a piece is missing, add it to the kit in a new file there rather than drawing it inside one screen.

## Rules that are easy to break

- State never relies on colour alone: LIVE, AUDIO, scheduled and offline always carry words.
- `context.lt.faint` is below 4.5:1. Use it only for captions that are not essential; otherwise use `muted`.
- Text on gold is ink (`LanternTokens.onGold`), never white.
- Every tappable thing has a spoken name (`label:`), is at least 44 px, and shows the focus ring (`LPressable` does both).
- Motion that is not needed to use the app stops when `Lantern.calm(context)` is true. A controller that repeats must stop in that case (see `LStarLoader`). Never give `AnimatedSize` a zero duration.
- Numbers that tick use `Lantern.tabular`.
- No new packages, no new backend services, no network calls from a view.
- Strings: add keys to your own file in `brief/tools/lantern_i18n/`, then run the merge tool. Both languages must have the same keys. Reuse an existing key (`'feed.x'.tr()`) when the text already exists.

## Tests

Each Lantern screen has a test file that, with `test/support/lantern_harness.dart`:

- lays the screen out in Arabic and English, phone (390 × 844) and website (1440 × 900), day and night, with no exception and no overflow;
- checks its states (loading, empty, error, and the ones the design draws);
- checks the main actions call the same provider or controller methods as the older screen;
- and adds the route to the list in `test/lantern_isolation_test.dart` if it is new.

`flutter analyze` must report 0 issues.
