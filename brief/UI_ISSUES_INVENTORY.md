# UI issue inventory

Date: 2026-09-22

This inventory records the issues visible in `brief/Ui_issues/`. It is a work list for a later implementation pass. The screenshots are evidence of visual problems, not proof of the underlying runtime cause.

## Reference images

The source screenshots are stored in [`brief/Ui_issues/`](Ui_issues/):

- [`SearchPar_Discovery_feed.jpg`](Ui_issues/SearchPar_Discovery_feed.jpg)
- [`SearchPar_Spatial_map.jpg`](Ui_issues/SearchPar_Spatial_map.jpg)
- [`OBS_set_up.jpg`](Ui_issues/OBS_set_up.jpg)
- [`OBS_Extend_screen_shot.jpg`](Ui_issues/OBS_Extend_screen_shot.jpg)
- [`Local_set_up.jpg`](Ui_issues/Local_set_up.jpg)
- [`stream_set_up_arabic.jpg`](Ui_issues/stream_set_up_arabic.jpg)
- `Screenshot_20260922_113308_Hadayah Live.jpg` through `Screenshot_20260922_113334_Hadayah Live.jpg` for the broadcaster tutorial modal
- [`Viewer_bording_page.jpg`](Ui_issues/Viewer_bording_page.jpg)
- [`app_icon_main_page.jpg`](Ui_issues/app_icon_main_page.jpg)
- [`Map_when_wifi_on.jpg`](Ui_issues/Map_when_wifi_on.jpg)
- [`Map_when_wifi_Off.jpg`](Ui_issues/Map_when_wifi_Off.jpg)

## Priority summary

| ID | Area | Priority | Type | Status |
|---|---|---:|---|---|
| UI-01 | Feed and map search-bar corner mismatch | P1 | Visual consistency | Open |
| UI-02 | Broadcaster Studio contrast and control styling | P1 | Visual consistency and accessibility | Open |
| UI-03 | Broadcaster tutorial text contrast | P1 | Visual consistency and accessibility | Open |
| UI-04 | Arabic broadcaster mode labels and selection | P1 | Localization and interaction | Open |
| UI-05 | Viewer onboarding uses real-person avatar presets | P1 | Product/content safety | Open |
| UI-06 | Launcher icon mark is too large | P2 | Android branding | Open |
| UI-07 | Online map basemap is too dark and low quality | P1 | Map rendering | Open |
| UI-08 | Offline map has no usable basemap | P1 | Offline feature | Open |
| UI-09 | Broadcaster sheet has clipped or weak bottom actions | P1 | Responsive layout | Open |
| UI-10 | Broadcaster tutorial has weak hierarchy and excessive empty space | P2 | Responsive layout | Open |
| UI-11 | Map controls and overlays lack a unified surface treatment | P2 | Visual consistency | Open |
| UI-12 | Map marker scale and map-to-marker contrast need review | P2 | Map usability | Open |

## UI-01: Search bars have mixed corner geometry

References: [`SearchPar_Discovery_feed.jpg`](Ui_issues/SearchPar_Discovery_feed.jpg), [`SearchPar_Spatial_map.jpg`](Ui_issues/SearchPar_Spatial_map.jpg).

### What is visible

Both search bars show a rounded outer border with sharp or squared portions at the left and right edges. The feed search bar looks clipped where it meets the screenshot edges. The map search bar has a white rectangular field with visible square corners while the adjacent Arabic button and lower filter controls use rounded corners. The result looks like two different components placed beside each other.

### Likely source locations

- `project/lib/features/discovery/presentation/discovery_feed_screen.dart`, the feed search `Container` and `TextField` around the `feed.search_feed` hint.
- `project/lib/features/map/presentation/widgets/top_spatial_search_bar.dart`, `TopSpatialSearchBar` and its outer `Container`.
- Shared shape and spacing tokens: `project/lib/core/theme/app_theme.dart`.

### Required result

Use one shared search-field surface contract for feed and map:

- one radius, one border width, and one clipping rule;
- no child `TextField` background or decoration that escapes the rounded parent;
- consistent height, icon alignment, horizontal padding, focus border, and shadow;
- correct mirroring in Arabic without changing the shape;
- verify at 320 px, 360 px, 412 px, tablet, landscape, English, and Arabic.

## UI-02: Broadcaster Studio has poor contrast and inconsistent control styling

