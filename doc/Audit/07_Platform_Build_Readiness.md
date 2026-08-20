---
type: audit
project: Streamer_app
phase: 7 of 8
created: 2026-08-20
status: complete
---

# 🏗️ Phase 7 — Platform Build Readiness (Android + iOS)

**A note on what I could and couldn't do directly this phase:** I have write access to your project files and made real, committed changes to the Android build config (details below). I do **not** have the Flutter SDK or network access in this session's environment — your actual Flutter install lives on your own machine (`C:\Users\User\sru\flutter`, confirmed from your `local.properties`), and generating the iOS platform folder requires running the `flutter` CLI, which I can't do from here. Section 2 gives you the exact commands and file contents to run yourself; I've done everything short of that.

---

## 1. Android — changes applied directly to your project

Three files were edited/added just now:

| File | Change |
|---|---|
| `android/app/build.gradle.kts` | Added conditional release signing (reads `android/key.properties` if present, falls back to debug signing if not — see keystore instructions below); enabled `isMinifyEnabled = true` and `isShrinkResources = true` (R8 code shrinking, was previously off); added `proguardFiles(...)` referencing a new rules file. |
| `android/app/proguard-rules.pro` (new) | Keep-rules for Flutter engine, `webview_flutter`/`webview_flutter_android`, `flutter_vlc_player`, and `google_sign_in` — without these, R8's shrinking can strip classes those plugins reach via reflection, causing release-only crashes that never show up in debug/`flutter run`. |
| `android/app/src/main/res/xml/network_security_config.xml` (new) + `AndroidManifest.xml` | Replaced the blanket `android:usesCleartextTraffic="true"` (Phase 1's VULN-DATA-02) with `false` plus an explicit network security config denying cleartext by default. Also removed the unused `CAMERA` permission (Phase 2 finding — `image_picker` is only ever called with `ImageSource.gallery` in this codebase). |

**None of this changes app behavior today** — the signing change only takes effect once you create `android/key.properties` (see below), and removing an unused permission has no functional effect since nothing called it. Safe to build and test immediately.

### 1a. Generating your real upload keystore (you should run this yourself)

I'm deliberately not generating this for you — a signing keystore's passwords are exactly the kind of credential that shouldn't be invented by an AI session and passed through chat/logs. Run this yourself, in a terminal on your own machine, and keep the resulting file and passwords somewhere safe (a password manager, not just a note) — **losing this keystore later means you can never update your Play Store listing under the same app again**, only publish a new one from scratch:

```powershell
keytool -genkey -v -keystore C:\Users\User\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

It'll ask for a password (choose a strong one, remember it) and some certificate details (name/org — can be anything reasonable, Google doesn't verify these). Then create `android/key.properties` (this file is already covered by `.gitignore`, confirmed — it won't get committed):

```properties
storePassword=<the password you just chose>
keyPassword=<same password, or a separate one if you set one>
keyAlias=upload
storeFile=C:/Users/User/upload-keystore.jks
```

The `build.gradle.kts` change above will automatically pick this up on your next release build — no further edits needed.

### 1b. Application ID — a decision only you can make

`applicationId` is still `com.example.streamer_app` (the Flutter default placeholder) in both the manifest namespace and Gradle config. I left this alone and marked it with a `TODO` comment rather than guessing, because **this becomes permanent the moment you first submit to the Play Store** — changing it afterward means publishing as a brand-new app listing, losing your reviews/install count/ASO history. Pick a real reverse-DNS identifier now (e.g. `sa.com.<yourbrand>.streamerapp`) before your first real build, and update it in three places: `android/app/build.gradle.kts`'s `applicationId`, and (once generated) the iOS bundle identifier should match in spirit if not exactly.

### 1c. The one thing I couldn't verify without a real build

**16 KB memory page size compliance.** Google now requires new/updated apps targeting recent Android versions to support 16 KB page sizes (relevant for newer devices). Recent Flutter/Android Gradle Plugin versions handle this automatically for Flutter's own native code, but this project also depends on **`flutter_vlc_player`** and **`webview_flutter_android`**, both of which ship their own native `.so` libraries — whether *their* native builds are 16 KB-aligned is outside this project's control and outside what a code read can confirm. This will surface (if it's a problem at all) in Google Play Console's automated pre-launch report the first time you upload a build there — worth checking that report specifically for this warning rather than assuming it's fine.

---

## 2. iOS — from scratch, exact runbook for your machine

Confirmed there is no `ios/` folder anywhere in this project. Here's the complete sequence, in order, to go from "doesn't exist" to "ready for Xcode":

### Step 1 — Generate the platform folder
Run this in the `project/` directory on your own machine (where your real Flutter SDK lives):

```powershell
cd "C:\Users\User\Documents\Amir Ob\projects\Ideas\Current\Streamer_app\project"
flutter create --platforms=ios --org <your.reverse.dns.here> .
```

Use the *same* reverse-DNS prefix you picked for Android's `applicationId` in §1b for `--org` (e.g. `sa.com.yourbrand` → produces bundle ID `sa.com.yourbrand.streamerApp` or similar, adjustable after in Xcode). This single command scaffolds the entire `ios/` Xcode project, `Runner.xcworkspace`, `Info.plist`, and `Podfile` from Flutter's own templates — it needs your local Flutter SDK but no network access, so it should run instantly offline.

### Step 2 — `Info.plist` additions
Once generated, add these keys to `ios/Runner/Info.plist` (values drafted in Phase 2, repeated here for convenience):

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Choose a profile photo or banner image from your library.</string>
```

Do **not** add `NSCameraUsageDescription` or `NSMicrophoneUsageDescription` unless you've confirmed the app actually needs them (Phase 2 found no camera usage in code; microphone usage for broadcasting wasn't confirmed either way and needs a quick check of whether "Go Live" ever accesses the device mic directly versus just relaying an external OBS/YouTube source).

