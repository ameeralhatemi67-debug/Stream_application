# Comprehensive Technical Documentation & Systems Architecture Report

**Author:** Lead Technical Writer & Systems Communicator  
**Target:** Educational Cloud Streaming Application (AlSharqia Region Phase 1)  
**Date:** August 2026

---

## 1. End-to-End Application Overview

The **Educational Cloud Streaming Application** is a specialized mobile streaming and venue discovery platform designed for Saudi Arabia (starting locally in Al Khobar, Dhahran, and Dammam within AlSharqia / Eastern Province).

The application solves a dual objective:
1. **Virtual Live Streaming & VOD Archives:** Provides a dedicated platform for controlled academic creators (verified university professors and scholars) to broadcast educational streams and archive past lectures.
2. **Physical Venue Discovery & Navigation:** Enables students to discover live broadcasts on an interactive GIS spatial map, estimate driving distance/time via Haversine GIS formulas, and launch external turn-by-turn navigation (Google Maps / Apple Maps) to attend lectures in person.

The app supports full bilingual localization in English (LTR) and Arabic (RTL) with dynamic font switching (**Inter** & **Tajawal**).

---

## 2. Architecture & Core Systems

```
+-----------------------------------------------------------------------+
|                              main.dart                                |
|  - EasyLocalization (en.json / ar.json)                               |
|  - MultiProvider (AppProvider / ChatState)                            |
|  - AppTheme (Minimalist Dark Theme #0E0E10)                           |
+-----------------------------------------------------------------------+
                                   |
                                   v
+-----------------------------------------------------------------------+
|                       app_router.dart (go_router)                     |
|  - StatefulShellRoute.indexedStack (Preserves Map & Feed States)       |
|  - Root Navigator: /live/:id, /profile/:id, /settings                 |
+-----------------------------------------------------------------------+
          /                        |                        \
         v                         v                         v
+------------------+    +--------------------+    +---------------------+
| SpatialMapScreen |    | DiscoveryFeedScreen|    | BroadcasterProfile  |
| - GIS Map Engine |    | - Responsive Grid  |    | - Cover Header      |
| - gadm41_SAU.svg |    | - Category Chips   |    | - 2-Tab (VOD Grid)  |
| - GPS FAB        |    | - Search Bar       |    | - Follow/Reminder   |
+------------------+    +--------------------+    +---------------------+
```

### A. Navigation Shell (`app_router.dart`)
Built using `go_router` with `StatefulShellRoute.indexedStack`. This maintains persistent tab viewports (`/map` and `/feed`) without re-instantiating widgets when users toggle tabs. Deep-link routes (`/live/:id`, `/profile/:id`, `/settings`) run on `_rootNavigatorKey`.

### B. State Management Flow (`AppProvider`)
`AppProvider` extends `ChangeNotifier` and acts as the central state hub:
- Maintains mock professor dataset (`StreamerModel`), active live states, viewer counts, and city bounds.
- Tracks active category filter (`currentCategoryFilter`) and search query (`searchQuery`), synchronizing markers on the Spatial Map and cards on the Discovery Feed in real time.
- Manages reactive `followedStreamerIds` and `reminderStreamerIds` sets.
- Holds Pitch Director Mode triggers and local RTMP laptop IP configuration state (`rtmpLaptopIp`).

### C. Polymorphic Video Player Adapters (`AbstractVideoPlayer`)
To decouple UI logic from video player SDK dependencies, the app uses a polymorphic factory pattern:
- **`AbstractVideoPlayer.fromSource(...)`**: Dynamic factory constructor.
- **`VlcPlayerAdapter`**: Local low-latency RTMP hardware loopback via `flutter_vlc_player`.
- **`AwsIvsPlayerAdapter`**: AWS Interactive Video Service HLS `.m3u8` player.
- **`YouTubePlayerAdapter`**: YouTube live/VOD iframe embed via `youtube_player_iframe`.

### D. Spatial GIS Vector Ingestion & Distance Calculation
- **Vector Polygons**: Ingests municipal sector boundaries (`assets/map/gadm41_SAU_2.svg`) with GeoJSON fallback.
- **Dark Basemap Matrix**: Inverts OpenStreetMap tile color filters to fit the minimalist dark theme `#0E0E10`.
- **Haversine GIS Distance**: Calculates geodesic distance in kilometers between the user's location and university auditioriums:
  $$\text{Haversine } d = 2R \arcsin \left( \sqrt{\sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta \lambda}{2}\right)} \right)$$

### E. Bilingual Localization Engine (`easy_localization`)
Translation key strings stored in `assets/i18n/en.json` and `assets/i18n/ar.json` with 100% key symmetry across 9 namespaces (`app`, `nav`, `map`, `feed`, `profile`, `live`, `safety`, `language`, `venue`, `settings`).

---

## 3. Repository Folder and File Tree Map

