# Permissions and foreground-service declaration

Status: 2026-11-11, checked against Google's current foreground-service and location pages; section 1a (plugin additions) is new, and section 5 has a new limit. 2026-10-16: ready to paste, but the video in section 3 still has to be recorded by the owner. Text is based on `project/android/app/src/main/AndroidManifest.xml` and `RtmpForegroundService.kt`. Verify against the merged manifest of the final `.aab` before submitting.

## 1. What the manifest declares and why

| Permission | Why the app needs it | When it is requested |
| --- | --- | --- |
| `INTERNET`, `ACCESS_NETWORK_STATE` | Load content, chat, maps and play video; show the offline notice. | Never prompts. |
| `CAMERA` | Phone broadcast with video. | Only when an approved broadcaster opens the phone broadcast screen and chooses video; the app explains first, then the system prompt appears. |
| `RECORD_AUDIO` | Phone broadcast audio (video or audio-only). | Same screen, same way. |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CAMERA`, `FOREGROUND_SERVICE_MICROPHONE` | Keep a started broadcast running with a visible notification while the app is in the background or the screen is locked. | Starts only after the broadcaster taps Go live, with the app on screen. Stops when the broadcast ends. |
| `POST_NOTIFICATIONS` | Show the ongoing broadcast notification, and reminders and organization notices. | Android 13+ system prompt, best-effort; a "no" never blocks capture. |
| `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION` | "Use my location" when picking a venue point. | Only when the user taps that button; foreground only; never in the background. |

Not declared on purpose: storage or media permissions (the system photo picker is used), contacts, background location, `SYSTEM_ALERT_WINDOW`, full-screen intents.

### 1a. What the plugins add (checked 2026-11-11)

Read from the merged manifest of the last release build (2026-10-26, `project/build/app/intermediates/merged_manifests/release/`) and from each plugin's own manifest in the pub cache. Check again on the final `.aab` (section 5 of `brief/fable/ANDROID_PLAY_STATUS.md`).

| Added by | What | Action |
| --- | --- | --- |
| `firebase_messaging` | `WAKE_LOCK`, `com.google.android.c2dm.permission.RECEIVE`, `POST_NOTIFICATIONS`, its services and receivers (not exported, or protected by `c2dm.permission.SEND`) | Keep. Push needs them. No Play form. |
| androidx core | `sa.hadayah.streamer_app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (signature level) | Keep. Internal to the app. |
| `geolocator_android` | A service with `foregroundServiceType="location"` | **Removed** in the app manifest with `tools:node="remove"` (2026-11-11). The app never starts it, so Play Console must not see a location foreground service. |
| `image_picker_android` | A file provider and the photo picker module trigger | Keep. No permission. |
| `share_plus`, `url_launcher_android` | A file provider, a receiver and a web view activity, none exported | Keep. |
| androidx profile installer | A receiver protected by `android.permission.DUMP` | Keep. Standard. |

Hardware features: `android.hardware.camera`, `camera.autofocus` and `microphone` are declared `required="false"` (2026-11-11). Without that, the `CAMERA` and `RECORD_AUDIO` permissions make Play hide the app from devices without a rear camera or microphone, although most people only watch.

## 2. Play Console: Foreground service permissions form

Play Console > Policy > App content > **Foreground service permissions**. Declare two types. Google's help page (answer 13392821, read 2026-11-11) asks for each type: a description of the feature, the impact on the user if the task is delayed or stopped, a video link, and a use case from Google's list. Pick the use cases that describe streaming from the camera and capturing audio while the app is in the background, as the list words them on the day. The notification wording was made mode-neutral on 2026-10-16: it reads "You're broadcasting live. Your phone is streaming live video or audio."

### Camera (`FOREGROUND_SERVICE_CAMERA`)

- **Describe the feature that uses this type:** "Approved broadcasters stream a live lecture from their phone camera to their own YouTube channel. The service keeps the camera capture and the stream running if the broadcaster switches apps or the screen locks, and shows an ongoing notification for as long as the camera is in use."
- **Impact if the system delays or stops it:** "The live broadcast would freeze or end for all viewers, and the lecture would be lost. Viewers see a "We'll be right back" message and the broadcaster can reconnect within two minutes."
- **How a user starts it:** "Only the broadcaster, by choosing Go Live > phone camera, granting camera permission and tapping Go Live while the app is open. The service starts after that tap and stops when the broadcast ends."
- **Does a user-visible notification show?** Yes, ongoing.

