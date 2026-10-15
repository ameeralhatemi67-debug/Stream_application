# 04 — Firebase setup for reminders and push notifications

Written 2026-10-15. Replaces the short version in [01_OWNER_STEPS.md §4](01_OWNER_STEPS.md).

**What this turns on:** the reminder bell on channels and Upcoming cards, the reminder lead-time setting, and the notification that arrives before a planned live. Builds without these values hide all reminder controls automatically, so nothing is broken while you set this up.

**What is already done (no action):**
- The app code for Android and web push (`ReminderPushService`, `project/web/firebase-messaging-sw.js`).
- The `dispatch-upcoming-reminders` Edge Function is deployed on `zkkmfjsjouqzibvnzkau`.
- The reminder claim function was fixed and deployed on 2026-10-15 (`20261015174558`). Before that, no reminder could ever be claimed.

**Time needed:** about 30 minutes, plus a rebuild.

**Golden rule:** the service-account JSON file in step 6 is a **secret**. It goes only into Supabase. Never into git, chat, screenshots or the app build. Every other value in this guide is public and is safe in the build.

---

## Step 1 — Create the Firebase project

1. Open <https://console.firebase.google.com> and sign in with the Google account that will own the app long term (the same one as Play Console).
2. Click **Create a project**. Two choices:
   - **Recommended:** choose **"Add Firebase to an existing Google Cloud project"** and pick the Google Cloud project that already holds the YouTube OAuth client. One project is easier to manage.
   - Or create a new project named `Hadayah`.
3. Google Analytics: **turn it off**. The app does not need it, and leaving it off keeps the Play "Data safety" form shorter.
4. Click **Create project** and wait for it to finish, then **Continue**.

## Step 2 — Add the Android app

1. On the project overview page, click the **Android** icon ("Add app").
2. **Android package name:** `sa.hadayah.streamer_app` (exactly, no `.wave4v2`).
3. **App nickname:** `Hadayah Android`.
4. **Debug signing certificate SHA-1:** leave empty. Push does not need it.
5. Click **Register app**.
6. "Download google-services.json": you may download it to look at it, but **do not put it in the project**. The app reads its values from the build settings instead. Click **Next** until the wizard ends ("Continue to console").

## Step 3 — Add the Web app (for Chrome push)

1. Project overview → **Add app** → the **Web** icon (`</>`).
2. **App nickname:** `Hadayah Web`.
3. **Do not** tick "Also set up Firebase Hosting" (the web app stays on Vercel).
4. Click **Register app**. A code box with `firebaseConfig` appears. You only need its values (next step). Click **Continue to console**.

## Step 4 — Copy the public values

Open **Project settings** (gear icon next to "Project Overview") → **General** tab → scroll to **Your apps**.

Write these down in a note (they are public):

| Value | Where | Example shape |
|---|---|---|
| `FIREBASE_PROJECT_ID` | General → **Project ID** | `hadayah-12345` |
| `FIREBASE_MESSAGING_SENDER_ID` | Cloud Messaging tab → **Sender ID** (same as the project number) | `123456789012` |
| `FIREBASE_API_KEY` (Android) | Your apps → Hadayah Android → **API key**. If it isn't shown there, open the google-services.json from step 2 and use `current_key`. | `AIza…` |
| `FIREBASE_APP_ID` (Android) | Your apps → Hadayah Android → **App ID** | `1:123…:android:abc…` |
| `FIREBASE_API_KEY` (Web) | Your apps → Hadayah Web → SDK setup → `apiKey` | `AIza…` |
| `FIREBASE_APP_ID` (Web) | Your apps → Hadayah Web → **App ID** | `1:123…:web:abc…` |

The Android and Web **App IDs are different**. The phone build uses the Android ones; Vercel uses the Web ones.

## Step 5 — Check Cloud Messaging and create the web push key

1. **Project settings** → **Cloud Messaging** tab.
2. Under **Firebase Cloud Messaging API (V1)** it must say **Enabled**. If it says Disabled, click the ⋮ menu → **Manage API in Google Cloud Console** → **Enable**. (The old "Legacy API" can stay disabled; the app does not use it.)
3. Scroll to **Web configuration** → **Web Push certificates** → **Generate key pair**.
4. Copy the long **Key pair** value. This is `FIREBASE_WEB_VAPID_KEY` (public).

## Step 6 — Create the server key (SECRET)

