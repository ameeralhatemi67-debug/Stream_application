# Streamer App — User Flow & UX Ergonomics Comprehensive Audit
**Platform:** Academic & Live Lecture Streaming Platform (Saudi Arabia / AlSharqia Focused)  
**Evaluator:** Elite UX, Product Design & User Journey Specialist  
**Evaluation Methodology:** Nielsen Norman 10 Usability Heuristics, W3C WCAG 2.1 AA Accessibility, Material Design 3 Guidelines, Bi-directional (RTL/LTR) Localization Ergonomics  
**Date:** August 2026  
**Status:** Complete Audit Report & Implementation Action Plan  

---

## 1. Executive Summary

### 1.1 Platform Overview & UX Maturity Assessment
The **Streamer App** is an academic broadcasting and spatial lecture discovery platform targeting university students, faculty members, researchers, and educational organizations across Saudi Arabia’s Eastern Province (Dhahran, Al Khobar, Dammam). The application bridges digital live broadcasts (via YouTube Live and local OBS RTMP) with physical campus attendance through an interactive GIS OpenStreetMap engine.

The platform demonstrates an **exceptional technical architecture**—featuring real-time multi-source video switching, live YouTube channel syncing, multi-tenant organization speaker rosters, and dynamic bilingual localization (Arabic / English). However, from a UX and cognitive ergonomics perspective, several high-friction bottlenecks and heuristic violations impede seamless onboarding, broadcaster application, and spatial navigation.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        UX MATURITY SCORECARD                           │
├────────────────────────────────┬────────────────┬──────────────────────┤
│ Metric Dimension               │ Score (1-100)  │ Grade / Status       │
├────────────────────────────────┼────────────────┼──────────────────────┤
│ 1. Visual Hierarchy & Contrast │ 88 / 100       │ Excellent (Grade A)  │
│ 2. Spatial & Map Usability     │ 84 / 100       │ Very Good (Grade B+) │
│ 3. Onboarding & Auth Journey   │ 68 / 100       │ Needs Work (Grade C) │
│ 4. Application Wizard Flow     │ 72 / 100       │ Moderate (Grade B-)  │
│ 5. Touch Target Ergonomics     │ 74 / 100       │ Moderate (Grade B-)  │
│ 6. RTL Bi-directional Fidelity │ 82 / 100       │ Good (Grade B)       │
│ 7. Error Prevention & Recovery │ 65 / 100       │ Needs Work (Grade C) │
├────────────────────────────────┴────────────────┴──────────────────────┤
│ OVERALL UX HEALTH SCORE: 76.1 / 100 (Solid Foundation with UX Frictions)│
└────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Top 5 Platform Strengths
1. **Rich Spatial-First Identity:** The integration of live broadcasting with physical campus auditoriums, GPS proximity calculation, and interactive OSM map clustering provides a unique, highly contextual experience for university students.
2. **Resilient Dark Mode Theme:** Clean graphite palette (`#121214`, `#1A1A1E`, `#24242A`) paired with intentional accent colors (Coral Red `#FF8080` for Live Video, Gray `#A1A1AA` for Audio-Only, and Purple `#C084FC` for Verification).
3. **Fluid Multi-Speaker Stage:** The live streaming room seamlessly handles multi-speaker audio stages, ghost commentary simulation, and dynamic presenter floating overlays without UI locking.
4. **Comprehensive Multi-Tenant Org Support:** Robust data modeling and administrative interfaces for university organizations (branches, rosters, granular permissions, audit trails).
5. **Real-time Bilingual Synchronization:** Instant language switching (Arabic RTL with Tajawal font and English LTR with Inter font) without rebuilding or dropping active video playback streams.

