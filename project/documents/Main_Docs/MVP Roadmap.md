# Version 0.1: The Interactive Shell, Localization & Spatial Map Engine

## Checkpoint 1.1: Core Infrastructure, Localization & UX Safety System

### Phase 1.1.1: Research, Design & Discovery

- **Task 1:** Research and draft the app's visual style guide based on a minimalist "Educational Twitch" aesthetic (deep dark mode palette `#0E0E10`, high-contrast text, pastel red `#FF8080` / `rgb(255, 128, 128)` accent color for live feeds).
    
- **Task 2:** Research Flutter localization frameworks (`easy_localization` vs `flutter_localizations`) and document LTR (English) and RTL (Arabic) layout mirroring rules.
    
- **Task 3:** Map out the core user navigation flow from App Launch $\rightarrow$ Map/Feed Toggle $\rightarrow$ Professor Profile $\rightarrow$ Live Room.
    
- **Task 4:** Define the UX specification for the universal **"Feature In Progress"** modal and toast handlers for unbuilt features.
    

### Phase 1.1.2: Design System & Navigation Architecture

- **Task 1:** Configure `MaterialApp` with the global dark theme, primary dark surfaces (`#161619`), typography (Inter & Tajawal), and accent colors (`#FF8080`).
    
- **Task 2:** Implement `easy_localization` with translation asset paths for English (`en.json`) as the primary language and Arabic (`ar.json`).
    
- **Task 3:** Set up persistent bottom navigation using `StatefulShellRoute` in `go_router` so switching tabs does not rebuild the map state.
    
- **Task 4:** Build the global `FeatureInProgressModal` widget with localized text and smooth bottom-sheet animations.
    

### Phase 1.1.3: Language Switcher & Universal Safety Triggers

- **Task 1:** Build a top-bar Language Switcher toggle (`EN` / `عربي`) that instantly swaps app locale and switches layout direction between LTR and RTL.
    
- **Task 2:** Attach `FeatureInProgressModal` triggers to all placeholder app bar icons (e.g., User Settings, Notifications, Bookmark, Search Filters).
    
- **Task 3:** Add key translation strings in both languages for all navigation items, dialog titles, and generic system messages.
    

## Checkpoint 1.2: The AlSharqia Impressive Spatial Map Engine

### Phase 1.2.1: Research, Design & Discovery

- **Task 1:** Research vector boundary data for Saudi Arabia’s Eastern Province (AlSharqia) using the root `gadm41_SAU_2.svg` asset for **Al Khobar, Dhahran, and Dammam**, establishing GeoJSON extraction and web search as fallback strategies.
    
- **Task 2:** Research spatial vector styling in Flutter (`flutter_svg` / `flutter_map` / `vector_map_tiles`) to achieve a flat, desaturated outline style with dark polygon fills.
    
- **Task 3:** Map out spatial interactions: single tap (select sector), double tap (trigger cinematic camera zoom), and zoom-threshold pin reveals.
    
- **Task 4:** Design custom map marker graphics: pulsing radar rings (`#FF8080`) for **Live Broadcasters** and static markers for **Offline Broadcasters**.
    

### Phase 1.2.2: Spatial Map Canvas & Bounding Limits

- **Task 1:** Implement `SpatialMapCanvas` ingesting `gadm41_SAU_2.svg` vector paths (with GeoJSON fallback) mapping AlSharqia municipal borders.
    
- **Task 2:** Set `minZoom` and `maxZoom` parameters, locking `LatLngBounds` strictly to the Eastern Province to prevent panning into empty voids.
    
- **Task 3:** Apply desaturated dark polygon styling to replicate the high-end spatial layout mockup.
    

### Phase 1.2.3: Interactive Cinematic Camera & Dynamic Markers

- **Task 1:** Create custom `Marker` widgets with animated pulsating red keyframes (`#FF8080`) for live streams and desaturated markers for offline professors.
    
- **Task 2:** Implement an `AnimationController` that executes a 1.5-second smooth camera zoom/pan curve down to Al Khobar coordinates when triggered.
    
- **Task 3:** Implement a map zoom listener that keeps broadcaster pins hidden when zoomed out, smoothly fading them in once passing the target zoom threshold.
    

