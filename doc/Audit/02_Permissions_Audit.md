---
type: audit
project: Streamer_app
phase: 2 of 8
created: 2026-08-20
status: complete
---

# 🔑 Phase 2 — Permissions Audit (Android + iOS)

**Method:** Compared what `AndroidManifest.xml` actually declares against what the code in `lib/` actually calls. iOS can't be checked the same way yet because **the `ios/` platform folder doesn't exist in this project at all** (confirmed by listing `project/` — only `android/`, `web/`, `windows/` are present). Section 2 below documents what will need to be added the moment that platform is generated (Phase 7).

---

## 1. Android — current manifest vs. actual usage

| Permission (as declared) | Declared? | Actually used in code? | Verdict |
|---|---|---|---|
| `INTERNET` | Yes | Yes (HTTP calls, WebView, YouTube embeds) | ✅ Correct, keep |
| `ACCESS_NETWORK_STATE` | Yes | Plausible (connectivity checks for offline fallback) | ✅ Keep |
| `CAMERA` | Yes | **No** — grepped the whole `lib/` tree for `ImageSource.camera`; every `image_picker` call found (`apply_step_2_media.dart:53,79`) uses `ImageSource.gallery` only | 🟠 **Remove or justify.** An unused permission is a real problem at review time: Google Play's Data Safety questionnaire and Apple's App Privacy questions both ask you to declare *why* each permission/capability is present, and "app requests camera access but the binary never opens the camera" is exactly the kind of mismatch reviewers flag, and it needlessly worries privacy-conscious users who check permissions before installing. Either remove `CAMERA` entirely (if gallery-only upload is intentional) or add an in-app "Take Photo" option so the permission is actually justified. |
| `READ_EXTERNAL_STORAGE` (≤ SDK 32) | Yes | Yes, via `image_picker` on older Android | ✅ Correctly scoped with `maxSdkVersion="32"` (Android 13+ uses scoped `READ_MEDIA_IMAGES` instead, already present below) |
| `READ_MEDIA_IMAGES` | Yes | Yes | ✅ Correct for Android 13+ |
| **`ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`** | **No** | **No — confirmed not needed.** No `geolocator`/`location` package in `pubspec.yaml`, no `LocationPermission` or `getCurrentPosition()` call anywhere in `lib/`. All map coordinates are picked by tapping a static `flutter_map` widget, not read from device sensors. | ✅ **Correctly absent.** This directly contradicts what `doc/roadmap to publishing.md` Phase 6 describes ("`ACCESS_FINE_LOCATION` with runtime rationale dialog") — that roadmap section describes a planned future feature (e.g. "nearby streams" proximity alerts from `new feature list.md`), not the current app. If that feature ships, this permission needs adding then, with a proper runtime rationale dialog — don't add it speculatively before the feature exists. |
| `POST_NOTIFICATIONS` (Android 13+) | **No** | No push notification backend exists (confirmed — no FCM, no `firebase_messaging`, no native push plugin in `pubspec.yaml`) | ✅ **Correctly absent for what exists today.** Needed only when/if the FCM backend from the feature backlog is actually built (`doc/new feature list.md` §1, unchecked). Don't add prematurely. |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | **No** | The app *does* have background/PiP audio playback (`FloatingStreamMiniPlayer`, audio-only live mode, `wakelock_plus`) | 🟠 **Likely a real gap, not a false positive.** Unlike location/notifications above, this one is worth double-checking in Phase 6/7: if the mini-player is meant to keep audio playing while the app is backgrounded or the screen is locked, Android 8+ requires a properly declared and typed foreground service (`mediaPlayback` type on Android 14+) or playback will simply be killed by the OS a few seconds after backgrounding. `wakelock_plus` alone only prevents the *screen* from sleeping while the app is foregrounded — it does not create a foreground service and won't keep audio alive once the user leaves the app. Recommend verifying actual current behavior (does audio survive backgrounding today on a real device?) before deciding whether to add this. |
| `usesCleartextTraffic="true"` (app-level, not a permission but sits in the same manifest) | Yes | — | 🔴 Carried over from Phase 1 security findings — flagged again here because it's the kind of thing Google Play's automated pre-launch report explicitly calls out under "Security" and can delay review. |

### Net effect
The manifest is actually **narrower than your own roadmap doc assumes**, not broader — good news for minimizing permission-related store friction, but it also means the location/notification features described elsewhere in your docs as "done" or "needed for launch" are not yet wired up permission-wise. One real over-ask exists (`CAMERA`) and one likely under-ask exists (foreground service for background audio) that needs a device check, not a doc read, to resolve.

---

## 2. iOS — nothing exists yet, here's what Phase 7 will need to add

Since there is no `ios/` folder, none of the below exists today. Listing it now so Phase 7 (platform build readiness) has a ready checklist instead of starting from zero, and so you can see the shape of the work involved in generating and configuring the iOS target.

**`Info.plist` usage-description strings needed**, mapped to the feature that requires each one:

| Key | Required because of | English string (draft) | Arabic string (draft) |
|---|---|---|---|
| `NSPhotoLibraryUsageDescription` | `image_picker` gallery access (avatar/banner upload) | "Choose a profile photo or banner image from your library." | "اختر صورة الملف الشخصي أو صورة الغلاف من مكتبة الصور لديك." |
| `NSCameraUsageDescription` | Only needed **if** `CAMERA` permission item above is kept and a take-photo option is added; otherwise omit entirely | — | — |
| `NSMicrophoneUsageDescription` | Only if the app ever accesses the mic directly (RTMP/audio broadcast source) — worth confirming in Phase 6 whether broadcasting audio is device-mic-based or purely an external OBS/YouTube ingest the app just plays back | TBD pending Phase 6 confirmation | TBD |
| `NSLocationWhenInUseUsageDescription` | Not currently needed (see Android section above) — add only if/when a real geolocation feature ships | — | — |

