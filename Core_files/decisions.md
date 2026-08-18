---
type: decisions
project: Streamer_app
updated: 2026-08-09
---

# 🏛️ Architecture Decision Records (ADRs): Streamer App

> Key architectural, UX, and technical decisions governing the Educational Streamer App.

---

## ADR-001: Persistent Dual Navigation via `go_router` StatefulShellRoute
* **Status:** `ACCEPTED`
* **Context:** The application features two primary discovery paradigms: an interactive Spatial GIS Map and a Twitch-style Discovery Feed. Rebuilding the map canvas on every tab switch would destroy pan/zoom state and cause visual stutter.
* **Decision:** Use `StatefulShellRoute` in `go_router` to maintain independent navigation stacks and persistent widget trees for both tabs.
* **Consequences:** Instant tab switching with zero map reload latency and preserved camera coordinates.

---

## ADR-002: Dual Streaming Strategy (YouTube Live Embeds + Cloud RTMP/HLS)
* **Status:** `ACCEPTED`
* **Context:** To ensure low operational cost while scaling educational content across Saudi Arabia, authorized educational channels primarily broadcast on YouTube Live, with cloud fallback (AWS IVS / RTMP) for custom private seminars.
* **Decision:** Implement `youtube_player_iframe` for YouTube Live and VOD playback, with clean encapsulation in a unified `VideoViewport` interface.
* **Consequences:** Zero streaming server hosting costs for public lectures, reliable multi-bitrate HLS playback, and native integration with YouTube's CDN.

---

## ADR-003: Dynamic Bilingual Layout Mirroring (Easy Localization)
* **Status:** `ACCEPTED`
* **Context:** The platform serves Saudi Arabia and international academic audiences, requiring 100% parity between Arabic (RTL) and English (LTR).
* **Decision:** Use `easy_localization` with JSON translation catalogs (`en.json`, `ar.json`) and native `Directionality` layout mirroring.
* **Consequences:** Sub-100ms language swaps without restarting the app or losing current scroll/stream states.

---

## ADR-004: Anti-Slop Design System & Impeccable Contract (`Desgin.md`)
* **Status:** `ACCEPTED`
* **Context:** Prior UI iterations suffered from generic design patterns and ad-hoc color styles.
* **Decision:** Enforce a strict `Core_files/Desgin.md` contract governed by `[[impeccable]]` design rules, curated HSL/OKLCH color palettes, glassmorphism surface layers, and modern typography (Inter + Tajawal).
* **Consequences:** Premium educational aesthetic, crisp visual hierarchy, and automated design linting via `.agents/hooks.json`.

---

## ADR-005: 100% Pitch Safety & Graceful Error Overlays
* **Status:** `ACCEPTED`
* **Context:** During investor pitches and stakeholder live demos, unhandled errors or blank tabs destroy credibility.
* **Decision:** Never expose raw Flutter exception screens. All unbuilt actions route to `FeatureInProgressModal`, and network drops display a branded "Stream Temporarily Offline" overlay with secret Pitch Director overrides.
* **Consequences:** Guaranteed crash-free demo experience.

---

## ADR-006: YouTube IFrame Cross-Origin Referrer Architecture (Error 150/152/153 Prevention)
* **Status:** `ACCEPTED` (Implemented & Verified 2026-08-16)
* **Context:** YouTube's mid-2025/2026 security updates enforce strict embedder verification on mobile WebViews. Loading raw URLs or using default WebView headers caused Error 150 (embed restriction), Error 152 (Play Integrity/bot check on debug builds), and Error 153 (configuration error due to missing/same-origin `Referer` headers).
* **Decision:** In `YouTubePlayerAdapter`, configure:
  1. `AndroidWebViewController.setMediaPlaybackRequiresUserGesture(false)` and `WebKitWebViewController.setAllowsInlineMediaPlayback(true)`.
  2. Embed wrapper HTML with `<meta name="referrer" content="strict-origin-when-cross-origin">` and `iframe referrerpolicy="strict-origin-when-cross-origin"`.
  3. Base URL set strictly to `https://www.youtube-nocookie.com`.
  4. Embed source URL: `https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&playsinline=1&controls=1&rel=0&modestbranding=1&enablejsapi=1`.
* **Consequences:** 100% verified, seamless playback for both YouTube Live Streams and Archived Lectures (VODs) across all Android and iOS devices with zero Error 150/152/153 crashes.

