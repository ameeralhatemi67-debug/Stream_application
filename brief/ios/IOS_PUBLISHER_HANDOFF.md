# W17 publisher handoff — default off, E0 native / E1 Dart

Updated 2026-10-18. IOS_PLAN_V2.md §12 withdrew the W11 dependency. W17 source
is now implemented; it has **not been compiled or run on iOS**. Keep it out of the
viewer release until native compilation and the E3 matrix pass.

## Dependency and build isolation

Flutter stays pinned to 3.41.2 with CocoaPods for Flutter plugins. HaishinKit 2.x
discontinued CocoaPods support; use its SwiftPM products directly in Runner only
after explicit activation. This does not migrate Flutter plugins to SwiftPM or
apply the newer Flutter 3.44 template to the 3.41 shell.

The committed viewer project has three conditional Swift source references, an
optional xcconfig include and conditional AppDelegate registration. Every publisher
Swift file is inside `#if IOS_PHONE_PUBLISHING`. It has **no remote package/product
reference**, no generated publisher config, no base-plist camera/mic key and no
background mode. The Dart bool.fromEnvironment flag defaults false, makes no
publisher channel calls, and preserves the Studio notice. A Dart-only flag mismatch
fails the native isSupported probe before permissions or UiKitView creation. Direct phone-screen setup also checks iOS availability before requesting capture permissions; its narrow error surface is covered in EN/AR.

The opt-in helper attaches exact HaishinKit **2.2.5** (HaishinKit + RTMPHaishinKit)
and its Logboard **2.6.0** dependency, adds the native Swift flag, selects
Info-Publisher.plist and the alternate app privacy manifest. The exact SDK manifest
uses Swift tools 6.0, iOS 15 and Xcode 16.4+; the actual Mac/Xcode integration is
unverified. SwiftPM can resolve other package metadata/transitives even when only
these products are linked; that risk belongs only to the opted-in build.

`project/ios/Publisher/configure.py` changes marked package blocks, three plist
selections and one privacy path, plus one ignored xcconfig. It refuses changed
anchors, existing unrelated SwiftPM integration, escaping paths and unmanaged
xcconfig content. It never edits signing. Host tests cover exact byte restoration
and idempotence. This is configuration evidence, not Xcode parsing or resolution.

## Mac activation and rollback

