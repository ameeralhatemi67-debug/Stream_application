# 01 — Owner steps before the Google Play launch

Written 2026-10-10. This file covers only what **you** must do (accounts, keys, money, legal, Play Console). Testing is in [02_TESTING_PLAN.md](02_TESTING_PLAN.md). Claude's engineering work is in [03_CLAUDE_REMAINING_WORK.md](03_CLAUDE_REMAINING_WORK.md).

Tick each box when it is done. Never paste a password, keystore, service-account JSON or client secret into chat, git or a screenshot.

---

## The waiting times (start these first)

Some steps take days or weeks and you cannot speed them up. Start them in week 1, then do everything else while you wait.

| Step | Typical wait | Section |
|---|---|---|
| Play Console identity check | a few days | 2 |
| D-U-N-S number (only for an organization account) | up to ~30 days | 2 |
| Google OAuth verification for the YouTube scope | ~2–8 weeks (estimate) | 3 |
| Closed test: 12 testers for 14 days in a row (only for a new personal account) | 14+ days | 8 |
| Lawyer review | depends on the lawyer | 9 |

---

## 0. Decisions to make first

- [ ] **Account type: personal or organization.**
  - *Personal:* $25, your government ID, fast to open. A personal account opened after November 13, 2023 **must** run a closed test with at least 12 testers for 14 days in a row before it can publish.
  - *Organization:* needs a registered entity and a D-U-N-S number. It is exempt from the 12-tester rule and shows an organization name as the developer, which fits a platform like Hadayah.
- [ ] **Organization broadcasting at launch: on or off.** Recommended: launch with it **off**, run the 3-show pilot privately, and switch it on later from Admin → Safety. If you want it on at launch, the full organization test section in 02 becomes a release gate.
- [ ] **Reminders and push notifications at launch: in or hidden.** They need a Firebase project (section 4). If you don't set Firebase up, tell Claude to hide the reminder bell for v1.0.
- [ ] **Production backend.** Decide whether Supabase project `zkkmfjsjouqzibvnzkau` (streamer_app) *is* production. Its region can't be changed later without a new project, and its region matters for the Saudi PDPL (cross-border data).
- [ ] **Launch countries.** Saudi Arabia only, GCC, or worldwide.
- [ ] **Store category.** Suggested: *Education* (lectures). Alternatives: *Video Players & Editors*, *Social*.

---

## 1. Domain, support email and public pages

Google sign-in verification requires the privacy policy to be on the **same domain** as the app's home page. Right now the privacy page is on `ameeralhatemi67-debug.github.io` and the web app is on `stream-application-ten.vercel.app`. These are two different domains, so verification would fail.

- [ ] **Buy a domain** (recommended), for example `hadayah.app` or `hadayah.sa`, and point it at the Vercel project (Vercel → Project → Settings → Domains). This fixes the domain problem and looks professional in the store.
  - No domain? Then host the privacy and delete-account pages on the Vercel app itself, so everything is on `stream-application-ten.vercel.app`.
- [ ] **Create a support email** on that domain (for example `support@hadayah.app`), or a dedicated Gmail. Your personal address becomes public in the store listing and in the privacy policy.
- [ ] **Verify the domain in Google Search Console** (needed by the OAuth consent screen): Search Console → Add property → follow the DNS or HTML-file steps.
- [ ] **Publish 3 public pages on that domain.** Claude prepares the text and HTML (see 03); you approve and publish.
  1. Home page: a short description of the app and a link to the store.
  2. Privacy policy, in Arabic and English.
  3. **Account deletion page.** Google Play requires a web page where a user can ask to delete their account and data *without reinstalling the app*. A draft exists at `project/web/delete-account.html`.
- [ ] Open all three URLs on your phone, signed out, and confirm they load.
- [ ] Tell Claude the final URLs so the app's `AppIdentity` and the store docs can be updated.

---

## 2. Google Play Console developer account

1. [ ] Go to <https://play.google.com/console/signup> and sign in with the Google account that will **own** the app long term. Don't use a throwaway account.
2. [ ] Choose **personal** or **organization** (decision 0).
3. [ ] Pay the one-time $25 fee.
4. [ ] Complete **identity verification** (government ID; the organization route also needs the D-U-N-S number and an organization website).
5. [ ] Verify the **contact phone number and email** that Play asks for.
6. [ ] Add a second admin user if someone else will help (Users and permissions). Give them only what they need.
7. [ ] Only if you will ever sell anything: set up a payments profile. Not needed for a free app.

---

## 3. Google Cloud: sign-in verification, API keys and quota

These are in the Google Cloud project that holds the YouTube OAuth client (the one whose callback is `https://zkkmfjsjouqzibvnzkau.supabase.co/functions/v1/channel-authorization`).

### 3a. OAuth consent screen and verification (blocks real users from connecting YouTube)

