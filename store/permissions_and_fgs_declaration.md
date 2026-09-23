# Android permissions and foreground-service declaration draft

Status: 2026-09-24 code-based text for owner review. No Play Console form, release AAB merged manifest, recording or submission exists. P8B is not accepted.

## Declared behavior

project/android/app/src/main/AndroidManifest.xml declares INTERNET, ACCESS_NETWORK_STATE, CAMERA, RECORD_AUDIO, FOREGROUND_SERVICE, FOREGROUND_SERVICE_CAMERA, FOREGROUND_SERVICE_MICROPHONE and POST_NOTIFICATIONS. RtmpForegroundService is declared with foregroundServiceType camera|microphone and exported=false. It shows an ongoing broadcast notification and uses START_NOT_STICKY. The native RtmpPublisherBridge starts it during broadcaster-initiated RTMP publishing and stops it with the stream. The app declares no location or broad photo-library permission in this manifest.

Camera and microphone rationale: an approved broadcaster chooses phone video or audio-only and starts a live RTMP transmission. Video uses the camera and mic; audio-only uses the mic with a static video source. The permission prompt is contextual in PhoneBroadcastScreen. The RTMP destination is a broadcaster-provided endpoint, commonly YouTube; the app database carries stream metadata rather than the live media. This is implementation description, not physical-device acceptance.

Foreground-service camera/microphone rationale: the ongoing service keeps a started phone broadcast visible and running during app backgrounding/screen lock. It does not start capture itself. If the system interrupts the service or the RTMP connection fails, the stream can stop or reconnect and viewers may lose media; do not promise uninterrupted broadcasting. Android requires matching service types and permissions, plus runtime camera/mic permission. A camera/microphone service generally must start while the app has a visible activity because those permissions are while-in-use. [Android foreground-service types](https://developer.android.com/develop/background-work/services/fgs/service-types) [Android start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)

POST_NOTIFICATIONS is requested so the ongoing broadcast notice can be visible on Android 13 and later; notification denial must not be described as denial of capture. The current notification always says "Camera and microphone are being streamed," even in audio-only mode. Correct that copy before using an audio-only demonstration. Confirm the final merged manifest, permission behavior and OS variants on the release AAB.

Google Play asks Android 14+ apps to declare each foreground-service type in Play Console, describe the functionality and interruption impact, and link a video showing how a user starts each feature. [Play foreground-service declaration guidance](https://support.google.com/googleplay/android-developer/answer/13392821?hl=en-GB) Whether the current feature and evidence satisfy Play review is **for counsel review** and the owner.

## Proposed Play form wording, subject to evidence

- Camera: "An approved broadcaster starts a phone video stream. The app uses the device camera only for that live broadcast and releases it when the stream ends."
- Microphone: "An approved broadcaster starts video or audio-only phone streaming. The app sends live microphone audio to the configured RTMP destination until the broadcast ends."
- Foreground service, camera and microphone: "While a phone broadcast is active, an ongoing notification accompanies camera/microphone streaming if the app moves to the background or the screen locks. Interruption may stop the stream or trigger a reconnect; viewers may experience a gap."
- Notification: "Show the ongoing phone broadcast indicator."

These are draft declarations, not verified claims for submission. The current evidence is emulator/local RTMP and local code/tests. The latest brief/LEDGER.md RESUME block explicitly lacks two physical phones, Google OAuth and authorized YouTube ingest. Do not present desktop broadcasting, same-Wi-Fi Local, private invites, or seamless background/reconnect as accepted release modes.

## Demonstration-video shot list for a later owner recording

1. On a physical supported Android phone, sign in as an approved broadcaster and show the phone mode choice and the contextual camera/mic permission prompts. Keep keys and account details off screen.
2. Start video to an authorized test ingest, show the persistent notification, app background/return and viewer playback on a second device, then stop and show capture/notification cleanup.
3. Repeat for audio-only, including the mic permission and visible interruption behavior. Record denied-permission and system-interruption outcomes honestly.
4. Provide Play review access instructions and a non-secret test account only through the owner's approved submission process. Do not record or publish a real stream key.

The owner must review the release artifact and record actual demonstrations before using this wording. No video was made in this task.