### Phase 1.2.4: Spatial Navigation Controls (Search, Dropdown & Drawer)

- **Task 1:** Build the top floating search bar with auto-complete matching city names; selecting a city triggers the cinematic zoom sequence.
    
- **Task 2:** Build the center city selector dropdown (`Al Khobar v`, `Dhahran v`, `Dammam v`); selecting an item animates the camera to that city’s coordinates.
    
- **Task 3:** Build the right-side `endDrawer` sliding panel listing all 5 mock professors with their location tags and real-time live availability badges.
    

# Version 0.2: Structured Discovery Feed & Creator Identity

## Checkpoint 2.1: The Structured Content Discovery Hub

### Phase 2.1.1: Research, Design & Discovery

- **Task 1:** Research content categorization hierarchies for educational streams (e.g., Mosque Lessons, University Seminars, Public Lectures).
    
- **Task 2:** Design responsive grid card layouts for channel tiles displaying live viewer counts, streamer avatars, and category chips.
    
- **Task 3:** Define search and topic filter interaction flows in LTR and RTL orientations.
    

### Phase 2.1.2: Discovery Grid & Channel Card Layouts

- **Task 1:** Build a 3-column responsive `GridView.builder` layout for the main discovery feed.
    
- **Task 2:** Create channel cards featuring high-resolution thumbnails, lecturer name, location tag, and a pulsing red "LIVE" badge overlay.
    
- **Task 3:** Add category filter chips at the top of the feed with localized titles (e.g., "Islamic Studies", "Computer Science", "Engineering").
    

### Phase 2.1.3: Search & Filter Interactivity

- **Task 1:** Wire the search bar on the feed page to filter local mock professor objects in real time by name, category, or city.
    
- **Task 2:** Connect non-functional advanced filter buttons (e.g., "Date Range", "Academic Level") to trigger the `FeatureInProgressModal`.
    

## Checkpoint 2.2: Professor Profiles & VOD Archive Integration

### Phase 2.2.1: Research, Design & Discovery

- **Task 1:** Research `CustomScrollView` and `SliverAppBar` techniques to achieve a collapsible header image effect for mosque/university imagery.
    
- **Task 2:** Evaluate YouTube embedding options (`youtube_player_iframe` vs `youtube_player_flutter`) for playing unlisted past lecture archives inline.
    
- **Task 3:** Design the mock dataset structure (`mock_data.dart`) containing bio, schedule, follower count, and past VOD links in both English and Arabic.
    

### Phase 2.2.2: Broadcaster Profile UI Shell

- **Task 1:** Build the profile screen using `CustomScrollView` with a collapsible `SliverAppBar` showcasing location header imagery.
    
- **Task 2:** Wrap broadcaster avatars on the Map/Feed in `Hero` widgets matching tags on the Profile page for spatial transition effects.
    
- **Task 3:** Render professor bio, verified badges, upcoming stream schedule, and localized follower statistics.
    

### Phase 2.2.3: Archive (VOD) Gallery & Embed Integration

- **Task 1:** Build a 2-column grid in the "Archive" tab displaying past lecture thumbnails and titles.
    
- **Task 2:** Integrate `youtube_player_iframe` to play unlisted YouTube past recordings directly inside a modal view when a VOD tile is tapped.
    
- **Task 3:** Wire secondary action buttons ("Follow", "Enable Reminders", "Share Profile") to active states or the `FeatureInProgressModal`.
    

# Version 0.3: The Live Broadcast Experience (Path 4 & Local Hack)

## Checkpoint 3.1: Live Media Player Pipeline

### Phase 3.1.1: Research, Design & Discovery

- **Task 1:** Research local RTMP loopback architecture (`flutter_vlc_player` connecting to `node-media-server` on local laptop IP) versus Path 4 YouTube Live webview embeds.
    
- **Task 2:** Design player viewport controls: live status badge, viewer counter, close button, full-screen toggle, and landscape orientation rules.
    
- **Task 3:** Map out graceful error handling and fallback UI screens if the local Wi-Fi connection drops during a pitch demo.
    

### Phase 3.1.2: Video Viewport Integration