### 1.3 Top 5 Critical UX Friction Points
1. **OAuth Loop & Guest Ambiguity (`welcome_screen.dart`):** Both "Sign Up with Google" and "Log In" trigger simulated Google OAuth with identical outcomes, yet returning users are repeatedly forced into `/role-select` instead of resuming their persistent session. Guest users face ambiguous barriers before exploring.
2. **Application Wizard Step Invalidation (`streamer_apply_screen.dart`):** Toggling between "Individual Scholar" and "Organization" dynamically inserts Step 3.5 (Speakers Roster), altering total steps from 5 to 6 on the fly. This causes the progress bar percentage to jump backwards, disorienting applicants.
3. **Aspect Ratio Mismatch in Banner Cropping (`apply_step_2_media.dart` vs `discovery_feed_screen.dart`):** The media crop modal forces a fixed 150dp crop preview, whereas the Feed card and Broadcaster profile expect standard 16:9 responsive banners, resulting in unexpected letterboxing or heads being sliced off in production.
4. **Sub-44dp Touch Targets in Critical Toolbars:** Multiple floating buttons, close icons, and bottom sheet action pills measure below the recommended 44×44dp / 48×48dp touch bounding box, causing high miss rates on compact 360dp mobile viewports.
5. **Review Screen Edit Barriers (`apply_step_5_review.dart`):** The final application review step displays an aggregated summary card but lacks granular "Edit Step" jump buttons. If an applicant spots a typo in their bio or YouTube handle, they must repeatedly tap "Back" 4 times to fix it.

---

## 2. End-to-End User Journey Map Matrix

Below is an exhaustive matrix evaluating the five core user personas navigating through each chronological lifecycle phase.

| Journey Phase | First-Time Guest Viewer | Enrolled Student / Return Viewer | Academic Scholar Applicant | Org Administrator | Super Admin / Moderator |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1. First Contact & Onboarding** | • Lands on Welcome Screen.<br>• Sees "Continue as Guest" or "Google Sign In".<br>*Friction:* Guest setup demands display name upfront without a "Skip / Browse Anonymously" option. | • Enters via Google OAuth.<br>*Friction:* If user clicks "Sign Up" instead of "Log In", they are redirected to Role Select rather than directly to their personalized feed. | • Selects "Apply as Streamer" in Role Select.<br>*Friction:* No preview of required materials or estimated time commitment before embarking on the 5-step wizard. | • Same onboarding as Scholar.<br>*Friction:* No dedicated "Register Institution / University" badge on landing screen. | • Signs in with privileged Google account.<br>*Friction:* No direct link to Admin Hub from landing; must navigate through Settings. |
| **2. Discovery & Spatial Exploration** | • Explores Discovery Feed.<br>• Filters by CS / Medicine / Sharia.<br>• Switches to Spatial Map.<br>*Strength:* Immediate visual feedback for live streams.<br>*Friction:* Topic pills in Map top bar scroll off screen on 360px phones. | • Views followed scholars and active campus live streams.<br>• Uses search bar for topics.<br>*Strength:* Live Hero Carousel with active viewer counters. | • Navigates feed to benchmark competitor stream layouts.<br>*Strength:* Seamless profile switching. | • Explores university cluster on Map.<br>*Strength:* Polygon boundary outlines indicate regional campuses. | • Filters streamers by verification status and active streams.<br>*Strength:* Fast search bar in admin registry. |
| **3. Live Broadcast Engagement** | • Taps live stream card.<br>• Experiences instant playback.<br>*Friction:* Mini-player PIP floats over bottom navigation bar when dismissed back to feed. | • Participates in live chat, sends reactions (👏, ❤️, 🔥).<br>• Toggles "Raise Hand".<br>*Strength:* Real-time responsive overlay without full screen re-renders. | • Accesses Live Broadcast Studio.<br>• Switches stream between YouTube Live and Local OBS RTMP.<br>*Strength:* Scoped auto-detect for channel live broadcast. | • Inspects multi-speaker audio stage.<br>*Strength:* Visual audio wave pulses and speaker attribution tags. | • Moderates live chat and stream health telemetry.<br>*Strength:* Real-time viewer count polling. |
| **4. Campus Venue Navigation** | • Clicks "Directions" on map card.<br>• Opens Venue Navigation Sheet.<br>*Strength:* Seating capacity, auditorium gate, and distance calculation.<br>*Friction:* External map URL copies to clipboard rather than launching native Google Maps intent. | • Checks auditorium details (Gate 4, Building 24, KFUPM).<br>• Shares venue card.<br>*Strength:* Clear typography and distance in KM. | • Verifies assigned auditorium seating and gate info in profile header. | • Manages venue branches and seating capacities in Org Management. | • Edits venue GPS coordinates with live map picker modal. |
| **5. Profile & Community** | • Browses Scholar VODs and Playlists.<br>*Friction:* Tapping speaker pill in Org profile switches tab but lacks visual reset indicator. | • Toggles "Follow" and "Set Reminder".<br>• Watches archived lectures in VOD bottom sheet. | • Edits scholar bio, links YouTube channel, views verified badge.<br>• Uses "Join Organization" modal. | • Adds guest speakers, configures granular broadcast permissions (Video/Audio/Location). | • Audits organizational change history in Audit Trail log. |
| **6. Governance & Settings** | • Toggles Dark Theme and Arabic / English language.<br>*Strength:* Instant dynamic RTL layout inversion. | • Customizes video streaming quality presets.<br>• Reviews Terms & Conditions and Privacy Policy. | • Tracks application review status (Pending / Approved / Revision Needed). | • Reviews pending speaker affiliation requests. | • Approves/Rejects broadcaster applications with custom feedback notes. |

