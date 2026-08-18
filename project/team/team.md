## Team Breakdown & Role Assignments

```
                            +-------------------------------------+
                            |    YOU: Lead Architect & Integrator |
                            |  (App Shell, Routing, Pitch Mode)   |
                            +-------------------------------------+
                                 /           |           \
                                /            |            \
                               v             v             v
+----------------------------------+  +------------------------+  +-----------------------------------+
| DEV 1: Spatial Map & GIS Specialist|  | DEV 2: Streaming & Real-|  | DEV 3: UI/UX, Localization & Layout|
| (GeoJSON, Camera Curves, Pins)   |  | Time Engine Specialist |  | (English/Arabic, Feed, Safety)    |
+----------------------------------+  +------------------------+  +-----------------------------------+
```

### Role 1: Team Lead & Core Architect (YOU)

**Primary Responsibility:** Application skeleton, state architecture, module integration, and "Pitch Director Mode" triggers.

|**Roadmap Focus**|**Owned Checkpoints & Tasks**|
|---|---|
|**Version 0.1**|* **Checkpoint 1.1:** Setup `go_router` with `StatefulShellRoute`, configure `Provider`/`Riverpod` architecture, and build `mock_data.dart` data models.|
|**Version 0.2**|* **Checkpoint 2.2:** Connect profile navigation handlers and `Hero` transition tags between Feed and Profile screens.|
|**Version 0.3**|* **Checkpoint 3.1:** Build the Abstract Player Interface allowing live switching between local VLC RTMP and YouTube WebViews.|
|**Version 1.0**|* **Checkpoint 4.1:** Build "Pitch Director Mode" (long-press logo override, artificial shimmer delays) and simulated notification triggers.<br><br>  <br><br>* **Checkpoint 4.2:** Final QA, build hardening, and offline router network setup.|

### Role 2: Spatial Map & GIS Specialist (Dev 1)

**Primary Responsibility:** Visual mapping engine, camera movement curves, GeoJSON polygon styling, and spatial UI controls.

|**Roadmap Focus**|**Owned Checkpoints & Tasks**|
|---|---|
|**Version 0.1**|* **Checkpoint 1.2:** Integrate `flutter_map` with AlSharqia GeoJSON vector outlines.<br><br>  <br><br>* **Task 1.2.2:** Apply desaturated dark polygon styling and set `LatLngBounds` to prevent panning out.<br><br>  <br><br>* **Task 1.2.3:** Implement 1.5-second cinematic zoom `AnimationController` down to Al Khobar.<br><br>  <br><br>* **Task 1.2.3:** Build pulsing animated marker pins for Live/Offline status.<br><br>  <br><br>* **Task 1.2.4:** Wire Map Search Bar, Dropdown Selector, and Right-side Streamer Drawer.|
|**Version 1.0**|* **Checkpoint 4.2:** Polish map boundary bounce-back logic and map gesture responsiveness.|

### Role 3: UI/UX, Localization & Safety Specialist (Dev 2)

**Primary Responsibility:** Design system, English/Arabic (LTR/RTL) localization, "Feature In Progress" safety system, Discovery Feed, and Broadcaster Profiles.

|**Roadmap Focus**|**Owned Checkpoints & Tasks**|
|---|---|
|**Version 0.1**|* **Checkpoint 1.1:** Build the "Twitch Dark Mode" theme palette (`#0E0E10`).<br><br>  <br><br>* **Checkpoint 1.1:** Implement `easy_localization` (`en.json` & `ar.json`) and LTR/RTL layout direction rules.<br><br>  <br><br>* **Checkpoint 1.1:** Create the universal `FeatureInProgressModal` and attach it to all non-functional icons.|
|**Version 0.2**|* **Checkpoint 2.1:** Build the 3-column responsive Discovery Grid, category chips, and search filters.<br><br>  <br><br>* **Checkpoint 2.2:** Build the `CustomScrollView` Broadcaster Profile with collapsible `SliverAppBar`.|
|**Version 1.0**|* **Checkpoint 4.2:** Audit all screens in Arabic RTL mode and verify 100% coverage of "Feature In Progress" modals across all unbuilt buttons.|

### Role 4: Streaming, Media & Real-Time Engine Specialist (Dev 3)

**Primary Responsibility:** Local RTMP video integration, YouTube VOD embeds, ghost audience simulation, and interactive chat UI.

|**Roadmap Focus**|**Owned Checkpoints & Tasks**|
|---|---|
|**Version 0.2**|* **Checkpoint 2.2:** Integrate `youtube_player_iframe` for past video lecture archives inside profile tabs.|
|**Version 0.3**|* **Checkpoint 3.1:** Implement `flutter_vlc_player` ingesting local Wi-Fi RTMP streams (`rtmp://[LAPTOP_IP]/live/demo`).<br><br>  <br><br>* **Checkpoint 3.1:** Build landscape auto-fullscreen behavior (`OrientationBuilder` + `wakelock_plus`) and fallback offline screens.<br><br>  <br><br>* **Checkpoint 3.2:** Build inverted `ListView` chat UI, local message posting, and floating emoji animations.<br><br>  <br><br>* **Checkpoint 3.2:** Build the `Timer.periodic` "Ghost Audience" comment injection engine with localized mock messages.|

## Parallel Execution Strategy (Preventing Merge Conflicts)

To ensure all 4 team members can work simultaneously without blocking one another, structure your Flutter repository using **Feature-First Architecture**:

```
lib/
 ├── core/
 │    ├── theme/                <-- [Dev 2] Dark theme, typography
 │    ├── i18n/                 <-- [Dev 2] en.json, ar.json
 │    ├── widgets/              <-- [Dev 2] FeatureInProgressModal
 │    └── routing/              <-- [YOU] go_router, ShellRoute
 ├── features/
 │    ├── map/                  <-- [Dev 1] Isolated GIS Map Code
 │    ├── discovery/            <-- [Dev 2] Feed Grid & Cards
 │    ├── profile/              <-- [Dev 2] Sliver Profile & VODs
 │    ├── live_stream/          <-- [Dev 3] VLC Player, Chat, Ghost Timer
 │    └── pitch_director/       <-- [YOU] Director Overrides & Notifications
 └── main.dart                  <-- [YOU] Core Initialization
```