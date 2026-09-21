---
type: design-system
project: Streamer_app
status: active
updated: 2026-09-21
---

# 🎨 Streamer App: Master Design Contract & Token Catalog (`Desgin.md`)

> **Design Philosophy:** **Refined Minimalist Academic**  
> Engineered for focused academic learning and live lecture discovery across Saudi Arabia. Eliminates distracting visual clutter, building hierarchy through tonal surface elevation, mathematical spacing, bundled IBM Plex Sans and IBM Plex Sans Arabic, and soft functional accents.

---

## Scheme A contract, selected 2026-09-21

The runtime source is `project/lib/core/theme/app_theme.dart`, matching `brief/assets/design_options/tokens_A.json`. This section supersedes the older graphite, coral, Inter and Tajawal specifications. The screen sketches below are historical layout references, not evidence of current functionality.

| Role | Token / value |
| --- | --- |
| Canvas and cards | bg / surface `#FFFFFF` |
| Alternate surface | surfaceAlt `#ECF6EF` |
| Borders | border `#D9DDDE`, borderStrong `#737B7D` |
| Text | primary `#202B2B`, secondary `#485554`, muted `#586563` |
| Primary, accent, live | `#17643F` |
| Success / warning / danger | `#22613D` / `#7C5012` / `#9D3044` |
| Media / onMedia | `#243536` / `#FFFFFF` |
| Disabled fill | `#E5E8E7` |

IBM Plex Sans and IBM Plex Sans Arabic are bundled in `project/assets/fonts/`, including OFL licenses. No runtime font download. Body is 15, title 21, display 30, caption 12. Arabic line heights are 1.8 for body, 1.6 for title and 1.5 for display. Latin line height is 1.4.

Cards, buttons and inputs use radius 12; chips use 999. Spacing tokens are 4, 8, 12, 16, 24 and 32; screen inset is 18. Cards have no shadow. Forms and settings should use a centered content width no greater than 720. Compact is below 600, medium below 900, expanded starts at 900. Use directional padding and native RTL.

### Supplied logo assets

All nine files in `project/assets/logo/` are owner-supplied and are preserved as delivered; none is regenerated. `AppLogo` renders `colored.svg` at runtime, with `black.svg` as the monochrome variant. `square.svg` / `square.png` and `cercal.svg` / `cercal.png` are the square and circular lockups reserved for launcher, adaptive and web icons in P8A; `colored.png` and `black.png` are the raster equivalents, and `logoInkscapeMaker.svg` is the editable source. The concept logo in the original token JSON is superseded by these files.

### Elevation

Cards stay flat. Raised overlays (mini player, markers, floating menus, toasts) take `AppTheme.shadowSoft`, `shadow` or `shadowStrong`, tinted from `media` rather than pure black. Ad-hoc `Colors.black26/38/45/54/87` shades are not permitted and no longer appear in `lib/`.

### Gradients

Three, all from `AppGradients`, and nothing else may declare one (gate G2d):

- `brand`, top-start to bottom-end, stops `#17643F` and `#327044`, white text.
- `soft`, top-start to bottom-end, stops `#D7EDDC` and `#B8DBB9`, primary text.
- `mediaScrim`, top-centre to bottom-centre, both stops `media` `#243536` at alpha `0x00` then `0xCC`.

`brand` and `soft` are allowed on primary buttons, logo tiles, the welcome hero and small status accents, at most two visible; never on app bars, navigation, list cards, dialogs, inputs or body backgrounds. Contrast must pass at both stops.

`mediaScrim` is the only correct way to darken a thumbnail or viewport that carries `onMedia` text. Its bottom stop is pinned at `0xCC` because a lighter scrim drops white text below 4.5:1 over a bright frame. A solid `media` fill is not a scrim: used as one it hides the image underneath entirely, which is what happened to the feed card banner and the VOD thumbnail before this rule existed.

### Surfaces and their text

