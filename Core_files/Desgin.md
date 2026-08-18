---
type: design-system
project: Streamer_app
status: active
updated: 2026-08-09
---

# 🎨 Streamer App: Master Design Contract & Token Catalog (`Desgin.md`)

> **Design Philosophy:** **Refined Minimalist Academic**  
> Engineered for focused academic learning and live lecture discovery across Saudi Arabia. Eliminates distracting visual clutter, building hierarchy through tonal surface elevation, mathematical spacing, crisp bilingual typography (Inter + Tajawal), and soft functional accents.

---

## 🏛️ 1. Core Visual Tokens & Color Palette

### 🌑 Dark Mode Surface Elevation (Levels of Graphite)
Depth is created through tonal surface elevation without using harsh pure black (`#000000`):

| Token Name | Hex Value | OKLCH / CSS Equivalent | Application & Role |
| :--- | :--- | :--- | :--- |
| `--bg-base` | `#121214` | `oklch(0.14 0.005 260)` | Main application canvas backdrop & deep viewports. |
| `--surface-card` | `#1A1A1E` | `oklch(0.18 0.005 260)` | Stream cards, profile headers, drawer panels. |
| `--surface-elevated` | `#24242A` | `oklch(0.23 0.005 260)` | Active tab pills, dropdown popovers, search inputs. |
| `--surface-modal` | `#2D2D35` | `oklch(0.28 0.005 260)` | Bottom sheets, dialogs, map floating control overlays. |
| `--border-subtle` | `#27272F` | `oklch(0.25 0.000 0)` | Clean card dividing lines and list separators (1px). |
| `--border-highlight`| `#3F3F4C` | `oklch(0.35 0.000 0)` | Active focus borders, top rim lighting on cards. |

### 🎯 Functional Accent Tokens
Functional accents are strictly reserved for state indicators:

| Accent Token | Hex Value | Semantic Purpose |
| :--- | :--- | :--- |
| `--accent-live` | `#FF8080` / `#FF4B4B` | **Live Stream Pulse:** "LIVE" chips, radar map markers, active broadcast indicator. |
| `--accent-verified` | `#38BDF8` | **Verified Scholar Badge:** Official university / speaker certification tick. |
| `--accent-venue` | `#34D399` | **Physical Venue Status:** Available seating, in-person attendance directions. |
| `--accent-vod` | `#A78BFA` | **Archived VOD Catalog:** Recorded lectures, timestamps, slide chapter markers. |

### ✍️ Typography & Contrast Scale

* **English Typography:** `GoogleFonts.inter()` (geometric, ultra-clean sans-serif).
* **Arabic Typography:** `GoogleFonts.tajawal()` (modern, high-legibility Arabic typography).

| Hierarchy Level | Font Size | Weight | Contrast Level & Color |
| :--- | :--- | :--- | :--- |
| **H1 Screen Title** | `24sp` / `1.5rem` | Bold (`700`) | Primary White `#FFFFFF` (100% Lightness) |
| **H2 Section Header** | `18sp` / `1.2rem` | SemiBold (`600`) | Primary White `#F4F4F5` (95% Lightness) |
| **H3 Card Title / Speaker**| `15sp` / `1.0rem` | Medium (`500`) | Secondary White `#E4E4E7` (90% Lightness) |
| **Body / Chat Text** | `13sp` / `0.85rem`| Regular (`400`) | Muted Gray `#A1A1AA` (70% Lightness) |
| **Caption / Timestamp** | `11sp` / `0.75rem`| Regular (`400`) | Dimmed Gray `#71717A` (50% Lightness) |

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
