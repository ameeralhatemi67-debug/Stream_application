As the Media & Real-Time Specialist, your primary focus is driving the core "live experience" of the platform: implementing the zero-cost local RTMP loopback hack (`flutter_vlc_player`) for sub-second pitch demo latency, embedding YouTube VOD archives, building the inverted live chat UI, and orchestrating the automated **"Ghost Audience"** comment engine.

# Streaming, Media & Real-Time Engine Specialist Roadmap

## Version 0.2: VOD Archives & Video Embedding

### Checkpoint 2.2: YouTube VOD Integration for Past Archives

#### Phase 2.2.1: Research & Media Embed Discovery

- **Task 1:** Evaluate YouTube embedding packages (`youtube_player_iframe` vs `youtube_player_flutter`) for playing unlisted past lecture archives inline inside modals/tabs.
    
- **Task 2:** Design the mock video metadata schema (YouTube ID, duration, thumbnail, title) in coordination with Team Lead's data models.
    

#### Phase 2.2.2: VOD Player & Archive Grid Engine

- **Task 1:** Build the 2-column "Archive" tab grid displaying past lecture thumbnails and titles on the Profile screen.
    
- **Task 2:** Integrate `youtube_player_iframe` to load and play unlisted YouTube past recordings directly inside a modal overlay when a VOD tile is tapped.
    

#### Phase 2.2.3: VOD Playback UX & Lifecycle Management

- **Task 1:** Implement proper player controller initialization (`initState`) and disposal (`dispose`) to prevent memory leaks during tab switches.
    
- **Task 2:** Build inline video playback controls (play/pause toggle, scrub bar, full-screen trigger).
    

## Version 0.3: The Live Broadcast Experience (Path 4 & Local Hack)

### Checkpoint 3.1: Live Media Player Pipeline

#### Phase 3.1.1: Research, Design & Video Pipeline Discovery

- **Task 1:** Research local RTMP loopback architecture (`flutter_vlc_player` connecting to `node-media-server` running on local laptop IP) versus Path 4 YouTube Live webview embeds.
    
- **Task 2:** Design player viewport UI controls: live status badge, viewer counter, close button, full-screen toggle, and landscape orientation rules.
    
- **Task 3:** Map out graceful network fallback UI screens if the local Wi-Fi connection drops during a live pitch demo.
    

#### Phase 3.1.2: Video Viewport & RTMP Implementation

- **Task 1:** Implement `flutter_vlc_player` using `VlcPlayerController.network()` targeting `rtmp://[LAPTOP_LOCAL_IP]/live/demo` for sub-second local Wi-Fi pitch streaming.
    
- **Task 2:** Implement `AbstractVideoPlayer` adapter integration connecting VLC (Local RTMP), AWS IVS HLS Low-Latency Player, and YouTube embeds to the polymorphic viewport.
    
- **Task 3:** Implement landscape auto-fullscreen behavior using `OrientationBuilder` and `wakelock_plus` to keep the device screen active during broadcasts.
    
- **Task 3:** Ensure strict controller disposal (`_controller.dispose()`) inside the widget lifecycle override to prevent memory spikes or app crashes when backing out of the live screen.
    

#### Phase 3.1.3: Live Player Overlays & Fallback Systems

- **Task 1:** Build video player overlay elements: pulsing red "LIVE" indicator, active viewer count pill ("294 Watching"), and close button.
    
- **Task 2:** Construct a branded stream fallback screen displaying "Stream Temporarily Offline" if network disconnects occur, preventing raw Flutter red error screens.
    

### Checkpoint 3.2: Real-Time Interactive Engagement Engine

#### Phase 3.2.1: Research, Design & Chat Architecture Discovery

- **Task 1:** Research Twitch/YouTube-style inverted chat stream UI architecture (`reverse: true` list view).
    
- **Task 2:** Design the "Ghost Audience" simulation algorithm using timer-based local message injection.
    
- **Task 3:** Prepare localized mock chat datasets in English and Arabic reflecting authentic student and viewer comments during a live lecture.
    

#### Phase 3.2.2: Live Chat UI & Local Input Engine

- **Task 1:** Build an inverted `ListView.builder` (`reverse: true`) occupying the lower 60% of the live broadcast view.
    
- **Task 2:** Build the bottom message input bar ("Type something..." / "اكتب شيئاً...") with a send button.
    
- **Task 3:** Implement local chat submission: typing a message instantly appends it to index 0 of the chat list with a "You" badge and clears the text field.
    

#### Phase 3.2.3: Ghost Audience Engine & Floating Reactions

- **Task 1:** Implement `Timer.periodic` scheduled to inject a random comment from the localized EN/AR mock chat pool every 4–7 seconds.
    
- **Task 2:** Build gesture reaction buttons (Clap, Heart, Raise Hand) in the bottom control bar.
    
- **Task 3:** Implement floating animated heart/clap emoji keyframes that drift upward over the video player when tapped.
    

## Version 1.0: Pitch Polish & Media Stability

### Checkpoint 4.2: Video Memory Hardening, Network Safety & Rehearsal

#### Phase 4.2.1: Research & Media Stress Audit

- **Task 1:** Audit RAM and video memory utilization during prolonged RTMP playback sessions to ensure zero memory accumulation.
    
- **Task 2:** Test landscape vs. portrait orientation rotation transitions during active live streaming to verify smooth player rebuilding.
    

#### Phase 4.2.2: Media Error Handling & Fallback Polish

- **Task 1:** Wrap `VlcPlayer` in an error builder to catch Wi-Fi drops gracefully and display branded recovery banners.
    
- **Task 2:** Ensure background ghost chat timers cancel cleanly when leaving the screen to prevent background memory overhead.
    

#### Phase 4.2.3: Hardware Loopback Verification & Pitch Rehearsal

- **Task 1:** Perform hardware loopback testing with Team Lead (Laptop OBS broadcast $\rightarrow$ Local Travel Router $\rightarrow$ Test Device VLC Player).
    
- **Task 2:** Rehearse the complete media presentation loop: trigger notification banner $\rightarrow$ enter live room $\rightarrow$ post chat message $\rightarrow$ observe ghost audience messages $\rightarrow$ flip phone to landscape fullscreen.