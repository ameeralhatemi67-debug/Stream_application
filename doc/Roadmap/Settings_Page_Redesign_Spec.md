# Settings & Preferences Page Redesign — Feature Specification

This document details the complete redesign of the **Settings & Preferences Screen** (`settings_screen.dart`), structuring it into a modern, modular, role-aware hub with rich profile headers, dedicated sub-sheets, smooth navigation, and centralized `Language.svg` integration.

---

## 1. Executive Summary & Screen Layout Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  [ ← Back to Map ]        Settings & Preferences          [ 🌐 Language.svg] │  ◄── Top AppBar (Uses Language.svg)
└─────────────────────────────────────────────────────────────────────────────┘
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │   [ STREAMER PROFILE CARD / VIEWER SIMPLE CARD ]                      │  │
│  │                                                                       │  │
│  │   ┌────────────────────────────────────────────────────────────────┐  │  │
│  │   │  Banner Image (Top 1/3 Height)                                 │  │  │
│  │   └───────────────────────────────┬────────────────────────────────┘  │  │
│  │             [ Avatar + ✔️ Badge ]  │ Overlapping cut-line               │  │
│  │   Name: Amir Al-Hatemi                                                │  │
│  │   Handle: @apop8091  •  Institution: Multimedia University            │  │
│  │   Email: user@example.com                                             │  │
│  │   Description: "I like to build applications and software with AI..." │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  [ ✏️ Edit Account Profile ]  ──► Opens Full Verification Wizard in Edit Mode│
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  [ 📡 Streamer Mode Active ]                         [ Toggle Switch ] │  │  ◄── Streamer Only
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  [ 🎓 Become a Verified Broadcaster / Status ]         [ Apply/Status] │  │  ◄── Viewer / Applicant
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  [ 🔑 Sign In / Log In with Google ]                     [ Sign In ]   │  │  ◄── Viewer / Guest Only
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  [ 🔄 Switch Account / Open Welcome & Onboarding ]       [ Re-open ]   │  │  ◄── Streamer Only
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  [ 🔔 Notification Preferences ]                                  [ > ]│  │  ◄── Opens Notification Sheet
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  [ 🎬 Broadcaster & Studio Preferences ]                          [ > ]│  │  ◄── Streamer Only
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Platform Governance & Policies:                                      │  │
│  │  • [ 📄 Terms of Service ]                                        [ > ]│  │
│  │  • [ 🛡️ Broadcaster Code of Conduct ]                              [ > ]│  │  ◄── 3-Row Container
│  │  • [ 🔒 Privacy Policy (Saudi PDPL Compliant) ]                   [ > ]│  │      (Paging < > Reader)
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Account & Privacy:                                                   │  │
│  │  • [ 📥 Download My Data ] (PDPL Export)                              │  │
│  │  • [ 🚪 Sign Out / Log Out ]                                          │  │
│  │  • [ 🗑️ Delete My Account ]                                           │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  [ ℹ️ About App & Platform ]                                          │  │
│  │  Version: 2.0.0  •  Region: Eastern Province, KSA  •  Status: 🟢 OK   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Detailed Component Specifications

### A. Top Navigation Bar & Centralized Language Icon
* **Back Button:** Intelligent navigation (`context.canPop() ? context.pop() : context.go('/')`).
* **Title:** Localized *"Settings & Preferences"* / *"الإعدادات والتفضيلات"*.
* **Language Switcher Icon (`LanguageSwitcher`):**
  - Update [`lib/core/widgets/language_switcher.dart`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/lib/core/widgets/language_switcher.dart) to render [`assets/Language.svg`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/project/assets/Language.svg) via `SvgPicture.asset`.
  - Automatically upgrades language toggles across the entire app (`WelcomeScreen`, `DiscoveryFeedScreen`, `SpatialMapScreen`, `BroadcasterProfileScreen`, `LiveBroadcastScreen`, and `SettingsScreen`).

---

### B. User / Streamer Dynamic Header Card

#### 1. When User is a Viewer:
* A compact, elegant card:
  - User Avatar on left.
  - User Name & Email.
  - `[ 👤 Viewer / Student ]` badge.

#### 2. When User is an Approved Broadcaster:
* **Banner Image:** Top 1/3 of the card height (`SafeImageProvider` loading banner URL with fallback gradient).
* **Avatar & Verification Badge:**
  - Avatar positioned centrally, overlapping the cut-line between the banner and body.
  - Verification checkmark badge (`Icons.verified_rounded`) positioned on the top-right of the avatar ring.