**Other iOS-specific requirements to build in from day one of generating the platform** (detailed further in Phase 7, flagged here so they're not forgotten):
- `PrivacyInfo.xcprivacy` (Apple's Privacy Manifest) — mandatory since Apple started enforcing it for apps using any "required reason" API (e.g. `UserDefaults`, disk space APIs used by `shared_preferences` and `flutter_vlc_player`'s caching). Missing this can cause an **automatic App Store Connect rejection before a human reviewer even looks at the app.**
- App Transport Security (ATS) — iOS's default is the opposite of Android's current cleartext setting: ATS blocks non-HTTPS by default. Once the cleartext-traffic fix from Phase 1 is done, iOS should need no ATS exceptions at all — worth treating that as a forcing function to do the Android fix properly rather than adding blanket ATS exceptions to match today's lax Android config.
- `UIBackgroundModes` → `audio` if the background-audio question above resolves to "yes, this needs to keep playing" — the iOS equivalent of the Android foreground-service gap.

---

## 3. Runtime permission UX (not just manifest presence)

Not fully auditable without a device/emulator run, but worth flagging for Phase 6: Android 13+ and iOS both expect the *rationale* to be shown to the user contextually (right before the OS prompt, not on cold start of the app) with a clear explanation of why. This project has `feature_in_progress_modal.dart` as a pattern for graceful "not yet" states — the same care should apply to whichever permission prompts do get added later, rather than firing them all at first launch.

---

## 4. Summary of actions

1. **Remove `CAMERA` permission** (or add a real take-photo flow to justify it) — quick fix, cleans up both Play Console and future Apple privacy declarations.
2. **Verify background audio survival** on a real Android device with the app backgrounded/screen locked; add `FOREGROUND_SERVICE_MEDIA_PLAYBACK` + a properly typed foreground service if it doesn't currently survive.
3. **Do not add** location or notification permissions speculatively — only when those backlog features are actually built, each with its own runtime rationale.
4. Fix Android cleartext traffic (Phase 1) before iOS work starts, so no ATS exceptions are needed to match it.
5. When Phase 7 generates the iOS project, build `Info.plist` strings and `PrivacyInfo.xcprivacy` in from the start rather than retrofitting them after a rejection.




----
we need to discuss this, this is my idea: 
### Stage 1: The $0 Launch Phase _(0 to 50,000 Users)_

- **Database & Auth**: Supabase Free Tier ($0/mo).
- **Video & Bandwidth**: YouTube Embed / Live ($0/mo).
- **Notifications**: Firebase Cloud Messaging ($0/mo).
- **What it costs**: **$0.00 / month**.
- **Effort to maintain**: Minimal.

---

### Stage 2: The Paid Pro Upgrade _(50,000 to 200,000 Users)_

When your app starts gaining significant traction or generating subscription/sponsorship revenue, you upgrade with a **single click in the Supabase dashboard**:

#### How the upgrade works:

- **No Code Changes**: You do not change a single line of Flutter code.
- **Click "Upgrade to Pro" ($25/mo)**:
    - Storage increases from **1 GB →→ 100 GB+**.
    - Database size increases from **500 MB →→ 8 GB+ (auto-scaling)**.
    - Active users increase to **100,000+ MAU**.
    - Realtime messages increase to **5,000,000+ messages/month**.
    - Automatic **Daily Backups & 7-day Point-in-Time Recovery (PITR)** are activated.

---

### Stage 3: Adding Private Native Video Streaming _(Replacing YouTube)_

When you want your own private, ad-free, unbranded video player with custom paywalls or zero YouTube branding:

#### How the upgrade works:

- We simply update `AbstractVideoPlayer` to connect to dedicated low-cost live video clouds:
    - **Cloudflare Stream** _(~$1 per 1,000 minutes watched — industry's cheapest)_, OR
    - **AWS Interactive Video Service (IVS)** _(ultra-low latency sub-second live streaming)_.
- **Flutter Impact**: Our video architecture already has `StreamSourceType.cloudHls` and `StreamSourceType.localRtmp` built in! You just supply the new streaming URL and it works immediately.

---

### Stage 4: Enterprise & Saudi Sovereign Cloud _(500k+ Users & Government/Corporate Orgs)_

When large Saudi educational institutions, universities, or government ministries join your platform and require data stored 100% inside the Kingdom of Saudi Arabia under the **Saudi Personal Data Protection Law (PDPL)**:

#### How the upgrade works:

- Because Supabase and PostgreSQL are **100% Open Source**, you don't stay locked into any US cloud provider:
    - You can deploy your entire database, Auth, and Realtime cluster using Docker/Kubernetes directly onto **Google Cloud Dammam Region (`me-central2`)** or **Oracle Cloud Riyadh/Jeddah**.
    - In your Flutter app, you only change **one line** (your `Supabase.initialize(url: 'https://api.yourcustomsaudiserver.com')`).  


note: we are currntly only going to build Stage 1: The $0 Launch Phase _(0 to 50,000 Users)_