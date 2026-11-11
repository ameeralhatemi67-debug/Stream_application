# Android and Google Play: where the app stands

Written 2026-11-11 for the owner. Branch `fable/lantern-skin`. Nothing was built, pushed or deployed.

Words used the same way throughout:
- **your key**: the file `upload-keystore.jks` that `brief\launch\make_upload_key.ps1` creates. It signs the website APK and becomes the Play signing key.
- **the app bundle**: the `.aab` file you upload to Play.
- **the build step**: the day Claude (or you) builds the app bundle and runs the checks in section 5.

---

## 1. What is ready

- The Android setup meets Google's target level (API 36) and should meet the 16 KB rule. The last release APK's native libraries pass Google's 16 KB check.
- The manifest asks only for what the app uses. No background location, no photo-library permission, no location foreground service.
- In-app account deletion exists. The web deletion page now meets Google's rule with an email request.
- The Play build can never offer the website APK. It only opens its own Play listing.
- Drafts for every Play Console form are in `store/` and match the code as of today.

---

## 2. What you must do, in order

### Step 1. Create your key

1. Open PowerShell yourself (not through Claude). Go to the repository folder.
2. Run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File brief\launch\make_upload_key.ps1
   ```
3. Type a password of 12 or more characters. It is never shown and never goes to chat.
4. The script creates `%USERPROFILE%\hadayah-keys\upload-keystore.jks` and `project\android\key.properties`. It prints the SHA-1 and SHA-256 fingerprints.
5. Copy `upload-keystore.jks` and the password to two safe places, for example a password manager and an encrypted USB drive. Google cannot give you a copy later. If you lose it, nobody can update the app.
6. If a website APK was already shared, it must be signed with this same key. Check it: `apksigner verify --print-certs <the APK>` must print the same SHA-256 as the script.

### Step 2. Choose the version number

The number after `+` in `project/pubspec.yaml` (now `1.0.0+1`) must be higher than every APK you have shared from the website. Otherwise Play cannot install over those APKs. Ask Claude to set it before the build.

### Step 3. Build the app bundle

From `project/`:
```powershell
flutter build appbundle --release --dart-define-from-file=dart_define.local.json --dart-define=DISTRIBUTION=play
```
The file is `build\app\outputs\bundle\release\app-release.aab`. The build stops if `key.properties` is missing, or if `DISTRIBUTION` is not `play`. That is on purpose.

### Step 4. Run the secret scan

From `project/`:
```powershell
node ..\brief\tools\scan_build_secrets.mjs build\app\outputs\bundle\release\app-release.aab
```
It must print `RESULT: clean`. Then run the checks in section 5.

### Step 5. Set up signing in Play Console, before any upload

1. Play Console > your app > Test and release > App integrity > App signing.
2. Google now gives new apps a Google-generated key by default. Change it: choose to **use your own key**, the option that exports and uploads a key from a Java keystore.
3. Download Google's PEPK tool and run the command Play Console shows, with your key. Upload the file it makes.
4. Decide on the upload key (see section 6, decision 1).
5. Check the developer verification page in Play Console. The package `sa.hadayah.streamer_app` and your key must show as registered. This keeps the website APK installable when Google enforces verification in more countries in 2027.

### Step 6. Upload to the closed track

1. Test and release > Testing > **Closed testing** > Create track (or use "Closed testing - Alpha").
2. Countries: include every tester's country.
3. Testers: add your Google Group's email address.
4. Create a release, upload the app bundle, add release notes in Arabic and English, and send it for review.
5. Optional but useful: first upload the same app bundle to **Internal testing** and install it on your own phone from the Play link. That is the first time the Play-signed app runs.

### Step 7. Fill each Play Console form

All are under Policy > App content. Copy from these drafts:

| Form | Copy from |
|---|---|
| Privacy policy | `https://live.hedayh.org.sa/privacy.html` |
| App access (reviewer account) | `store/reviewer_access.md` section 2. Prepare the account first (section 1 there). |
| Ads | "No ads". |
| Content rating (IARC) | `store/data_safety.md` Part 3, "Content rating" row. |
| Target audience | 18 and over, or 13 and over if your lawyer agrees. Never under 13. |
| Data safety | `store/data_safety.md` Parts 1 and 2. |
| Account deletion | `https://live.hedayh.org.sa/delete-account.html`, and "the app has in-app deletion". |
| Foreground service permissions | `store/permissions_and_fgs_declaration.md` section 2, and the video from section 3. |
| Photo and video permissions | Not used. The app does not ask for them. |
| Government, financial, health, news | No, none, none, no. |
| Store listing | `store/listing_draft_ar_en.md`. Screenshots: `store/screenshot_shot_list.md`. |

