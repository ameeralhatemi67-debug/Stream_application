# iOS viewer UX audit

2026-10-18, W22. E1 Windows Dart/source checks only. Swift stays E0. Findings
below describe the viewer; the publisher and its real interruption behavior are
separate device gates. Paths are relative to project/ unless noted.

| Area | Result | File:line evidence and behavior |
|---|---|---|
| Page transitions and back swipe | Fix | lib/core/routing/app_router.dart:42 returns CupertinoPage for iOS profile/live stack pages. The previous CustomTransitionPage lacked the Cupertino edge gesture. Other GoRoute builder pages retain Flutter's platform-adaptive route. Theme app_theme.dart:109 does not override pageTransitionsTheme. EN/AR tests push a real profile through AppRouter and swipe back to the retained feed. |
| Scroll physics | Pass | lib/core/widgets/ds/ca_pull_to_refresh.dart:89 supplies bouncing + always-scrollable physics; live_broadcast_screen.dart:1554 uses bouncing chat. Other scrollables inherit Flutter's iOS behavior. No app-wide clamping override. |
| Status bar on dark surfaces | Fix | lib/core/widgets/ds/ca_navigation.dart:31 selects light foreground/back-arrow icons and system icons for AppTheme.media, used by live_broadcast_screen.dart:985; other bars use dark icons. EN/AR tests assert both system styles and the actual inherited BackButtonIcon color. Fullscreen chrome remains a native-observation row. |
| Bottom bar SafeArea | Pass | lib/core/widgets/ds/ca_navigation.dart:61 places the actual nav bar inside bottom SafeArea; app_router.dart:546 mounts it as Scaffold.bottomNavigationBar. Sweeps simulate bottom 34. |
| Return-to-broadcast chip | Fix | lib/core/widgets/floating_stream_mini_player.dart:57 clamps against LayoutBuilder body bounds, not the full screen behind bottom navigation. :60 sizes the chip for scaled text. A real Arabic 1.5 overflow and overlap risk were corrected. EN/AR drag-to-bottom tests assert it clears the actual nav bar. It remains a shortcut; playback stops when the room closes. |
| Orientation restore | Fix | lib/features/live_stream/presentation/live_broadcast_screen.dart:470 restores portrait + both landscapes on iOS after leaving a room; Android keeps its prior portrait policy. Runner/Info.plist:78 already permits these iPhone orientations. Read-only Android manifest has no screenOrientation lock and handles orientation changes. Host tests capture the actual SystemChrome method arguments on room disposal. No manifest edited. |
| Wakelock lifecycle | Pass, needs device | live_broadcast_screen.dart:411 enables for an active room, :414 stops/clears it and :457 invokes room cleanup on dispose. Paused/hidden lifecycle handlers call _stopRoom. Plugin errors are already best-effort. Real lock-screen, suspension and return behavior remain unverified. |
| Pull-to-refresh | Pass | discovery_feed_screen.dart:362 invokes a real catalog refresh through CaPullToRefresh. ca_pull_to_refresh.dart:53 uses selection haptics and :89 permits overscroll even for short lists. Native feel/haptics need device. |
| Keyboard over live chat | Fix | live_broadcast_screen.dart:954 reduces the compact viewport while typing, omits the channel header and hides chat tabs during chat editing (:1415). :1590 gives the composer more of the remaining panel. Before the fix, its bottom was about 30px behind an SE keyboard. New tests focus/type into it with viewInsets.bottom=336 and assert the entire EditableText clears the keyboard. |
| Keyboard dismissal | Fix | lib/core/widgets/ds/ca_fields.dart:324 and live_broadcast_screen.dart:1975 explicitly unfocus on outside tap. Discovery :368, settings_screen.dart:397 and live chat :1554 dismiss on drag. The application wizard keeps its page/field scroll handling; actual text fields are exercised with the keyboard open. |
| Text selection | Pass | CaInput uses TextFormField/EditableText with platform controls; iOS long-press from unfocused state selects a word in both languages, and an outside tap dismisses focus. This does not prove native selection-handle positioning. |
| Large text | Fix | lib/main.dart:133 preserves iOS platform text scaling instead of the former app-wide 1.3 cap; other platforms retain their existing policy. Welcome no longer ellipsizes action labels. All three iPhone sizes exercise welcome, settings and deletion at 2.0 and 3.0. Some short navigation titles intentionally truncate visually while retaining semantic text. |
| Accessibility targets/contrast | Fix | ios_support_contact.dart:58 gives the selectable address at least 48px and darker text. welcome_screen.dart:227 and privacy_settings_section.dart:387 use stronger small-text contrast. The same support address in the Mail fallback also has a minimum target. No semantic nodes were hidden to make guidelines pass. |

## Coverage and limits

`test/ios_layout_sweep_b_test.dart` uses actual EN/AR catalogs and bundled fonts,
iOS platform overrides reset in every widget-body finally and tearDown, with
no FlutterError suppression. Matrix B covers both landscape sizes, 336px keyboard,
2x/3x text at all three portrait sizes, all five individual wizard steps, notifications, viewer editor,
public individual/organization profiles, organization hub, and all three gated
notices. Profile media is populated with existing test fixtures rather than
waiting for network. The matrix asserts layout exceptions and active controls.

