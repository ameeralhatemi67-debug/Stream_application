As the lead, your primary focus is building the project's foundation, establishing data contracts, managing deep-link routing, isolating video dependencies through abstraction layers, and orchestrating the hidden **"Pitch Director Mode"** for presentation day.

# Team Lead & Core Architect Roadmap

## Version 0.1: Shell Architecture, Navigation & Data Contracts

### Checkpoint 1.1: Project Skeleton, Navigation Shell & Core Data Models

#### Phase 1.1.1: Research, Design & Architecture

- **Task 1:** Evaluate state management patterns (`Provider` vs `Riverpod`) to select a low-footprint solution for prototype state management.
    
- **Task 2:** Architect the `go_router` hierarchy using `StatefulShellRoute` to preserve the spatial map viewport state when switching bottom navigation tabs.
    
- **Task 3:** Draft modular feature data schemas (`map_models.dart`, `streamer_models.dart`, `live_stream_models.dart`, `vod_models.dart`, `chat_models.dart`) aligned with `03_Data_Schemas.md`.
    
- **Task 4:** Establish Git branch policies and define the Feature-First directory structure (`lib/core/` and `lib/features/`) to prevent team merge conflicts.
    

#### Phase 1.1.2: Repository Setup & Core Navigation Infrastructure

- **Task 1:** Initialize the Flutter project repository and enforce the Feature-First directory structure.
    
- **Task 2:** Implement `StatefulShellRoute` in `go_router` with persistent bottom navigation tabs (Map vs. Discovery Feed).
    
- **Task 3:** Create modular mock dataset files populated with 5 hardcoded Al Khobar professors featuring coordinates, bios, schedules, and `isLive` status booleans.
    

#### Phase 1.1.3: Core State Injection & Dev Integration Setup

- **Task 1:** Build the global `AppProvider` / state notifier to broadcast app-wide live stream and locale states.
    
- **Task 2:** Define concrete data contracts and interfaces for Dev 1 (Map), Dev 2 (Feed/Profiles), and Dev 3 (Live Stream) to work independently.
    
- **Task 3:** Wire core navigation routes between the Shell, Map, Feed, Profile, and Live Stream viewports.
    

## Version 0.2: Spatial & Profile Navigation Orchestration

### Checkpoint 2.2: Cross-Feature Navigation & Hero Animation Orchestration

#### Phase 2.2.1: Research & Animation Strategy

- **Task 1:** Research shared element spatial transitions (`Hero` widgets) between Map/Feed avatars and Profile header images.
    
- **Task 2:** Define route parameters and deep-linking arguments for navigating directly into Broadcaster Profiles (`/profile/:id`).
    

#### Phase 2.2.2: Hero Transition Architecture

- **Task 1:** Implement a global `Hero` tag naming convention (`avatar_${professor.id}`) across Map markers and Feed cards.
    
- **Task 2:** Wire cross-feature navigation handlers so double-tapping Map pins or tapping Feed cards smoothly pushes the Profile route.
    

#### Phase 2.2.3: Data Binding & Reactive State Synchronization

- **Task 1:** Pass `mock_data.dart` objects directly into `ProfileScreen` constructors.
    
- **Task 2:** Implement reactive state observers so toggling a broadcaster's `isLive` status instantly updates Map pins, Feed cards, and Profile status badges across the entire app simultaneously.
    

## Version 0.3: Video Player Abstraction & Architecture

### Checkpoint 3.1: Polymorphic Media Player Architecture

#### Phase 3.1.1: Research & Abstraction Pattern Design

- **Task 1:** Research the Adapter Design Pattern to decouple the UI viewport from specific underlying video player implementations.
    
- **Task 2:** Define contract interfaces for an `AbstractVideoPlayer` class supporting `flutter_vlc_player` (Local RTMP Hack), AWS IVS HLS Low-Latency Player, and `youtube_player_flutter` (Path 4).
    

#### Phase 3.1.2: Player Adapter Implementation

- **Task 1:** Code the `AbstractVideoPlayer` abstract class with mandatory `play()`, `pause()`, and `dispose()` life-cycle methods.
    
- **Task 2:** Create concrete `VlcPlayerAdapter`, `AwsIvsPlayerAdapter`, and `YouTubePlayerAdapter` wrapper classes that implement `AbstractVideoPlayer`.
    
- **Task 3:** Build a dynamic `VideoPlayerContainer` factory widget that picks the active player adapter based on environment flags.
    

## Version 1.0: Pitch Director Mode, Notification System & Final Integration

### Checkpoint 4.1: Simulated Push Notifications & Pitch Director Mode

#### Phase 4.1.1: Research & Golden Path Presentation Flow

- **Task 1:** Map out the exact step-by-step investor presentation sequence (Map $\rightarrow$ Notification Trigger $\rightarrow$ Live Room $\rightarrow$ Chat $\rightarrow$ Fullscreen Landscape).
    
- **Task 2:** Design secret gesture handlers (AppBar triple-tap, logo long-press) for invisible pitch control during live demos.
    

#### Phase 4.1.2: In-App Notification Trigger Pipeline

- **Task 1:** Build the simulated push notification overlay using `top_snackbar_flutter`.
    
- **Task 2:** Add a secret triple-tap gesture on the top AppBar logo that waits exactly 3 seconds before dropping the notification banner.
    
- **Task 3:** Wire the notification banner tap action to execute `context.push('/live/demo')`, bypassing all navigation menus to jump directly into the live stream.
    

#### Phase 4.1.3: Pitch Director Mode & Performance Polish

- **Task 1:** Implement a secret long-press gesture on the app logo that forces `mock_data.dart` into "Pitch Ready" state (1 professor set to Live, viewer count set to 294, ghost chat timer armed).
    
- **Task 2:** Inject artificial 600ms `shimmer` loading delays across Feed and Profile routes to simulate fetching data from a live cloud database.
    

### Checkpoint 4.2: Project Release Hardening & Pitch Sandbox QA

#### Phase 4.2.1: Research & Deployment Audit

- **Task 1:** Draft the pre-pitch checklist covering device settings (brightness lock, Do Not Disturb, auto-lock prevention).
    
- **Task 2:** Establish fallback procedures if local Wi-Fi router port forwarding (Port 1935) drops during the pitch.
    

#### Phase 4.2.2: Final Integration & Codebase Audit

- **Task 1:** Perform the final code review and merge Dev 1 (Map), Dev 2 (UI/i18n), and Dev 3 (Live Stream) branches into `main`.
    
- **Task 2:** Remove the debug banner (`debugShowCheckedModeBanner: false`) and initialize `wakelock_plus` on application startup.
    

#### Phase 4.2.3: Offline Sandbox & Hardware Rehearsal

- **Task 1:** Configure a dedicated mobile travel router network with static local IP routing for internal RTMP port forwarding.
    
- **Task 2:** Execute a full hardware loopback test (Laptop OBS $\rightarrow$ Travel Router $\rightarrow$ Test Device) to ensure 100% offline pitch reliability without relying on external venue Wi-Fi.