`onMedia` white belongs only on `media`, on a `mediaScrim`, or on a filled `danger` / `primary` control. On `surface`, `surfaceAlt` or an unfilled outlined button it is invisible, not merely low-contrast. Text on a white surface takes `textPrimary`, `textSecondary` or `textMuted`; an outlined button's label takes `primary`.

### Layout helpers

`core/layout/content_width.dart` holds the responsive helpers: `AppBreakpoints` (compact below 600, medium below 900, expanded from 900, content 720), `ContentWidth` for forms and lists, and `CenteredScrollable` for centred panels and empty states that must scroll rather than overflow on a landscape phone or at text scale 2.0.

Missing images are resolved through `core/widgets/safe_image_provider.dart`. `resolveImageProviderOrNull` returns null for an absent URL so the caller can paint a neutral placeholder; `StreamerAvatar` is that placeholder for people. `buildSafeImageProvider`, which substitutes a specific person's photograph, is only correct where the caller means that person.

### Direction

Padding, alignment and positioning are directional: `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional` and `AnimatedPositionedDirectional`. `lib/` contains no `EdgeInsets.only(left:/right:)`, no `Alignment.centerLeft/Right` family and no side-anchored `Positioned`, so overlays and badges mirror in Arabic instead of staying on the Latin side.

### Verification

`project/test/theme_contrast_test.dart` pins the palette and the gradient stops. `project/test/rendered_contrast_test.dart` resolves each rendered label against the background actually painted behind it, across fifteen screens in both locales, which is what catches a sound token used on the wrong surface. `project/test/layout_sweep_test.dart` covers screens, dialogs and sheets at seven sizes, three text scales and both locales, with `test/support/stub_video_player.dart` standing in for the platform player so the live room can be laid out at all.

Widget evidence does not establish real-device streaming or release readiness.

---

## 📱 2. Core Screen Layout Contracts

### 📺 Screen 1: Cinema Split-View Live Stream Room

```
+---------------------------------------------------------------------------------------------------+
| [← Back]                   LIVE: Machine Learning Seminar                   [Share] [EN/عربي]    |
+---------------------------------------------------------------------------------------------------+
|                                                                                                   |
|                                16:9 STICKY YOUTUBE PLAYER VIEWPORT                                |
|                              (youtube_player_iframe / Custom Controls)                            |
|                                                                                                   |
| [🔴 LIVE NOW • 1,240 Viewers]                                              [🔊 HD 1080p] [⛶ Full] |
+---------------------------------------------------------------------------------------------------+
| [Prof. Dr. Ahmed Al-Amer ✓]  •  KFUPM Computer Science Dept  •  [Follow / متابعة]                |
+---------------------------------------------------------------------------------------------------+
|  [ 💬 Live Chat (Active) ]  |  [ 📄 Lecture Slides ]  |  [ 👤 Speaker ]  |  [ 📍 Venue Map ]     |
+---------------------------------------------------------------------------------------------------+
|                                                                                                   |
|  💬 Omar S.: "Can you repeat slide 4 on backpropagation please?"                                  |
|  💬 Sarah M.: "Great explanation of gradient descent!"                                            |
|  💬 [Moderator]: Welcome everyone. Lecture notes are available in the Slides tab.                |
|                                                                                                   |
|  [💖 42] [👏 88] [✋ 12 Hand Raised]                                                              |
+---------------------------------------------------------------------------------------------------+
|  [ Type an academic question or message...                       ]  [ Send ✈️ ]  [ ✋ Raise Hand ] |
+---------------------------------------------------------------------------------------------------+
```

### 🧭 Screen 2: Multi-Section Dynamic Discovery Hub

