# Admin Hub redesign and P6 acceptance, 2026-09-23

P6 is **not accepted**. P6S has not started. This checkpoint completes the Admin Hub changes and extends local acceptance evidence; it does not establish physical-device or Google OAuth acceptance.

## Changes

- The Admin Hub uses a scrollable side navigation from 900 px and a drawer below it. Existing destinations, count badges, role gates and selection are retained. Removing Master Admin while its Roles view is selected returns to Overview. Debug-only Testing Tools stays debug-only.
- The header uses the existing LanguageSwitcher and EasyLocalization persistence. All navigation labels and new copy have matching English/Arabic keys. RTL puts navigation on the right. Fixed the Terms shortcut opening Analytics and the narrow Roles form/header overflows reproduced by tests.
- Overview labels loaded broadcaster/organization counts honestly and filters Verified Scholars by verification. Unmeasured viewer/attendance KPIs say Unavailable. Viewer Analytics explains that measurements are unavailable; sample regional percentages are removed. Legacy model defaults and missing JSON values are zero, and a missing analytics row is no longer seeded during loading. Existing stored analytics rows were not rewritten and are not displayed as live metrics. This is an Admin Hub truthfulness correction, not completion of all P2 work.
- A direct /admin URL waits for the backend role check, then builds the Hub. The route observes loading changes; an early implementation remained on its spinner because GoRouter refresh alone did not rebuild the same route. A regression test covers the corrected behavior. Existing-user token refresh does not replace a loaded Hub with a spinner.

## Fresh local environment

Created a new, disposable P6_admin_20260923 stack from all repository migrations through 20260923140000, on localhost ports 55320–55329. Workdir: ignored brief/.runtime/p6-admin-20260923. Google OAuth is disabled in the copied local configuration; no real secrets were used. The older P6_accept_disposable stack was found running. Its recorded workdir did not exist, so the attempted stop failed without changing it. The first new-stack start collided on its ports; separate ports resolved that. The old stack remains untouched.

Four new local GoTrue fixture users, five distinct password-grant sessions: Viewer A, Viewer B, Master Admin, verified Caster, and a second Viewer A session. Browser storage was isolated by origins 8181–8185. Caster exercised authenticated RPCs plus a local heartbeat, not phone capture or RTMP. Fresh login helpers and sessions were generated in this task; no old sessions or Opus helper were reused. Credentials stayed in ignored local files. CLI bootstrap printed disposable stack credentials to its redirected startup log; that output was removed from the log and is excluded from evidence. No fixture password/session is in committed files.

## Acceptance results

| Scenario | Evidence and result |
| --- | --- |
| Sign-ups pause | UI PASS: Master switch Off with reason; Welcome notice, disabled Sign Up, enabled Log In. Clicking Log In opens the consent dialog. Google OAuth itself was not completed. Screenshot welcome-signups-paused.png. |
| Existing user/new user | API PASS: new signup 500 while paused; existing local user's fresh password login 200 and session refresh 200. After reopening, new signup 200. signup.txt. These are local GoTrue users, not Google accounts. |
| End broadcast | UI PASS: reason entered and confirmed in Safety, live row removed and count zero. Audit shows Master Admin P6 and the typed reason. end-broadcast.png. |
| Remove from feed | UI PASS: reason entered, success toast and empty live list. API PASS: same video 403, Stream removed by moderation; new video 204. remove-from-feed.png, removed-video.txt. No claim of stopping YouTube media. |
| Audit | UI PASS: actor, timestamps and typed end/remove reasons visible; keyword added/changed/removed rows all present. Action filter showed only broadcast-end row. audit-keywords-and-live.png and audit-filter.png. Existing viewer supports action filtering; actor/date filter controls from the broader work plan remain absent. |
| Keywords | UI PASS: add p6blockedword, change to Anywhere in text, remove, three audit entries. API PASS: Viewer B message refused with 400, contains a banned keyword. keyword-changed.png and keyword-denial.txt. |
| History and recovery | UI PASS: Order one above Order two. A paused open room recovered its composer after the flag resumed without reload. chat-history-order.png and chat-recovered-without-reload.png. Pause API denied both viewer and broadcaster with 403. |
| Cross-session blocks | API created A's block of B. UI PASS: refreshed A room hid B history, A session 2 listed B in Settings, UI Unblock emptied the list, refreshed A session 1 restored both messages in order. This run did not exercise the long-press Block User action, which has earlier-session UI evidence. second-session-block.png, first-session-unblocked.png. |
| Unauthorized actions | Real Viewer B session: flag/end/remove/keyword writes 403; audit read 200 with zero visible rows. api-denials.txt. |
| Responsive navigation | UI screenshots inspected at 1280×800 and 390×844, English and Arabic. Phone drawer navigation worked. Final desktop screenshots replaced early captures clipped by browser zoom. Widget tests prove language persistence, selected destination retention, role removal and both sizes/locales. |
| Physical devices | NOT RUN: adb devices -l returned no devices. No physical phone, real Google account or real broadcast test channel exercised. |