References: [`OBS_set_up.jpg`](Ui_issues/OBS_set_up.jpg), [`OBS_Extend_screen_shot.jpg`](Ui_issues/OBS_Extend_screen_shot.jpg), [`Local_set_up.jpg`](Ui_issues/Local_set_up.jpg), [`stream_set_up_arabic.jpg`](Ui_issues/stream_set_up_arabic.jpg).

### What is visible

The three broadcaster modes, OBS, Phone, and Local, share several problems:

- the sheet title and selected-tab labels are white or near-white on a pale surface;
- the selected mode uses a pink wash and border that compete with the text instead of improving clarity;
- disabled `Go Live`, `Stream`, and similar actions are almost invisible;
- text fields, preset IP chips, buttons, and category chips use several different border and fill treatments;
- the icon, title, mode selector, form fields, and bottom actions do not form a clear visual hierarchy;
- the Local mode contains a large amount of unused vertical space;
- input placeholder text is too faint, especially for the stream key and ingest URL;
- the bottom action row is close to the navigation bar and may be clipped on shorter screens.

### Likely source locations

- `project/lib/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart`
  - `LiveBroadcasterStudioSheet`
  - `_buildHeader`
  - `_buildModePill`
  - `_buildObsFields`
  - `_buildPhoneFields`
  - `_buildLocalFields`
  - `_buildBottomRow`
- Localization keys under `live_studio` and `design_copy` in `project/assets/i18n/en.json` and `project/assets/i18n/ar.json`.
- Color, surface, border, and disabled-state tokens in `project/lib/core/theme/app_theme.dart`.

### Required result

Redesign the shared studio shell once, then apply it to all three modes. Text must meet the existing contrast test requirements. Selected, enabled, disabled, focused, and error states must be visibly distinct. The bottom action must remain visible above the safe-area inset on short Android screens.

Do not solve this by adding more red borders or more shadows. Use the existing semantic theme tokens and a small, consistent set of field, chip, tab, and action styles.

## UI-03: Broadcaster tutorial headings and icons disappear on pale cards

References: `Screenshot_20260922_113308_Hadayah Live.jpg` through `Screenshot_20260922_113334_Hadayah Live.jpg`.

### What is visible

The `STREAMER ACADEMY` label is readable, but the level title, large tutorial heading, and central icon are white on a very pale green card. They are difficult to read or effectively invisible. The body copy is readable, so the problem is specific to the heading/icon color choice. The tutorial card also leaves a large unused area between its content and the navigation controls.

### Likely source locations

- `project/lib/features/live_stream/presentation/widgets/streamer_setup_guide_modal.dart`
  - `_buildHeader`
  - `_buildQuestCard`
  - heading and icon styles using `AppTheme.onMedia`.

### Required result

- Use a dark semantic text token for headings and icons on the pale card.
- Keep `onMedia` only for text placed on genuinely dark media or overlay surfaces.
- Maintain readable hierarchy between academy label, step title, card heading, body, and buttons.
- Place the progress indicator and navigation buttons in a stable bottom area without excessive empty space.
- Check every tutorial step in English and Arabic.

## UI-04: Arabic broadcaster mode labels and selection are confusing

Reference: [`stream_set_up_arabic.jpg`](Ui_issues/stream_set_up_arabic.jpg).

### What is visible

In Arabic mode, the mode selector visually reverses the positions, but the selected indicator, icon, and label relationship is confusing. The screenshot makes `محلي` appear where the OBS option is expected and makes the OBS option appear where Local is expected. The mode must never change meaning because of RTL ordering.

### Likely source locations

- `project/lib/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart`
  - `StudioMode { obs, phone, local }`
  - `_buildModePill`
  - `effectiveIndex`
  - `_pillTab`.
- `project/assets/i18n/ar.json`, keys `live_studio.obs`, `live_studio.phone`, and `live_studio.local` or their current equivalents.

### Required result

Keep the semantic mode-to-label mapping fixed:

- OBS = OBS with the laptop icon;
- Phone = الجوال with the phone icon;
- Local = محلي with the local/lightning icon.

RTL may change visual order, but it must not change which label, icon, selected state, form, or submit action belongs to each `StudioMode`. Add a widget test that taps every mode in both locales and verifies the displayed fields and selected mode.

## UI-05: Viewer onboarding uses real-person avatar presets

Reference: [`Viewer_bording_page.jpg`](Ui_issues/Viewer_bording_page.jpg).