If the background-audio question from Phase 2 resolves to "yes, the mini-player should keep playing when backgrounded," also add:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### Step 3 — Privacy Manifest (`PrivacyInfo.xcprivacy`)
Create `ios/Runner/PrivacyInfo.xcprivacy` — Apple will auto-reject submissions missing this if the app (via its own code or a dependency like `shared_preferences`) uses any "required reason" API. Minimal starting template covering what this app is known to use (`UserDefaults` via `shared_preferences`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```
(`CA92.1` = "access info from same-app UserDefaults" — the correct reason code for `shared_preferences`' own on-device storage use in this app.) Once you complete Phase 3's account-deletion and consent-flow work and know exactly what data categories you collect, `NSPrivacyCollectedDataTypes` should be filled in accurately to match your finished App Privacy "nutrition label" answers — leave it empty until then rather than guessing.

### Step 4 — App Transport Security
Should need **zero exceptions** if the Android cleartext fix from §1 reflects real behavior (all traffic is already HTTPS: YouTube Data API, YouTube embeds, OSM tiles). If you hit an ATS error during testing, that's a signal something is quietly using HTTP, not a reason to add a blanket ATS exception — track down the actual URL first.

### Step 5 — Sign in with Apple
Per Phase 3: since Google Sign-In is the only login offered today, Apple's Guideline 4.8 will very likely require adding Sign in with Apple before this can ship on iOS. This means, once the `ios/` project exists: enabling the "Sign in with Apple" capability in Xcode's Signing & Capabilities tab, adding the `sign_in_with_apple` Flutter package, and wiring a second auth path alongside `GoogleAuthService` (which itself needs the Phase 1 auth-bypass fix applied regardless of which login methods exist).

### Step 6 — Apple Developer account & provisioning
Needs your own Apple Developer Program enrollment ($99/year, per your own roadmap doc), an App ID + provisioning profile created in the Apple Developer portal matching the bundle identifier from Step 1, and eventually a signed archive via Xcode (`flutter build ipa --release`) — all of which require a Mac with Xcode, which is outside what either this session or your Windows machine can do. Worth deciding now whether that means borrowing/renting Mac time (a colleague's Mac, a cloud Mac service, or a physical Mac) before the rest of this checklist is otherwise done, so it's not a last-minute scramble.

---

## 3. Summary

| Item | Status after this phase |
|---|---|
| Android signing config | ✅ Wired, needs your real keystore (§1a) |
| Android R8/shrinking | ✅ Enabled |
| Android cleartext traffic | ✅ Fixed |
| Android unused permission | ✅ Removed |
| Android application ID | ⏳ Your decision (§1b) |
| Android 16KB page size | ⏳ Needs verification via a real Play Console upload |
| iOS platform folder | ⏳ Needs `flutter create` run on your machine (§2 Step 1) |
| iOS Info.plist / Privacy Manifest / ATS | 📝 Ready-to-paste content provided (§2 Steps 2–4) |
| Sign in with Apple | ⏳ Not started — needed before iOS submission |
| Apple Developer enrollment + Mac/Xcode access | ⏳ Business/logistics decision, not a code task |
