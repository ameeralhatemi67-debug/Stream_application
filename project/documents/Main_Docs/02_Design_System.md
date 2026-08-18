# Design System & Visual Architecture: Minimalist Educational Streaming App

## Overview & Design Philosophy

This design system establishes a **refined, ultra-minimalist visual architecture** engineered specifically for the Educational Cloud Streaming Application. 

The aesthetic eliminates unnecessary decorative colors and visual clutter. Depth, structure, and hierarchy are built entirely through **precise levels of black and gray in Dark Mode**, **clean levels of white and subtle gray in Light Mode**, **mathematical spatial padding**, and **deliberate typography**.

Subtle feature accents are reserved strictly for functional indicators (Live status, venue availability, GIS map pins, and verified scholar badges).

---

## 1. Dark Mode Neutral System (Levels of Black & Gray)

In Dark Mode, pure black (`#000000`) is avoided to eliminate harsh screen contrast and halation (light bleed) on modern OLED displays. Depth is expressed using **Tonal Surface Elevation**: higher elements in the z-axis receive slightly lighter surface shades.

```
+---------------------------------------------------------------------------------------------------+
|                                   DARK MODE ELEVATION SURFACE MAP                                 |
|                                                                                                   |
|  [ Level 0: Base Backdrop ]   #0E0E10  oklch(0.12 0.005 250)   Main app canvas                    |
|  [ Level 1: Cards & Panels  ]  #161619  oklch(0.16 0.005 250)   Grid cards, list tiles             |
|  [ Level 2: Elevated / Hover]  #202024  oklch(0.20 0.005 250)   Active states, dropdown menus      |
|  [ Level 3: Modals & Sheets ]  #2A2A30  oklch(0.25 0.005 250)   Floating sheets, dialogs           |
+---------------------------------------------------------------------------------------------------+
```

### Color Tokens (Dark Mode)

| Token Name | Hex Code | OKLCH Equivalent | Usage & Application |
| :--- | :--- | :--- | :--- |
| `--dark-bg-base` | `#0E0E10` | `oklch(0.12 0.005 250)` | Deep page background & map canvas base |
| `--dark-surface-1` | `#161619` | `oklch(0.16 0.005 250)` | Stream cards, profile headers, drawer panels |
| `--dark-surface-2` | `#202024` | `oklch(0.20 0.005 250)` | Dropdown menus, elevated cards, active tabs |
| `--dark-surface-3` | `#2A2A30` | `oklch(0.25 0.005 250)` | Modals, bottom sheets, map control overlays |
| `--dark-border-subtle` | `#27272A` | `oklch(0.24 0.000 0)` | Subtle component dividing borders |
| `--dark-border-highlight`| `#3F3F46` | `oklch(0.32 0.000 0)` | Active container borders & top rim lighting |

### Text Contrast Levels (Dark Mode De-Emphasis Formula)
To make titles stand out without harshness, secondary text lightness is de-emphasized:

* **Primary Text (Titles, Headings, Broadcaster Names):** `#FFFFFF` / `oklch(0.98 0 0)` — 98% Lightness (Maximum contrast point of focus).
* **Secondary Text (Body Copy, Descriptions, Timestamps):** `#A1A1AA` / `oklch(0.70 0 0)` — 70% Lightness (Readable without competing with titles).
* **Tertiary / Muted Text (Disabled states, placeholder text):** `#71717A` / `oklch(0.50 0 0)` — 50% Lightness (Non-distracting metadata).

---

## 2. Light Mode Neutral System (Levels of White & Gray)

Light Mode uses a clean off-white base to reduce glare, pairing pure white card surfaces with subtle ambient drop shadows for natural depth.

```
+---------------------------------------------------------------------------------------------------+
|                                  LIGHT MODE ELEVATION SURFACE MAP                                 |
|                                                                                                   |
|  [ Level 0: Base Backdrop ]   #FAFAFA  oklch(0.98 0.000 0)     Soft off-white canvas              |
|  [ Level 1: Pure White Card ]  #FFFFFF  oklch(1.00 0.000 0)     Cards, list items                  |
|  [ Level 2: Elevated State  ]  #FFFFFF  + Soft Shadow            Dropdown menus, popovers           |
|  [ Level 3: Recessed Track  ]  #F4F4F5  oklch(0.96 0.000 0)     Inputs, progress bar tracks        |
+---------------------------------------------------------------------------------------------------+
```

### Color Tokens (Light Mode)