1. **Project settings** → **Service accounts** tab.
2. Make sure **Firebase Admin SDK** is selected, then click **Generate new private key** → **Generate key**.
3. A `.json` file downloads. **This is the secret.** Keep it open in a text editor for step 7; do not email, upload or commit it.

## Step 7 — Put the secrets into Supabase

1. Open <https://supabase.com/dashboard> → project **streamer_app** (`zkkmfjsjouqzibvnzkau`).
2. Left menu → **Edge Functions** → **Secrets** (or Project Settings → Edge Functions).
3. Add a secret:
   - **Name:** `FIREBASE_SERVICE_ACCOUNT_JSON`
   - **Value:** the **entire content** of the JSON file from step 6, from the first `{` to the last `}`, pasted as is.
4. Add a second secret:
   - **Name:** `FIREBASE_PROJECT_ID`
   - **Value:** the project ID from step 4.
5. Click **Save**.
6. Delete the JSON file from your Downloads folder and empty the Recycle Bin. If you ever need it again, generate a new key (and delete the old one under Service accounts).

## Step 8 — Turn on the reminder schedule (one-time)

The function exists, but nothing calls it yet. It needs two Vault secrets and a job that runs every minute. The file `supabase/functions/dispatch-upcoming-reminders/cron.sql` does all three; the dispatch key is generated inside the database and never shown to anyone.

**Option A (easiest): tell Claude "run the reminder cron SQL on hosted".** Claude runs it through the Supabase connector and checks the first run.

**Option B: run it yourself.**
1. Supabase dashboard → **SQL Editor** → **New query**.
2. Paste the content of `supabase/functions/dispatch-upcoming-reminders/cron.sql`.
3. Replace `<project-ref>` with `zkkmfjsjouqzibvnzkau`, so the URL reads `https://zkkmfjsjouqzibvnzkau.supabase.co/functions/v1/dispatch-upcoming-reminders`.
4. Click **Run**. It is safe to run twice.
5. Check it: **Database** → **Cron Jobs** (or Integrations → Cron). You should see `dispatch-upcoming-reminders` running every minute next to `hadayah-reconcile-broadcasts`.

## Step 9 — Put the public values into the phone build

1. Open `project/dart_define.local.json` on your computer (it's git-ignored; create it from `dart_define.example.json` if missing).
2. Fill in the **Android** values from step 4 and the VAPID key from step 5:
   ```json
   "FIREBASE_API_KEY": "<Android API key>",
   "FIREBASE_APP_ID": "<Android App ID 1:…:android:…>",
   "FIREBASE_MESSAGING_SENDER_ID": "<Sender ID>",
   "FIREBASE_PROJECT_ID": "<Project ID>",
   "FIREBASE_WEB_VAPID_KEY": "<VAPID key>"
   ```
3. Save. The next build Claude makes (or `flutter build appbundle --release --dart-define-from-file=dart_define.local.json`) includes push. The reminder bell reappears automatically.

## Step 10 — Put the public values into the web app (Vercel)

1. <https://vercel.com> → the Hadayah project → **Settings** → **Environment Variables**.
2. Add each one for **Production** (use the **Web** values from step 4):
   `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_WEB_VAPID_KEY`.
3. **Deployments** → latest → ⋮ → **Redeploy**. `scripts/build_vercel_web.sh` passes them into the web build.

## Step 11 — Test end to end

1. Install the new build on a phone. Sign in with a normal (non-broadcaster) account.
2. Open a broadcaster's profile and tap the **bell**. Android asks for notification permission: **Allow**.
3. Tell Claude "check push devices". Claude counts rows in `schedule_push_devices` (expect at least 1) without reading any token.
4. With a broadcaster account, add a **one-time** Upcoming show starting about **20 minutes** from now. (The default reminder lead time is 15 minutes; change it in Settings → Notifications if you like.)
5. About 15 minutes before the show, the phone should get the reminder, even with the app closed.
6. If nothing arrives: Supabase → Edge Functions → `dispatch-upcoming-reminders` → **Logs**. Send Claude the error text (not the secret). Also check the phone isn't blocking notifications for the app, and that battery optimisation isn't set to "Restricted" for it.

## After it works

- **Play Data safety form:** declare **Device or other IDs** (the push token) as collected, for **App functionality**, not shared, deletable (account deletion removes it). Claude will update `store/data_safety.md` with this.
- **Organization notifications** (invitations, show assignments) use the same Firebase secrets but a second function, `dispatch-organization-events`, which isn't deployed yet. It's only needed for the organization pilot; ask Claude when you start the pilot.
- Turn on 2-step verification for the Google account that owns Firebase.