### Microphone (`FOREGROUND_SERVICE_MICROPHONE`)

- **Describe the feature:** "Approved broadcasters send live audio from the phone microphone, with video or as an audio-only broadcast. The service keeps audio capture running in the background or with the screen locked, and shows an ongoing notification."
- **Impact if stopped:** "Viewers lose the lecture audio, which is the main content, and the broadcast ends if the connection is not restored within two minutes."
- **How a user starts it:** "Same as camera: the broadcaster taps Go live (video or audio only) while the app is open, after granting microphone permission."

### Answers to likely questions

- "Does the service start while the app is in the background?" No. It starts from a user tap on a visible screen.
- "Does it run without the user knowing?" No. The notification is always shown, and capture indicators of the system (camera and microphone dot) show.
- "Do you record the audio or video?" No. The phone sends the media directly to the broadcaster's YouTube live ingest. We do not receive, record or store it.

## 3. The demo video (the owner records it)

Google asks for a link, usually an unlisted YouTube video, of about 60 to 120 seconds on a real phone, showing the feature the permission is for. Record the phone screen with the system recorder (swipe down > Screen record), and keep the stream key and RTMP address off screen.

Use a reviewer or test broadcaster account that is approved, connected to a test YouTube channel.

| # | What to show | Say or caption |
| --- | --- | --- |
| 1 | Open the app signed in as the test broadcaster. Tap **Go Live** and choose the phone camera (**Open Camera**). | "An approved broadcaster opens Go Live." |
| 2 | Tap video. The app's explanation appears, then the system **camera** and **microphone** prompts. Tap Allow. | "The app asks for camera and microphone only here." |
| 3 | The camera preview shows. Tap **Go live**. | "The broadcaster starts the stream." |
| 4 | Pull down the notification shade: **You're broadcasting live** is visible. Show the system camera and microphone indicator dots. | "While live, a notification and the system indicators are always visible." |
| 5 | Press Home, open another app for 10 seconds, then lock the screen for 10 seconds, unlock. | "The broadcast keeps running in the background and with the screen locked." |
| 6 | On a second device (or YouTube Studio on a laptop), show the live broadcast still playing. | "Viewers keep watching." |
| 7 | Return to the app and tap **End**. Show that the notification disappears. | "Ending the stream stops the service and the notification." |
| 8 | Repeat steps 3 to 7 quickly in **audio-only** mode (choose the audio broadcast type before opening the phone screen). Show the notification again. | "Audio-only works the same way, sending only the microphone." |

Checklist before uploading:
- The video has the app name visible at least once.
- No stream key, no real email address, no other person's face.
- Set it to **Unlisted**, copy the link into both type sections of the form.
- Read it once as if you had never seen the app.

## 4. Other permission-related declarations

- **Location (not background):** no special declaration form is required for foreground location. If Play asks, answer "used when the user taps *use my location* to place a venue pin". The merged manifest has no `ACCESS_BACKGROUND_LOCATION` and, since 2026-11-11, no location foreground service. Coming: Google's sensitive-permissions policy (answer 16558241) says apps that target Android 17 (API 37) must use the Android location button for one-time location, effective 27 January 2027. This app targets 36, so it applies only when the target moves to 37.
- **Photo and video permissions policy:** the app does not request `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` or `READ_EXTERNAL_STORAGE`. The Android photo picker returns a single file per tap.
- **Exact alarms, full-screen intents, SMS, call log, accessibility, VPN, `QUERY_ALL_PACKAGES`:** none.
- `<queries>` lists `https`/`http`/`vnd.youtube` view intents and the YouTube package only, to open links and videos.

## 5. Known limits to say honestly if asked

- The service is declared as both camera and microphone even in audio-only mode. This is safe because the phone broadcast screen asks for camera and then microphone permission before any setup, in every mode (`phone_broadcast_screen.dart`, `_confirmPresetAndSetup`), and stops if either is denied. The consequence: a broadcaster who denies the camera cannot do an audio-only broadcast either.
- Interruption by the system (battery saver, a phone call) can stop the stream; the app reconnects for up to two minutes, then the server ends the broadcast.
- Not yet tried on a phone (2026-11-11): a reconnect while the app is in the background or the screen is locked. On a disconnect, `RtmpPublisherBridge.releaseStream()` stops the foreground service, and the next attempt starts it again. Android 12 and later refuse to start a foreground service from the background, and Android 14 and later refuse a camera or microphone one. So that reconnect may fail until the broadcaster opens the app. Test it before recording the video, and do not show a background reconnect in it.