```text
c:/Users/User/Documents/Obsidian/projects/Streamer_app/project/
├── assets/
│   ├── i18n/
│   │   ├── ar.json                       # Arabic localization dictionary (RTL)
│   │   └── en.json                       # English localization dictionary (LTR)
│   └── map/
│       └── gadm41_SAU_2.svg              # AlSharqia municipal GIS vector map asset
├── documents/
│   └── critic/                           # External evaluation and critique reports
│       ├── design_gis_critic_report.md   # Usability & GIS performance evaluation
│       ├── flutter_code_critic_report.md # Code quality & optimization critique
│       └── technical_documentation_report.md # Comprehensive systems documentation
├── lib/
│   ├── main.dart                         # Application entry point & localization init
│   ├── core/                             # Core framework utilities & app-wide components
│   │   ├── providers/
│   │   │   └── app_provider.dart         # Global state provider (streamers, filters, RTMP IP)
│   │   ├── routing/
│   │   │   └── app_router.dart           # Declarative go_router navigation shell
│   │   ├── theme/
│   │   │   └── app_theme.dart            # Minimalist dark theme tokens, Inter/Tajawal fonts
│   │   └── widgets/
│   │       ├── feature_in_progress_modal.dart # Universal safety modal for unbuilt features
│   │       └── language_switcher.dart    # Bilingual locale toggle button (EN / عربي)
│   └── features/                         # Modular feature domain layers
│       ├── discovery/
│       │   └── presentation/
│       │       └── discovery_feed_screen.dart # Responsive 2/3 column feed grid & search bar
│       ├── live_stream/
│       │   ├── models/
│       │   │   └── ghost_comments.dart   # Localized ghost audience comments dataset
│       │   └── presentation/
│       │       ├── abstract_video_player.dart # Polymorphic player factory interface
│       │       ├── live_broadcast_screen.dart # Video viewport, player controls & inverted chat
│       │       ├── adapters/
│       │       │   ├── aws_ivs_player_adapter.dart # AWS IVS HLS player adapter
│       │       │   ├── vlc_player_adapter.dart     # VLC local RTMP loopback adapter
│       │       │   └── youtube_player_adapter.dart # YouTube iframe embed adapter
│       │       └── widgets/
│       │           ├── floating_reactions_overlay.dart # Keyframe floating emoji reactions
│       │           ├── live_player_overlay_controls.dart # Player overlay controls & live badge
│       │           └── rtmp_ip_dialog.dart         # Pitch Director local RTMP IP settings
│       ├── map/
│       │   ├── models/
│       │   │   └── map_models.dart       # GIS regions, markers & Haversine distance helpers
│       │   └── presentation/
│       │       ├── spatial_map_screen.dart # FlutterMap canvas & SVG vector ingestion
│       │       └── widgets/
│       │           ├── city_selector_dropdown.dart # City target camera animation dropdown
│       │           ├── marker_summary_card.dart    # Map pin single-tap expandable summary card
│       │           ├── offline_marker.dart         # Offline scholar marker pin widget
│       │           ├── pulsing_live_marker.dart    # Pulsing red LIVE radar marker pin widget
│       │           ├── streamer_sliding_drawer.dart# Right-side sliding broadcaster drawer
│       │           ├── top_spatial_search_bar.dart # Floating spatial search bar widget
│       │           └── venue_navigation_sheet.dart # In-person venue attendance action sheet
│       └── profile/
│           ├── models/
│           │   ├── streamer_models.dart  # Broadcaster professor schema & 5 mock records
│           │   └── vod_models.dart       # Archived lecture VOD schema & sample pool
│           └── presentation/
│               ├── broadcaster_profile_screen.dart # SliverAppBar cover photo profile hub
│               ├── settings_screen.dart  # Global settings, quality selector & pitch controls
│               └── widgets/
│                   ├── vod_grid_tile.dart          # 2-Column VOD archive grid thumbnail tile
│                   └── vod_player_modal_sheet.dart # Inline YouTube VOD player modal sheet
├── team/                                 # Team reports, test execution & decision logs
│   ├── documents/critic/                 # Mirrored copy of critic reports
│   ├── questions/user_questions.md       # Consolidated user decisions log (Q1.1 - Q4.6)
│   ├── reports/                          # Subagent accomplishment reports
│   └── testAndErrors/                    # Test checklists & empirical execution reports
├── test/                                 # Automated test suites (36/36 Passing Tests)
│   ├── live_stream_test.dart             # Ghost chat, fallback recovery & player tests
│   ├── spatial_map_test.dart             # GIS bounds, Haversine & venue navigation tests
│   ├── v04_core_architect_settings_test.dart # AppProvider settings & quality tests
│   ├── v04_ui_ux_specialist_test.dart    # Theme contrast, font binding & i18n key tests
│   └── vod_archive_test.dart             # VOD models, RTMP IP & follow state tests
└── pubspec.yaml                          # Dependencies, assets & fonts declaration
```

---

## 4. Component and Module Inter-Communication

1. **State-Driven Map & Feed Filtering:**
   Selecting a category chip on `DiscoveryFeedScreen` or `SpatialMapScreen` calls `AppProvider.setCategoryFilter()`. Both screens listen to `AppProvider` and immediately filter their displayed markers/cards in real-time.

2. **Spatial Hero Navigation Flow:**
   Tapping a map marker or channel card triggers `context.push('/profile/${streamer.streamerId}')`. The `Hero(tag: 'avatar_${streamerId}')` widget smoothly animates the lecturer's avatar from its 2D GIS map position into the broadcaster profile header.

3. **Polymorphic Media Player Stream Selection:**
   When navigating to `/live/:id`, `LiveBroadcastScreen` inspects the streamer's `sourceType` and passes parameters to `AbstractVideoPlayer.fromSource(...)`. The factory instantiates `VlcPlayerAdapter` for hardware RTMP loopback, `AwsIvsPlayerAdapter` for AWS IVS, or `YouTubePlayerAdapter` for YouTube embeds, isolating engine complexity behind a unified interface.