### What is visible

The viewer setup screen offers photographs of identifiable people and a branded podcast image as default avatars. These are not safe default assets for a public product and should not be presented as anonymous viewer choices.

### Likely source locations

- `project/lib/features/auth/presentation/viewer_setup_screen.dart`, `_avatarPresets` and its initial selection.
- `project/lib/features/profile/presentation/widgets/viewer_profile_editor_dialog.dart`, its duplicate `_avatarPresets` list.
- `project/lib/core/providers/app_provider.dart`, guest-viewer fallback avatar handling around `setupGuestViewer`.
- `project/assets/images/` and any avatar assets referenced by those lists.

### Required result

- Remove all defaulted real-person and branded-photo presets from viewer onboarding and viewer profile editing.
- Add neutral, original, non-human default avatars, such as abstract geometric or initials-based avatars, with English/Arabic-safe rendering.
- Keep the custom image-picker action.
- Use a neutral default when the user skips a custom image.
- Do not delete assets used by verified streamer or organization profiles without checking their separate product purpose.
- Add tests proving no viewer default points to the old real-person asset paths and that custom avatar selection still works.

## UI-06: Launcher icon mark is too large

Reference: [`app_icon_main_page.jpg`](Ui_issues/app_icon_main_page.jpg).

### What is visible

The launcher mark fills too much of the adaptive icon mask. It has little breathing room and may feel cramped on different Android launcher masks.

### Likely source locations

- `brief/tools/make_launcher_assets.py`, source-layer scale and centering.
- `project/assets/launcher/adaptive_foreground.png` and related generated launcher assets.
- `project/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`.

### Required result

Reduce the foreground mark scale while keeping the logo legible at small sizes. Render and inspect circular, squircle, and themed-icon masks before accepting the change. Re-run the Android launcher asset checks and keep the supplied source logo unchanged.

## UI-07: Online map basemap is too dark and low quality

Reference: [`Map_when_wifi_on.jpg`](Ui_issues/Map_when_wifi_on.jpg).

### What is visible

The online map is very dark, low contrast, and visually noisy. Roads and place information are difficult to read. The large regional outlines compete with the basemap and the marker is small against the map. The map does not match the light product theme shown by the surrounding controls.

### Likely source locations

- `project/lib/features/map/presentation/spatial_map_screen.dart`, tile constants and `TileLayer`.
- `project/lib/features/map/presentation/spatial_map_screen.dart`, `PolygonLayer` region styling.
- `project/lib/features/map/presentation/widgets/spatial_streamer_marker.dart`, marker size and contrast.
- `project/lib/features/map/presentation/widgets/marker_summary_card.dart` and map controls.

### Required result

- Use a readable light basemap that is permitted by its terms and has visible attribution.
- Keep the map visually compatible with the white theme.
- Reduce the visual weight of region outlines.
- Make markers readable at the intended zoom levels without covering roads or the selected venue.
- Preserve the exact venue coordinates and Google Maps navigation behavior.
- Test online rendering in English and Arabic at city and venue zoom levels.

This is more than a color tweak if the current tile source is inherently dark or low-resolution. Check tile terms, attribution, zoom coverage, and loading behavior before changing providers.

## UI-08: Offline map has no usable basemap

Reference: [`Map_when_wifi_Off.jpg`](Ui_issues/Map_when_wifi_Off.jpg).

### What is visible

When Wi-Fi is off, the map shows a blank white field with rough region polygons. It does not show a usable geographic basemap, roads, venue context, or a clear offline state. The user cannot understand where a marker or venue is.

### Likely source locations

- `project/lib/features/map/presentation/spatial_map_screen.dart`, `TileLayer` and fallback behavior.
- `project/lib/features/map/models/map_models.dart`, bundled region geometry.
- Offline/connectivity and cache services under `project/lib/core/services/` and `project/lib/core/providers/app_provider.dart`.

### Required result

Add a real offline map strategy, not only a polygon overlay. The implementation must:

- show an explicit bilingual offline banner;
- display the last available catalog with its timestamp;
- render a usable permitted offline basemap or a clearly documented bundled map layer;
- show cached venue markers when available;
- label live status as unavailable while offline;
- disable actions that require the network and explain why;
- provide Retry and recover when connectivity returns;
- show attribution and expose cache/clear behavior if the chosen map strategy requires it.

This should be tracked as a feature phase, not treated as a small visual patch.