* **Streamer Details:**
  - Full Name (e.g. *Amir Al-Hatemi*).
  - Public Handle (e.g. `@apop8091`).
  - Academic / Professional Institution (e.g. *Multimedia University Graduate*).
  - Contact Email.
  - Multiline Bio / Research Description.

#### 3. Edit Account Profile Action:
* Located right below the card: `[ ✏️ Edit Account Profile ]`.
* **Action:** Opens the **5-Step Streamer Verification Wizard in Edit Mode** (`BroadcasterApplicationSheet`):
  - Step 1: Identity & Legal Full Name
  - Step 2: Media (Profile Avatar & Banner Image Upload)
  - Step 3: Professional Info, YouTube Channel & Handle
  - Step 4: Content Tags & Academic Categories
  - Step 5: Campus Location & Admin Contact

---

### C. Account Onboarding & Authentication Toggles

1. **For Viewers / Guests:**
   - Shows **`[ 🔑 Sign In / Log In with Google ]`** tile/button allowing unauthenticated viewers to authenticate and link their account.
2. **For Streamers:**
   - Shows **`[ 🔄 Switch Account / Open Welcome & Onboarding ]`** allowing broadcasters to re-open the onboarding wizard or switch their active Google account.

---

### D. Role-Aware Experience Toggles & Verification

1. **Streamer Mode Active Switch:** Visible **ONLY** for approved broadcasters (`isLoggedInStreamer == true`).
2. **Broadcaster Verification Status:**
   - **For Viewers:** Displays *"Become a Verified Broadcaster / Register Organization"* with `[ Apply for Verification ]` button.
   - **For Pending Applicants:** Displays *"Application Pending Review"* with an amber status pill.
   - **For Approved Broadcasters:** Displays *"Verified Broadcaster"* with green status badge.

---

### E. Dedicated Sub-Sheets

1. **`[ 🔔 Notification Preferences ] >`**:
   - Opens a dedicated sheet with the 10-minute alert limit slider and active notification categories.
2. **`[ 🎬 Broadcaster & Studio Preferences ] >` (Streamer Only):**
   - Opens a dedicated sheet to configure Default Streaming Quality, Default Broadcast Format, Default Stream Privacy, and Ingest keys.

---

### F. Platform Governance & Legal Policies (Paging Reader)
* 3-row grouped card:
  1. `[ 📄 Terms of Service ] >`
  2. `[ 🛡️ Broadcaster Code of Conduct & Guidelines ] >`
  3. `[ 🔒 Privacy Policy (Saudi PDPL Compliant) ] >`
* Tapping any document opens the full-screen reader view with **`< Previous Document`** and **`Next Document >`** buttons at the bottom to smoothly navigate between all 3 policies!

---

### G. Account & Data Management
1. **`[ 📥 Download My Data ]`**: PDPL user data export.
2. **`[ 🚪 Sign Out / Log Out ]`**: Logs out and resets local session state.
3. **`[ 🗑️ Delete My Account ]`**: Opens deletion confirmation modal.

---

### H. About App & Platform Info
* Compact footer showing App Version (`2.0.0`), Target Region (`Eastern Province, KSA`), and System Status (`🟢 All Services Operational`).

---

## 3. Implementation Plan & File Scope

1. **`lib/core/widgets/language_switcher.dart`**
   - Replace `Icons.language_rounded` with `SvgPicture.asset('assets/Language.svg')`.
2. **`lib/features/profile/presentation/settings_screen.dart`**
   - Implement the complete modular redesign with dynamic Viewer vs. Streamer cards.
   - Add Viewer "Sign In / Log In" and Streamer "Switch Account / Welcome Onboarding".
   - Connect sub-sheets for Notifications and Streamer Preferences.
   - Connect the 3-document reader with `< Previous` and `Next >` navigation.
3. **`lib/features/profile/presentation/widgets/legal_document_reader_screen.dart`** *(NEW)*
   - Paging document viewer for Terms of Service, Code of Conduct, and Privacy Policy.
4. **`test/settings_screen_test.dart`** *(NEW)*
   - Test viewer vs. streamer card rendering, mode toggle visibility, notification sheet launch, and legal document pagination.
