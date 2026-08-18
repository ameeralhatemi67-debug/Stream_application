---
type: project
tags: [streaming, flutter, educational, saudi-arabia, youtube, gis, maps]
status: active
updated: 2026-08-09
---

# 📺 Educational Cloud Streaming Application (Streamer App)

> **Live Educational & Spatial Discovery Platform for Saudi Arabia (AlSharqia / KSA)**  
> Combining a Twitch-inspired live streaming discovery feed with an interactive GIS spatial map of Saudi Arabia's Eastern Province.

---

## 🎯 Executive Summary & Vision

The **Educational Cloud Streaming Application** is a specialized Flutter mobile application engineered to discover, broadcast, and archive high-quality educational, academic, and cultural lectures across Saudi Arabia.

Unlike entertainment streaming platforms, this application integrates physical venue locations with digital live broadcasts:
* **Digital Participation:** Real-time YouTube Live and low-latency cloud video streaming with synchronized live chat, Q&A, and floating reaction keyframes.
* **Physical Attendance:** An interactive spatial vector map of AlSharqia allowing viewers to locate venues in real-time, view schedules, and attend in person.
* **Curated Broadcasters:** Approved scholars, professors, and academic institutions with verified status and zero-noise educational focus.

---

## 🏗️ Architecture & Core Components

```
+---------------------------------------------------------------------------------------------------+
|                                  STREAMER APP CORE ARCHITECTURE                                   |
|                                                                                                   |
|   +------------------------------------------+    +-------------------------------------------+   |
|   |         SPATIAL MAP FINDER (GIS)         |    |         TWITCH-STYLE DISCOVERY FEED       |   |
|   | • Dynamic SVG vector map of AlSharqia    |    | • Live stream carousel & category grid    |   |
|   | • Smooth pan/zoom bounds (Al Khobar/KSA) |    | • Streamer profile cards & verified badges|   |
|   | • Pulsing radar pins for live streams    |    | • Bilingual English (LTR) / Arabic (RTL)  |   |
|   +------------------------------------------+    +-------------------------------------------+   |
|                                      ▲                                                            |
|                                      │                                                            |
|   +----------------------------------┴--------------------------------------------------------+   |
|   |                             YOUTUBE & MEDIA STREAMING ENGINE                              |   |
|   | • YouTube Live / VOD playback (youtube_player_iframe / flutter_vlc_player)                 |   |
|   | • Real-time live chat overlay & audience engagement gestures                              |   |
|   | • Offline fallback protection & Pitch Director mock overrides                             |   |
|   +-------------------------------------------------------------------------------------------+   |
+---------------------------------------------------------------------------------------------------+
```

---

## 🛠️ Technology Stack

| Layer | Technology | Purpose |
| :--- | :--- | :--- |
| **Framework** | **Flutter 3.x / Dart** | Cross-platform mobile & desktop client. |
| **Routing** | `go_router` (StatefulShellRoute) | Preserves map canvas and stream states across tab switches. |
| **Streaming** | `youtube_player_iframe` & `flutter_vlc_player` | YouTube live broadcast embeds, RTMP testing, and VOD playback. |
| **Mapping & GIS** | `flutter_map`, `latlong2`, `flutter_svg` | Eastern Province vector map boundaries and custom live pins. |
| **Localization** | `easy_localization` | Dynamic instant switching between English (LTR) and Arabic (RTL). |
| **Typography & UI**| `google_fonts` (Inter & Tajawal) | High-contrast educational dark aesthetic. |
| **Design Contract**| `[[Desgin.md]]` & `[[impeccable]]` | Enforces 59+ anti-slop visual and layout quality rules. |

---

## 📂 Project Directory Structure

```text
Ideas/Current/Streamer_app/
├── Core_files/                             <-- 5 Mandatory Core Files
│   ├── README.md                           (This master overview)
│   ├── STATUS.md                           (Live health, blockers, next steps)
│   ├── progres.md                          (Milestone logs & sprint timeline)
│   ├── decisions.md                        (Architecture decision records / ADRs)
│   └── Desgin.md                           (Design system tokens, contracts, UI rules)
├── Core_files/agents/                      <-- Project-Specific Subagent Personas
│   ├── 01_lead_architect_agent.md          (Architecture & contract enforcement)
│   ├── 02_ui_ux_design_specialist.md        (Visual hierarchy & Impeccable quality)
│   ├── 03_youtube_streaming_specialist.md   (YouTube Live & media viewport engine)
│   └── 04_gis_spatial_map_specialist.md     (Spatial GIS & map rendering)
└── project/                                <-- Flutter Application Source Code
    ├── lib/
    │   ├── core/                           (Theme, localization, routing, constants)
    │   └── features/                       (discovery, live_stream, map, profile)
    └── pubspec.yaml                        (Flutter dependencies)
```

---

## 🚀 Getting Started

```powershell
# Navigate to the Flutter project folder
cd "c:\Users\User\Documents\Amir Ob\projects\Ideas\Current\Streamer_app\project"

# Fetch dependencies
flutter pub get

# Run on Chrome or connected Android device
flutter run -d chrome
```

---

## 📚 Related Vault Links
* 🧠 **[[Vault Master Guide.md]]** — Master vault operating standards.
* 📁 **[[Project Core Files Operating Protocol.md]]** — Mandatory core files governance.
* 🎨 **[[Impeccable Command Reference.md]]** — 21 design commands for UI auditing and polish.
* 📦 **[[Git Hub repos.md]]** — Integrated tool ecosystem.
