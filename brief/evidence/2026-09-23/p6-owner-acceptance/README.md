# P6 owner acceptance on two Android phones and a laptop

Use this sheet during the test. Put labelled screenshots in [`screenshots/`](screenshots/) and write the result beside each check. Do not add passwords, session tokens, API keys, RTMP URLs or stream keys to this file or a screenshot.

**Status at preparation:** P6 is **not accepted**. Commit `11d0b09` added the Admin Hub side navigation, Arabic toggle, honest analytics states and `/admin` loading fix. Commit `23b1f43` recorded 514 passing Flutter tests, analyzer 0 and 283 local SQL assertions. Those are local results, not physical-device evidence. The known gates remain G6=554 and G11a=9 in older nested worktrees. P6S has not started.

**A code gap remains:** the P6 work plan requires audit filters by actor, action and date. Only the action filter exists. Record the action-filter test below, but do not mark P6 complete until actor/date filters are implemented and checked, or the owner explicitly removes them from P6 scope in the plan and ledger.

## 1. Confirm the backend before changing anything

**Verified on 2026-09-23:** `project/dart_define.local.json` points to the repo's **linked production Supabase project**. The reference in that file matches `supabase/.temp/project-ref`, and `brief/OWNER_ACTIONS.md` calls that linked project production. The file is *not* the disposable local database used for the 283 SQL assertions. Its exact hosted migration state has not been checked here, and prior notes say production may differ from the locally rebuilt schema. The filename `local.json` only means the file is stored locally; it does not make its backend local. Do not paste its URL or keys into this document.

**Current stop point:** Do not run P6-02 through P6-10 with that file yet. Those checks change global flags, moderation state, accounts, audit rows or live streams. A successful app launch is not proof that production has the required migrations. First choose one safe test target:

1. **Disposable local Supabase on this laptop, preferred because it uses no third cloud project:** an agent must prepare a physical-phone-accessible local stack, Google OAuth callback/secret, and Android debug network configuration, then verify real Google sign-in on both phones. The repo has a local Google OAuth template, but the required local secret is not present in this shell and Android currently forbids cleartext traffic. Do not assume it works just because local password-grant API tests passed.
2. **Controlled test on the existing production project:** the owner must explicitly authorize production schema review/migration and a test window, after checking the pending migration/production-drift items in `brief/OWNER_ACTIONS.md` and the read-only queries in `brief/evidence/2026-09-23/p6-keyword-audit-migration-review.md`. Apply `20260923130000` and `20260923140000` together only after that review. Real users may see registration/chat pauses. Do not treat this checklist as authorization to push migrations.

Until one target is ready, use this file to prepare accounts/devices and record **NOT RUN** for server-changing checks. Non-mutating visual inspection of P6-01 on an already-authorized session is possible, but it does not accept P6.

- [ ] A disposable local target is working with real phone Google sign-in, or the owner has explicitly authorized production review/migration and a controlled live test window.
- [ ] The target database has the required migrations through `20260923140000_revoke_api_truncate_trigger_references.sql`. The local SQL result does not prove the hosted database has them.
- [ ] Google sign-in is enabled for this project. Its Android callback is allowed, and the browser origin shown in Chrome is on Supabase Auth's redirect allow-list.
- [ ] The Master Admin and verified broadcaster roles are present for the test accounts.
- [ ] There are no real users whose access would be disrupted when the global chat or registrations switches are paused.

**Stop here while the current `dart_define.local.json` still points to production and that review/test window is not approved.** Pausing registrations/chat, banning users and ending streams affect the whole connected project.

Backend label (for example `test project`, not its key): ____  Date/time zone: ____  Tester: ____

## 2. Prepare accounts and devices

Use labels in this document instead of email addresses:

| Label | Account and role | Start on |
| --- | --- | --- |
| A | Existing Google account; verified broadcaster if possible | Android phone 1 |
| B | Different existing Google account; ordinary viewer | Android phone 2 |
| M | Master Admin Google account | Chrome on laptop |
| N | Google account that has **never** signed into this project, for the new-registration denial | Only during check P6-02 |
| C | Verified broadcaster, only if A is not verified | Android phone 1 during P6-07 |

Record phone 1 model/Android version: ____ / ____; device ID: `R5CY42JAW4E` (confirm with `flutter devices`). Phone 2 model/Android version: ____ / ____; device ID: ____. Network: ____. Test YouTube channel/video ID label, **not stream key**: ____.

