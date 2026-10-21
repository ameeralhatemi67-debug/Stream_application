# W17 publisher handoff — default off, E0 native / E1 Dart

Updated 2026-10-18. IOS_PLAN_V2.md §12 withdrew the W11 dependency. W17 source
is now implemented; it has **not been compiled or run on iOS**. Keep it out of the
viewer release until native compilation and the E3 matrix pass.

## Dependency and build isolation

Flutter stays pinned to 3.41.9 with CocoaPods for Flutter plugins. HaishinKit 2.x
discontinued CocoaPods support; use its SwiftPM products directly in Runner only
after explicit activation. This does not migrate Flutter plugins to SwiftPM or
apply the newer Flutter 3.44 template to the 3.41 shell. The project's
`pubspec.yaml` pins `flutter.config.enable-swift-package-manager: false` to
keep Flutter plugins on CocoaPods even if the Flutter SDK is upgraded. This
does not disable the helper's explicit Runner SwiftPM dependency opt-in.

The committed viewer project has three conditional Swift source references, an
optional xcconfig include and conditional AppDelegate registration. Every publisher
Swift file is inside `#if IOS_PHONE_PUBLISHING`. It has **no remote package/product
reference**, no generated publisher config, no base-plist camera/mic key, no
camera/mic purpose in the viewer's localized InfoPlist.strings and no
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
selections, one privacy path and the two InfoPlist.strings paths (the opt-in
`Runner/PublisherStrings/*.lproj` files carry the camera/microphone purposes),
plus one ignored xcconfig. It refuses changed
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
| Detection/retry | Retry reactivates AVAudioSession, restarts the mixer if needed, calls startCapturing and checks isRunning before connecting. Connection/stream failure or eight seconds without outgoing bytes closes transport. Until the first network report, eight seconds without non-empty audio submissions is the fallback; submissions show capture/feed progress, not remote delivery. Capture stays active during Dart's bounded recovery so background retry can remain eligible. Dart alone reauthorizes and owns online/time/attempt bounds. User stop, revoked authorization, exhaustion and dispose release capture/session |
| Lifetime | Stop releases capture/audio session and retains prepared quality/static frame for a fresh retry; dispose also clears frame/preview. Resume never automatically re-enables camera |
| Credentials | RTMP/RTMPS URL split in memory only; no URL/name/SDK descriptions in events/logs. SDK loggers use NullAppender to prevent credential diagnostics; compiler warnings are not suppressed |

Backend sender remains `phone_direct`. The iOS channel-connection OAuth guard is
independent and remains in place. No new hosted/backend platform behavior is claimed.

Part A source checks: [MediaMixer.swift at 2.2.5](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/Mixer/MediaMixer.swift) exposes actor-isolated `isRunning`, async `startRunning()` and `startCapturing()` (iOS 15 compatible; its annotation restricts tvOS only). [RTMPStream.swift](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/RTMPHaishinKit/Sources/RTMP/RTMPStream.swift) exposes actor-isolated `append(_:when:)` without throws. All native changes remain E0; interruptions and no-monitor behavior require the iPhone matrix.

## Native self-review and E3 acceptance

### W21 API inventory, source verification only (E0 Swift)

Read official tag archives HaishinKit 2.2.5 and Logboard 2.6.0, Flutter 3.41.2
engine headers, and Apple's structured declarations/availability on 2026-10-18.
P = PublisherPipeline.swift, B = HadayahRtmpPublisher.swift, S = PublisherStaticFrame.swift,
A = AppDelegate.swift. "Match" means declaration/source match, never a compiler
or runtime result. SDK actor methods require `await` across actors even when
their declaration is synchronous. Apple C APIs below are synchronous/nonthrowing;
OSStatus results are checked. All listed APIs are available by iOS 15. tvOS-only
availability annotations in MediaMixer do not raise the iOS minimum.