---

## 3. Screen-by-Screen Detailed Audit Findings

### 3.1 Auth & Onboarding Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ONBOARDING FLOW GRAPH                           │
│                                                                        │
│   [ WelcomeScreen ] ──► (Guest Flow)  ──► [ ViewerSetupScreen ]        │
│          │                                        │                    │
│          ├────────────► (Google OAuth) ──► [ RoleSelectScreen ]        │
│                                                   │                    │
│                               ┌───────────────────┴──────────────────┐ │
│                               ▼                                      ▼ │
│                      [ DiscoveryFeed ]                     [ StreamerApply ]
└────────────────────────────────────────────────────────────────────────┘
```

#### Issue A-01: Welcome Screen OAuth Mode Ambiguity
- **File:** `lib/features/auth/presentation/welcome_screen.dart` (Lines 80–180)
- **Severity:** `P1 (High)`
- **Heuristic:** NN/H1: *Visibility of System Status* & NN/H6: *Recognition Rather than Recall*
- **Description & User Impact:**
  The screen presents two distinct primary actions: `auth.continue_google` ("Sign in with Google") and `auth.login` ("Log In"). However, tapping either triggers the exact same mock Google sign-in flow. Furthermore, returning registered users who click "Sign in with Google" are routed into `RoleSelectScreen` instead of taking them straight to `/feed`.
- **Recommended Remediation:**
  Check `provider.hasCompletedOnboarding` or user role persistence. If a returning user logs in, immediately redirect to `/feed`. If a new user signs in, route to `/role-select`. Combine redundant login/signup buttons into a clear "Continue with Google" button with sub-text "We will automatically find or create your account."

#### Issue A-02: Mandatory Guest Setup Blocks Exploration (Zero-Friction Guest Entry)
- **File:** `lib/features/auth/presentation/viewer_setup_screen.dart` (Lines 110–190)
- **Severity:** `P1 (High)`
- **Heuristic:** NN/H3: *User Control and Freedom*
- **Description & User Impact:**
  When a user taps "Explore as Guest", they are forced into `ViewerSetupScreen` where they must enter a name and pick an avatar. If the user only wants to see what streams are active in Al Khobar, this creates immediate friction and abandonment.
- **Recommended Remediation:**
  Add a prominent "Skip for now" / "Browse Anonymously" button in the top AppBar of `ViewerSetupScreen` which generates a random guest ID (e.g. `Guest #4192`) and immediately navigates to `/feed`.