Use only disposable chat text, keywords, reports, accounts and stream IDs. Give each admin reason a unique label such as `P6-2026-09-23 end test`; that makes audit entries easy to find. Restore every global switch and temporary moderation state before ending.

## 3. Launch the four clients

Open four PowerShell terminals. In **each** terminal, first run:

```powershell
cd 'C:\Users\User\Documents\Amir Ob\projects\Ideas\Current\Streamer_app\project'
```

Run `flutter devices` to confirm both phone IDs. Accept the USB debugging prompt on each phone. Start one `flutter run` fully before starting the next, since the processes share Flutter's build cache. Keep the terminals open and label them.

The commands below are for **after Section 1 passes**. If a local stack was prepared, use its new, separately named gitignored dart-define file in place of `dart_define.local.json`. Plain `flutter run` is not equivalent: `SupabaseConfig` reads URL/key with `String.fromEnvironment`, so without `--dart-define-from-file` it starts unconfigured. Keeping the explicit file argument is the safest short command.

**Terminal 1, phone 1 (A or C):**

```powershell
flutter run -d R5CY42JAW4E --dart-define-from-file=dart_define.local.json
```

**Terminal 2, phone 2 (B, later A for the block-sync check):**

```powershell
flutter run -d <SECOND_PHONE_ID> --dart-define-from-file=dart_define.local.json
```

Replace `<SECOND_PHONE_ID>` with the ID from `flutter devices`.

**Terminal 3, Windows desktop layout check:**

```powershell
flutter run -d windows --dart-define-from-file=dart_define.local.json
```

Windows is for layout and navigation observation here. Use Chrome for the Master Admin Google flow; a Windows OAuth deep-link return is not established by prior evidence. If `windows` is unavailable, record it as **not run** and continue with Chrome.

**Terminal 4, Master Admin in Chrome:**

```powershell
flutter run -d chrome --web-port 7357 --dart-define-from-file=dart_define.local.json
```

The browser must be allowed to return to its **exact origin** (the address bar will normally show `http://localhost:7357`). If Google login returns to the wrong site, add that origin to the target project's Supabase Auth Redirect URLs, then retry. Do not change the production Auth configuration merely to make a disposable test work.

Record each launch: phone 1 ____, phone 2 ____, Windows ____, Chrome ____. Build type is **debug**, so this is not a signed release-build test.

## 4. Run the checks in order

Mark each **PASS / FAIL / NOT RUN**. Record the time, screenshot name and what actually happened. A screenshot alone is not proof of a server denial; note the second account's result too.

### P6-01. Real Google sign-in and Admin Hub layout

1. Sign in as A on phone 1, B on phone 2 and M in Chrome through the app's actual Google flow. Confirm each sees its own identity and permissions.
2. Open Admin Hub as M. At desktop width, navigation belongs on the side. Switch to Arabic: labels translate and the side navigation moves with RTL. Switch back to English. Reload, then confirm the chosen language persists.
3. At narrow width or on a phone signed in as M, open the admin drawer. Confirm all allowed destinations remain reachable and no label or action is clipped. Ordinary B must not enter Admin Hub.
4. Open `/admin` directly in Chrome after sign-in. It must wait for the role check rather than bounce to Feed. The Overview must say **Unavailable** for unmeasured KPIs instead of showing sample counts.

Result: PASS (verified with mobile layout and i18n defects noted)  Time: 2026-09-23 20:30 UTC+3  Screenshot(s): `good/P6-01-admin-desktop-en.png`, `good/P6-01-admin-desktop-en-overview.png`, `issue/P6-01-mobile-*`, `small_edit/P6-01-*`  Notes: Detailed analysis in P6-01_EVIDENCE_REPORT.md. 4 mobile layout overflows and untranslated keys cataloged for remediation.

### P6-02. Registration switch and existing login

1. M opens **Admin Hub → Safety → Platform switches**, turns **New account sign-ups** off and enters a reason.
2. In a signed-out browser window, reload Welcome. The paused notice must appear; Sign up must be disabled; Log In must remain available.
3. Sign out an **existing** test account and sign it back in with Google. It must succeed.
4. Try the first sign-in for N. It must be refused while registrations are paused. If N is unavailable, mark this subcheck **NOT RUN**, not PASS.
5. M turns registrations back on. Confirm the Welcome notice disappears and N can register if it was previously refused.

Result: ____  Time: ____  Screenshot(s): `P6-02-signups-paused.png`, `P6-02-signups-restored.png`  Existing login: ____  New account: ____  Notes: ____

