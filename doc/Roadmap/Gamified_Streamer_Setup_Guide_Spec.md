# Gamified Multi-Step Broadcaster Setup Guide & Studio Sheet V2 Refinements — Specification

This document details:
1. **The Broadcaster Studio Sheet V2 Visual & Layout Refinements** (80% height, system pinkish accent, blur backdrop, clean borderless container, centered sliding pills, and pulsing Audio-Only toggle).
2. **The Interactive Gamified Multi-Step Setup Guide (`!`)** (Quests, animated expanding pinkish dots, and zero-friction action buttons).

---

## 1. Studio Bottom Sheet V2 Refinements

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  [Dimmed & Frosted Background Blur: ImageFilter.blur sigma 16px]            │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     ─── Drag Handle (40x4) ───                        │  │
│  │                                                                       │  │
│  │  📡 [Pulsing Pink Glow]  BROADCASTER STUDIO                           │  │
│  │                          Choose how you want to broadcast today       │  │
│  │                                                                       │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │  [ 💻 OBS Studio ]     [ 📱 Phone Camera ]     [ ⚡ Local RTMP ] │  │  │  ◄── Perfectly Centered 1/3 Pill Slider
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                       │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │   Dynamic Morphing Middle Container                             │  │  │
│  │  │   • Broadcast Title & Multiline Description                     │  │  │  ◄── Smooth Height Morph
│  │  │   • Mode-specific inputs (Stream Key / Presets / Laptop IP)     │  │  │
│  │  │   • Gamified Multi-Step Info Modal Button [ ! ]                 │  │  │
│  │  │   • (Unfolds when Audio-Only selected): Background Poster Picker│  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                       │  │
│  │  ┌───────────────────────────┐      ┌──────────────────────────────┐  │  │
│  │  │  [ 📹 Video ] [ 🎙️ Audio ] │      │  🔴  [ Shrink-Pop Action CTA ]│  │  │  ◄── Left: Audio Pulse | Right: CTA
│  │  └───────────────────────────┘      └──────────────────────────────┘  │  │
│  │    (Pulsing glow when active)        (Pinkish #FF2D55 Gradient)       │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                               (80% Screen Height • NO Outer Stroke)         │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Direct Visual Rules for V2:
1. **Height Expansion:** Set bottom sheet container height to **`screenHeight * 0.80`** (80% of screen height) instead of 70% to provide clean breathing space without content crowding.
2. **Unified System Accent Color (Pinkish `#FF2D55` / `AppTheme.accentRed`):**
   - Drop the mode-switching colors (no cyan for OBS, no green for Phone, no yellow for Local).
   - Use the app's signature **Pinkish Coral Accent** (`#FF2D55` / `AppTheme.accentRed` / `AppTheme.accentPink`) across **all 3 modes** for active tab pills, category highlights, icon rings, and CTA buttons.
3. **Drop the Outer Border Stroke:**
   - Remove the `border: Border.all(...)` on the main sheet container so the bottom sheet sits smoothly against the background with a clean, borderless top-radius edge (`radius: 28`).
4. **Background Backdrop Blur:**
   - Ensure the barrier / background behind the bottom sheet applies a real Gaussian blur (`BackdropFilter` with `sigmaX: 16, sigmaY: 16` and dark scrim `Colors.black54`) so the profile screen beneath is softly blurred.
5. **Pixel-Perfect Centering for the 3 Tabs:**
   - Fix the sliding indicator calculation in `_buildModePill`. Use `LayoutBuilder` with exact `tabWidth = (constraints.maxWidth - padding) / 3` and `AnimatedPositioned(left: index * tabWidth)` so the selected indicator capsule is always 100% centered over the active tab in both LTR and RTL.
6. **Audio-Only Pulsing Animation:**
   - When the user selects `[ 🎙️ Audio ]`, trigger an animated breathing glow/pulse around the Audio toggle button (using an `AnimationController` with repeating forward/reverse scale & opacity $1.0 \rightarrow 1.05$).

---

## 2. Gamified Multi-Step Info (`!`) Guide Carousel (`streamer_setup_guide_modal.dart`)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  ✨ STREAMER ACADEMY                          [ ✕ Close ]               │
│  Level 2 of 4: The Secret VIP Pass 🔑                                   │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                                                                   │  │
│  │     ╔═══════════════════════════════════════════════════╗         │  │
│  │     ║                🔑 [Glowing Animated Icon]         ║         │  │
│  │     ╚═══════════════════════════════════════════════════╝         │  │
│  │                                                                   │  │
│  │   Grab Your Secret Stream Key                                     │  │
│  │                                                                   │  │
│  │   "Think of your Stream Key like a secret VIP backstage pass.     │  │
│  │   It tells YouTube: 'Hey, this video is really from ME!'          │  │
│  │   In YouTube Studio, find the 'Stream' tab and click Copy         │  │
│  │   next to Default Stream Key."                                    │  │
│  │                                                                   │  │
│  │   [ 🔗 Open YouTube Studio ]       [ 📋 Paste from Clipboard ]    │  │  ◄── Interactive Quick Actions
│  │                                                                   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│               ● ──────── ════════════ ──────── ● ──────── ●             │  ◄── Expanding Bouncy Dots
│             Gray          [Pinkish Pill]      Gray       Gray           │      (Gray -> Glow Pinkish #FF2D55)
│                                                                         │
│  [ ◀ Previous Step ]                                 [ Next Quest ▶ ]   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Micro-Interactions:
- **Expanding Bouncy Indicator Dots:** Inactive dots ($7\text{px} \times 7\text{px}$, `#2C2F3E`) expand into an elongated glowing pill ($26\text{px} \times 7\text{px}$, `#FF2D55`) with `Curves.easeOutBack`.
- **Swipeable Story Cards:** `PageView.builder` with haptic feedback tick (`HapticFeedback.selectionClick()`).
- **Playful, Non-Technical Copywriting:**
  - **💻 OBS (4 Quests):** `Level 1: Mission Control` (Open YouTube Studio) $\rightarrow$ `Level 2: The Secret VIP Pass 🗝️` (Copy Stream Key) $\rightarrow$ `Level 3: Connecting the Wires 💻` (Paste in OBS) $\rightarrow$ `Level 4: Ready for Takeoff 🎬` (Start Stream & Go Live).
  - **📱 Phone (3 Quests):** `Level 1: Account Activation ⏳` (One-time 24h YouTube live rule) $\rightarrow$ `Level 2: Set It & Forget It 💾` (Paste key once) $\rightarrow$ `Level 3: Live from Your Phone 📱` (Open camera & go live).
  - **⚡ Local (2 Quests):** `Level 1: Same Room Network 📶` (Same Wi-Fi) $\rightarrow$ `Level 2: Plug & Play ⚡` (Enter Laptop IP).
- **Interactive Quick Action Buttons:** `[ 🔗 Open YouTube Studio ]`, `[ 📋 Paste Key from Clipboard ]`, and `[ 🚀 Got It, Let's Stream! ]`.

---

## 3. Implementation File Plan

1. **`lib/features/live_stream/presentation/widgets/streamer_setup_guide_modal.dart`** *(NEW File)*
   - Implements the complete multi-step story carousel modal for OBS, Phone, and Local modes.
2. **`lib/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart`** *(MODIFY)*
   - Update height to `screenHeight * 0.80`.
   - Remove outer border stroke.
   - Unify all colors to `AppTheme.accentRed` / `#FF2D55`.
   - Fix sliding pill centering with `LayoutBuilder`.
   - Add pulsing animation on `[ 🎙️ Audio ]` selection.
   - Wire Info `(!)` buttons to `StreamerSetupGuideModal.show(context, targetType: _mode)`.
3. **`test/rtmp_ip_dialog_test.dart`** *(MODIFY)*
   - Verify 80% height, system pinkish color palette, audio pulse, and setup guide launch.