First complete M1–M3 for the **default viewer**, per MAC_SETUP.md. No SDK activation
is required for those gates. Then, on a reviewable checkout, from project/ (Python
3.9+; install via the owner's normal tool setup if absent):

The helper tests expect the committed disabled project; run them before enabling:

```sh
python3 -m unittest discover -s ios/Publisher -p test_configure.py -v
python3 ios/Publisher/configure.py --enable
(cd ios && pod install)
flutter build ios --simulator --dart-define=IOS_PHONE_PUBLISHING=true
flutter build ios --release --no-codesign --dart-define=IOS_PHONE_PUBLISHING=true
```

Do not commit generated activation, Package.resolved/cache/Pods changes or signing
material during the default viewer gate. Native compile errors follow W13's first
error rule and iteration limit. A free-team **Debug** device build can exercise
camera/mic without adding a paid capability; it cannot exercise Apple sign-in,
APNs, universal links or distribution. On the actual listed phone:

```sh
flutter run --debug -d "$taskPhoneId" --dart-define=IOS_PHONE_PUBLISHING=true --dart-define-from-file=dart_define.local.json
```

The owner supplies a non-secret-listed device ID through the local workflow and
handles signing/trust. Never print the define file, ingest URL or stream key.

Rollback from project/:

```sh
python3 ios/Publisher/configure.py --disable
(cd ios && pod install)
flutter build ios --simulator
```

Also omit the Dart flag from every run/build. The dependency/config/media source is
one separate native commit after Dart commit 63b288f, so the owner can revert that
commit with normal Git review if necessary; the Dart probe handles a missing native
implementation. Do not run a destructive reset/clean as a rollback.

## Native contract

| Boundary | Implementation / limitation |
|---|---|
| Method / event channels | streamer_app/rtmp_publisher; streamer_app/rtmp_publisher/events |
| Preview | streamer_app/rtmp_camera_preview, MTHKView through UiKitView; independent of capture readiness |
| prepare | width/height/videoBitrate plus optional iOS audioOnly; low 640×360/800k, medium 1280×720/2.5M, high 1920×1080/4.5M; microphone required; camera only for video |
| startStream | URL/muted/audioOnly/front(false)/generation; immediate method ACK, live only after server publish acceptance |
| Media | AVCapture → MediaMixer → RTMPStream; H.264 Baseline AutoLevel, 30fps, two-second keyframes, AAC 44.1kHz stereo/128k |
| Audio-only | Detach camera; repeat one cached H.264 IDR with fresh host timing at 1fps; no local recording. E3 must verify YouTube acceptance and sustained playback |
| Background | Detach camera on background, stay audio-only until user explicitly resumes camera; cached IDR uses no background Metal/VideoToolbox encoding. AVAudioSession playAndRecord/videoRecording + background audio; actual OS survival unverified |
| Controls | setMuted, setAudioOnly, setOrientation(orientation degrees), stopStream, dispose; iOS retry watchdog alone passes stopStream {retry: true} to close transport while retaining capture. Ordinary stop releases it. Camera switching remains deferred as in shared engine |
| Events | live/disconnected, outgoing bitrate in bits/sec, normalized audioLevel, audioOnlyChanged; Dart generation and native epoch reject stale status/control work |
| Detection/retry | Connection/stream failure or eight seconds without outgoing bytes closes transport; capture stays active during Dart's bounded recovery so background retry can remain eligible. Dart alone reauthorizes and owns online/time/attempt bounds. User stop, revoked authorization, exhaustion and dispose release capture/session |
| Lifetime | Stop releases capture/audio session and retains prepared quality/static frame for a fresh retry; dispose also clears frame/preview. Resume never automatically re-enables camera |
| Credentials | RTMP/RTMPS URL split in memory only; no URL/name/SDK descriptions in events/logs. SDK loggers use NullAppender to prevent credential diagnostics; compiler warnings are not suppressed |

Backend sender remains `phone_direct`. The iOS channel-connection OAuth guard is
independent and remains in place. No new hosted/backend platform behavior is claimed.

## Native self-review and E3 acceptance

Host source/config checks do not validate Swift type checking, CocoaPods/SPM
coexistence, SDK packaging/manifests, codec behavior, camera/audio hardware,
background survival, TLS/ingest interoperability or iPhone permissions.

On the Mac, first inspect plists/project settings and build with the flag both off
and on. On an iPhone record actual model/OS/commit/language/fixture and observe:

1. EN/AR mic and camera descriptions; grant/refuse/permanently-denied/settings flow.
   Audio-only starts with microphone permission and no camera request/preview.
2. Each quality preset: actual remote video/audio, correct orientation, preview
   replacement, mute/unmute and stop/dispose releasing camera/mic indicators.
3. Audio-only from start, video→audio-only→video with explicit permission, and a
   real static image arriving at the receiver rather than a frozen local preview.
4. Background/lock for a sustained interval, silence/mute, phone call/Siri/audio
   route changes, foreground return without camera resuming, and explicit resume.
5. Wi-Fi/mobile loss/restoration, server refusal, zero-upload stall, fresh authorized
   retry, revoked authorization, episode/time/attempt bounds and user stop during
   connecting/reconnecting. Old callbacks must not restore live after stop.
6. Actual bitrate and RMS, no ingest/credential leakage in device/SDK logs; camera
   switch remains visibly unavailable; independent channel OAuth remains gated.
7. Default viewer rebuilt after disabling: no SDK link, capture permission or
   background mode; Google/guest/playback/map unaffected.

Only actual E2 compilation and E3 device observations can clear these rows. Camera,
microphone and background behavior cannot be awarded E2S. No feature is store-ready.

## Official references checked

- Context7 [HaishinKit 2.1 migration](https://github.com/HaishinKit/HaishinKit.swift/wiki/Moving-from-2.0.x-APIs-to-2.1.0)
  (CocoaPods discontinued), [exact 2.2.5 manifest](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/Package.swift),
  [SDK sources](https://github.com/HaishinKit/HaishinKit.swift/tree/2.2.5/HaishinKit/Sources) and
  [RTMP sources](https://github.com/HaishinKit/HaishinKit.swift/tree/2.2.5/RTMPHaishinKit/Sources).
  Exact-tag MediaMixerOutput/RTMPStream/StreamBitRateStrategy/NetworkMonitorReport were
  read; older Context7 HKStream examples were not copied into this version.
- Context7 [Flutter SwiftPM guidance](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers),
  [iOS platform views](https://docs.flutter.dev/platform-integration/ios/platform-views)
  and [scene migration](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate);
  pinned Flutter 3.41.2 local template retains CocoaPods.
- Context7 [permission_handler iOS](https://github.com/Baseflow/flutter-permission-handler/tree/main/permission_handler#ios),
  [camera key](https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription),
  [microphone key](https://developer.apple.com/documentation/bundleresources/information-property-list/nsmicrophoneusagedescription),
  [background audio](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes).
- Context7 [VideoToolbox](https://developer.apple.com/documentation/videotoolbox/vtcompressionsession-api-collection);
  [CoreMedia retiming](https://developer.apple.com/documentation/coremedia/cmsamplebuffercreatecopywithnewtiming(allocator:samplebuffer:sampletimingentrycount:sampletimingarray:samplebufferout:))
  declaration additionally read from Apple's Markdown reference.
- [Apple privacy manifest data types](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype),
  exact AudioData/PhotosorVideos values verified in Apple's structured documentation
  after Context7 did not return the category table.
- [Logboard 2.6.0](https://github.com/shogo4405/Logboard/tree/2.6.0/Sources/Logboard):
  LBLogger.with/appender and NullAppender.shared read from maintainer source.