| API | Where used | Verified signature / isolation | Official source | Verdict |
|---|---|---|---|---|
| MediaMixer | P.mixer | `public final actor MediaMixer`, `init(captureSessionMode: CaptureSessionMode = .single, multiTrackAudioMixingEnabled: Bool = false)` | [2.2.5 MediaMixer](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/Mixer/MediaMixer.swift) | Match, actor isolated |
| attachAudio / attachVideo | P.capture, stop, setAudioOnly | `(AVCaptureDevice?, track: UInt8 = 0, configuration: AudioDeviceConfigurationBlock? / VideoDeviceConfigurationBlock? = nil) async throws` | [MediaMixer](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/Mixer/MediaMixer.swift#L154) | Match, `try await` |
| setSessionPreset / setFrameRate / setVideoOrientation | P.capture, orientation | `(AVCaptureSession.Preset)`; `(Float64) throws`; `(AVCaptureVideoOrientation)`, actor methods | [MediaMixer](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/Mixer/MediaMixer.swift#L218) | Match; frame-rate call throws |
| isRunning / startRunning / stopRunning / startCapturing | P.capture, start, stop | `Bool { get }`; `() async`; `() async`; `()`, actor isolated | [MediaMixer](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/Mixer/MediaMixer.swift#L311) | Match; retry restores session/capture, E3 pending |
| addOutput / removeOutput / setAudioMixerSettings | P.capture, preview, stop, setMuted | `(some MediaMixerOutput)` / `(some MediaMixerOutput)` / `(AudioMixerSettings)`, no throws | [MediaMixer](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/Mixer/MediaMixer.swift#L299) | Match, awaited |
| AudioMixerSettings | P.capture, setMuted | `init(sampleRate: Float64 = 0, channels: UInt32 = 0, isMuted: Bool = false, mainTrack: UInt8 = 0, tracks: ... = [:])` | [2.2.5 settings](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/Mixer/AudioMixerSettings.swift#L38) | Match, value type |
| MediaMixerOutput | P conformance | `AnyObject, Sendable`; async track getters; two synchronous `mixer(_:didOutput:...)` callbacks; `selectTrack(_:mediaType:) async` | [protocol](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/Mixer/MediaMixerOutput.swift) | Match; callbacks nonisolated, hop to pipeline actor |
| MTHKView | B.preview, P.preview | `init(frame: CGRect)`; `videoGravity: AVLayerVideoGravity`; MediaMixerOutput conformance | [view](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/View/MTHKView.swift) | Match; MTKView/UI work on MainActor |
| StreamBitRateStrategy / NetworkMonitorEvent / report | P.network observer | `mamimumVideoBitRate: Int`, `mamimumAudioBitRate: Int`; `adjustBitrate(_:stream: some StreamConvertible) async`; status/insufficient/reset; `currentBytesOutPerSecond: Int` | [strategy](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/Stream/StreamBitRateStrategy.swift), [report](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/Network/NetworkMonitorReport.swift) | Match, including SDK misspelling |
| RTMPConnection | P.start, closeTransport | actor; `init(...)` defaults; `connect(_:arguments: (any Sendable)?...) async throws -> RTMPResponse`; `close() async throws`; `status: AsyncStream<RTMPStatus>` | [connection](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/RTMPHaishinKit/Sources/RTMP/RTMPConnection.swift) | Match; one status consumer |
| RTMPStream / RTMPStatus | P.start, status handlers, closeTransport | actor `init(connection: RTMPConnection, fcPublishName: String? = nil)`; `publish(_: String?, type: HowToPublish = .live) async throws -> RTMPResponse`; `close() async throws -> RTMPResponse`; status.code/level are String | [stream](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/RTMPHaishinKit/Sources/RTMP/RTMPStream.swift), [status](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/RTMPHaishinKit/Sources/RTMP/RTMPStatus.swift) | Match |
| setAudioSettings / setVideoSettings / setBitRateStrategy | P.start | `(AudioCodecSettings) throws`; `(VideoCodecSettings) throws`; `((some StreamBitRateStrategy)?)`, actor isolated | [stream](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/RTMPHaishinKit/Sources/RTMP/RTMPStream.swift#L712), [extension](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/Stream/StreamConvertible.swift#L78) | Match |
| AudioCodecSettings / VideoCodecSettings | P.start | `init(bitRate: Int, downmix: Bool = true, channelMap: [Int]? = nil, sampleRate: Float64, format: ... = .aac)`; video initializer accepts videoSize/bitRate/profileLevel/maxKeyFrameIntervalDuration: Int32/expectedFrameRate: Double? with intervening defaults | [audio](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/Codec/AudioCodecSettings.swift#L199), [video](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/Codec/VideoCodecSettings.swift#L129) | Match, argument order/types |
| append sample / audio | P.video, audio, sendStaticFrame | `append(_: CMSampleBuffer)`; `append(_: AVAudioBuffer, when: AVAudioTime)`, actor methods without throws | [stream](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/RTMPHaishinKit/Sources/RTMP/RTMPStream.swift#L726) | Match; audio timestamp update after append checks epoch |
| LBLogger / NullAppender / logger identifiers | B.register | `static with(_: String) -> LBLogger`; mutable `appender: any LBLoggerAppender`; `NullAppender.shared`; module identifier String constants | [logger 2.6.0](https://github.com/shogo4405/Logboard/blob/2.6.0/Sources/Logboard/LBLogger.swift), [null appender](https://github.com/shogo4405/Logboard/blob/2.6.0/Sources/Logboard/NullAppender.swift), [HaishinKit](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/HaishinKit/Sources/Util/Constants.swift), [RTMP module](https://github.com/HaishinKit/HaishinKit.swift/blob/2.2.5/RTMPHaishinKit/Sources/Util/Constants.swift) | Match; mutation on MainActor before SDK work; SDK global thread safety still runtime |
| AVAudioSession.sharedInstance, category/mode/options | P.capture, stop | `class func sharedInstance() -> AVAudioSession`; read-only typed category/mode/categoryOptions | [Apple session](https://developer.apple.com/documentation/avfaudio/avaudiosession) | Match, iOS 3/5/6 |
| setCategory / setPreferredSampleRate / setActive | P.capture, start, stop | `setCategory(_: Category, mode: Mode, options: CategoryOptions = []) throws`; `setPreferredSampleRate(_: Double) throws`; `setActive(_: Bool, options: SetActiveOptions = []) throws` | [category](https://developer.apple.com/documentation/avfaudio/avaudiosession/setcategory(_:mode:options:)), [sample rate](https://developer.apple.com/documentation/avfaudio/avaudiosession/setpreferredsamplerate(_:)), [activation](https://developer.apple.com/documentation/avfaudio/avaudiosession/setactive(_:options:)) | Match, sync throws; iOS 10/6/6. playAndRecord/videoRecording/defaultToSpeaker/allowBluetooth/notifyOthersOnDeactivation available by 15; Bluetooth option deprecated on newer SDK, still available |
| AVCaptureDevice authorization/defaults | P.permission, capture, setAudioOnly | `authorizationStatus(for: AVMediaType) -> AVAuthorizationStatus`; `requestAccess(for:) async -> Bool`; `default(for:) -> AVCaptureDevice?`; `default(_: DeviceType, for: AVMediaType?, position: Position) -> AVCaptureDevice?` | [Apple device](https://developer.apple.com/documentation/avfoundation/avcapturedevice) | Match, iOS 7/async overlay; defaults 4/10; audio/video/back/wide-angle and selected presets available |
| AVAudioPCMBuffer / AVAudioFormat / AVAudioTime | P.audio and callback | `frameLength: AVAudioFrameCount`; optional Int16/Float channel pointer arrays; `format: AVAudioFormat`; `channelCount: UInt32`; `isInterleaved: Bool` | [PCM buffer](https://developer.apple.com/documentation/avfaudio/avaudiopcmbuffer), [format](https://developer.apple.com/documentation/avfaudio/avaudioformat), [time](https://developer.apple.com/documentation/avfaudio/avaudiotime) | Match, synchronous properties, iOS 8; SDK supplies callback buffers |
| AVAudioSession interruption | B.observeLifecycle | `interruptionNotification: NSNotification.Name`; userInfo key AVAudioSessionInterruptionTypeKey; `InterruptionType.began.rawValue: UInt` | [Apple interruption](https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionnotification) | Match, iOS 6; notification callback hops to MainActor |
| VTCompressionSessionCreate / callback | S.make | `(allocator: CFAllocator?, width: Int32, height: Int32, codecType: CMVideoCodecType, encoderSpecification: CFDictionary?, imageBufferAttributes: CFDictionary?, compressedDataAllocator: CFAllocator?, outputCallback: VTCompressionOutputCallback?, refcon: UnsafeMutableRawPointer?, compressionSessionOut: UnsafeMutablePointer<VTCompressionSession?>) -> OSStatus`; callback `(refcon, sourceRefcon, OSStatus, VTEncodeInfoFlags, CMSampleBuffer?) -> Void` | [Apple session functions](https://developer.apple.com/documentation/videotoolbox/vtcompressionsession-api-collection) | Match, C synchronous creation; callback arbitrary thread uses NSLock; iOS 8 |
| VTSessionSetProperty / prepare / encode / complete / invalidate | S.make | `VTSessionSetProperty(_: VTSession, key: CFString, value: CFTypeRef?) -> OSStatus`; prepare(session) -> OSStatus; encode(session,imageBuffer,presentationTimeStamp,duration,frameProperties,sourceFrameRefcon,infoFlagsOut) -> OSStatus; complete(session,untilPresentationTimeStamp: CMTime) -> OSStatus; invalidate(session) -> Void | [Apple VT](https://developer.apple.com/documentation/videotoolbox/vtcompressionsession-api-collection), [property](https://developer.apple.com/documentation/videotoolbox/vtsessionsetproperty(_:key:value:)) | Match, synchronous/nonthrowing C APIs, iOS 8 |
| VT property/profile/force-keyframe constants | P.start, S.make | CFString keys ProfileLevel/AllowFrameReordering/RealTime/ForceKeyFrame and H264_Baseline_AutoLevel; CFBoolean values bridge to CFTypeRef | [compression properties](https://developer.apple.com/documentation/videotoolbox/compression-properties) | Match, iOS 8 |
| FlutterPlugin / FlutterPluginRegistrar | B.register, handle; A registration | `register(with:)`; `handle(_: FlutterMethodCall, result: @escaping FlutterResult)`; messenger(), addMethodCallDelegate(_:channel:), register(_:withId:), registrar(forPlugin:) optional registrar | [Flutter 3.41.2 Plugin.h](https://github.com/flutter/flutter/blob/3.41.2/engine/src/flutter/shell/platform/darwin/ios/framework/Headers/FlutterPlugin.h) | Objective-C signatures match; callbacks wrapped in MainActor.assumeIsolated; Mac importer/isolation check pending |
| Method/Event channels, StreamHandler, FlutterError | B channels/events | channel initializers `(name: String, binaryMessenger: FlutterBinaryMessenger)`; setStreamHandler; onListen(withArguments:eventSink:) / onCancel(withArguments:) -> FlutterError?; FlutterEventSink/FlutterResult `(Any?) -> Void`; error code/message/details; FlutterMethodNotImplemented sentinel | [Channels.h](https://github.com/flutter/flutter/blob/3.41.2/engine/src/flutter/shell/platform/darwin/common/framework/Headers/FlutterChannels.h), [Codecs.h](https://github.com/flutter/flutter/blob/3.41.2/engine/src/flutter/shell/platform/darwin/common/framework/Headers/FlutterCodecs.h) | Match; error payload fixed; no native compile proof |
| FlutterPlatformViewFactory / FlutterPlatformView | B preview types | `create(withFrame: CGRect, viewIdentifier: Int64, arguments: Any?) -> FlutterPlatformView`; `view() -> UIView` | [PlatformViews.h](https://github.com/flutter/flutter/blob/3.41.2/engine/src/flutter/shell/platform/darwin/ios/framework/Headers/FlutterPlatformViews.h) | Match; concrete MainActor UI results; importer check pending |
| FlutterAppDelegate / FlutterImplicitEngineDelegate / bridge | A | UIApplicationDelegate launch callback returns Bool; `didInitializeImplicitFlutterEngine(_:)`; `pluginRegistry: FlutterPluginRegistry`; GeneratedPluginRegistrant.register(with:) generated by Flutter | [AppDelegate.h](https://github.com/flutter/flutter/blob/3.41.2/engine/src/flutter/shell/platform/darwin/ios/framework/Headers/FlutterAppDelegate.h), [Engine.h](https://github.com/flutter/flutter/blob/3.41.2/engine/src/flutter/shell/platform/darwin/ios/framework/Headers/FlutterEngine.h#L456) | Match; generated registrant still requires Mac generation/build |

Additional Apple dependencies used by these APIs: CMSampleBuffer timing copy,
CMSampleTimingInfo/CMTime(value:timescale:), .zero/.invalid and
CMClockGetTime(CMClockGetHostTimeClock()) match [CoreMedia](https://developer.apple.com/documentation/coremedia/cmsamplebuffer-api),
available iOS 4/6. Pixel allocation/lock/base-address/bytes-per-row and ARGB keys
match [CoreVideo](https://developer.apple.com/documentation/corevideo/cvpixelbuffer),
iOS 4; CGContext/CGColor/CoreText drawing are synchronous. UIKit UIApplication
state/lifecycle, UIView layout/windowScene/interfaceOrientation, CGRect/CGSize,
and MTKView-derived preview are used on MainActor; windowScene requires iOS 13.
AVCaptureVideoOrientation is available on 15, deprecated on newer SDKs; no camera
auto-resume was introduced. MainActor.assumeIsolated is synchronous/rethrows
and back-deploys to iOS 13 according to [Apple's declaration](https://developer.apple.com/documentation/swift/mainactor/assumeisolated(_:file:line:)).
No additional SDK mismatch was found by source reading. Swift import/sendability,
generic constraints, linking and SDK availability diagnostics remain unverified.

The [official Swift Windows installer](https://www.swift.org/install/windows/)
is a free public download with no account required to fetch it and no paid Apple enrollment; it requires Windows SDK/Visual C++
dependencies. A Windows `swiftc -frontend -parse -D IOS_PHONE_PUBLISHING` could
check syntax, but cannot check Apple frameworks or iOS linking. Per W21, stop
at that feasibility result: no toolchain installation or parse result is claimed.
The owner must run swiftc/Xcode and both default/opt-in builds on the Mac.

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
