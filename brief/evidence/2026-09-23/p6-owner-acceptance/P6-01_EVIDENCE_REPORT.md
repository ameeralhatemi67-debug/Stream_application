# P6-01 Verification & Evidence Report: Admin Hub Layout, RTL & Responsiveness

**Date:** 2026-09-23  
**Status:** **PASSED WITH NOTED DEFECTS** (Core layout, role guards, and localization switching pass; 4 mobile layout overflows and untranslated admin keys identified)  
**Devices Tested:** Chrome Desktop (Master Admin), Android Physical Phone (`R5CY42JAW4E`), Incognito/Secondary Chrome (Viewer & Visitor)

---

## 1. Test Execution Summary

| Checkpoint | Expected Behavior | Actual Behavior | Result |
| :--- | :--- | :--- | :---: |
| **Desktop Nav** | Side navigation on left at desktop width | Confirmed sidebar navigation on left | **PASS** |
| **Honest Analytics** | Unmeasured KPIs display "Unavailable" | Displayed "Unavailable" for Active Viewers & Auditorium Seats | **PASS** |
| **RTL Switcher** | Arabic toggle mirrors layout and translates | UI flipped to RTL, Arabic translations applied | **PASS** |
| **Persistence** | F5 reload retains chosen language | Language choice persisted across F5 hard reloads | **PASS** |
| **Direct Route Guard** | `/admin` direct URL access denied for non-admin | Non-admin redirected away; admin page does not open | **PASS** |
| **Settings Access** | Admin link visible only to authorized accounts | Admin sees Admin Hub in Settings; non-admin cannot see it | **PASS** |
| **Session Isolation** | Copying URL into a new window opens as visitor | Opened as unauthenticated visitor | **PASS** |

---

## 2. Screenshot Catalog & Image Analysis

All screenshots located in `brief/evidence/2026-09-23/p6-owner-acceptance/screenshots/` have been analyzed and renamed with standardized identifiers:

### A. Verified Functionality (`screenshots/good/`)

1. **`P6-01-admin-desktop-en.png`** (formerly `Screenshot 2026-09-23 201708.png`)
   * **View:** Admin Hub (English, Desktop width).
   * **Verification:** Confirms desktop sidebar navigation, honest "Unavailable" status for unmeasured KPIs, Quick Actions, and language switcher ("عربي") in top app bar.
2. **`P6-01-admin-desktop-en-overview.png`** (formerly `Screenshot 2026-09-23 201738.png`)
   * **View:** Admin Hub Overview & Verification Queue sidebar tab active.
   * **Verification:** Confirms active tab highlighting and unmeasured metrics contract compliance.

---

### B. Mobile Layout Overflows (`screenshots/issue/`)

1. **`P6-01-mobile-verification-queue-overflow-51px.jpg`** (formerly `Screenshot_20260923_202312_Hadayah Live.jpg`)
   * **Symptom:** **"RIGHT OVERFLOWED BY 51 PIXELS"** hazard stripe on the filter chip row.
   * **Code Location:** `lib/features/admin/presentation/admin_hub_screen.dart` (lines ~835–877).
   * **Root Cause:** A non-scrollable horizontal `Row` containing a `TextField` search bar, 4 filter chips (`All`, `Pending`, `Approved`, `Rejected`), and a refresh `IconButton` exceeds the mobile screen width (~360–400px).
   * **Remediation:** Wrap the chips in a horizontally scrollable container (`SingleChildScrollView(scrollDirection: Axis.horizontal)`) or wrap in a column on narrow widths (`LayoutBuilder`).

2. **`P6-01-mobile-broadcasters-card-overflow-133px.jpg`** (formerly `Screenshot_20260923_202322_Hadayah Live.jpg`)
   * **Symptom:** **"RIGHT OVERFLOWED BY 133 PIXELS"** text across avatar and card.
   * **Code Location:** `lib/features/admin/presentation/admin_hub_screen.dart` (lines ~1950–2060).
   * **Root Cause:** The broadcaster item row places avatar + details + OFFLINE status badge + map switch toggle + edit icon + delete icon in a single unconstrained `Row` (>500px wide).
   * **Remediation:** Move the moderation controls (switch toggle, edit, delete) to a secondary row below the broadcaster details on mobile screens.