| Token Name | Hex Code | OKLCH Equivalent | Usage & Application |
| :--- | :--- | :--- | :--- |
| `--light-bg-base` | `#FAFAFA` | `oklch(0.98 0.000 0)` | Soft off-white page background |
| `--light-surface-1` | `#FFFFFF` | `oklch(1.00 0.000 0)` | Pure white cards, profile surfaces |
| `--light-surface-recessed`| `#F4F4F5` | `oklch(0.96 0.000 0)` | Search bar backgrounds, chat input tracks |
| `--light-border-subtle` | `#E4E4E7` | `oklch(0.91 0.000 0)` | Light card borders & list dividers |
| `--light-border-highlight`| `#D4D4D8` | `oklch(0.85 0.000 0)` | Focused inputs & active tab borders |

### Text Contrast Levels (Light Mode Inversion Formula)
Light Mode text lightness is inverted mathematically ($L_{light} = 100 - L_{dark}$):

* **Primary Text (Titles, Headings):** `#09090B` / `oklch(0.12 0 0)` — Charcoal black (12% Lightness for crisp readability).
* **Secondary Text (Body, Descriptions):** `#52525B` / `oklch(0.42 0 0)` — 42% Lightness (Muted secondary hierarchy).
* **Tertiary / Muted Text (Disabled text, hints):** `#A1A1AA` / `oklch(0.68 0 0)` — 68% Lightness.

---

## 3. Functional Feature Accent Palette

Accent colors are strictly limited to functional indicators, live stream statuses, map elements, and verification badges:

```
    🔴 RED             🟢 GREEN           🔵 BLUE            🟣 PURPLE
    rgb(255,128,128)   rgb(135,222,135)   rgb(95,188,211)    rgb(188,95,211)
    #FF8080            #87DE87            #5FBCD3            #BC5FD3
```

| Accent Name | RGB Value | Hex Code | Feature Application |
| :--- | :--- | :--- | :--- |
| **Pastel Red** | `rgb(255, 128, 128)` | `#FF8080` | Live broadcast badge, pulsing radar map ring, recording indicator. |
| **Pastel Green** | `rgb(135, 222, 135)` | `#87DE87` | Online streamer status, venue open indicator, success toast confirmation. |
| **Pastel Blue** | `rgb(95, 188, 211)` | `#5FBCD3` | GIS map pins, city navigation routes, interactive links, primary action focus. |
| **Pastel Purple**| `rgb(188, 95, 211)` | `#BC5FD3` | Verified scholar badge, university category chips, bookmark/favorite highlights. |

---

## 4. Typography Standard: Inter & Tajawal

The application standardizes on **Inter** for Latin (English) script and **Tajawal** for Arabic script. Both typefaces feature ultra-clean geometric structures, tall cap heights, and matching stroke weights for seamless bilingual UI performance.

```
+---------------------------------------------------------------------------------------------------+
|                                OFFICIAL TYPOGRAPHY SPECIFICATION                                  |
|                                                                                                   |
|  [ Latin / English ]   Inter (Google Fonts)    - Geometric sans-serif, high legibility            |
|  [ Arabic           ]   Tajawal (Google Fonts)  - Geometric Arabic, matching stroke weight         |
+---------------------------------------------------------------------------------------------------+
```

### Typeface Specification

* **Primary Latin Font (English LTR):** **Inter** (Google Fonts)
  * *Characteristics:* Neutral, geometric, engineered specifically for high-density screen UIs.
* **Primary Arabic Font (Arabic RTL):** **Tajawal** (Google Fonts)
  * *Characteristics:* Modern geometric Arabic typeface with open apertures and clean horizontal rhythms that perfectly align with Inter.

---

### Minimalist 3-Size Type Scale Strategy

Following the 80/20 UI principle, the app uses **only 3 core font sizes**, building hierarchy through font weight and color lightness rather than sizing bloat:

```
  ┌──────────────────┬────────────┬──────────────────┬───────────────────────────────────────┐
  │ Level            │ Size       │ Weight           │ Typical Usage                         │
  ├──────────────────┼────────────┼──────────────────┼───────────────────────────────────────┤
  │ Base Body        │ 14px / 16px│ 400 (Regular)    │ Body text, metadata, input fields     │
  │ Section Header   │ 18px / 20px│ 600 (SemiBold)   │ Stream titles, card headers, names    │
  │ Main Page Title  │ 24px / 28px│ 700 (Bold)       │ H1 Page headers, map drawer title     │
  └──────────────────┴────────────┴──────────────────┴───────────────────────────────────────┘
```

---

## 5. Spacing System & Border Radii

### 4px Incremental Spacing Scale

