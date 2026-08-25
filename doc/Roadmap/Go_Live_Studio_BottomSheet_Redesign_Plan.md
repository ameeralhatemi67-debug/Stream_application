# Go-Live Broadcaster Studio 80% Bottom Sheet Redesign & Phone Stream Fix — Implementation Plan

---

## 1. Issue Diagnosis & Resolution

### Log Analysis & Root Cause:
```
I/flutter (10755): YouTubeLiveService (simulated): ended broadcast bcast_mt8c4cvf
I/CommandsManager(10755): send Command(name='closeStream', transactionId=6, timeStamp=30, streamId=1...)
I/CameraManagerGlobal(10755): Camera 0 ... state now CAMERA_STATE_CLOSED
I/MicrophoneManager(10755): Microphone stopped
I/VideoEncoder(10755): stopped
```
1. **Fake Stream Key Rejection:** `YouTubeLiveService` generated a simulated stream key (`sim-key-xxxx`). When `PhoneBroadcastScreen` tried to open an actual RTMP socket to YouTube (`rtmp://a.rtmp.youtube.com/live2/sim-key-xxxx`), YouTube's RTMP ingest server immediately rejected the invalid key, triggering a `closeStream` command and tearing down the camera/mic pipeline.
2. **Dual Icon Clutter:** Having two separate cell tower icons caused confusion.
3. **Resolution:** 
   - Keep only **ONE single cell tower icon** that opens the **80% Glassmorphic Broadcaster Studio Bottom Sheet**.
   - In the Phone tab, allow using the streamer's saved/real YouTube stream key (pre-filled from profile/provider) with clear helper tooltips, ensuring the native camera RTMP engine connects successfully to YouTube or local testing servers.

---

