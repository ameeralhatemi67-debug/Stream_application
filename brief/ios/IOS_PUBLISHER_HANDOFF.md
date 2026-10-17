# W17 publisher handoff — dependency blocked

Date: 2026-10-17. This is source research, not a native publisher implementation.

## Entry condition

IOS_PLAN_V2.md §9 permits W17 on Windows **once W11 is done**. W11 remains PARTIAL:
ESC-2 needs an authorized backend Apple-token revocation flow and owner credentials;
ESC-3 needs legal/support routing and complete bilingual privacy content outside this
work order. The launch scope also has no E2 native compile result yet.

Keep the W8 iOS availability gate, W3 viewer-only permission set and W6 Firebase gate.
Do not enable phone capture, attach a streaming SDK or add background audio until
the W17 entry condition is satisfied. Account and out-of-scope blockers are already
recorded in the ledger; W18's independent specification can proceed.

This corrects W16's proposed “next: W17 implementation” scheduling note. No source
change, native build or native attempt was made for W17.

## Existing contract to port after the dependency clears

The Android implementation remains the reference. Read, never rewrite:
`project/android/app/src/main/kotlin/sa/hadayah/streamer_app/streaming/RtmpPublisherBridge.kt`.

| Boundary | Existing contract |
|---|---|
| Method channel | `streamer_app/rtmp_publisher` |
| Event channel | `streamer_app/rtmp_publisher/events` |
| Platform preview | `streamer_app/rtmp_camera_preview`; AndroidView today, iOS needs its own registered UIView/platform view |
| Preparation | `prepare` with width, height and videoBitrate; readiness waits for mounted preview |
| Publishing | `startStream` with URL, muted, audioOnly and Dart connection generation |
| Controls | `stopStream`, `dispose`, `setMuted`, `setAudioOnly`, `setOrientation` |
| Camera switch | Existing shared engine and Android bridge explicitly defer it; do not invent parity |
| Events | Shared engine accepts connection states, error, actual bitrate and audio level; late generation events must be ignored |
| Recovery | Shared Dart engine owns authorization checks, online checks and bounded reconnect; do not layer unbounded SDK retries |
| Secrets | Never send ingest URLs, keys or SDK error descriptions containing them to logs, events or evidence |

The backend sender discriminator is `phone_direct`, not `android`
(`supabase/migrations/20260925100000_broadcast_sessions_and_live_controls.sql:94`).
This read-only finding does not authorize backend edits or prove hosted behavior.
The independent channel-connection OAuth gate must remain; phone publishing does
not imply that iOS channel OAuth is supported.

## Official API research already checked

- [HaishinKit 2.2.5 release](https://github.com/HaishinKit/HaishinKit.swift/releases/tag/2.2.5)
  and [exact package manifest](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/Package.swift):
  Swift tools 6.0, iOS 15.0; separate `HaishinKit` and `RTMPHaishinKit` products.
  Evaluate those two products only. Flutter plugin integration remains CocoaPods;
  a native Swift package dependency is a separate Xcode decision.
- [MediaMixer](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/Mixer/MediaMixer.swift)
  and the exact-tag source establish actor-based capture and media output.
  Verify the repository paths and APIs again when implementing; do not copy older
  NetStream examples into 2.x.
- [Flutter iOS platform views](https://docs.flutter.dev/platform-integration/ios/platform-views):
  register custom plugins/platform-view factories through
  `didInitializeImplicitFlutterEngine` for this Flutter 3.41 scene-based shell.
  Preserve GeneratedPluginRegistrant registration.
- [permission_handler iOS integration](https://github.com/Baseflow/flutter-permission-handler/tree/main/permission_handler#ios):
  camera/microphone require both their Info.plist descriptions and the corresponding
  `PERMISSION_CAMERA=1` / `PERMISSION_MICROPHONE=1` CocoaPods definitions.
- [Apple camera key](https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription),
  [microphone key](https://developer.apple.com/documentation/bundleresources/information-property-list/nsmicrophoneusagedescription)
  and [background modes](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes)
  justify the future permission/background additions, not additions to today's viewer build.

Context7 supplied the framework/plugin references; the maintainer's exact 2.2.5
manifest and source were also read. No native dependency was added or resolved.

## Risks requiring real Mac/device proof

HaishinKit suspends camera video input when backgrounded. Audio-only parity needs
an independently verified static-image video path plus microphone capture; a frozen
foreground preview is not proof. Verify AVAudioSession interruptions, mute, start/stop,
orientation, background/lock behavior, network loss and recovery without camera
resuming unexpectedly. Do not log SDK credentials while diagnosing failures.

Protect the default viewer build while experimenting. Before any v1 inclusion,
require actual E2 compilation and E3 iPhone evidence for video, audio-only/static
image, background audio and authorized reconnect. Revisit privacy disclosures for
camera/microphone uploads and SDK manifests. No E0 publisher, E2 or E3 claim is made here.

Next: W18 spec. Resume W17 only after W11 is closed or the owner/manager explicitly
changes that dependency; use the Mac compile-fix rules and current reference source.