## Verification

- Focused final navigation/router and Safety run: +29, All tests passed.
- Full Flutter run once at stable scope: +514, All tests passed, 02:44. Includes layout sweep. Afterward only two const-only test lint fixes and a comment changed; no behavior changed.
- Final flutter analyze: No issues found! (16.6s). Release web build succeeded with local-only defines.
- Fresh disposable SQL suite: Files=15, Tests=283, Result: PASS. An initial selected-file invocation failed before assertions because of an incorrect test filename/Windows path mapping; running from the disposable project directory resolved invocation.
- Gates process exit 0 is NOT a pass. G6 FAIL 554, previously 552; the two added matches are translated Text calls. G7 key symmetry PASS 0. G11a FAIL 9, all reported paths in pre-existing nested .claude/worktrees, including a local runtime env file and historical scan/report files. These were not changed, deleted or certified harmless. G11b/d/e/f PASS 0. Other gates PASS or INFO. Exact report: gates.txt.
- git diff --check clean. No migration or production data changes. Owner AGENTS.md/README edits, both stashes and unrelated aedff5e commit preserved. No push, deploy or P6S work.

## Remaining acceptance and exact owner procedure

Use a non-production backend reviewed by the owner with migrations through 20260923140000. Use two physical Android phones, real Google test accounts A and B, a verified broadcaster with a test channel, and a Master Admin browser. Do not use the disposed fixture sessions.

1. Sign in A and B through the actual Google flow. Pause new sign-ups in Safety with a reason. Sign out and log back in with an existing account; try a genuinely new test account. Expect existing login allowed and new registration refused. Reopen sign-ups.
2. Join the same room on both phones. B sends two messages. A long-presses B's message and blocks B; B's next message must disappear for A. Sign A into the second phone, open Settings > Blocked accounts, unblock B. Return the first phone to the foreground or re-enter the room; expect B's history oldest first.
3. Keep a room open, pause chat in Safety, and send once. Expect refused message with Discard only and the paused notice. Resume chat; the composer should return within about 30 seconds without reloading.
4. Start an actual broadcast on the verified phone. Master Admin uses Safety > End broadcast with a reason. Record whether the phone leaves the live state and releases its publishing resources as designed. App-side moderation does not claim to stop external YouTube media. Repeat with Remove from feed; same video must be refused, a different video permitted.
5. Check audit actor/reason/time and action filter for every action. Add/change/remove a disposable keyword and verify all three audit entries. Record phone model, Android version, account roles, network, timestamps and pass/fail. Resolve the missing actor/date filters if the full work-plan audit-viewer contract remains required.

Separate unresolved P2/P6S finding: the fixture live page displayed AUDIO LIVE and a sample YouTube embed when its public video metadata was absent. It is not evidence of real playback/broadcast correctness; this task did not change the player fallback or start P6S.

Budget: fresh entry 6% weekly used; closeout entry 13%; final reading 14%, delta 8 percentage points. Owner override soft target 14%, hard stop 16%. No reset credit, meter changes or reset waiting. Final reading and commit IDs are in the newest LEDGER RESUME block.