3. **`P6-01-mobile-terms-overflow-77px-cramped.jpg`** (formerly `Screenshot_20260923_202443_Hadayah Live.jpg`)
   * **Symptom:** **"RIGHT OVERFLOWED BY 77 PIXELS"** on the header row; cramped side-by-side text areas.
   * **Code Location:** `lib/features/admin/presentation/admin_hub_screen.dart` (lines ~2215–2295).
   * **Root Cause:**
     1. Header `Row` contains title "Governance & Terms" and button "Save Terms & Conditions", overflowing by 77px.
     2. Markdown editors place "English Content" and "Arabic Content" side-by-side in a `Row` with two `Expanded` columns. On mobile screens, each text field gets ~150px, making markdown editing nearly unreadable.
   * **Remediation:** Stack the English and Arabic markdown editors vertically on narrow widths; use a flexible or wrapped header row.

---

### C. Localization & Minor Issues (`screenshots/small_edit/`)

1. **`P6-01-mobile-categories-overflow-1.5px.jpg`** (formerly `Screenshot_20260923_202342_Hadayah Live.jpg`)
   * **Symptom:** **"OVERFLOWED BY 1.5 PIXELS"** on the Academic Categories header row.
   * **Code Location:** Academic Categories tab header.
   * **Root Cause:** Title + "+ Add Category" button exceeds narrow mobile width by 1.5px.
   * **Remediation:** Adjust padding or replace button with a compact icon button on mobile.

2. **`P6-01-admin-roles-ar-untranslated.png`** (formerly `Screenshot 2026-09-23 201914.png`)
   * **Symptom:** Untranslated English strings and raw database snake_case keys in Arabic mode:
     * Search input placeholder: `...Account email` (untranslated).
     * Section headers: `"Master Admins"`, `"Admins"`, `"Permitted Admins (Org Owners & Co-Owners)"`.
     * Empty state strings: `".No Admins yet"`, `".No organization owners yet"`.
     * Raw capability keys: `manage_admins`, `moderate_chat_platform_wide`, `edit_terms`.
     * Role badge: `"Master Admin"`.
     * Language switcher button partially clipped on far left in RTL.
   * **Remediation:** Add Arabic dictionary keys in `assets/i18n/ar.json` and map permission flags to user-friendly translated labels.

3. **`P6-01-admin-chat-mod-ar-untranslated.png`** (formerly `Screenshot 2026-09-23 201931.png`)
   * **Symptom:** English metadata labels in Arabic Chat Moderation view:
     * Search bar placeholder: `...Search by sender, reporter, stream, or reason`.
     * Card labels: `"Reported:"`, `"Reason:"`, `"Reported by"`, `"Stream:"`.
   * **Remediation:** Replace hardcoded string interpolations with `.tr()` calls mapped in `en.json` and `ar.json`.

---

## 3. Investigation of Terminal Errors & Operational Observations

### A. White Screen on New Tab / Window (`http://localhost:7357/#/feed`)
* **Observed:** Opening a new tab with `http://localhost:7357/#/feed` occasionally remains blank white.
* **Analysis:**
  1. This is **not** an account revocation or "Sign out other devices" lockout. The device session check (`initDeviceSession()`) only triggers *after* Flutter initializes and authenticates.
  2. In Flutter Web development mode (`flutter run -d chrome`), opening a fresh browser window requires Chrome to re-download the CanvasKit engine, WebAssembly runtime, and application bundle from the local development server. During this compile/transfer window, Flutter displays an unstyled white canvas.
  3. If an unauthenticated user opens `/#/feed` directly, `app_router.dart` redirects them to `initialLocation: '/splash'`, which runs a 1.35s timer before navigating to `/welcome`. If CanvasKit hangs or DevTools paused on an unhandled resource, the canvas stays blank.

