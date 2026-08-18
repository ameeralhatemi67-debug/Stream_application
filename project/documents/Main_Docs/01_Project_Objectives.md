# Project Objectives & Success Criteria

## Overview

This document outlines the measurable **Strategic Business Goals**, **Product & UX Objectives**, **Technical Performance KPIs**, and **Pitch Readiness Metrics** for the Educational Cloud Streaming Application.

---

## 1. Strategic & Operational Objectives

* **Establish a Dedicated Educational Hub:** Build the premier digital platform specifically engineered for Saudi academic and community streams, free from generic entertainment noise.
* **Drive In-Person & Remote Attendance:** Increase attendance at local lectures in Al Khobar and AlSharqia by offering dual discovery (Map navigation for physical visits + Live streaming for remote views).
* **Curate High-Quality Educational Content:** Implement strict onboarding for approved broadcasters, ensuring 100% of published streams meet quality and regulatory guidelines.
* **Build an Educational VOD Repository:** Automatically transcode and archive 100% of completed live streams into a searchable, categorized Video-on-Demand vault for long-term reference.
* **Execute a Phased Expansion:** Successfully launch Phase 1 in Al Khobar, prepare data and geographic polygon infrastructure for Phase 2 (AlSharqia), and lay architectural foundations for Phase 3 (Kingdom-wide).

---

## 2. Product & User Experience Objectives

* **Intuitive Dual Discovery:** Enable users to seamlessly switch between the **Spatial Map Finder** and the **Twitch-Style Discovery Feed** in $\le 1$ tap.
* **Native Bilingual Experience:** Deliver 100% feature and layout symmetry between English (LTR) and Arabic (RTL) with dynamic instant language switching.
* **High Audience Interactivity:** Provide real-time chat engagement, localized ghost audience simulation for live demos, and frame-accurate floating reaction keyframes (claps, hearts, hand raising).
* **Creator Identity & VOD Integration:** Present comprehensive streamer profiles with collapsible headers, verified badges, stream schedules, and inline YouTube/IVS VOD playback.

---

## 3. Technical Performance Key Performance Indicators (KPIs)

| Domain | Metric / Parameter | Target Goal | Verification Method |
| :--- | :--- | :--- | :--- |
| **Stream Latency (Cloud)** | Production Cloud Latency (AWS IVS) | **< 3.0 seconds** | Amazon IVS Player SDK latency metrics |
| **Stream Latency (Pitch)** | Local Wi-Fi RTMP Pitch Demo | **< 500 ms** | Local VLC player network buffer logs |
| **Language Switch Speed** | Locale swap (EN $\leftrightarrow$ AR) | **< 100 ms** | `easy_localization` state rebuild timings |
| **Map Animation Smoothness** | Camera zoom/pan curve | **60 FPS target** | Flutter Performance Overlay & DevTools |
| **App Startup Time** | Cold boot to Map/Feed render | **< 2.0 seconds** | Flutter Engine init & frame metrics |
| **Memory Footprint** | Peak RAM consumption on mobile | **< 180 MB** | Memory profiler during live streaming |
| **Storage Lifecycle Efficiency** | S3 VOD Cost Optimization | **> 90% cost drop** | S3 Standard $\rightarrow$ Glacier auto-lifecycle tiering |

---

## 4. Quality Assurance & Pitch Readiness Metrics

To ensure an impressive, flaw-free presentation during investor and stakeholder demonstrations, the app enforces strict reliability targets:

```
+---------------------------------------------------------------------------------------------------+
|                                     PITCH SAFETY & RELIABILITY                                    |
|                                                                                                   |
|  [ 100% Fallback Protection ]    [ Zero Crash Guarantee ]      [ Pitch Director Overrides ]   |
|  All unbuilt buttons trigger     No red screens on network     Long-press logo trigger for   |
|  FeatureInProgressModal.         drop; clean offline overlay.  simulated notifications & state.|
+---------------------------------------------------------------------------------------------------+
```

1. **Zero Raw Error Screens:** The application must never exhibit red Flutter framework error screens or unhandled exceptions. If network connection drops, a branded "Stream Temporarily Offline" overlay must render.
2. **100% Feature-Safety Coverage:** Every unbuilt UI button, tab, or action icon must safely trigger the universal `FeatureInProgressModal` or localized toast message.
3. **Pitch Director Overrides:** A secret gesture (e.g., long-press on app logo) triggers simulated push notifications and artificial shimmer delays to simulate real-world backend responses seamlessly during live demos.

---

## 5. Milestone & Roadmap Alignment

| Version Milestone | Target Objective & Focus | Key Deliverables |
| :--- | :--- | :--- |
| **Version 0.1** | *The Interactive Shell, Localization & Spatial Map Engine* | `go_router` shell, `#0E0E10` dark theme, `easy_localization` (EN/AR), `flutter_map` AlSharqia GeoJSON vector canvas, cinematic zoom animations, `FeatureInProgressModal`. |
| **Version 0.2** | *Structured Discovery Feed & Creator Identity* | 3-Column discovery grid, category chips, search filters, Broadcaster profile with collapsible `SliverAppBar`, VOD archive gallery with YouTube embeds. |
| **Version 0.3** | *Live Broadcast & Real-Time Interaction Engine* | Dual player wrapper (VLC RTMP / IVS), landscape auto-fullscreen, inverted chat UI, periodic "Ghost Audience" comment injection engine, floating gesture keyframes. |
| **Version 1.0** | *Pitch Polish & Investor Readiness* | Pitch Director Mode, simulated push notifications, network fallback screens, full LTR/RTL QA audit, final build hardening. |