```
+---------------------------------------------------------------------------------------------------+
| 🏫 STREAMER APP (AlSharqia)                                        [🔍 Search] [🔔] [EN / عربي]   |
+---------------------------------------------------------------------------------------------------+
| 🌟 FEATURED LIVE BROADCAST (Hero Carousel)                                                        |
| +-----------------------------------------------------------------------------------------------+ |
| | [Thumbnail Preview] 🔴 LIVE IN AL KHOBAR • 3,420 Viewers                                      | |
| | "Advanced Distributed Systems Architecture" — Prof. Al-Amer ✓ (KFUPM)                         | |
| +-----------------------------------------------------------------------------------------------+ |
+---------------------------------------------------------------------------------------------------+
| 📍 LIVE NOW IN AL KHOBAR & DAMMAM (Horizontal Cards)                                              |
| [ 🔴 Live Card 1 (KFUPM) ]  [ 🔴 Live Card 2 (Imam Abdulrahman) ]  [ 🔴 Live Card 3 (Chamber) ]   |
+---------------------------------------------------------------------------------------------------+
| 🏷️ ACADEMIC CATEGORIES                                                                            |
| [ 💻 Computer Science ] [ ⚖️ Law & Sharia ] [ 🩺 Medicine ] [ 📊 Engineering ] [ 📚 Literature ] |
+---------------------------------------------------------------------------------------------------+
| 📼 RECENT VOD ARCHIVE (2-Column Responsive Grid)                                                  |
| +-----------------------------------+   +------------------------------------+                    |
| | [Thumbnail 1] (1:45:20)           |   | [Thumbnail 2] (58:12)              |                    |
| | Cloud Computing Seminar           |   | Microeconomics Lecture             |                    |
| | Dr. Khaled (Dammam Univ)          |   | Prof. Noura (KFUPM)                |                    |
| +-----------------------------------+   +------------------------------------+                    |
+---------------------------------------------------------------------------------------------------+
| 📱 BOTTOM NAV:   [ 🧭 Discovery (Active) ]         [ 🗺️ Spatial Map ]         [ 👤 Profile ]      |
+---------------------------------------------------------------------------------------------------+
```

### 🗺️ Screen 3: Spatial GIS Map Finder (AlSharqia Vector Radar)

```
+---------------------------------------------------------------------------------------------------+
| [ 🔍 Search Universities & Mosques...                           ]  [ Filter ⚙️ ]  [ 📍 My Loc ]    |
+---------------------------------------------------------------------------------------------------+
|                                                                                                   |
|                                 ALSHARQIA VECTOR MAP CANVAS                                       |
|                                (gadm41_SAU_2.svg Boundary Layer)                                  |
|                                                                                                   |
|                     [Dhahran / KFUPM]                                                             |
|                          (🔴 Pulsing Live Pin: 2 Lectures)                                        |
|                                                                                                   |
|                                                [Al Khobar Corniche]                               |
|                                                     (⚪ Offline Venue: Tech Hall)                 |
|                                                                                                   |
|   [Dammam City Center]                                                                            |
|       (🔴 Pulsing Live Pin: Medical Seminar)                                                      |
|                                                                                                   |
+---------------------------------------------------------------------------------------------------+
| [Selected Venue Card: KFUPM Auditorium 21]                                                        |
| 🔴 Active Stream: "Machine Learning Workshop" • [Join Live Stream] • [Get Driving Directions 🚗]  |
+---------------------------------------------------------------------------------------------------+
```

---

## 🛡️ 3. Impeccable Anti-Slop Design Guidelines

1. **Strict 44dp Touch Targets:** Every icon, filter pill, and reaction button has a minimum hit-box of $44 \times 44\text{ dp}$.
2. **Zero Unstyled Text:** All text widgets inherit directly from the theme typography hierarchy (`Theme.of(context).textTheme`).
3. **Instant RTL/LTR Mirroring:** All horizontal paddings (`EdgeInsetsDirectional`) and icons automatically invert when switching to Arabic.
4. **Hardware Performance Guarantee:** All blur and opacity effects use pre-computed surfaces (`#1A1A1E` / `#24242A`) rather than nested expensive runtime `BackdropFilter` shaders on low-end mobile devices.
5. **Pitch Safe Fallback:** Every placeholder button routes to `FeatureInProgressModal`.