#### Issue A-03: Role Selection Cognitive Asymmetry & Time Blindness
- **File:** `lib/features/auth/presentation/role_select_screen.dart` (Lines 60–160)
- **Severity:** `P2 (Medium)`
- **Heuristic:** NN/H10: *Help and Documentation*
- **Description & User Impact:**
  The "Viewer" card immediately completes onboarding, whereas "Broadcaster / Streamer" launches a rigorous 5-6 step verification wizard. Users are given no preview of what information will be required (national handle, photo, YouTube channel, university affiliation, GPS venue).
- **Recommended Remediation:**
  Add badge metadata to the Broadcaster card: `⏱️ ~2 min application • Requires YouTube channel & University affiliation`.

---

### 3.2 5-Step Broadcaster & Organization Application Wizard

```
┌────────────────────────────────────────────────────────────────────────┐
│                        WIZARD PROGRESSION                              │
│                                                                        │
│  [Step 1: Identity] ─► [Step 2: Media & Crop] ─► [Step 3: Professional] │
│                                                          │             │
│                     ┌────────────────────────────────────┘             │
│                     ├─► (If Org) ─► [Step 3.5: Speakers Roster]        │
│                     ▼                                                  │
│             [Step 4: Location & OSM] ─► [Step 5: Review & Submit]      │
└────────────────────────────────────────────────────────────────────────┘
```

#### Issue W-01: Dynamic Step Insertion Causes Progress Bar Reversal
- **File:** `lib/features/auth/presentation/streamer_apply_screen.dart` (Lines 80–140) & `apply_step_3_professional.dart`
- **Severity:** `P0 (Critical Blocker)`
- **Heuristic:** NN/H1: *Visibility of System Status*
- **Description & User Impact:**
  The total step count `_totalSteps` is dynamically calculated as `isOrganization ? 6 : 5`. When a user in Step 3 toggles the entity type from "Individual" to "Organization", the progress indicator suddenly drops (e.g., from 60% to 50%). When navigating backwards, step indices desynchronize.
- **Recommended Remediation:**
  Fix the wizard progress bar to reflect named structural milestones (e.g., `Identity → Media → Professional & Roster → Location → Review`) or smoothly animate the fraction indicator with explicit step labels (e.g., `"Step 3 of 6: Organization Roster"`).

#### Issue W-02: Aspect Ratio Mismatch in Image Cropper
- **File:** `lib/features/auth/presentation/widgets/image_arrange_modal.dart` (Lines 120–210) & `apply_step_2_media.dart`
- **Severity:** `P1 (High)`
- **Heuristic:** NN/H2: *Match between System and the Real World*
- **Description & User Impact:**
  The crop preview boundary uses a fixed height container (150dp), but banners on the Feed and Profile screen render in responsive 16:9 (`AspectRatio(aspectRatio: 16/9)`). Broadcasters crop their banners assuming the 150dp viewport, only to find the top and bottom severely cropped on wide devices.
- **Recommended Remediation:**
  Enforce a strict 16:9 aspect ratio mask overlay with semi-transparent rule-of-thirds grid guidelines inside `ImageArrangeModal`.

#### Issue W-03: Overly Restrictive YouTube Channel Validation
- **File:** `lib/features/auth/presentation/steps/apply_step_3_professional.dart` (Lines 180–230)
- **Severity:** `P1 (High)`
- **Heuristic:** NN/H5: *Error Prevention* & NN/H9: *Help Users Recognize Errors*
- **Description & User Impact:**
  The handle input field regex strictly demands `@username` or clean channel IDs. If an academic pastes their full browser URL (e.g. `https://www.youtube.com/@DrAhmedAlGhamdi` or `youtube.com/c/KFUPM_Official`), validation fails with a generic error toast.
