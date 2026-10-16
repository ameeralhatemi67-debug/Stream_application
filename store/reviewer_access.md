# Reviewer access (Play Console > App content > App access)

Status: 2026-10-16, ready to paste. No password is written here. The owner creates the reviewer account and types its password into Play Console only.

Why it is needed: most of the app works as a guest, but chat, follows, reminders, broadcasting and organizations need Google sign-in. Play's reviewer must be able to reach them without contacting you, or the app is rejected for "app access".

## 1. What the owner prepares first (about 45 minutes)

- [ ] **A dedicated Google account for the reviewer**, for example `hadayah.reviewer@gmail.com`. Not your own. Turn **2-step verification off** and add no recovery challenge, because the reviewer cannot receive codes. Use a long unique password.
- [ ] **A test YouTube channel** on that account (any name, with live streaming enabled in YouTube Studio; this can take up to 24 hours the first time, so do it today).
- [ ] **Approve the account as a broadcaster:** sign in with it, apply as an individual broadcaster, then approve it from your Admin account (verification queue).
- [ ] **Connect the YouTube channel** in the app (Settings > YouTube connections > Connect YouTube). Until Google's OAuth verification finishes, add this account in Google Cloud > Audience > **Test users**, or the consent screen refuses it.
- [ ] **Organizations (a core feature):** create a small test organization owned by this account, then switch organizations on for review: Admin > Safety > turn on the organization switch, or add this organization to **Organization pilots**. The organization applications switch can stay off. The hosted flags today are `organizations_v1_enabled = false` and `organization_applications_open = false`, so without this step the reviewer sees no organization broadcasting at all.
- [ ] **Make something to watch.** Leave one recorded lecture or a scheduled show available. A live stream is not guaranteed at review time, so the instructions below do not depend on one.
- [ ] Sign in once with the reviewer account on a phone, to check that every step below works with that exact account.

## 2. Text for the Play form

Labels below were taken from the app's English strings. The Go Live entry point (step 4) and the Settings row names were not clicked through in the signed build, so tap through the text once on a phone and fix any label that differs before you paste it.

Choose: "All or some functionality in my app is restricted" and add one set of credentials.

**Instructions (paste):**

> Hadayah Live works as a guest without any account.
>
> 1. Open the app, accept the privacy notice and tap "Continue as Guest Viewer (Skip Sign In)". You can browse the discovery feed, open a recorded lecture or channel, open the Map tab and view venues.
> 2. To use chat, follow, bookmarks, reminders, broadcasting and organizations, sign in with Google using the test account below (the account is already approved as a broadcaster and owns a test organization). Tap "Already have an account? Log In" on the welcome screen and choose that account. There is no other verification step.
> 3. Chat and reporting: open any live room or recorded video that has chat, send a message, then long-press a message to report or block it.
> 4. Broadcasting from the phone: in the feed tap Go Live, choose the phone camera (Open Camera), allow camera and microphone, confirm the quality, then tap Go Live. A notification "You're broadcasting live" stays while the app is in the background. Tap End to stop. The test YouTube channel is already connected (Settings > YouTube connections). Broadcast to this test channel only.
> 5. Organizations: Settings > Organizations > open the test organization. You can see its members and permissions, YouTube connections, and "Shows and assignments" where a show can be scheduled and started.
> 6. Account and data: Settings > Privacy > Download My Data; Settings > Delete My Account (please do not delete the test account). Public deletion page: https://stream-application-ten.vercel.app/delete-account.html
>
> Camera, microphone and location are requested only when you use those features. The privacy policy is at https://stream-application-ten.vercel.app/privacy.html.

**Username:** the reviewer Google address.
**Password:** type it in Play Console only.
**Other information:** "Google sign-in only. 2-step verification is turned off for this account. Contact: the support email, reply within 24 hours."

## 3. Gotchas that cause rejections

1. **The account must be approved and connected before you submit**, not while Google reviews. Otherwise step 4 shows "pending approval" and the reviewer rejects it.
2. **OAuth not yet verified:** if the test account is not in Google Cloud's **Test users** list, Google sign-in for the YouTube connection shows "access blocked". (Plain Google sign-in for the app does not use the sensitive scope.)
3. **Quota:** the YouTube API default is 10,000 units a day. A review plus your own testing uses a few hundred; do not run a 3-show pilot on the same day if you are close to the limit.
4. **Do not leave the test account live** when the review ends: end every broadcast and delete test videos so the feed looks clean.
5. If sign-in fails with "Something went wrong", check **Supabase > Authentication > URL configuration > Redirect URLs** includes `sa.hadayah.streamerapp://login-callback` and the web origin.

## 4. Screenshot and demo hygiene

Use the reviewer account for the store screenshots too, so the feed, profile and organization pages in the store listing are the ones the reviewer will see.