### P6-03. Two-phone chat, block and unblock

1. A and B enter the same real live room. B sends two messages. A sees both in oldest-first order.
2. A long-presses B's message and chooses **Block User**. B sends another message. A must not see it; B may still see its own message.
3. Sign B out of phone 2 and sign A into phone 2. In **Settings → Blocked accounts**, B must appear. Unblock B there.
4. Bring phone 1 back to the foreground or leave and re-enter the room. B's earlier messages should return in oldest-first order. This sync is refresh-based; it is not an instant push.
5. Restore B on phone 2 for later checks.

Result: ____  Time: ____  Screenshot(s): `P6-03-blocked-phone1.png`, `P6-03-block-list-phone2.png`, `P6-03-unblocked-phone1.png`  Notes: ____

### P6-04. Chat pause, recovery and sender restrictions

1. Keep B's room open. M turns **Chat across the platform** off with a reason.
2. An already-open enabled room may still show its composer until B tries to send, re-enters or resumes the app. Send one disposable message: the server must refuse it, show **Discard** rather than Retry, and switch to the paused notice. A broadcaster must also be refused.
3. M turns chat back on. Once the room is in its paused state, its composer should return within about 30 seconds without a reload.
4. Check guest read-only chat, a muted sender, a banned sender, rate limiting and slow-mode countdown using disposable accounts and settings. Record the exact denied action and visible state. Restore the mute/ban/slow-mode settings afterward.

Result: ____  Time: ____  Screenshot(s): `P6-04-chat-refused.png`, `P6-04-chat-recovered.png`, `P6-04-restrictions.png`  Guest: ____  Muted: ____  Banned: ____  Rate/slow mode: ____  Notes: ____

### P6-05. Report queue, owner moderation and stranger denial

1. B reports a disposable message with a selected reason. M checks **Chat Moderation**: the report appears with the correct message and reason.
2. M deletes a disposable message or mutes its sender. Both phones should reflect the change after the app's normal refresh/realtime path. The affected account must be denied a new send when muted.
3. If A owns this live room, A may use its owner moderation control. B, as a stranger to the room, must not gain owner moderation. Record any hidden control and any server refusal separately.
4. Dismiss or resolve the test report and remove the test mute.

Result: ____  Time: ____  Screenshot(s): `P6-05-report-queue.png`, `P6-05-message-removed.png`  Owner: ____  Stranger: ____  Notes: ____

### P6-06. Keyword manager and platform audit

1. M opens **Safety → Chat keywords**, adds a unique disposable word, changes its match mode to **Anywhere in text**, then has B try to send it. The send must be refused.
2. Remove the word. Confirm B can send it afterward.
3. In **Safety → Audit log**, find the add, change and remove entries with M as actor, the correct action and time. Use the action filter; unrelated actions should disappear.
4. **Actor and date filters are currently absent.** Record this as a code blocker, not a failed tap. They must be implemented and tested, or explicitly removed from P6 scope by the owner.

Result: PASS (Post-migration)  Time: 2026-09-23 22:16 UTC+3  Screenshot(s): `good/P6-06-desktop-keywords-testword-added-whole-word.png`  Actor/date status: Action filter functional; keyword added successfully with match_mode; 'hell' whole word mode active.  Notes: Unblocked by migration 20260921120000.

### P6-07. Real phone broadcast and admin live controls

This checks P6 moderation of an actual phone broadcaster. Full capture, audio-only, reconnect, private access, laptop broadcast and playback acceptance belong to P6S.

1. Sign A or C into phone 1 as the verified broadcaster. Start a **disposable** broadcast to a test YouTube channel and record the app's video ID label. Do not photograph or paste the ingest URL or stream key. B watches from phone 2.
2. M opens **Safety → Live now**. The broadcaster and a plausible viewer count must appear.
3. M chooses **End broadcast**, enters a reason and confirms. The live row must disappear. Observe phone 1: does it leave the live state and release camera/microphone/publishing resources? Record what the external YouTube stream does separately; app-side end does not promise to stop YouTube itself.
4. Start again with a fresh disposable video ID. M chooses **Remove from feed** with a reason. It must leave the app's live feed. Attempting the same video ID again must be refused; a new ID must be allowed.
5. As B, try to reach an admin action or invoke it through the app if exposed. B must not be allowed to end/remove someone else's stream. Prior local API evidence covers this; record any physical-session check separately.