- **Recommended Remediation:**
  Implement auto-sanitization:
  ```dart
  String sanitizeYouTubeHandle(String input) {
    var cleaned = input.trim();
    if (cleaned.contains('youtube.com/@')) {
      cleaned = cleaned.split('youtube.com/@').last;
    } else if (cleaned.startsWith('https://www.youtube.com/')) {
      cleaned = cleaned.replaceAll('https://www.youtube.com/', '');
    }
    if (!cleaned.startsWith('@') && !cleaned.startsWith('UC')) {
      cleaned = '@$cleaned';
    }
    return cleaned;
  }
  ```

#### Issue W-04: Location Picker OSM Pin Misses "Current Location" GPS FAB
- **File:** `lib/features/auth/presentation/widgets/location_picker_modal.dart` (Lines 100–180)
- **Severity:** `P1 (High)`
- **Heuristic:** NN/H7: *Flexibility and Efficiency of Use*
- **Description & User Impact:**
  The interactive FlutterMap modal opens centered on Al Khobar by default. An applicant located in Dammam or Dhahran must manually pan and zoom across tiles. There is no "Use My Current GPS Location" button.
- **Recommended Remediation:**
  Add a Floating Action Button with `Icons.my_location_rounded` that animates the map controller to the user's geolocated coordinates.

#### Issue W-05: Missing Jump-to-Edit Anchors on Final Review Card
- **File:** `lib/features/auth/presentation/steps/apply_step_5_review.dart` (Lines 90–220)
- **Severity:** `P1 (High)`
- **Heuristic:** NN/H3: *User Control and Freedom*
- **Description & User Impact:**
  The review screen displays sections for Identity, Media, Channel, and Venue. If an applicant spots an error in their Bio (Step 1), they have no direct "Edit" icon. They must press the wizard "Back" button 4 consecutive times, risking losing form state or triggering unnecessary validation.
- **Recommended Remediation:**
  Add an `[Edit]` button to each section card header on Step 5 that calls `pageController.animateToPage(stepIndex)`.

---

### 3.3 Main Experience & Discovery Feed

```
┌────────────────────────────────────────────────────────────────────────┐
│                        DISCOVERY FEED LAYOUT                           │
│                                                                        │
│  [ Search & Filter Bar ] ── [ Language Toggle ]                        │
│  [ Category Chips: All | Computer Science | Islamic | Medicine ... ]   │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ 🔴 HERO LIVE CAROUSEL (Active Streams with Live Viewer Badges)   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  ── Active Broadcasters Grid (2 Columns on Mobile / 4 on Desktop) ──   │
│  ┌──────────────────────────────┐    ┌──────────────────────────────┐  │
│  │ Streamer Card 1              │    │ Streamer Card 2              │  │
│  │ [16:9 Banner] [Live Badge]   │    │ [16:9 Banner]                │  │
│  │ [Avatar] [Name] [Verified]   │    │ [Avatar] [Name] [Org]        │  │
│  │ [Topic Tags] [Venue Location]│    │ [Topic Tags] [Venue Location]│  │
│  └──────────────────────────────┘    └──────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

#### Issue F-01: Low Contrast on Inactive Category Filter Chips
- **File:** `lib/features/discovery/presentation/discovery_feed_screen.dart` (Lines 220–290)
- **Severity:** `P2 (Medium)`
- **Heuristic:** WCAG 2.1 AA Contrast (1.4.3)
- **Description & User Impact:**
  Unselected category filter chips use `AppTheme.darkSurface1` with text color `#71717A` over `#121214` background. The measured contrast ratio is 3.8:1, falling below the 4.5:1 WCAG AA minimum threshold for normal text.
- **Recommended Remediation:**
  Increase inactive text color to `#A1A1AA` (Contrast 5.6:1) and add a subtle `0.8px` border `AppTheme.darkBorderSubtle`.