Layout spacing is structured on an 8pt / 4pt grid system using `rem` units (`1rem = 16px` baseline):

```
   xs (0.25rem / 4px)  ─── Micro spacing (icon-to-text gap)
   sm (0.50rem / 8px)  ─── Tight spacing (title to subtitle, button vertical padding)
   md (0.75rem / 12px) ─── Compact component gaps (chip padding, input gaps)
   lg (1.00rem / 16px) ─── Standard container padding (card inner padding)
   xl (1.50rem / 24px) ─── Group separation gap (between cards / sections)
  2xl (2.00rem / 32px) ─── Outer page margin & container boundary
```

### Golden Spacing Rules
1. **Inner vs. Outer Rule:** Spacing between elements inside a card (`8px–12px`) must always be smaller than the container padding (`16px`).
2. **Asymmetric Button Padding:** Horizontal button padding is 2.5× vertical padding (`padding: 8px 20px`).

### Border Radii Scale

```
  --radius-xs: 4px;   /* Small chips, notification badges */
  --radius-sm: 8px;   /* Action buttons, search inputs */
  --radius-md: 12px;  /* Stream cards, dropdown containers */
  --radius-lg: 16px;  /* Floating modals, bottom sheets */
  --radius-full: 9999px; /* Broadcaster avatars, live badges */
```

* **Radius-Padding Rule:** Container inner padding matches container border radius (`padding: 16px` $\rightarrow$ `border-radius: 16px`).

---

## 6. Shadows, Light Dynamics & Elevation System

Shadows and depth are applied differently between Dark and Light modes based on top-lit lighting principles:

```
+---------------------------------------------------------------------------------------------------+
|                                    LIGHT DYNAMICS & SHADOW RULES                                  |
|                                                                                                   |
|  DARK MODE: Surface Lightness Step + Top Rim Highlight Edge                                        |
|  • Uses `border-top: 1px solid rgba(255, 255, 255, 0.12)` to simulate light hitting the top edge.  |
|  • Uses deep, soft ambient drop shadow: `box-shadow: 0 12px 32px rgba(0, 0, 0, 0.6)`.            |
|                                                                                                   |
|  LIGHT MODE: Dual-Layered Ambient Drop Shadows                                                     |
|  • Short Direct Shadow: `0 1px 2px rgba(0, 0, 0, 0.05)` (crisp ground contact).                   |
|  • Diffused Ambient Shadow: `0 8px 16px -4px rgba(0, 0, 0, 0.08)` (smooth elevation).             |
+---------------------------------------------------------------------------------------------------+
```

### Elevation Levels (Hierarchy 0 to 3)

* **Level 0 (Flat Base):** Map canvas and main page background. No shadow.
* **Level 1 (Cards & Grid Items):**
  * *Dark Mode:* `--dark-surface-1` with 1px `--dark-border-subtle`.
  * *Light Mode:* `--light-surface-1` with `box-shadow: 0 1px 3px rgba(0,0,0,0.06)`.
* **Level 2 (Active Cards, Sticky Header Bar, Dropdown Menus):**
  * *Dark Mode:* `--dark-surface-2` with top inset rim light (`inset 0 1px 0 rgba(255,255,255,0.15)`).
  * *Light Mode:* `--light-surface-1` with `box-shadow: 0 4px 12px rgba(0,0,0,0.08)`.
* **Level 3 (Floating Modals, Bottom Sheets, Map Drawer):**
  * *Dark Mode:* `--dark-surface-3` with `box-shadow: 0 16px 40px rgba(0,0,0,0.8)`.
  * *Light Mode:* `--light-surface-1` with `box-shadow: 0 16px 32px -8px rgba(0,0,0,0.12)`.

---

## 7. Visual Hierarchy Summary Matrix

| Visual Dimension | Primary Focus (Level 1) | Secondary Support (Level 2) | Tertiary / Background (Level 3) |
| :--- | :--- | :--- | :--- |
| **Typography Size** | 18px – 24px (SemiBold/Bold) | 14px – 16px (Regular/Medium) | 12px – 14px (Regular) |
| **Dark Mode Text** | `#FFFFFF` (100% Lightness) | `#A1A1AA` (70% Lightness) | `#71717A` (50% Lightness) |
| **Light Mode Text**| `#09090B` (12% Lightness) | `#52525B` (42% Lightness) | `#A1A1AA` (68% Lightness) |
| **Surface Shading** | Raised Surface (`Level 2`) | Standard Card (`Level 1`) | Base Canvas (`Level 0`) |
| **Accents Usage** | Live Red / Map Blue | Scholar Purple | System Green |