## 2. Redesign Architecture: 80% Glassmorphic Bottom Sheet V2

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  [Dimmed & Frosted Background Blur: ImageFilter.blur sigma 16px, 0.5 Scrim]  │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                          ─── Drag Handle (40x4) ───                    │  │
│  │                                                                        │  │
│  │  📡 [Pulsing Pink Glow]  BROADCASTER STUDIO                            │  │
│  │                          Choose how you want to broadcast today        │  │
│  │                                                                        │  │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │  │
│  │  │   [ 💻 OBS Studio ]     [ 📱 Phone Camera ]     [ ⚡ Local RTMP ]  │  │  │  ◄── Perfectly Centered 1/3 Pill Slider
│  │  └──────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                        │  │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │  │
│  │  │                                                                  │  │  │
│  │  │   Dynamic Morphing Middle Container                              │  │  │
│  │  │   • Broadcast Title & Multiline Description                      │  │  │  ◄── Smooth Height Morph
│  │  │   • Mode-specific inputs (Stream Key / Presets / Laptop IP)      │  │  │
│  │  │   • Gamified Multi-Step Info Modal Button [ ! ]                  │  │  │
│  │  │   • (Unfolds when Audio-Only selected): Background Poster Picker │  │  │
│  │  │                                                                  │  │  │
│  │  └──────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                        │  │
│  │  ┌───────────────────────────┐      ┌───────────────────────────────┐  │  │
│  │  │  [ 📹 Video ] [ 🎙️ Audio ] │      │  🔴  [ Shrink-Pop Action CTA ]│  │  │  ◄── Left: Audio Pulse | Right: CTA
│  │  └───────────────────────────┘      └───────────────────────────────┘  │  │
│  │    (Pulsing glow when active)        (Pinkish #FF2D55 Gradient)        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                (80% Screen Height • NO Outer Stroke)         │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. UI Specifications & V2 Design Rules

### A. Top Section: Header & Mode Segmented Slider
1. **80% Sheet Height:** Set modal sheet height to **`screenHeight * 0.80`** for ample vertical breathing room.
2. **Single System Accent Color (`#FF2D55` / `AppTheme.accentRed`):**
   - Drop mode-specific colors (no cyan/green/yellow). Use the app's signature **Pinkish Coral Accent** across all modes.
3. **Borderless Container:**
   - Remove outer stroke border (`border: Border.all(...)`). The container sits smoothly with clean top rounded corners (`radius: 28`).
4. **Real Backdrop Blur:**
   - Ensure the modal route barrier applies `BackdropFilter` Gaussian blur (`sigmaX: 16, sigmaY: 16`) over the dimmed background.
5. **Pixel-Perfect Centered Sliding Tabs:**
   - Use `LayoutBuilder` with exact `tabWidth = (constraints.maxWidth - padding) / 3` and `AnimatedPositioned(left: index * tabWidth)` so the selected indicator is perfectly centered over each 1/3 tab.

---

### B. Middle Section: Dynamic Morphing Card & Fields
1. **When [ 💻 OBS Studio ] is selected**:
   - Broadcast Title field & Multiline Description field.
   - Category selector chips & tags.
   - Stream Key box with masking and copy button.
   - Ingest server URL preview (`rtmp://a.rtmp.youtube.com/live2`).
   - Info `(!)` button opening the **Gamified 4-Step OBS Quest Guide**.

2. **When [ 📱 Phone Camera ] is selected**:
   - Broadcast Title field & Multiline Description field.
   - Category selector chips & tags.
   - YouTube Stream Key field (pre-filled with saved key, with eye visibility toggle).
   - Quality Preset Pills (`480p Low` • `720p Recommended` • `1080p High`) with estimated bandwidth tag (`~2.5 Mbps`).
   - Info `(!)` button opening the **Gamified 3-Step Phone Quest Guide**.

3. **When [ ⚡ Local RTMP ] is selected**:
   - Laptop IP address input field (`192.168.x.x`) with subnet helper presets.
   - Target RTMP URL preview (`rtmp://192.168.1.50/live/demo`).
   - Info `(!)` button opening the **Gamified 2-Step Local Quest Guide**.

4. **Audio-Only Unfolding Background Option:**
   - When the user toggles `🎙️ Audio-Only` at the bottom, an animated card unfolds offering clean dark backdrop with live audio visualizer or custom poster image upload.

---

### C. Bottom Section: Format Toggle & Shrink-and-Pop CTA
1. **Left: Format Selector with Audio Pulse**:
   - Dual toggle: `[ 📹 Video Stream ]` vs. `[ 🎙️ Audio-Only ]`.
   - When `[ 🎙️ Audio ]` is selected, an animated breathing pulse / glow cycles around the Audio button.
2. **Right: Morphing CTA Button with Shrink-and-Pop Motion**:
   - On tab switch, button scales down to `0.85`, transitions label, and pops back to `1.0` with `Curves.easeOutBack`:
     - OBS $\rightarrow$ `[ ((•)) Go Live ]`
     - Phone $\rightarrow$ `[ 📷 Open Camera ]`
     - Local $\rightarrow$ `[ ⚡ Stream ]`

---

## 4. File Breakdown & Implementation Scope

1. **`lib/features/live_stream/presentation/widgets/streamer_setup_guide_modal.dart`** *(NEW)*
   - Interactive Gamified Story Carousel Modal (`PageView.builder`) with expanding pinkish dots (`#FF2D55`) and quick action buttons.
2. **`lib/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart`** *(MODIFY)*
   - Update height to 80% (`screenHeight * 0.80`).
   - Drop outer border stroke.
   - Unify all accent highlights to system pinkish color (`AppTheme.accentRed` / `#FF2D55`).
   - Fix sliding tab centering with `LayoutBuilder`.
   - Add pulsing animation to Audio-Only toggle.
   - Wire Info `(!)` buttons to `StreamerSetupGuideModal`.
3. **`test/rtmp_ip_dialog_test.dart`** *(MODIFY)*
   - Tests covering 80% bottom sheet rendering, pinkish palette, audio pulse, and setup guide modal.