#### Issue F-02: Live Hero Carousel Audio-Only Waveform Indicator Missing
- **File:** `lib/features/discovery/presentation/discovery_feed_screen.dart` (Lines 340–420)
- **Severity:** `P2 (Medium)`
- **Heuristic:** NN/H1: *Visibility of System Status*
- **Description & User Impact:**
  When a live lecture is in "Audio-Only" mode (e.g. podcast lecture), the Hero carousel card displays a static microphone badge. Users often assume the stream has a broken video feed rather than recognizing an intentional audio broadcast.
- **Recommended Remediation:**
  Add a dynamic 3-bar animated audio equalizer waveform icon next to the "Audio Live" badge.

---

### 3.4 Spatial GIS Map & Venue Navigation

```
┌────────────────────────────────────────────────────────────────────────┐
│                        SPATIAL MAP VIEWPORT                            │
│                                                                        │
│  [ Top Bar: Full-Width Search + Language Toggle ]                      │
│  [ Row 2: City Selector (Al Khobar) | Academic Topic Dropdown ]        │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Map Canvas (CartoDB Dark Basemap + AlSharqia Polygon Outlines)  │  │
│  │                                                                  │  │
│  │       📍 [Avatar Marker]          🔴 [Live Pulsing Marker]       │  │
│  │                                                                  │  │
│  │                     ┌───────────────────────────────────┐        │  │
│  │                     │ Selected Streamer Summary Card    │        │  │
│  │                     │ [Avatar] Prof. Ahmed Al-Ghamdi    │        │  │
│  │                     │ [KFUPM Auditorium 24] [Directions]│        │  │
│  │                     └───────────────────────────────────┘        │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                           [ FAB: Recenter GPS ]        │
│                                           [ FAB: Broadcaster Drawer ]  │
└────────────────────────────────────────────────────────────────────────┘
```

#### Issue M-01: Summary Card Collision on Low-Resolution Mobile (360px)
- **File:** `lib/features/map/presentation/spatial_map_screen.dart` (Lines 450–475) & `marker_summary_card.dart`
- **Severity:** `P1 (High)`
- **Heuristic:** NN/H4: *Consistency and Standards*
- **Description & User Impact:**
  On mid-zoom levels, when a marker is selected, `MarkerSummaryCard` floats at the bottom (`left: 16, right: 76`). On narrow screens (width ≤ 360dp), the action buttons ("Watch Live" and "Directions") overflow or clip the right boundary.
- **Recommended Remediation:**
  Wrap the card's action row in a `FittedBox` or stack the action buttons vertically when `MediaQuery.of(context).size.width < 380`.

#### Issue M-02: External Map URL Native Intent Integration
- **File:** `lib/features/map/presentation/widgets/venue_navigation_sheet.dart` (Lines 390–440)
- **Severity:** `P1 (High)`
- **Heuristic:** NN/H2: *Match between System and the Real World*
- **Description & User Impact:**
  Tapping "Open in Maps" in `VenueNavigationSheet` copies the Google Maps URL to the clipboard and shows a SnackBar toast. The user must manually leave the app, open their browser, and paste the URL.
- **Recommended Remediation:**
  Use `url_launcher` with `LaunchMode.externalApplication` (or `geo:` intent uri) to open Google Maps or Apple Maps natively with one tap.

---

### 3.5 Broadcaster Profile & Multi-Tenant Organization Management

#### Issue P-01: Organization Speaker Filter Reset State
- **File:** `lib/features/profile/presentation/broadcaster_profile_screen.dart` (Lines 770–805)
- **Severity:** `P2 (Medium)`
- **Heuristic:** NN/H1: *Visibility of System Status*
- **Description & User Impact:**
  In an Organization profile, tapping an affiliated speaker chip filters the VOD and Playlist archive below. However, there is no explicit "Clear Speaker Filter" pill displayed above the VOD grid, leaving users unaware of why fewer lectures are listed.
- **Recommended Remediation:**
  Display an active filter chip above the TabBar: `Showing lectures by: Dr. Faisal Al-Otaibi ✕`.