Before you fill the deletion URL: push the new `project/web/delete-account.html` so the live page shows it. Pushing `master` deploys the website.

### Step 8. Invite testers

Follow `brief/launch/06_CLOSED_TEST_TESTERS.md`. Recruit 15 to 20 people with Android phones, not 12. Send message 2 only after Google approves the closed-test release.

### Step 9. The rule for production

This applies to a personal developer account created after 13 November 2023:
- At least **12 testers** must be opted in to the closed test.
- They must stay opted in for the last **14 days in a row**.
- A tester who leaves and joins again starts their 14 days again.
- Then: Dashboard > **Apply for production**. Google asks about your closed test, your app, and how you know it is ready. Review usually takes 7 days or less.
- Keep notes of tester feedback and what you changed. The form asks for them.

Google's page says nothing about organization accounts. If your Play Console dashboard shows the testing requirement, it applies to you.

---

## 3. Google's requirements, checked today

Every page was opened on 2026-11-11. Most pages show no "last updated" date. "Meets" means the code meets the rule as read; section 5 lists what a build or a phone must still confirm.

| # | Requirement | What Google says today | Source | Status for this app |
|---|---|---|---|---|
| 1 | Target API level | New apps and updates must target API 36 since 31 August 2026. The extension ran to 1 November 2026. Existing apps must target 35 to reach new users. No later date is announced on the page. | [developer.android.com/google/play/requirements/target-sdk](https://developer.android.com/google/play/requirements/target-sdk), [support answer 11926878](https://support.google.com/googleplay/android-developer/answer/11926878) | **Meets.** targetSdk 36 (Flutter 3.41.9). `build.gradle.kts` refuses a build below 36. |
| 2 | 16 KB memory pages | From 1 February 2027, updates that do not support 16 KB pages cannot be released (apps targeting 35+, 64-bit devices). AGP 8.5.1+ with NDK r28+ is aligned by default. Check with `zipalign -c -P 16`, `bundletool dump config`, `check_elf_alignment.sh` or `llvm-objdump`. | [developer.android.com/guide/practices/page-sizes](https://developer.android.com/guide/practices/page-sizes) | **Meets on the last APK.** AGP 8.11.1, NDK 28.2. The 2026-10-26 release APK passes zipalign; every `.so` has LOAD alignment 2\*\*14 or more. **The final app bundle still needs the check** (section 5). |
| 3 | Foreground service, camera and microphone | Declare the type, hold `FOREGROUND_SERVICE_CAMERA`/`_MICROPHONE`, and have `CAMERA`/`RECORD_AUDIO` granted before `startForeground()`. A camera or microphone service cannot start while the app is in the background, with few exceptions. Only `dataSync` and `mediaProcessing` have the 6-hour limit. Play Console asks, per type: a description, the impact if delayed, a video link, and a use case from its list. | [service types](https://developer.android.com/develop/background-work/services/fgs/service-types), [background start](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start), [timeout](https://developer.android.com/develop/background-work/services/fgs/timeout), [support answer 13392821](https://support.google.com/googleplay/android-developer/answer/13392821) | **Meets in code.** Manifest `camera\|microphone`, both permissions, `startForeground` with both types, started after a tap on Go live. **Owner action:** the declaration and video. **Cannot tell:** a reconnect while the app is in the background (section 6, risk 3). No boot receiver, so the boot rule does not apply. |
| 4 | Camera, microphone, location; background location; disclosure | Ask for sensitive permissions in context and only for current features. Background location needs a declaration and a prominent in-app disclosure before the prompt. A location foreground service is allowed only as part of a user action. From 27 January 2027, apps targeting API 37 must use the Android location button for one-time location. | [support answer 16558241](https://support.google.com/googleplay/android-developer/answer/16558241), [answer 9799150](https://support.google.com/googleplay/android-developer/answer/9799150), [answer 11150561](https://support.google.com/googleplay/android-developer/answer/11150561), [location permissions](https://developer.android.com/develop/sensors-and-location/location/permissions) | **Meets.** No `ACCESS_BACKGROUND_LOCATION`. Location is read once on tap, with an explanation first. The geolocator plugin's unused location service is now removed. The location-button rule applies only when the target moves to 37. |
| 5 | Photo and video permissions | Apps targeting 33+ may ask for `READ_MEDIA_IMAGES`/`_VIDEO` only if the system picker is not enough, with a declaration. Full compliance since 28 May 2025. The page describes no declaration for an app that asks for neither. | [support answer 14115180](https://support.google.com/googleplay/android-developer/answer/14115180), [photo picker](https://developer.android.com/training/data-storage/shared/photopicker) | **Meets.** No media permission in the manifest or the last merged manifest. `image_picker` uses the system photo picker. No declaration needed. |
| 6 | Notification permission | Declare `POST_NOTIFICATIONS` and ask in context. A foreground service runs without it; its notice then shows in the Task Manager, not the shade. | [notification permission](https://developer.android.com/develop/ui/views/notifications/notification-permission) | **Meets.** Asked on the broadcast screen, when the user turns on a reminder, and on a first follow. A "no" never blocks broadcasting. |
| 7 | Data safety form | "Collect" means sent off the device. "Share" means sent to a third party; service providers and user-started transfers are not sharing. Ephemeral data is still declared. Firebase lists the app version and the Firebase installation ID for Cloud Messaging. | [support answer 10787469](https://support.google.com/googleplay/android-developer/answer/10787469), [firebase.google.com/docs/android/play-data-disclosure](https://firebase.google.com/docs/android/play-data-disclosure) | **Owner action.** `store/data_safety.md` updated today. |
| 8 | Account deletion | An in-app path, and a web resource that loads, names the app or developer as on the listing, features the deletion path, and lets people request deletion without the app. An email address or a form is acceptable. Deactivation is not deletion. | [support answer 13327111](https://support.google.com/googleplay/android-developer/answer/13327111), [User Data policy 10144311](https://support.google.com/googleplay/android-developer/answer/10144311) | **Meets after you push the web change.** In-app: Settings > Account & Data > Delete My Account (`delete_own_account`). Web: email request, now with the operator's name, the address in plain text, what support does, and retention. |
| 9 | Privacy policy, UGC, Families | Privacy policy linked in Play Console and in the app, public, not a PDF, with contact, data, sharing, security, retention. UGC: terms accepted before posting, cannot be skipped; in-app report and block for users **and content**; ongoing moderation. Families policy applies only if children are a target audience. | [answer 9859455](https://support.google.com/googleplay/android-developer/answer/9859455), [answer 10144311](https://support.google.com/googleplay/android-developer/answer/10144311), [UGC 9876937](https://support.google.com/googleplay/android-developer/answer/9876937), [UGC guidance 12923286](https://support.google.com/googleplay/android-developer/answer/12923286), [Families 9893335](https://support.google.com/googleplay/android-developer/answer/9893335), [target audience 9867159](https://support.google.com/googleplay/android-developer/answer/9867159) | Privacy: **meets**, with one YouTube gap (row 14). UGC: **meets once the migration `20261111120000_content_reports.sql` is applied** (updated 2026-11-12): chat messages can be reported and users blocked, and a broadcast or a channel can be reported in all three designs. A single recording is reported through its channel. Families: **owner action**: choose 18+ or 13+. |
| 10 | Content rating (IARC) | Every app needs a rating; unrated apps are removed. Answer honestly and again whenever features change. Social and chat features must be declared. The pages say nothing special about religious content. | [answer 9898843](https://support.google.com/googleplay/android-developer/answer/9898843), [answer 188189](https://support.google.com/googleplay/android-developer/answer/188189) | **Owner action.** Answers in `store/data_safety.md` Part 3. |
| 11 | Closed test for new personal accounts | 12 testers opted in for the last 14 consecutive days, then apply for production. Review usually takes 7 days or less. The page covers personal accounts created after 13 November 2023 and says nothing about organization accounts. | [answer 14151465](https://support.google.com/googleplay/android-developer/answer/14151465), [answer 9845334](https://support.google.com/googleplay/android-developer/answer/9845334) | **Owner action.** Section 2, steps 6, 8 and 9. |
| 12 | Play App Signing | New apps get a Google-generated key by default; you can choose your own key instead, before the first release. Keys: RSA 2048 or more, valid past 22 October 2033. Google cannot return the key. A lost upload key can be reset; a lost own signing key cannot. | [answer 9842756](https://support.google.com/googleplay/android-developer/answer/9842756), [app signing](https://developer.android.com/studio/publish/app-signing) | **Owner action.** The script makes RSA 2048, valid about 27 years. Choose "use your own key" (step 5). |
| 13 | Android developer verification | Started 30 September 2026 in Brazil, Indonesia, Singapore and Thailand, for certified devices on Android 7+. Worldwide from 2027. A developer on and off Play uses Play Console; Play registers most Play apps automatically, and one package can have more than one key. | [developer.android.com/developer-verification](https://developer.android.com/developer-verification), [Play Console guide](https://developer.android.com/developer-verification/guides/google-play-console), [FAQ](https://developer.android.com/developer-verification/guides/faq) | **Owner action.** Check the registration in Play Console (step 5). |
| 14 | Updates outside Play; YouTube terms | An app may not update itself except through Play, and may not download code from elsewhere. YouTube: never use "YouTube" in the app name; the privacy policy must say the app uses YouTube API Services and link Google's privacy policy; link the YouTube Terms; no overlays in front of the player; player at least 200 by 200 px. | [Device and Network Abuse 16559646](https://support.google.com/googleplay/android-developer/answer/16559646), [YouTube developer policies](https://developers.google.com/youtube/terms/developer-policies), [required minimum functionality](https://developers.google.com/youtube/terms/required-minimum-functionality), [branding](https://developers.google.com/youtube/terms/branding-guidelines) | Play build: **meets** (`app_release_service.dart` lets the Play build open only its Play listing; no install permission). YouTube: **gap**: `privacy.html` links Google's privacy policy but does not say "YouTube API Services" or link the YouTube Terms (the in-app terms and the listing do). **Cannot tell:** the audio room draws its own stage over the player, and organization rooms float speakers over the video. |
| 15 | Android 16 behaviour (target 36) | Edge-to-edge cannot be turned off. Predictive back is on: `onBackPressed` is not called. On screens 600 dp and wider, orientation and resize limits are ignored (temporary opt-out ends with target 37). Jobs that run beside a foreground service count against job quotas. | [behavior-changes-16](https://developer.android.com/about/versions/16/behavior-changes-16), [behavior-changes-all](https://developer.android.com/about/versions/16/behavior-changes-all), [behavior-changes-15](https://developer.android.com/about/versions/15/behavior-changes-15) | **Meets in code; device check owed.** No edge-to-edge opt-out in `styles.xml`; `android16_layout_test.dart` covers insets. `MainActivity` does not override back. Portrait locks in the live and broadcast screens are ignored on tablets (layouts were widget-tested). No WorkManager. |

---

## 4. What changed, file by file

| File | Change | Why |
|---|---|---|
| `project/android/app/src/main/AndroidManifest.xml` | `uses-feature` camera, camera autofocus and microphone with `required="false"`. | The `CAMERA` and `RECORD_AUDIO` permissions otherwise make them required, and Play hides the app from devices without them. Most people only watch. |
| same | `android:allowBackup="false"` and `android:dataExtractionRules`. | Shared preferences hold the Supabase session, the device ID used for the one-broadcaster rule, and Firebase's registration. Android's backup guide says not to back up device IDs and push tokens. `allowBackup` alone does not stop device-to-device transfer on Android 12+. |
| same | Removes `com.baseflow.geolocator.GeolocatorLocationService` with `tools:node="remove"`. | The plugin declares a `location` foreground service the app never starts. Play Console would see a location foreground service and ask about it. `getCurrentPosition()` does not use the service. |
| `project/android/app/src/main/res/xml/data_extraction_rules.xml` (new) | Excludes every app folder from cloud backup and device transfer. | Same reason. |
| `project/android/app/proguard-rules.pro` | Removes the `flutter_vlc_player` keep rules; relabels the Play services rules. | VLC and `google_sign_in` are no longer dependencies. |
| `project/android/app/src/main/res/xml/network_security_config.xml` | Comment only: RootEncoder and RTMPS instead of VLC. | It described a removed plugin. |
| `project/android/app/build.gradle.kts` | Comment and error message point to `make_upload_key.ps1`. | They pointed to the stale audit report. |
| `project/web/delete-account.html` | Names the operator; shows the support address and what to write; says what support does next; lists what is kept and for how long (logs 30 days, backups about 90 days, from `privacy.html` section 7); the two public "TO CONFIRM" notes are now HTML comments. | Google's deletion rule (row 8). No backend change. |
| `store/data_safety.md` | Preacher data, Firebase's own list, backup off, RTMPS, the merged permission list. | The draft was from 2026-10-16. |
| `store/permissions_and_fgs_declaration.md` | New section 1a (what each plugin adds), the form's four parts, the 2027 location-button rule, the untested background reconnect. | Row 3 and 4. |
| `store/ugc_moderation_evidence.md` | Google's current UGC rules and the missing report path. | Row 9. |
| `doc/Audit/07_Platform_Build_Readiness.md` | A dated "current state" block at the top. | The report was from August. |
| `brief/launch/01_OWNER_STEPS.md` | Organization-account note; the default Google-generated key; the SHA-1 step no longer feeds an API key; Firebase is done. | Stale against today's pages and the ledger. |
| `brief/launch/03_CLAUDE_REMAINING_WORK.md` | 16 KB result on the last APK; a merged-manifest check item. | Build-step checklist. |
| `brief/launch/05_APK_RELEASE.md` | Signing default and developer verification facts. | Rows 12 and 13. |

App behaviour is unchanged, with one exception you should know: because backup is off, a user who moves to a new phone or reinstalls signs in again and sets language and design again.

### Suggestions not made (they need `project/lib` or a backend change)

1. **Report a stream, recording, channel or profile.** Done on 2026-11-12 for a broadcast and a channel, in all three designs, with an admin list; it needs the migration `20261111120000_content_reports.sql`. Not done: a Report button on a single recording.
2. **Keep the foreground service across a reconnect.** `RtmpPublisherBridge.releaseStream()` stops the service on every disconnect. Keeping it until the broadcast really ends would let a background reconnect work.
3. **Privacy policy, YouTube wording.** Add one sentence to `privacy.html`: "Hadayah Live uses YouTube API Services", with links to the YouTube Terms of Service and Google's privacy policy.
4. **Broadcast notification.** It uses the full-colour launcher icon (Android shows a plain square) and English text only. The monochrome icon the push notifications use would fit.
5. **A real deletion form.** Today the web page opens an email. A form would need a small public endpoint (for example a Vercel function or a Supabase function with a captcha) that stores the request and emails support. Not needed for Google's rule.

---

## 5. Checklist for the build step

Run from `project/` after step 3. `$BT` is the path to Google's `bundletool` jar (from github.com/google/bundletool releases). `$SDK` is `D:\app\Android\Sdk`.

**A. The build itself**
- [ ] The release build finishes, including Android lint (`lintVitalAnalyzeRelease`). The new `data_extraction_rules.xml` and the `tools:node="remove"` line are new to lint.

**B. 16 KB alignment**
- [ ] `java -jar $BT dump config --bundle=build\app\outputs\bundle\release\app-release.aab | Select-String alignment` prints `PAGE_ALIGNMENT_16K`.
- [ ] Make a universal APK and check it:
  ```powershell
  java -jar $BT build-apks --bundle=build\app\outputs\bundle\release\app-release.aab --output=build\hadayah.apks --mode=universal
  Copy-Item build\hadayah.apks build\hadayah-apks.zip; Expand-Archive build\hadayah-apks.zip build\hadayah-apks -Force
  & "$SDK\build-tools\36.1.0\zipalign.exe" -c -P 16 -v 4 build\hadayah-apks\universal.apk | Select-String "\.so|Verification"
  ```
  Last line: `Verification successful`.
- [ ] Every `arm64-v8a` and `x86_64` library has LOAD alignment `2**14` or more:
  ```powershell
  Copy-Item build\hadayah-apks\universal.apk build\universal.zip; Expand-Archive build\universal.zip build\universal -Force
  Get-ChildItem build\universal\lib\arm64-v8a, build\universal\lib\x86_64 -Filter *.so | ForEach-Object { $_.Name; & "$SDK\ndk\28.2.13676358\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-objdump.exe" -p $_.FullName | Select-String LOAD }
  ```
  Without `--ks`, bundletool signs the universal APK with the debug key. That is fine for this check and the smoke test, not for sharing.

**C. Merged manifest**
- [ ] `java -jar $BT dump manifest --bundle=build\app\outputs\bundle\release\app-release.aab | Select-String "uses-permission|uses-feature|foregroundServiceType|allowBackup|dataExtractionRules|exported=\"true\""`
- [ ] Permissions are exactly: `INTERNET`, `ACCESS_NETWORK_STATE`, `CAMERA`, `RECORD_AUDIO`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CAMERA`, `FOREGROUND_SERVICE_MICROPHONE`, `POST_NOTIFICATIONS`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, `WAKE_LOCK`, `com.google.android.c2dm.permission.RECEIVE`, `sa.hadayah.streamer_app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. Anything else goes into `store/` before upload, or is removed.
- [ ] The only `foregroundServiceType` is `camera|microphone`. No `location`.
- [ ] The three `uses-feature` lines show `required="false"` (bundletool prints it as `android:required="false"` or `0`).
- [ ] `allowBackup` is false and `dataExtractionRules` is set.
- [ ] Exported components are only: the two launcher aliases, `MainActivity`, the two Firebase receivers (protected by `c2dm.permission.SEND`) and the profile-install receiver (protected by `DUMP`).
- [ ] `versionCode` is higher than every website APK (`... --xpath=/manifest/@android:versionCode`).

**D. Smoke test on a phone or emulator** (install with `java -jar $BT install-apks --apks=build\hadayah.apks`)
- [ ] Starts, welcome screen, guest feed, map, lessons, a recorded lecture plays, Settings > About shows the version.
- [ ] Google sign-in returns to the app.
- [ ] "Use my location": the app explains, then the system asks; a pin appears.
- [ ] Phone broadcast with video: camera and microphone prompts, notification visible, Home, lock 10 s, unlock, still live, End removes the notification.
- [ ] Same in audio-only mode.
- [ ] Deny the notification permission: broadcasting still works.
- [ ] Turn the network off during a broadcast with the **screen locked**, turn it on within a minute. Note whether it reconnects (risk 3).
- [ ] Android 16 device or emulator: back gesture from a pushed page and from the root; status and navigation bars do not cover buttons.
- [ ] Tablet emulator (600 dp or wider), Android 16: rotate the live room and the broadcast screen.
- [ ] Emulator with no rear camera (AVD setting "Back camera: None"): the app installs and runs, and opening the phone broadcast shows an error, not a crash.
- [ ] A push notification arrives and opens its page.
- [ ] Reinstall: the app starts signed out (backup is off).
- [ ] If anything crashes only in release, read the stack trace for a missing class and add a keep rule (`proguard-rules.pro`).

**E. Secret scan:** `RESULT: clean` (step 4).

---

## 6. Risks for review, most serious first

1. **Report for a broadcast or a channel needs the migration.** The button is in all three designs since 2026-11-12. Until the migration `20261111120000_content_reports.sql` is applied, it answers "could not be sent", and a reviewer who tries it sees a failure. *Do:* apply the migration before you submit, then send one test report and clear it.
2. **The reviewer cannot reach the features.** Most features need sign-in, an approved broadcaster and a connected YouTube test channel; organizations are switched off on the backend. *Do:* section 1 of `store/reviewer_access.md`, all of it, before you submit. Turn the organization switch on for review, or remove organizations from the listing text.
3. **Foreground service declaration.** Google wants a video of the user starting the broadcast and the notification. A reconnect with the screen locked may fail, because the service stops on a disconnect and Android forbids starting it again from the background. *Do:* record the video as in `store/permissions_and_fgs_declaration.md` section 3, without a background reconnect. Test risk 3 at the build step. Fix with suggestion 2 if it fails.
4. **Signing key choice.** If you accept Google's default key, Play cannot update website APK installs; every APK user must uninstall. *Do:* step 5 before the first upload to any track.
5. **Closed-test count.** If fewer than 12 testers stay opted in, the 14 days do not complete. *Do:* recruit 15 to 20, and check the count every few days.
6. **YouTube terms.** The privacy policy lacks the "uses YouTube API Services" sentence and the YouTube Terms link. The audio room covers the player with its own stage; YouTube forbids overlays in front of the player. This matters most for Google's OAuth verification and YouTube's API compliance review, less for Play. *Do:* suggestion 3 now. Ask Claude to review the audio stage against YouTube's minimum functionality page.
7. **Data safety mismatch.** A form that declares less than the app collects is a policy violation. *Do:* copy `store/data_safety.md` as written, then compare with the merged manifest at the build step.
8. **Deletion by email.** Google accepts an email path, but the page now promises a reply, an ownership check when needed, deletion within 30 days and an email when done. *Do:* make sure someone reads `livesupport@hedayh.org.sa` and follows that.
9. **Target audience and chat.** Users chat with strangers. Google says chat-with-strangers apps must not target children. *Do:* choose 18+ (or 13+ with your lawyer's yes), and answer the IARC chat questions with yes.
10. **Tablet and Android 16 layout.** Portrait locks are ignored on tablets, and edge-to-edge is forced. Widget tests pass; no device run yet. *Do:* the tablet and Android 16 rows in section 5 D.

---

## Decisions for you

1. **Upload key.** Use your key for uploads too (simpler: one file to protect), or create a second key just for uploads (Google's advice: the two "should be different", and a lost upload key can be reset). Recommendation: one key for now; a separate upload key can be added later.
2. **Target audience:** 18+ or 13+.
3. **The deletion promise:** confirm support can follow the steps on the deletion page within 30 days, then push the page.
4. **Version code** for the first Play upload (above every website APK).
5. **Report button before submitting** (risk 1): built on 2026-11-12 after you said yes. What is left is your approval to apply the migration.
6. **Organizations during review:** switch on, or leave them out of the listing.