### B. NetworkImageLoadException: HTTP 429 (`lh3.googleusercontent.com`)
* **Observed:**
  ```text
  NetworkImageLoadException: HTTP request failed, statusCode: 429
  https://lh3.googleusercontent.com/a/ACg8ocIwVR2L-UqX1CFgSpRzPJuY8KDZLS7f2eY0YK_jHmgdb1Ghvw=s96-c
  ```
* **Analysis:**
  * Google User Content enforces rate limits when rapid Flutter hot-reloads or multi-tab web instances request the user's avatar image repeatedly.
  * In Flutter, an unhandled image load error throws `NetworkImageLoadException` to the console.
  * **Fix:** Ensure avatar widgets specify `errorBuilder` on `Image.network` or provide a fallback initial avatar when the network request returns a non-200 status code.

### C. Windows Desktop Build Failure: `permission_handler_windows`
* **Observed:**
  ```text
  error C2338: static assertion failed: 'error STL1011: The /await compiler option, <experimental/coroutine>, <experimental/generator>, and <experimental/resumable> are deprecated by Microsoft and will be REMOVED SOON... You can define _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS to suppress this error for now.'
  ```
* **Analysis:**
  * The local Visual Studio compiler (MSVC `14.51.36231`) treats deprecated experimental coroutines in `permission_handler_windows` as fatal compilation errors.
  * P6 acceptance sheet §3 specifically anticipated this: *"Windows is for layout and navigation observation here. Use Chrome for the Master Admin Google flow... If windows is unavailable, record it as not run and continue with Chrome."*
  * **Fix:** When building for Windows, pass `/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` in `windows/runner/CMakeLists.txt` or rely on Chrome for administrative web verification.

### D. Role Selection & Onboarding Prompt Inconsistency ("Visitor vs Streamer")
* **Observed Symptom:**
  * Sometimes when opening the app with an existing signed-in account, the app presents the prompt: *"Do you want to be a visitor or streamer?"* (`/role-select`).
  * Other times when signing in with a fresh new account, the prompt does not appear, routing directly into Discovery feed.
* **Code Trace & Root Cause:**
  1. In `lib/core/providers/app_provider.dart` (lines 616–617, 780–789), `_hasCompletedRoleSelection` is an **ephemeral in-memory boolean** initialized to `false` in RAM:
     ```dart
     bool _hasCompletedRoleSelection = false;
     ```
     It is **never persisted** to `SharedPreferences` or synchronized to the Supabase `profiles` table.
  2. Every time the app boots, reloads (F5), or is restarted on mobile, `_hasCompletedRoleSelection` resets to `false`.
  3. In `lib/core/routing/app_router.dart` (lines 78–82 & 96–99):
     ```dart
     if (!provider.hasCompletedRoleSelection && !provider.isApprovedStreamer) {
       return '/role-select';
     }
     ```
     * For existing accounts where `isApprovedStreamer` is `false` (regular viewers), every page refresh or app restart triggers this condition, forcing them to re-select their role.
     * For newly registered accounts, asynchronous latency between Google OAuth token creation and `_applySessionUser()` profile fetching can cause race conditions where the router evaluates before or after role state is set.
* **Remediation Plan:**
  * Persist `hasCompletedRoleSelection` in `SharedPreferences` keyed to the user ID: `_prefs.setBool('has_completed_role_selection_${userId}', true)`.
  * Ensure router gates check the persisted preference rather than an uninitialized in-memory variable.

---

## 4. Next Step in Acceptance Run

Now that P6-01 visual and navigation checks are thoroughly documented and cataloged:

* **Proceed to Test 2: P6-06 (Keyword Manager & Platform Audit)**
  1. Add a disposable test keyword with match mode "Anywhere in text".
  2. Verify rejection when attempting to send the keyword.
  3. Remove the keyword and verify messages can be sent again.
  4. Inspect the Audit Log in Admin Hub and verify the action filter works.