#### Issue P-02: Join Organization Flow Missing From Public Broadcaster Settings
- **File:** `lib/features/profile/presentation/settings_screen.dart` (Lines 560–630)
- **Severity:** `P2 (Medium)`
- **Heuristic:** NN/H7: *Flexibility and Efficiency of Use*
- **Description & User Impact:**
  Individual broadcasters can only discover the "Join an Organization" sheet from another broadcaster's profile card (`broadcaster_profile_screen.dart:508`). It is absent from their personal Settings and Application hub.
- **Recommended Remediation:**
  Add a "Request Organization Affiliation" card in `SettingsScreen` under the Broadcaster Management section.

---

### 3.6 Live Broadcast Studio & RTMP Pitch Controls

#### Issue L-01: Mini-Player PiP Docking Collision with Bottom Navigation Bar
- **File:** `lib/core/routing/app_router.dart` (Lines 380–430) & `live_broadcast_screen.dart`
- **Severity:** `P0 (Critical Blocker)`
- **Heuristic:** NN/H4: *Consistency and Standards* & NN/H7: *Flexibility and Efficiency*
- **Description & User Impact:**
  When a user minimizes a live broadcast to PIP mini-player (`launchMiniPlayer`), the floating box docks at `bottom: 16, right: 16`. On mobile devices, this sits directly on top of the `BottomNavigationBar` (or the rightmost "Settings" icon), preventing users from navigating tabs while watching.
- **Recommended Remediation:**
  Calculate dynamic bottom padding based on navigation bar height:
  ```dart
  bottom: isDesktop ? 20.0 : kBottomNavigationBarHeight + 16.0 + MediaQuery.of(context).padding.bottom
  ```

#### Issue L-02: RTMP IP Presets Hardcoded for Localhost
- **File:** `lib/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart` (Lines 35–42)
- **Severity:** `P2 (Medium)`
- **Heuristic:** NN/H5: *Error Prevention*
- **Description & User Impact:**
  The IP presets chip list includes `127.0.0.1`, which fails on physical Android/iOS devices trying to connect to a host laptop running OBS.
- **Recommended Remediation:**
  Add an explanation subtitle: `"For physical mobile devices, enter your laptop's Wi-Fi IPv4 address (e.g. 192.168.1.X) instead of 127.0.0.1."`

---

## 4. Cross-Cutting Usability & Ergonomics Analysis

### 4.1 Touch Targets & Minimum Bounding Box (WCAG 2.1 AA — 2.5.5)
The platform generally maintains generous touch padding, but several critical interactive elements fall below the 44×44dp / 48×48dp threshold:

```
┌──────────────────────────────────────┬──────────────┬──────────────┬──────────────┐
│ UI Element & Screen Location         │ Actual Size  │ Standard Req │ Status       │
├──────────────────────────────────────┼──────────────┼──────────────┼──────────────┤
│ Close icon button in Modal Cards     │ 28 × 28 dp   │ 44 × 44 dp   │ ❌ Non-Compl │
│ Language Switcher Pill in Top Bar    │ 62 × 30 dp   │ 44 dp height │ ⚠️ Marginal  │
│ Live Chat Reactions FAB Icons        │ 32 × 32 dp   │ 44 × 44 dp   │ ❌ Non-Compl │
│ Speaker Permission Tag Remove Button │ 22 × 22 dp   │ 44 × 44 dp   │ ❌ Non-Compl │
│ Floating Recenter Map Button         │ 44 × 44 dp   │ 44 × 44 dp   │ ✅ Compliant │
│ Primary Onboarding Buttons           │ 100% × 48 dp │ 48 × 48 dp   │ ✅ Compliant │
└──────────────────────────────────────┴──────────────┴──────────────┴──────────────┘
```

### 4.2 RTL Bi-directional Ergonomics (Arabic Locale Fidelity)
1. **Letter Spacing Integrity:** The Arabic font `Tajawal` is correctly configured with `letterSpacing: 0.0` in `app_theme.dart` (preventing disconnected Arabic glyph ligatures).
2. **Icon Mirroring:** Directional chevrons and back arrows correctly mirror in RTL. However, the Google "G" logo and external deep-link icons in `welcome_screen.dart` and `venue_navigation_sheet.dart` require explicit `Directionality` wrapping to avoid improper flipping.