## UI-09: Broadcaster sheet bottom actions can be clipped or too faint

References: [`OBS_Extend_screen_shot.jpg`](Ui_issues/OBS_Extend_screen_shot.jpg), [`Local_set_up.jpg`](Ui_issues/Local_set_up.jpg), [`stream_set_up_arabic.jpg`](Ui_issues/stream_set_up_arabic.jpg).

### What is visible

The lower action row sits at the very bottom of the sheet. In the taller OBS capture, the title area is partly clipped near the top of the scroll content. The disabled action button has very low contrast, and the navigation bar competes with the button area.

### Likely source locations

- `rtmp_ip_dialog.dart`, sheet height, `SingleChildScrollView`, bottom inset padding, and `_buildBottomRow`.
- `AppTheme` disabled colors and button styles.

### Required result

Use a layout that keeps the header, scrollable form, and bottom action row inside a predictable safe-area structure. Test 320 px and 360 px heights, large text, keyboard open, and all three modes.

## UI-10: Broadcaster tutorial hierarchy and spacing need refinement

References: all `Screenshot_20260922_1133*.jpg` tutorial images.

### What is visible

The tutorial card is visually sparse, with a large empty lower area. The step dots and action buttons are detached from the card content. The primary action is strong red, but the content heading is unreadable, so the interaction hierarchy is backwards.

### Likely source locations

- `streamer_setup_guide_modal.dart`, modal layout, quest card, and navigation row.

### Required result

Fix contrast first, then tighten the vertical rhythm. Keep enough space for Arabic text expansion and large text without clipping. Use the same layout rules for the OBS, Local, and Phone guidance paths.

## UI-11: Map controls and overlays need one surface treatment

References: [`Map_when_wifi_on.jpg`](Ui_issues/Map_when_wifi_on.jpg), [`Map_when_wifi_Off.jpg`](Ui_issues/Map_when_wifi_Off.jpg).

### What is visible

The search field, Arabic switcher, city/topic controls, floating location/list buttons, region outlines, bottom navigation, and map marker use different border weights, shadows, and opacity levels. On the dark map, the controls look detached. Offline, the same controls float over an almost empty white field.

### Likely source locations

- `spatial_map_screen.dart`
- `top_spatial_search_bar.dart`
- `city_selector_dropdown.dart`
- `topic_selector_dropdown.dart`
- `streamer_sliding_drawer.dart`
- `spatial_streamer_marker.dart`

### Required result

Define a small map overlay contract for surface color, radius, border, shadow, icon size, and active state. Apply it consistently without reducing map readability or RTL support.

## UI-12: Map marker scale and contrast need review

Reference: [`Map_when_wifi_on.jpg`](Ui_issues/Map_when_wifi_on.jpg).

### What is visible

The visible venue marker is small relative to the map and has a bright image ring that competes with the dark basemap. It is not immediately clear whether the marker is selected, live, or simply present.

### Likely source locations

- `project/lib/features/map/presentation/widgets/spatial_streamer_marker.dart`
- `project/lib/features/map/presentation/widgets/marker_summary_card.dart`
- LOD and ordering logic in `spatial_map_screen.dart`.

### Required result

Keep live/offline/selected states distinct, enlarge the hit target, preserve marker clustering or LOD behavior, and verify that the selected marker and summary card remain readable at city and venue zoom levels.

## Suggested implementation order

1. Fix shared contrast and layout primitives in the broadcaster studio and tutorial modal: UI-02, UI-03, UI-09, UI-10.
2. Fix the Arabic mode mapping and add tests: UI-04.
3. Remove real-person viewer presets and add neutral defaults: UI-05.
4. Unify feed/map search fields: UI-01.
5. Fix the launcher scale: UI-06.
6. Improve the online map and marker treatment: UI-07, UI-11, UI-12.
7. Design and implement the offline map feature separately: UI-08.

## Verification requirements for the later fix pass

- Run `flutter analyze`.
- Run the full Flutter test suite.
- Add or update widget tests for both locales and every broadcaster mode.
- Run the existing layout sweep at phone, tablet, landscape, Arabic, English, and large text sizes.
- Inspect screenshots for feed search, map search, OBS, Phone, Local, Arabic studio, tutorial steps, viewer onboarding, online map, and offline map.
- Test Chrome and at least one Android emulator.
- Record each issue as fixed, still open, or blocked with a screenshot path and command result.

