# WO-0 iOS recon

| Scope | Result |
|---|---|
| Date | 2026-10-11, WO-0, Windows host, read-only application/backend inspection |
| Changed paths | This report and IOS_LEDGER.md only; no ios/ project generated |
| Evidence | Windows checks below; no macOS CI build, device run or gate verdict |
| Notation | L/ = project/lib/; M/ = supabase/migrations/; line numbers are one-based |

## 1. Toolchain and SwiftPM

| Check | Observation |
|---|---|
| flutter --version | Flutter 3.41.2 stable, framework 90673a4eef, Dart 3.11.0, DevTools 2.54.1 |
| flutter config --list | enable-swift-package-manager: (Not set); no explicit global opt-in |
| .flutter-plugins-dependencies | version 3.41.2; swift_package_manager_enabled.ios=false and .macos=false |
| Project state | No project/ios/; no pubspec SwiftPM override; launcher icons ios: false at project/pubspec.yaml:123 |
| flutter doctor -v | Windows 11; Windows, Chrome and Edge targets. No Xcode/iOS toolchain section on Windows and no iOS target. One warning category: Android license status unknown. This does not establish iOS build readiness. |
| Flutter iOS template | Minimum 13.0 at installed SDK packages/flutter_tools/templates/app/ios.tmpl/Runner.xcodeproj/project.pbxproj.tmpl:375,504,555. [Pinned official source](https://github.com/flutter/flutter/blob/90673a4eef/packages/flutter_tools/templates/app/ios.tmpl/Runner.xcodeproj/project.pbxproj.tmpl). |
| Official dependency-manager guidance | [Flutter SwiftPM docs](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers), fetched through Context7. Current docs include later Flutter releases; installed 3.41.2 observations above control this recon. No configuration changed. |

## 2. Every iOS plugin in generated metadata

Versions were checked against project/pubspec.lock and the cache. Cache evidence below is relative to C:/Users/User/AppData/Local/Pub/Cache/hosted/pub.dev/<name>-<version>/. integration_test is instead under C:/Users/User/sru/flutter/packages/integration_test/.

| Plugin | Locked version | Packaging present | FFI / native assets | Minimum iOS; cache evidence |
|---|---|---|---|---|
| app_links | 7.0.0 | SwiftPM + CocoaPods | No | 13.0; ios/app_links/Package.swift:9, ios/app_links.podspec:18 |
| connectivity_plus | 6.1.5 | SwiftPM + CocoaPods | No | 12.0; ios/connectivity_plus/Package.swift:9, ios/connectivity_plus.podspec:19 |
| firebase_core | 4.15.0 | SwiftPM + CocoaPods | No | 15.0; ios/firebase_core/Package.swift:16, ios/firebase_core.podspec:30 |
| firebase_messaging | 16.7.0 | SwiftPM + CocoaPods | No | 15.0; ios/firebase_messaging/Package.swift:16, ios/firebase_messaging.podspec:31 |
| geolocator_apple | 2.3.14 | SwiftPM + CocoaPods | No | 11.0; darwin/geolocator_apple/Package.swift:9, darwin/geolocator_apple.podspec:22 |
| image_picker_ios | 0.8.13+6 | SwiftPM + CocoaPods | No | 13.0; ios/image_picker_ios/Package.swift:12, ios/image_picker_ios.podspec:21 |
| integration_test | 0.0.0, Flutter SDK | SwiftPM + CocoaPods | No | 12.0; ios/integration_test/Package.swift:9, ios/integration_test.podspec:23; dev dependency |
| package_info_plus | 9.0.1 | SwiftPM + CocoaPods | No | 12.0; ios/package_info_plus/Package.swift:9, ios/package_info_plus.podspec:17 |
| path_provider_foundation | 2.6.0 | Dart registration; neither Package.swift nor podspec | Yes, via objective_c 9.5.0 | No fixed minimum discovered; pubspec.yaml:16 declares dartPluginClass; :21,24 depend on ffi/objective_c; lib/src/path_provider_foundation_real.dart:9 imports objective_c |
| permission_handler_apple | 9.6.1 | SwiftPM + CocoaPods | No | 12.0; ios/permission_handler_apple/Package.swift:724, ios/permission_handler_apple.podspec:19 |
| share_plus | 10.1.4 | SwiftPM + CocoaPods | No | 12.0; ios/share_plus/Package.swift:9, ios/share_plus.podspec:22 |
| shared_preferences_foundation | 2.5.6 | SwiftPM + CocoaPods | No | 13.0; darwin/shared_preferences_foundation/Package.swift:12, darwin/shared_preferences_foundation.podspec:18 |
| sqflite_darwin | 2.4.2 | SwiftPM + CocoaPods | No | 12.0; darwin/sqflite_darwin/Package.swift:9, darwin/sqflite_darwin.podspec:20 |
| url_launcher_ios | 6.4.1 | SwiftPM + CocoaPods | No | 13.0; ios/url_launcher_ios/Package.swift:13, ios/url_launcher_ios.podspec:23 |
| wakelock_plus | 1.5.2 | SwiftPM + CocoaPods | No | SwiftPM 11.0 / CocoaPods 12.0; ios/wakelock_plus/Package.swift:9, ios/wakelock_plus.podspec:19; use the higher floor when comparing |
| webview_flutter_wkwebview | 3.25.1 | SwiftPM + CocoaPods | No | 13.0; darwin/webview_flutter_wkwebview/Package.swift:12, darwin/webview_flutter_wkwebview.podspec:20 |

| Finding | Consequence |
|---|---|
| 15/16 have SwiftPM and CocoaPods files; none is CocoaPods-only | Packaging presence is not compile proof |
| path_provider_foundation native_build=false | Still uses native assets through objective_c; objective_c hook/build.dart:28 supports iOS/macOS, :202-204 inherits the configured iOS target version. CI verification remains necessary. |
| Highest discovered floor is 15.0 | Recommend D6 = iOS 15.0, above Flutter template 13.0. Firebase plugins impose this even with push inert. Native-assets compatibility remains unverified. |

## 3. All platform sites in lib

Search covered all lib for Platform.is*, defaultTargetPlatform, TargetPlatform and kIsWeb. No Platform.is* calls found. Import-only matches: L/core/providers/app_provider.dart:58 and L/features/live_stream/presentation/live_broadcast_screen.dart:9. The directions helper also declares a TargetPlatform parameter at :12. All executable matches follow.

| Path under L/ / lines | iOS today | Disposition for WO-8 / later gates |
|---|---|---|
| core/layout/window_class.dart:18-20 | Phone classification includes native iOS below shortest-side threshold | Keep; device-test phone/iPad/landscape |
| core/config/reminder_firebase_config.dart:15 | supported=false | Keep push deferred |
| core/config/reminder_firebase_config.dart:22 | VAPID requirement applies only on web; supported still blocks iOS | Keep leading support gate |
| core/providers/app_provider.dart:1189 | Device platform is ios | Keep; device schema accepts it, §4 |
| core/services/youtube_api_service.dart:47 | Native public API-key define path, same as Android | Verify native data loading |
| core/services/youtube_api_service.dart:76 | Default web proxy off | Preserve deliberate native path; do not infer web-proxy behavior |
| core/widgets/safe_image_provider.dart:23 | Existing native files become FileImage | Keep; verify selected photos on device |
| core/widgets/safe_image_provider.dart:57 | Alternate image helper also resolves native files | Keep |
| core/widgets/ds/canopy_lattice_background.dart:87 | Web pointer spotlight off | Keep |
| core/widgets/ds/canopy_lattice_background.dart:127 | Native medium-width tablet layout stops texture animation | Keep; verify iPad layout/performance |
| core/widgets/ds/ca_discovery.dart:50 | Web hover callback off | Keep |
| core/services/supabase_auth_service.dart:18 | Native OAuth custom-scheme redirect | Register scheme in WO-5; test cold/warm return at E3 |
| core/services/reminder_push_service.dart:57 | Refresh would label native token android, but ready=false prevents attachment | Keep inert; future iOS push must replace label |
| core/services/reminder_push_service.dart:79 | Native token fetch omits VAPID; unreachable on iOS | Keep inert |
| core/services/reminder_push_service.dart:85 | Sync would label native token android; ready gate prevents iOS access | Keep inert |
| core/services/organization_broadcast_service.dart:106-107 | return_platform=web; channel consent returns to website | Viewer-first should defer/gate channel connection; native return requires separate backend authorization |
| features/map/presentation/venue_directions_launcher.dart:14 | Android Google Maps branch skipped | Keep |
| features/map/presentation/venue_directions_launcher.dart:17 | Apple Maps HTTPS daddr URI selected | Keep; verify external opening |
| features/map/presentation/venue_directions_launcher.dart:38 | Passes native target to URI builder, with Google fallback on launch failure | Existing pure URI test is not launch evidence |
| features/live_stream/presentation/live_broadcast_screen.dart:192 | Native recovery retains play intent/mute state; web forces pause/mute | Device-test bridge/recovery |
| features/live_stream/presentation/adapters/web_live_player_adapter.dart:48 | Native WebView navigation delegate attaches | Verify fallback/loading on device |
| features/live_stream/presentation/adapters/youtube_player_adapter.dart:86-88 | Commands include iOS after ready/error checks | Preserve ADR-006; delivery/playback unverified |
| features/live_stream/presentation/adapters/youtube_player_adapter.dart:138 | WK params allow inline playback and empty user-action-required media set | Already written; WO-7 audits and E3 verifies |
| features/live_stream/presentation/adapters/youtube_player_adapter.dart:158 | Native JavaScript bridge attaches | Preserve; device-test |
| features/live_stream/presentation/adapters/youtube_player_adapter.dart:316 | HTML/base-URL path instead of web loadRequest | Preserve youtube-nocookie.com and strict-origin referrer at :46,346,538,550 |
| features/live_stream/presentation/widgets/phone_camera_preview.dart:19 | Android-only explanatory placeholder instead of AndroidView | Keep publishing deferred |
| features/live_stream/presentation/widgets/rtmp_ip_dialog.dart:69 | _android=false; initial phone sender falls back to OBS at :74-75; phone tab disabled :355-357, explanation :382-386 | Keep phone unavailable; D3 decides wider studio scope |

## 4. Backend ios acceptance, checked first

| Evidence | Finding |
|---|---|
| L/core/providers/app_provider.dart:1189,1204,1216 | Builds ios device model and calls claimDeviceState when account/session conditions permit |
| L/core/services/admin_database_service.dart:2756-2761; fallback :2734-2737 | Sends p_platform to claim_broadcaster_device_state, with claim_broadcaster_device fallback |
| M/20260831090000_device_sessions.sql:8-15 | platform text not null default '' at :12; no enum or platform CHECK |
| M/20260924100000_broadcaster_device_claim_state.sql:19-32,47 | Text parameter, auth/ban/device/broadcast permission validation; forwards platform unchanged |
| M/20260925100000_broadcast_sessions_and_live_controls.sql:245-272 | Current RPC inserts left(coalesce(p_platform,''),32) at :270, preserving ios. Permission/ownership failures remain possible independently of platform. |
| All 80 local SQL migrations searched | No later device-platform CHECK/enum/allow-list found. Repository schema accepts ios on this call chain; hosted deployment state was not inspected. |
| Separate reminder push | M/20260930010000_upcoming_live_schedules.sql:125 table CHECK and :170 RPC reject ios; not the device-session chain. iOS client is inert, §7. |
| Separate channel consent | supabase/functions/channel-authorization/index.ts:15-20,84 recognizes android/android_test for native return; all others use web. Redirect limitation, not a device_sessions constraint. |
| Disposition | No backend platform blocker for device sessions found. No backend files edited. Push/native channel return are not implemented on iOS. |

## 5. Native permissions

| Capability | Call sites under L/ | Plugin / reachability |
|---|---|---|
| Foreground location | features/auth/presentation/widgets/location_picker_modal.dart:155,159,161,167,175 | geolocator → geolocator_apple; service/permission check, request, settings, current position. Shared picker has no Android-only gate; no background-location call found. |
| Viewer avatar | features/auth/presentation/viewer_setup_screen.dart:48-49 | image_picker → image_picker_ios, gallery |
| Application media | features/auth/presentation/steps/apply_step_2_media.dart:44-45,72-73 | image_picker, gallery both paths |
| Org speaker photo | features/auth/presentation/steps/apply_step_3_5_org_speakers.dart:72-73 | image_picker, gallery |
| Profile assets | features/profile/presentation/widgets/profile_media_editor.dart:49-50; custom_stream_cards_section.dart:69-70 | image_picker, gallery; no ImageSource.camera call found anywhere in lib |
| Camera/microphone | features/live_stream/presentation/screens/phone_broadcast_screen.dart:189,195; open settings :264 | permission_handler → permission_handler_apple; publisher is custom streamer_app/rtmp_publisher at features/live_stream/services/rtmp_publish_engine.dart:207-208. Phone screen is reached via Android-gated sender; no iOS native publisher. |
| Phone notification permission | features/live_stream/presentation/screens/phone_broadcast_screen.dart:200 | permission_handler; same phone screen |
| Reminder notification permission | core/services/reminder_push_service.dart:71-73; provider requests at core/providers/app_provider.dart:4731,4749 | firebase_messaging; ready=false prevents native iOS permission/token calls |

WO-3 must map reachable D3 capabilities to official plugin/Apple permission guidance. No plist keys or entitlements added here.

## 6. Auth and deep links

| Source | Fact |
|---|---|
| project/android/app/build.gradle.kts:59 | Normal oauthScheme = sa.hadayah.streamerapp, distinct from applicationId |
| Same file :76-78 | Optional wave4v2 test debug flavor changes it to sa.hadayah.streamerapp.wave4v2; not normal iOS scheme |
| L/core/config/supabase_config.dart:19-21 | OAUTH_REDIRECT_URL compile-time define; default sa.hadayah.streamerapp://login-callback. Local define file was not read. |
| L/core/services/supabase_auth_service.dart:15-18 | Supabase Google OAuth; native uses configured redirect, web uses Uri.base.origin |
| L/main.dart:34-38 | Initializes supabase_flutter with default auth options only when configured |
| supabase_flutter 2.17.2 cache lib/src/flutter_go_true_client_options.dart:35 | detectSessionInUri defaults true |
| Same package lib/src/supabase_auth.dart:76,133,254-265,278-288 | Owns AppLinks and native uriLinkStream including initial mobile link; explicit getInitialLink is web-only. No direct AppLinks consumer/import found in app lib. |
| L/core/routing/app_router.dart:166-174,207-210 | GoRouter consumes login-callback host/path, routes according to auth/onboarding state |
| Same router :346-350 | channels/channel-connected read status; channel-connected builds ChannelConsentReturnScreen. Studio return note at features/live_stream/presentation/widgets/rtmp_ip_dialog.dart:109; return-stack filtering at features/organization/presentation/channel_connections_screen.dart:73. |
| Same router :342-344 | Org invite route reads token. No iOS Associated Domains configuration exists in absent ios/ project; native HTTPS invitation delivery is not established. |
| project/android/app/src/main/AndroidManifest.xml:73,80 | Registers scheme placeholder with login-callback and channel-connected hosts; iOS registration/OS routing remain WO-5/E3 work |

## 7. Firebase initialization

| Source | Gate / evidence |
|---|---|
| L/main.dart:46 | Calls ReminderPushService.initializeIfConfigured at startup |
| L/core/services/reminder_push_service.dart:21-29 | Only Firebase.initializeApp site in lib, :25; returns first when config false |
| L/core/config/reminder_firebase_config.dart:14-22 | Supported only web/Android; configured also needs Firebase defines, plus VAPID on web. Native iOS false even with defines supplied. |
| L/core/services/reminder_push_service.dart:32-38,64-72,89-90 | ready short-circuits before Firebase.apps on iOS; attach/sync/signOut return before messaging APIs/registration |
| Limit | Dart gating inspected. Linked native Firebase startup without initialization still needs CI/device proof. WO-6's platform-override test remains outstanding. No iOS push/signing config added. |

## 8. Regression baseline

| Check from project/ | Result |
|---|---|
| flutter analyze | PASS, 0 issues, 43.1 seconds |
| flutter test --reporter expanded | PASS, 1,085 passed / 0 failed / 0 skipped; exit 0, 5m 38s. Exactly one full suite run. Final lines: 05:38 +1085: (tearDownAll); 05:38 +1085: All tests passed! Offline fixture logs also reported uninitialized Supabase/backend unavailable; these were not test failures or hosted-backend evidence. |
| Existing iOS-related test | test/map_p5_presentation_test.dart:271 tests Apple Maps URI with TargetPlatform.iOS. No iOS debugDefaultTargetPlatformOverride found in test/. WO-10 outstanding. |
| Meaning | Windows static/widget baseline for shared Android behavior; no Android device or iOS compile/playback proof |
| Invocation note | Initial sandbox doctor/analyze stalled without output and were interrupted. SDK shared.bat:55 takes an outside-workspace cache lock. Approved rerun produced toolchain/doctor and passing analyze. |
| Android bytes | SHA-256 comparison before/after commands: 77 files before, 77 after, 0 byte changes. Includes the already-modified generated report, preserved as found. |

## 9. Owner dependencies / G0 decisions

| Pending input | Source / effect |
|---|---|
| D1 bundle ID | IOS_PLAN recommends sa.hadayah.streamerApp; owner must fix before generation/store registration. Do not copy Android underscore; builder has not chosen an ID. |
| D2 physical iPhone, iOS 17+ | IOS_PLAN D2; roadmap v1.1:57 requires real-device pass. E3 requires physical iPhone observations. G0 should reconcile D2's simulator alternative with §2 E3; a simulator cannot award E3. |
| D3 first scope | Plan recommends viewer-first discovery/watch/chat/map/profile; no owner answer yet. Roadmap v1.1:44-50 includes later publishing/background parity; current plan defers RTMP/push. Gate native channel return and decide wider studio/background scope. |
| D4 paid Apple enrollment | Roadmap v1.1:59-64 requires account, matching App ID/provisioning, TestFlight. Plan recommends enrollment when WO-9 written. Owner handles Apple/Supabase provider material. |
| D5 macOS CI | Plan recommends Codemagic; owner chooses/connects account/repo and pushes. Pricing/minutes not checked here. CI supplies E2; Windows cannot. |
| D6 target | Recommend iOS 15.0 from §2, subject to owner/auditor decision and native-assets CI verification. |
| Auth URLs / deployed schema | brief/OWNER_ACTIONS.md:10,28-30: owner reviews deployment and final Auth URLs/region. Hosted state/allow-list not inspected. |
| Google branding/restrictions | brief/OWNER_ACTIONS.md:40-41: owner configures final app accounts; existing Android restrictions do not establish iOS behavior. |
| Public privacy/deletion pages, support, counsel | brief/OWNER_ACTIONS.md:8,11,20,24-25 still marks these pending/unverified. No legal/page-availability review in WO-0. |
| Device/store evidence | brief/OWNER_ACTIONS.md:12; roadmap v1.1:57,63-68: owner provides device access, runs matrix, relays evidence and handles signed archive/store submission. No signing material inspected. |
| Stop | WO-0 complete; Windows checks and Android byte comparison passed. Only this report and ledger enter the local commit; G0 pending. D1-D6 not answered by builder. |