### 4.3 Mobile Viewport Responsiveness (360px – 414px)
1. **Search Bar Row in Spatial Map:** On 360dp width screens (e.g. Galaxy A series), the Top Search Bar + Language Toggle + City Dropdown + Topic Dropdown occupy 132dp of vertical screen space, occluding ~22% of the map viewport. Collapsing Row 2 into a single unified filter row on mobile frees up 48dp of valuable map canvas.

---

## 5. Prioritized Action Plan & Implementation Roadmap

```
┌────────────────────────────────────────────────────────────────────────┐
│                     IMPLEMENTATION TIMELINE                            │
│                                                                        │
│  [PHASE 1: P0 BLOCKERS]  ──► Mini-Player PIP Docking Inset             │
│                              Wizard Step Counter Invariance            │
│                                                                        │
│  [PHASE 2: P1 HIGH-IMPACT] ──► Direct Native Maps Launch               │
│                                Jump-to-Edit Anchors in Step 5          │
│                                Zero-Friction Guest Mode                │
│                                Aspect-Ratio 16:9 Cropper Mask          │
│                                                                        │
│  [PHASE 3: P2 POLISH]    ──► Sub-44dp Touch Target Enlargement         │
│                              Inactive Category Chip Contrast Boost     │
│                              Audio Equalizer Waveform Micro-Anim       │
└────────────────────────────────────────────────────────────────────────┘
```

### Phase 1: P0 Immediate Blockers (Sprint 1)
- [ ] **Fix Global Mini-Player PIP Safe Area Docking:** Adjust `bottom` inset in `app_router.dart` to clear `BottomNavigationBar` on mobile viewports.
- [ ] **Stabilize Application Wizard Step Progression:** Ensure `streamer_apply_screen.dart` does not desynchronize step count indices when switching between Scholar and Organization modes.

### Phase 2: P1 High-Impact Ergonomic Fixes (Sprint 2)
- [ ] **Implement Zero-Friction Guest Entry:** Add "Browse Anonymously" action to `viewer_setup_screen.dart`.
- [ ] **Add Jump-to-Edit Anchors on Review Screen:** Provide direct page navigation buttons next to each section in `apply_step_5_review.dart`.
- [ ] **Enforce 16:9 Crop Mask in Image Arrange Modal:** Ensure uploaded banners perfectly match the display aspect ratio across feed and profile headers.
- [ ] **Launch Native Navigation Intents:** Replace clipboard copy in `venue_navigation_sheet.dart` with direct external map launching.
- [ ] **Sanitize YouTube Handle Inputs:** Automatically parse pasted channel URLs into valid handles.

### Phase 3: P2 Visual Polish & Micro-Interactions (Sprint 3)
- [ ] **Boost Category Filter Chip Contrast:** Increase text contrast on unselected pills from `#71717A` to `#A1A1AA`.
- [ ] **Add Audio Waveform Equalizer:** Display animated visual pulses for audio-only live streams in the hero carousel.
- [ ] **Enlarge Sub-44dp Touch Targets:** Wrap modal close buttons and chat reaction FABs with minimum `BoxConstraints(minWidth: 44, minHeight: 44)`.
- [ ] **Display Active Speaker Filter Clear Pill:** In `broadcaster_profile_screen.dart`, render an explicit dismissible filter tag above the VOD list.

---

## 6. Conclusion
The **Streamer App** has established a state-of-the-art foundation combining live video infrastructure, multi-speaker stage logic, and spatial campus exploration. By executing this prioritized UX action plan, the platform will eliminate its remaining cognitive friction points, achieve WCAG AA compliance, and deliver an intuitive, world-class educational experience for academic communities across Saudi Arabia.