- **Task 1:** Implement `flutter_vlc_player` configured to ingest `rtmp://[LAPTOP_LOCAL_IP]/live/demo` for sub-second local Wi-Fi pitch streaming.
    
- **Task 2:** Build a polymorphic `AbstractVideoPlayer` interface supporting VLC (Local RTMP Hack), AWS IVS HLS Low-Latency Player, and `youtube_player_flutter` (Path 4 YouTube Embed).
    
- **Task 3:** Implement landscape auto-fullscreen behavior using `OrientationBuilder` and `wakelock_plus` to keep the screen active.
    

### Phase 3.1.3: Live Player UX & Fallback Systems

- **Task 1:** Build top video player overlay elements: pulsing red "LIVE" indicator, active viewer count pill ("294 Watching"), and close button.
    
- **Task 2:** Construct a branded stream fallback screen displaying "Stream Temporarily Offline" if network disconnects occur, preventing raw Flutter red error screens.
    

## Checkpoint 3.2: Real-Time Interactive Engagement Engine

### Phase 3.2.1: Research, Design & Discovery

- **Task 1:** Research Twitch/YouTube-style inverted chat stream UI architecture (`reverse: true` list view).
    
- **Task 2:** Design the "Ghost Audience" simulation algorithm using timer-based local message injection.
    
- **Task 3:** Prepare localized mock chat datasets in English and Arabic reflecting authentic student/viewer comments during a lecture.
    

### Phase 3.2.2: Live Chat UI & Local Input Engine

- **Task 1:** Build an inverted `ListView.builder` occupying the lower 60% of the live broadcast view.
    
- **Task 2:** Build the bottom message input bar ("Type something..." / "اكتب شيئاً...") with send button.
    
- **Task 3:** Implement local chat submission: typing a message instantly appends it to the bottom of the chat list with a "You" badge.
    

### Phase 3.2.3: Ghost Audience Engine & Floating Reactions

- **Task 1:** Implement `Timer.periodic` scheduled to inject a random comment from the localized EN/AR mock chat pool every 4–7 seconds.
    
- **Task 2:** Build gesture reaction buttons (Clap, Heart, Raise Hand) in the bottom control bar.
    
- **Task 3:** Implement floating animated heart/clap emoji keyframes that drift upward over the video player when tapped.
    

# Version 1.0: Pitch Polish, Interactivity & Investor Readiness

## Checkpoint 4.1: Simulated Push Notifications & Pitch Director Mode

### Phase 4.1.1: Research, Design & Discovery

- **Task 1:** Map out the exact step-by-step "Golden Path" presentation flow for the investor pitch.
    
- **Task 2:** Design the trigger gesture and UI presentation for in-app simulated live push notifications.
    
- **Task 3:** Design a hidden "Pitch Director Mode" toggle to programmatically force app state into an active demo configuration.
    

### Phase 4.1.2: Simulated In-App Live Notification Banner

- **Task 1:** Implement `top_snackbar_flutter` styled as a system push notification reading: _"Professor [Name] is going live in Al Khobar!"_ / _"البروفيسور [الاسم] يبث الآن في الخبر!"_.
    
- **Task 2:** Add a secret gesture trigger (e.g., rapid triple-tap on the top AppBar logo) that waits 3 seconds and drops the notification banner.
    
- **Task 3:** Wire the notification banner tap action to execute `context.push('/live/demo')`, jumping straight into the live stream screen.
    

### Phase 4.1.3: Pitch Director Mode & Performance Polish

- **Task 1:** Implement a hidden long-press trigger on the app logo that forces mock data into "Pitch Ready" state (1 professor set to Live, viewer count set to 294, ghost chat timer armed).
    
- **Task 2:** Add an artificial 600ms `shimmer` loading effect when opening profile or feed tabs to simulate a live cloud database fetch.
    

## Checkpoint 4.2: Final QA, Placeholder Audit & Investor Package Build

### Phase 4.2.1: Research, Design & Discovery

- **Task 1:** Create an audit checklist covering all screens in both LTR (English) and RTL (Arabic) modes.
    
- **Task 2:** Review every button and interactive element against the "Feature In Progress" safety requirement.
    