The app asks for `https://www.googleapis.com/auth/youtube.force-ssl`. Google classes it as a **sensitive scope**. Until it is verified, only accounts you add as "test users" can connect a channel, and they see an "unverified app" warning.

- [ ] Google Cloud Console → **Google Auth Platform → Branding**: app name (منصة هدايه / Hadayah), logo, support email, home page URL, privacy policy URL, terms URL, authorized domain (from section 1).
- [ ] **Data Access**: keep only the scopes the app really uses: `openid`, `email`, `profile` and `youtube.force-ssl`. Do **not** add `youtube`, `youtube.readonly` or `youtube.upload` next to `force-ssl`; that is a known rejection reason.
- [ ] Write the **justification**: "Broadcasters connect their own YouTube channel so the server can create the live broadcast and stream, bind them, start, end and check the stream on the broadcaster's behalf." Claude will draft the full text (03).
- [ ] Record the **demo video** (unlisted YouTube link). It must show:
  - the app name and OAuth client ID
  - the full Google consent screen
  - every place the app uses the YouTube API (connect channel → go live → end → status)

  Claude will write the script (03).
- [ ] **Audience → Publish app** (move from "Testing" to "In production"), then **submit for verification**. Reply quickly to Google's emails; each round of questions restarts the wait.
- [ ] Until it is approved, keep adding your pilot broadcasters as test users (maximum 100).

### 3b. Replace and restrict the YouTube API key

The old key is still in git history, so treat it as leaked.

*Changed 2026-10-26 (ADR-017):* phones no longer carry a YouTube key. They read YouTube through the website's `/api/youtube`, like the web. A downloadable APK can be unpacked, and a phone key restricted to Android apps would not have worked anyway: the app does not send the headers Google checks.

- [ ] APIs & Services → Credentials → delete the old phone key, or restrict it to nothing.
- [ ] Keep one **server key** for the Vercel function (API restriction = YouTube Data API v3, no application restriction), stored only in Vercel's Production environment variables as `YOUTUBE_API_KEY`.
- [ ] Remove `YOUTUBE_API_KEY` from `project/dart_define.local.json`. The build no longer reads it, and the secret scan fails if a second Google key ever appears in a build.

### 3c. YouTube quota and terms