The three Flutter guidelines run on welcome, chat actions, settings and deletion
at 375x667, 393x852 and 430x932 in both languages. Settings is checked repeatedly
while scrolling all the way to the bottom. Other surfaces also have explicit
layout/interaction tests, not a claim of whole-app WCAG certification.

There is **no dedicated follows-list screen/route** in the current app:
`followedStreamerIds` is consumed by per-channel follow controls, not a list UI.
The reachable public channel/organization/member lists and profile follow
controls are covered. W22 does not invent a follow-list product feature. A
future request for a dedicated list needs its own design/work order.

## Needs device

- VoiceOver reading/focus order, rotor actions, modal focus restoration and
  pronouncing Arabic/provider names. Flutter's labeled-target test only checks
  the presence of semantic labels, not their spoken quality.
- Real Dynamic Type/nonlinear scaling, Bold Text, Reduce Motion, native system
  permission/auth sheets and the system keyboard/selection menus.
- Interactive swipe-back cancellation during WKWebView playback, RTL edge
  gestures, URL return and nested-stack restoration on actual iOS.
- Status/home indicators through fullscreen/rotation/background; notch/Dynamic
  Island, hardware keyboard, keyboard prediction/autocorrect and dismissal feel.
- Real scroll spring, haptic refresh, readable contrast against loaded images,
  native WebView content and screen-brightness changes.
- Wakelock/idle timer, background suspension, calls/Siri/audio routes and the
  default-off publisher's W21-3 transport/capture behavior.

Sources: [Flutter accessibility tests](https://docs.flutter.dev/ui/accessibility/accessibility-testing),
[CupertinoPage](https://api.flutter.dev/flutter/cupertino/CupertinoPage-class.html),
[scroll behavior](https://api.flutter.dev/flutter/widgets/ScrollBehavior/getScrollPhysics.html).
Context7 plus the installed Flutter 3.41.2 scroll/route implementation were used.
No native compile, Simulator, physical device or higher evidence level is claimed.

## W23 keyboard follow-up and CaInput caller audit

The W22 keyboard rows above are superseded here. The live composer now keeps
one element tree through keyboard insets. The entire composer Row is a
TextFieldTapRegion. Outside-tap unfocus is native-iOS-only in chat and CaInput;
Android/web use Flutter's default. Drag dismissal remains on both platforms.
New connection tests never reconnect the input after applying the inset.

`rg -n "CaInput\(" project/lib` found all callers below, including the shared
CaSearchField wrapper. Related external actions were checked at their callbacks:
none gates its action on focus or changes its enabled state from a focus listener.
Unfocus does not consume the pointer, so their submit/add/picker action still
fires using the controller value. No additional tap-region wrapper is needed.
The iOS CaInput host action test exercises submit, suffix, add and picker taps,
asserting the action/value and focus result; actual native pickers remain E0.

| Caller, under project/lib | Related action and source check |
|---|---|
| features/auth/presentation/steps/apply_step_1_identity.dart | Name/email fields; wizard Next validates controllers. No field-local external suffix action. |
| features/auth/presentation/steps/apply_step_3_professional.dart | Custom-field dialog Add reads its controller; custom-tag sibling Add calls _submitCustomTag, reads text and clears it. YouTube trailing status remains inside the TextFormField region. |
| features/auth/presentation/steps/apply_step_3_5_org_speakers.dart | Dialog Add reads controllers. Handle lookup trailing IconButton calls checkAndAutofill and is already inside the field region. Avatar picker and Add Speaker callbacks do not depend on input focus. |
| features/auth/presentation/steps/apply_step_4_location.dart | Branch Add reads name/address; sibling map buttons open LocationPickerModal/_openMapPinpoint. Add/remove branch and contact preference callbacks remain enabled independently of focus. Phone trailing icon is status only. |
| features/profile/presentation/widgets/viewer_profile_editor_dialog.dart | Save/_handleSave reads controllers; avatar picker and Cancel remain callable after unfocus. |
| features/profile/presentation/widgets/join_org_modal_sheet.dart | Submit/_submitRequest reads role/note controllers; organization selection is independent of focus. |
| features/profile/presentation/widgets/upcoming_schedule_editor_sheet.dart | Save/_save reads form controllers; _pickDate/_pickTime open their pickers after unfocus. |
| features/profile/presentation/widgets/broadcaster_application_sheet.dart | Shared field builder; Submit/_handleSubmit and _openLocationPicker read state/controllers without focus guards. |
| features/profile/presentation/settings/broadcasting_settings_section.dart | URL onChanged persists state; title/venue controllers feed start action. Campus picker/start callbacks are independent of focus. |
| features/live_stream/presentation/widgets/rtmp_ip_dialog.dart | Optional title controller feeds studio actions; start/go-live actions remain governed by studio state, not field focus. |
| core/widgets/ds/ca_fields.dart | CaSearchField delegates to CaInput. Any trailing control is passed through suffixIcon and stays inside its field tap region. |

Sources: [Flutter onTapOutside](https://api.flutter.dev/flutter/material/TextField/onTapOutside.html)
and [TextFieldTapRegion](https://api.flutter.dev/flutter/widgets/TextFieldTapRegion-class.html).
Context7 was queried first; unrelated/no matching results required the official
API pages as fallback. Host touch tests do not establish native keyboard behavior.
