# UI/UX, Localization & Safety Specialist: Comprehensive Test Checklist

**Owner:** UI/UX, Localization & Safety Specialist  
**Project:** Educational Cloud Streaming Application  
**Target Module:** Version 0.1 & Version 0.2 Checkpoints  
**File Location:** [`team/testAndErrors/ui_ux_specialist_tests.md`](file:///c:/Users/User/Documents/Obsidian/projects/Streamer_app/project/team/testAndErrors/ui_ux_specialist_tests.md)

---

## 1. Unit Tests

### 1.1 AppTheme Color Token Integrity
- [ ] **[TC-UT-01]** Verify `AppTheme.darkBgBase` equals `#0E0E10`.
- [ ] **[TC-UT-02]** Verify `AppTheme.darkSurface1` equals `#161619`, `darkSurface2` equals `#202024`, and `darkSurface3` equals `#2A2A30`.
- [ ] **[TC-UT-03]** Verify text contrast tokens: `textPrimaryDark` (`#FFFFFF`), `textSecondaryDark` (`#A1A1AA`), `textMutedDark` (`#71717A`).
- [ ] **[TC-UT-04]** Verify feature accent tokens: `accentRed` (`#FF8080`), `accentGreen` (`#87DE87`), `accentBlue` (`#5FBCD3`), `accentPurple` (`#BC5FD3`).

### 1.2 Localization Dictionary Key Symmetry (`en.json` vs `ar.json`)
- [ ] **[TC-UT-05]** Verify all top-level keys in `en.json` (`app`, `nav`, `map`, `feed`, `profile`, `live`, `safety`, `language`) exist in `ar.json`.
- [ ] **[TC-UT-06]** Verify zero missing translation values or null string returns in both English and Arabic dictionaries.
- [ ] **[TC-UT-07]** Verify safety modal translation keys `safety.modal_title`, `safety.modal_body`, `safety.got_it` produce valid non-empty copy in both locales.

---

## 2. Widget Tests

### 2.1 `LanguageSwitcher` Widget
- [ ] **[TC-WT-01]** Render `LanguageSwitcher` in English locale (`en`): Verify label reads `عربي` and globe icon is displayed.
- [ ] **[TC-WT-02]** Render `LanguageSwitcher` in Arabic locale (`ar`): Verify label reads `EN` and globe icon is displayed.
- [ ] **[TC-WT-03]** Tap `LanguageSwitcher` in English mode: Verify `EasyLocalization.of(context).setLocale(Locale('ar'))` is called.
- [ ] **[TC-WT-04]** Tap `LanguageSwitcher` in Arabic mode: Verify `EasyLocalization.of(context).setLocale(Locale('en'))` is called.

### 2.2 `FeatureInProgressModal` Widget
- [ ] **[TC-WT-05]** Call `FeatureInProgressModal.show(context)`: Verify bottom sheet renders with Level 3 surface (`#2A2A30`).
- [ ] **[TC-WT-06]** Verify construction icon (`Icons.construction_rounded`) is rendered inside Accent Blue container.
- [ ] **[TC-WT-07]** Verify localized title and body text are displayed correctly based on active locale.
- [ ] **[TC-WT-08]** Tap `safety.got_it` button: Verify modal bottom sheet pops cleanly from navigator stack.

---

## 3. Layout Direction & RTL Mirroring Tests

### 3.1 Text Alignment & Directionality
- [ ] **[TC-RTL-01]** Switch to Arabic (`ar`): Verify `Directionality.of(context)` returns `TextDirection.rtl`.
- [ ] **[TC-RTL-02]** Switch to English (`en`): Verify `Directionality.of(context)` returns `TextDirection.ltr`.
- [ ] **[TC-RTL-03]** Verify text headers align to Right in RTL and Left in LTR across all screens.
- [ ] **[TC-RTL-04]** Verify AppBar back button arrow automatically mirrors (`Icons.arrow_back` points Right in RTL, Left in LTR).

### 3.2 Typography & Font Binding
- [ ] **[TC-RTL-05]** Verify Arabic text renders using **Tajawal** font family.
- [ ] **[TC-RTL-06]** Verify English text renders using **Inter** font family.
- [ ] **[TC-RTL-07]** Verify no text overflow / clipping occurs on 320px width screens when switching between long Arabic and English string keys.

---

## 4. Integration & Placeholder Safety Tests

### 4.1 Unbuilt Feature Trigger Safety
- [ ] **[TC-INT-01]** Tap Settings icon in Spatial Map screen: Verify `FeatureInProgressModal` opens.
- [ ] **[TC-INT-02]** Tap Advanced Filters icon in Discovery Feed screen: Verify `FeatureInProgressModal` opens.
- [ ] **[TC-INT-03]** Tap Bookmarks icon in top app bar: Verify `FeatureInProgressModal` opens.
- [ ] **[TC-INT-04]** Tap Follow Channel button in Broadcaster Profile screen: Verify `FeatureInProgressModal` opens.
- [ ] **[TC-INT-05]** Tap Set Reminder button in Broadcaster Profile screen: Verify `FeatureInProgressModal` opens.
- [ ] **[TC-INT-06]** Tap Audio Only button in Live Broadcast screen: Verify `FeatureInProgressModal` opens.
- [ ] **[TC-INT-07]** Tap Quality button in Live Broadcast screen: Verify `FeatureInProgressModal` opens.
- [ ] **[TC-INT-08]** Tap Report Stream button in Live Broadcast screen: Verify `FeatureInProgressModal` opens.

---

## 5. Visual Design & Contrast Compliance Tests

- [ ] **[TC-DES-01]** Verify Primary Text (`#FFFFFF`) against Level 0 Background (`#0E0E10`) achieves contrast ratio >= 15:1 (WCAG AAA standard).
- [ ] **[TC-DES-02]** Verify Secondary Text (`#A1A1AA`) against Level 1 Surface (`#161619`) achieves contrast ratio >= 5.5:1 (WCAG AA standard).
- [ ] **[TC-DES-03]** Verify 4px grid spacing scale (`spaceXs: 4`, `spaceSm: 8`, `spaceMd: 12`, `spaceLg: 16`, `spaceXl: 24`, `space2Xl: 32`) is strictly respected across all custom cards and padding.
- [ ] **[TC-DES-04]** Verify border radii scale (`radiusXs: 4`, `radiusSm: 8`, `radiusMd: 12`, `radiusLg: 16`) is consistently applied to chips, buttons, cards, and modals.

---

## 6. Version 0.2 Checkpoint 2.1 & 2.2 Test Suite

### 6.1 `DiscoveryFeedScreen` Responsive Grid & Real-time Search
- [ ] **[TC-FEED-01]** View `DiscoveryFeedScreen` on mobile screen width <= 600px: Verify grid renders 2 columns (`crossAxisCount == 2`).
- [ ] **[TC-FEED-02]** View `DiscoveryFeedScreen` on tablet screen width > 600px: Verify grid renders 3 columns (`crossAxisCount == 3`).
- [ ] **[TC-FEED-03]** Tap Category Chip "Computer Science & AI": Verify `AppProvider.currentCategoryFilter` updates to `'cs_tech'` and grid filters to matching streamers.
- [ ] **[TC-FEED-04]** Tap Category Chip "Islamic Studies": Verify grid filters to Sheikh Dr. Omar Al-Dossary (`categoryId == 'islamic_studies'`).
- [ ] **[TC-FEED-05]** Type "Al-Ghamdi" into Search Field: Verify real-time list updates dynamically to show only matching lecturer card.
- [ ] **[TC-FEED-06]** Type nonexistent query "XYZ99": Verify empty state container displays `feed.no_results` message and "Reset Filters" button.
- [ ] **[TC-FEED-07]** Tap "Reset Filters" button in empty state: Verify search bar clears and category filter resets to 'all'.

### 6.2 `BroadcasterProfileScreen` & Collapsible Header
- [ ] **[TC-PROF-01]** Open `/profile/prof_alghamdi_01`: Verify collapsible `SliverAppBar` displays banner image and gradient overlay.
- [ ] **[TC-PROF-02]** Scroll profile down: Verify `SliverAppBar` collapses cleanly and displays pinned broadcaster title in app bar.
- [ ] **[TC-PROF-03]** Verify Verified Scholar Badge (`#BC5FD3` Accent Purple icon) is visible next to verified scholar names.
- [ ] **[TC-PROF-04]** Tap Follow Channel button (`profile.follow_btn`): Verify `FeatureInProgressModal` opens cleanly.
- [ ] **[TC-PROF-05]** Tap Set Reminder button (`profile.reminder_btn`): Verify `FeatureInProgressModal` opens cleanly.
- [ ] **[TC-PROF-06]** Switch to "Info" Tab: Verify lecturer biography, university venue details, and upcoming schedule items render properly.
- [ ] **[TC-PROF-07]** Switch to "Past Archives" Tab: Verify VOD list loads with duration badges (e.g. "54:00") and view counts.
- [ ] **[TC-PROF-08]** Tap VOD item: Verify `FeatureInProgressModal` opens for VOD playback.

### 6.3 Hero Tag Shared Element Animation
- [x] **[TC-HERO-01]** Inspect avatar Hero tags in `ChannelCard`, `MarkerSummaryCard`, and `BroadcasterProfileScreen`: Verify all use exact format `avatar_${streamer.streamerId}`.
- [x] **[TC-HERO-02]** Navigate from Discovery Feed card or Map summary card to Profile screen: Verify avatar performs smooth Hero transition without tag mismatch or duplicate key errors.

---

## 7. Version 0.4 Checkpoint 4.1 & 4.2 Test Execution Results

### 7.1 Automated Unit & Integration Tests (`test/v04_ui_ux_specialist_test.dart`)
- [x] **[TC-I18N-01]** 100% Localization Key Symmetry between `en.json` and `ar.json`: Verified all 78 dictionary keys are bi-directionally present.
- [x] **[TC-THEME-01]** Minimalist Dark Theme Palette & High Contrast Ratios: Verified `#0E0E10` base, `#161619` Level 1 surface, `#202024` Level 2 surface, `#2A2A30` Level 3 surface, `#FF8080` red accent, `#5FBCD3` blue accent, `#87DE87` green accent, and `#BC5FD3` purple accent.
- [x] **[TC-THEME-02]** Dark Theme Base Surface and Accent Constants Verification: Verified scaffold background, color scheme surface, primary, and secondary tokens.
- [x] **[TC-PITCH-01]** Pitch Director Mode Activation & Live State Forcing: Verified triple-tap notification trigger and long-press director mode activation.
- [x] **[TC-PITCH-02]** Category Filtering and Search Operations: Verified search and category filtering in `AppProvider`.

### 7.2 Universal Safety Audit & Modal Verification Summary
- [x] **[TC-AUDIT-01]** Universal Placeholder Safety Audit: Verified all unbuilt action buttons display `FeatureInProgressModal` with localized titles and body text.
- [x] **[TC-AUDIT-02]** LTR / RTL Alignment Check: Verified zero text clipping or alignment inversion errors across 320px–600px screens.
- [x] **[TC-AUDIT-03]** Full Suite Execution: Executed `flutter test` — **36/36 Tests Passed (100% Success Rate)**.