- [ ] APIs & Services → YouTube Data API v3 → **Quotas**. The default is 10,000 units per day. Creating, binding and ending broadcasts costs units for every show. If you expect many shows a day, file the **quota extension form**. That includes a YouTube API Services compliance review, so read the [YouTube API Services Developer Policies](https://developers.google.com/youtube/terms/developer-policies) first.

---

## 4. Firebase (only if reminders and push are in v1.0)

**Detailed click-by-click version: [04_FIREBASE_REMINDERS_SETUP.md](04_FIREBASE_REMINDERS_SETUP.md).** It also covers the reminder schedule (Vault + cron) and the end-to-end test.

No Firebase project exists yet, so no reminder or push can reach a phone today.

1. [ ] <https://console.firebase.google.com> → **Add project**. Use the same Google Cloud project as above if you like.
2. [ ] **Add an Android app**, package `sa.hadayah.streamer_app`. Download nothing into git. You only need the values in step 4.
3. [ ] **Add a Web app** (for Chrome push).
4. [ ] Copy these **public** values. They are safe to put in the build and in Vercel:
   - `FIREBASE_API_KEY`
   - `FIREBASE_APP_ID` (Android and web have different app IDs; Claude needs both)
   - `FIREBASE_MESSAGING_SENDER_ID`
   - `FIREBASE_PROJECT_ID`
5. [ ] Project settings → **Cloud Messaging → Web configuration → Generate key pair**. This is `FIREBASE_WEB_VAPID_KEY` (public).
6. [ ] Project settings → **Service accounts → Generate new private key**. This JSON file is **secret**. Do not send it to anyone.
7. [ ] Supabase dashboard → Edge Functions → **Secrets**, add:
   - `FIREBASE_SERVICE_ACCOUNT_JSON` = the whole JSON content
   - `FIREBASE_PROJECT_ID`
8. [ ] Add the public values from steps 4–5 to:
   - `project/dart_define.local.json` (for the phone build), and
   - Vercel → Project → Settings → Environment Variables (Production), then redeploy.
9. [ ] Delete the downloaded JSON file from your Downloads folder once it is saved in Supabase.

---

## 5. Supabase (hosted project `zkkmfjsjouqzibvnzkau`)

Checked by Claude on 2026-10-10:
- All 80 migrations are already applied.
- 4 functions are live.
- The broadcast-recovery job is running.
- **Missing:** the organization notification function, the reminder job, the organization notification job and the reminder Vault secrets.

- [ ] Edge Functions → Secrets: confirm these exist:
  - `YOUTUBE_OAUTH_CLIENT_ID`, `YOUTUBE_OAUTH_CLIENT_SECRET`, `YOUTUBE_OAUTH_CALLBACK_URL`
  - `PUBLIC_APP_ORIGIN` (your final web domain, no path)
  - `BROADCAST_RECONCILE_KEY`
- [ ] Add `ORG_EVENTS_DISPATCH_KEY`: a new long random value. Generate it in a terminal with:
  ```bash
  node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
  ```
- [ ] Authentication → URL Configuration:
  - **Site URL** = your final web domain.
  - **Redirect URLs** include the web domain and the Android callback (`<your app scheme>://login-callback`). Claude will give you the exact scheme value.
- [ ] Authentication → Providers → Google: confirm the Google sign-in client is the production one, with branding from section 3a.
- [ ] Authentication → **Email**: set the sender name and turn on rate limits (Supabase's built-in email sender is for testing only; add custom SMTP if you send email).
- [ ] **Approve Claude** to:
  - deploy the `dispatch-organization-events` function
  - run the reminder and organization-event schedule SQL
  - add the stale-live-flag sweep job

  (Claude can do these through the Supabase connector, but only with your yes.)
- [ ] Billing: the free plan pauses inactive projects and has no daily backups. **Move to the Pro plan before launch**, so the backend never sleeps and you get backups.
- [ ] Database → Backups: confirm daily backups are on.

### 5b. Email to preachers (added 2026-10-29, ADR-020)

Preachers get emails for their invitation, their application's decision, lessons added for them, approved or declined requests, cancellations, moves and a reminder the day before. The app queues them; nothing is sent until a sender is set up. Until then the admin log's Emails view says the emails are waiting.

- [ ] **Needs the domain from section 1.** An email service only sends to anyone from a domain you own and have verified.
- [ ] Create a **Resend** account (resend.com; the free plan sends 3,000 emails a month, 100 a day). Domains → Add domain → add the DNS records it shows at your domain's registrar → wait until it says Verified.
- [ ] API keys → create a key with **sending access** only. Do not paste it in chat or in any file.
- [ ] Supabase → Edge Functions → Secrets: add
  - `RESEND_API_KEY` = the key
  - `EMAIL_FROM` = for example `Hadayah <lessons@your-domain>`
  - optional `EMAIL_REPLY_TO` = the support email from section 1, so preachers can reply
  - optional `PUBLIC_SITE_URL` = your final web address (default: the current Vercel address)
- [ ] **Approve Claude** to apply migration `20261029103349`, deploy `dispatch-preacher-emails` and run its `cron.sql`.
- [ ] Test: add yourself as a preacher with your own email, tick "Email him his link now", and check your inbox (and spam folder).

---

## 6. App signing key (upload key)

Release builds refuse to run until this exists.

*2026-10-26:* if the app is first shared as an APK from the website ([05_APK_RELEASE.md](05_APK_RELEASE.md)), this key signs every APK install, so it must also become the **Play app signing key**: in Play Console choose "use my own key" and upload it, or APK users will have to uninstall to move to Play.

**Easiest way (2026-10-16):** run `powershell -ExecutionPolicy Bypass -File brief\launch\make_upload_key.ps1` from the repo root in your own terminal. It asks for the password (never typed into chat), creates `%USERPROFILE%\hadayah-keys\upload-keystore.jks` and `project\android\key.properties`, and prints the SHA-1 for section 3b. The manual steps below do the same thing.

1. [ ] In a terminal (Java's `keytool` comes with Android Studio):
   ```bash
   keytool -genkey -v -keystore C:/Users/User/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Choose a strong password and write it down in a password manager.
2. [ ] Create `project/android/key.properties` (it's already git-ignored):
   ```properties
   storePassword=<your password>
   keyPassword=<your password>
   keyAlias=upload
   storeFile=C:/Users/User/upload-keystore.jks
   ```
3. [ ] **Back up** `upload-keystore.jks` and the password in two safe places (for example a password manager and an encrypted USB drive). If you lose it you can ask Google to reset it, but that is slow.
4. [ ] Get the upload key's SHA-1 for section 3b:
   ```bash
   keytool -list -v -keystore C:/Users/User/upload-keystore.jks -alias upload
   ```
5. [ ] Tell Claude it's ready. Claude then builds the signed release bundle (`.aab`) and scans it for secrets.

---

## 7. Create the app in Play Console and fill "App content"

Play Console → **Create app**: name *منصة هدايه* (max 30 characters), default language (Arabic or English), App, Free, accept the declarations.

### 7a. App content (Policy → App content). Every item must be green.

- [ ] **Privacy policy**: the URL from section 1.
- [ ] **App access**: much of the app needs sign-in, so the reviewer needs a way in. Give step-by-step instructions plus a **dedicated reviewer Google account** (not yours) that is an approved streamer with a test YouTube channel. Also mention that Guest mode works without sign-in. Claude will draft the text.
- [ ] **Ads**: "No, my app does not contain ads".
- [ ] **Content rating**: fill the IARC questionnaire honestly. User-generated content and live chat: yes. Users can interact: yes. Shares location: answer per Claude's check of the location feature.
- [ ] **Target audience**: choose 18+ (or 13+ if lawyer approves). **Do not include under-13**; that brings in the stricter Families policy.
- [ ] **Data safety**: answer from `store/data_safety.md`. Claude will update it to the current code first (location, Firebase, bookmarks, organizations and reminders have changed it). Make sure the account deletion URL is included.
- [ ] **Account deletion**: the delete-account web URL, and confirm the app has in-app deletion (Settings → Delete account).
- [ ] **Foreground service declaration**: declare **camera** and **microphone** (live broadcasting keeps running when the screen locks). For each one:
  - a short description
  - the user impact if it were delayed ("the live stream would stop")
  - a **video link** showing a broadcast going on with the app in the background and the notification visible

  Claude will write the text and the video script; you record it.
- [ ] **Government app**: No. **Financial features**: None. **Health**: None. **News app**: No.
- [ ] **Photo and video permissions**: the app doesn't request broad media access. Confirm "not used".
- [ ] **User-generated content**: confirm you have:
  - reporting
  - blocking
  - moderation
  - published terms that ban harmful content

  These all exist; evidence is in `store/ugc_moderation_evidence.md`.

### 7b. Store listing (Grow → Store presence → Main store listing). Do Arabic and English.

- [ ] App name (≤30 characters), short description (≤80), full description (≤4000). Draft: `store/listing_draft_ar_en.md`. Claude will refresh it so it promises only features that exist.
- [ ] App icon 512×512: `store/assets/icon_512.png`.
- [ ] **Feature graphic 1024×500** (needs to be made).
- [ ] **Phone screenshots**: 2–8 per language, portrait. Take them from the release build with real content: feed, live room, map, chat, profile, settings.
- [ ] Optional: 7-inch and 10-inch tablet screenshots (the app has tablet layouts).
- [ ] Category, tags, contact email, website.

### 7c. Pricing and countries

- [ ] Countries/regions (decision 0). Free.

---

## 8. Upload, closed test and production

1. [ ] **Internal testing** track → create a release → upload the `.aab` Claude built → add yourself and your testers' emails → install from the Play link on your phones. This is the first time the real Play-signed app runs.
2. [ ] Play Console → Test and release → **App integrity** → copy the **app signing key SHA-1**. Add it to the API key in section 3b.
3. [ ] **Closed testing** (required for a new personal account):
   - Create a closed track and a Google Group or email list with **at least 12 real testers**, people who will actually open and use the app. Messages, opt-in steps and the 14-day task list: [06_CLOSED_TEST_TESTERS.md](06_CLOSED_TEST_TESTERS.md).
   - Keep at least 12 opted in for **14 days in a row**. If the number drops below 12, the count starts again.
   - Collect their feedback. Google asks what you learned and changed when you apply for production.
4. [ ] **Apply for production** (Dashboard → Production access) and answer the questions about the test.
5. [ ] After approval: **Production** → new release → same or newer `.aab` → **staged rollout** (start at 10–20%) → watch crashes and ANRs in Android vitals for 2–3 days → raise to 100%.
6. [ ] Each new upload needs a higher `versionCode`. Claude bumps it in `pubspec.yaml`.

---

## 9. Legal and compliance (Saudi Arabia)

Nothing in the repo is legal advice. Questions for the lawyer are in `store/counsel_questions.md` and `store/saudi_compliance_checklist.md`.

- [ ] Book a lawyer familiar with **PDPL** (personal data) and **CST/GCAM** (digital content and media platform licensing).
- [ ] Ask:
  - whether a licence is needed
  - data residency and cross-border transfer (Supabase region, Google, Vercel)
  - minimum age
  - Arabic Terms of Service and Privacy Policy wording
  - live-content liability and takedown process
- [ ] Get the final Arabic and English **Terms** and **Privacy Policy** text and give it to Claude to put in the app and on the web pages.
- [ ] If the lawyer says a licence is needed, apply before the public launch. The closed test can run meanwhile.

---

## 10. Housekeeping

- [ ] **Push to GitHub** when Claude finishes a phase (you push; Claude only commits).
- [ ] Keep `dart_define.local.json`, `key.properties`, the keystore and all Firebase/Google secrets out of git. Claude's secret scan checks the final `.aab`.
- [ ] Decide whether the three master-admin emails stay as they are before you share the repository with anyone (one is personal).
- [ ] Turn on 2-step verification on every account involved: Google, Play Console, Supabase, Vercel, GitHub, Firebase.