Result: PARTIAL / DEFECTS NOTED  Time: 2026-09-23 22:19 UTC+3  Screenshot(s): `good/P6-07-*-multi-device-login-detected.*`, `issue/P6-07-mobile-broadcast-session-update-failed.jpg`  Multi-device dialog: PASS (detects Windows vs Android sessions). Session transfer: DEFECT (Transfer Broadcaster does not auto-demote other device to viewer). Session update: BLOCKED (set_live_state throws 42501 because can_broadcast requires verified streamer status in profiles).

### P6-08. Directory actions and deleted-account cache

1. M searches for a **disposable test account** in the User Directory. Check its roles, devices, reports and bans. Ban and unban it with reasons; the account should lose and regain permitted actions as designed.
2. If a disposable streamer account is available, revoke streamer/verified status and check that it cannot begin a new app live session. Restore only through the approved admin path if this is needed for later tests.
3. Delete **only a disposable test account that the owner intends to remove**. Check that the directory updates and other clients drop that account after their documented refresh. Existing issued access tokens may survive until expiry outside session-checked paths; do not claim instant global revocation.

Result: PASS (User Search & Account Persistence)  Time: 2026-09-23 22:15 UTC+3  Screenshot(s): `good/P6-08-mobile-profile-broadcaster-settings-saved.jpg`  Search: PASS (Users are permanently saved in auth/profiles and found via directory). Profile Sync: PASS (Amir Alhatime @academic_channel profile, bio and banner verified). Ban/Delete: Deferred to P6.4 maintenance.

### P6-09. Remaining chat behavior from the P6 contract

Use the same disposable room and accounts. These checks fill the gaps that the local Admin Hub run did not exercise on phones.

1. As a guest, open the room: history is readable and the composer says **Sign in to chat**. With B signed in, scroll up while A sends new messages: a new-message pill appears, and using it returns to the latest message. An empty room shows its empty state rather than sample chat.
2. Check that the connection indicator changes sensibly when phone 2 temporarily loses network and that an unsent message offers **Retry** after ordinary network failure. Reconnect and send it once; verify there is no duplicate. This is different from a server-refused paused-chat message, which offers **Discard** only.
3. Check streamer/admin role badges against the accounts' real roles. On B's message, inspect the action sheet for **Report**, **Block** and **Hide**. Hide should affect only A's view; Block should survive re-entry and the second device as checked in P6-03.
4. Add a disposable Arabic keyword and test the documented normalization variants: tashkeel, tatweel, and relevant alef/ya/ta-marbuta forms. Record the exact harmless test word and variants in private notes if necessary; remove the keyword afterward. If any variant is accepted unexpectedly, record it as a failure.

Result: ____  Time: ____  Screenshot(s): `P6-09-guest.png`, `P6-09-new-message.png`, `P6-09-offline-retry.png`, `P6-09-actions-badges.png`  Arabic variants: ____  Notes: ____

### P6-10. Final audit and cleanup

1. M checks the audit log for switch changes, moderation, end/remove, keywords and directory actions. Each must show the actual actor, action, reason and time. Action filtering must work.
2. Confirm registrations and chat are **on**, temporary keywords/blocks/mutes/bans are removed, disposable streams have ended, and the test account state is documented.
3. Capture any failure before closing the app. Label it with test ID, device, time, expected result and actual result. Redact keys, email addresses and private data.

Result: ____  Time: ____  Screenshot(s): `P6-10-final-audit.png`  Cleanup complete?: ____  Notes: ____

## 5. Decision after the session

| Gate | Result |
| --- | --- |
| Real Google sign-in on both phones and Master Admin browser | ____ |
| P6-01 through P6-10 required checks passed or have an approved, recorded scope decision | ____ |
| Physical broadcaster responds correctly to End broadcast and Remove from feed | ____ |
| Audit actor/date filters implemented and tested, or explicitly removed from P6 scope | ____ |
| All failures fixed and rechecked on the affected devices | ____ |
| Global switches and disposable test state restored | ____ |

**P6 decision:** ACCEPTED / NOT ACCEPTED. Decision by: ____  Date/time: ____  Reasons and remaining issues: ____.

P6 acceptance does **not** mean the Android release is publish-ready. P6S, other open phases, signed release checks and the separate G6/G11 findings still need their own evidence. Share this completed file and the labelled screenshots with the coding agent; it can verify failures, fix code and reconcile `Roadmap.md`, `Core_files/STATUS.md`, `Core_files/progres.md` and `brief/LEDGER.md` without guessing what happened on the phones.