### Phase 4.2.2: Universal Placeholder Audit & Localization Review

- **Task 1:** Audit every secondary button across Map, Feed, Profile, and Live screens (e.g., Settings, Filter, Donate, Audio Only, Share).
    
- **Task 2:** Ensure every unbuilt button triggers the `FeatureInProgressModal` with localized messaging:
    
    - **EN:** _"Feature In Progress: This capability is scheduled for the Version 2 production release."_
        
    - **AR:** _"الميزة قيد التطوير: هذه الخاصية مجدولة للإطلاق في الإصدار القادم."_
        
- **Task 3:** Verify layout alignment and text string completeness across all screens in Arabic mode.
    

### Phase 4.2.3: Build Hardening & Pitch Day Preparation

- **Task 1:** Disable the debug banner in `MaterialApp` (`debugShowCheckedModeBanner: false`).
    
- **Task 2:** Verify `wakelock_plus` is enabled to prevent screen timeout during presentations.
    
- **Task 3:** Perform a offline rehearsal using a standalone travel router network to ensure zero dependence on external venue Wi-Fi.
    

## Implementation Summary at a Glance

```
Version 0.1 (Shell & Spatial Map)
 ├── Checkpoint 1.1: Core Infrastructure, Localization & Safety Systems
 │    ├── Phase 1.1.1: Research, Design & Discovery (i18n, Twitch Theme, Flow)
 │    ├── Phase 1.1.2: Design System & Navigation Architecture
 │    └── Phase 1.1.3: Language Switcher & Universal Safety Triggers
 └── Checkpoint 1.2: AlSharqia Impressive Spatial Map Engine
      ├── Phase 1.2.1: Research, Design & Discovery (GeoJSON, Markers, Camera)
      ├── Phase 1.2.2: Spatial Map Canvas & Bounding Limits
      ├── Phase 1.2.3: Interactive Cinematic Camera & Dynamic Markers
      └── Phase 1.2.4: Spatial Navigation Controls (Search, Dropdown, Drawer)

Version 0.2 (Discovery Feed & Profiles)
 ├── Checkpoint 2.1: Structured Content Discovery Hub
 │    ├── Phase 2.1.1: Research, Design & Discovery (Content Grid, Cards)
 │    ├── Phase 2.1.2: Discovery Grid & Channel Card Layouts
 │    └── Phase 2.1.3: Search & Filter Interactivity
 └── Checkpoint 2.2: Professor Profiles & VOD Archive Integration
      ├── Phase 2.2.1: Research, Design & Discovery (Slivers, YouTube Embeds)
      ├── Phase 2.2.2: Broadcaster Profile UI Shell
      └── Phase 2.2.3: Archive (VOD) Gallery & Embed Integration

Version 0.3 (The Live Broadcast Experience)
 ├── Checkpoint 3.1: Live Media Player Pipeline
 │    ├── Phase 3.1.1: Research, Design & Discovery (Path 4 vs Local RTMP)
 │    ├── Phase 3.1.2: Video Viewport Integration
 │    └── Phase 3.1.3: Live Player UX & Fallback Systems
 └── Checkpoint 3.2: Real-Time Interactive Engagement Engine
      ├── Phase 3.2.1: Research, Design & Discovery (Chat Layout, Ghost Engine)
      ├── Phase 3.2.2: Live Chat UI & Local Input Engine
      └── Phase 3.2.3: Ghost Audience Engine & Floating Reactions

Version 1.0 (Pitch Polish & Readiness)
 ├── Checkpoint 4.1: Simulated Push Notifications & Pitch Director Mode
 │    ├── Phase 4.1.1: Research, Design & Discovery (Golden Path & Director Mode)
 │    ├── Phase 4.1.2: Simulated In-App Live Notification Banner
 │    └── Phase 4.1.3: Pitch Director Mode & Performance Polish
 └── Checkpoint 4.2: Final QA, Placeholder Audit & Investor Package Build
      ├── Phase 4.2.1: Research, Design & Discovery (Audit Checklist)
      ├── Phase 4.2.2: Universal Placeholder Audit & Localization Review
      └── Phase 4.2.3: Build Hardening & Pitch Day Preparation
```
