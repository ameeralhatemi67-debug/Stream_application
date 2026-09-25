# P6S wave 3: session handoff (2026-09-25, Claude Opus 5.5)

The first session stopped at about 93% of its context. This file lets a new session continue without repeating any work. **It is not the final `HANDOFF_TO_ASTRA.md`**; that deliverable is still to be written (see "Remaining deliverables").

## Where things are

| Item | Value |
|---|---|
| Worktree | `C:\Users\User\Documents\Amir Ob\projects\Ideas\Current\Streamer_app\.claude\worktrees\p6s-wave3` |
| Branch | `opus/p6s-wave3-implementation` (not pushed, not merged) |
| Base | local `master` `760a69b58b92d3eadeace34a15380820974f5a31` |
| Committed | `cb3caee` `fix(streaming): truthful live state, exact watch identity and admin controls` (Group 1) |
| Uncommitted (Group 2 WIP) | `project/lib/core/providers/app_provider.dart`, `project/lib/core/services/youtube_api_service.dart` |
| Main checkout | untouched: its dirty files, untracked owner evidence and `brief/research/` are not in this branch. Both stashes are untouched: `stash@{0}` d646b94 "owner-brief-settings-before-window2-2026-09-20" and `stash@{1}` d53c178 "preexisting-before-budget-stop-2026-09-20". |
| Disposable DB | local Supabase `P6S_wave3_20260925`, API `127.0.0.1:55711`. Config: `brief/.runtime/p6s-wave3/supabase/` (git-ignored). Reset and run all pgTAP: `bash brief/.runtime/p6s-wave3/sqlrun.sh` |
| E3 probe | `brief/.runtime/p6s-wave3/probe_g1.dart`. Run from that folder: `dart --packages="../../../project/.dart_tool/package_config.json" probe_g1.dart` |
| Saved scripts and drafts | `brief/.runtime/p6s-wave3/handoff/` (git-ignored): edit scripts, `i18n_set.py` (sets en and ar keys together; usage `python i18n_set.py <project> <keys.py>`), `decisions_draft.md`, `retest_draft.md`, `g2_*` drafts, `research_hashes.txt`, `initial_state.txt` |

Research inputs were read from the main checkout by absolute path; SHA-256 prefixes are in `handoff/research_hashes.txt`. The completed owner retest `REPAIR_RETEST_RESULTS.md` hash prefix is `5fa7f7ab7aedd699`.

## Group 1: done, committed (`cb3caee`), critic loop finished

The demonstrated causes, all verified in code:
- **Wrong viewer video.** The room played the profile's `youtube_video_id`, which phone broadcasts never set. `youtube_player_adapter.dart` then substituted `M7lc1UVf-VE`. That is the IFrame API sample, "YouTube Developers Live: Embedded Web Player Customization"; the public oEmbed title and the owner's 22:24 screenshot match. Fix: the room plays only the exact `active_stream_id`, with no sample video, no failover and no borrowing another streamer.
- **Stale LIVE after transfer.** The room never ended while online, its LIVE badge was unconditional, and a coalesced catalog load could return data read before the change. E3 also showed that **non-admin clients receive no Realtime events for other accounts' profile rows**, because profiles RLS is own-row only. Fixes: the room ends on fresh catalog data and polls every 20 s; feed and map have a 30 s freshness lease; the badge follows the server; each new request gets one follow-up catalog read; the catalog reloads after claim, transfer or demotion. The exact surface the owner saw was never recorded, so an E4 retest is required.
- **Admin End / Remove demoted the broadcaster.** `admin_auth_account_action` cleared `is_primary_broadcaster`. The new migration `20260925100000_broadcast_sessions_and_live_controls.sql` adds:
  - `broadcast_sessions`, synced by trigger, with end reasons;
  - force_end and remove_from_feed that keep the device and approval;
  - a reversible, audited `admin_set_stream_discovery` ("Hide from app discovery", explicitly not private);
  - `my_broadcast_status`;
  - session-fenced `start_broadcast_session`, `report_broadcast_ingest` (returns 55000 once the session has ended) and `end_broadcast_session`;
  - a legacy `set_live_state(true)` that cannot restart an admin-ended watch ID;
  - an interrupted phone ended as `ingest_lost` after 120 s;
  - `organization_revoked` as an end reason.
- **Sign-ups paused, new Google account.** The refusal was dropped because there was no `onError`. It now shows a localized refusal dialog that names the account still signed in. It is gated to a real OAuth attempt, and refresh or session errors are ignored. The server boundary is the existing `enforce_registrations` trigger on `auth.users`.
- **Other fixes:** the `StreamerModel` default `youtubeVideoId` (was `dQw4w9WgXcQ`) and handle are now empty; the fake `stream_live_992` projections are gone; the mini-player closes, with a notice, when its broadcast ends.

**Evidence:** pgTAP 20 files / 433 assertions PASS on a fresh disposable DB; E3 two-client probe 16/16 PASS; full Flutter suite 615 passed; analyzer 0; gates PASS/INFO (G6=0, G7=0, G11a=0).

**Critic history (independent subagent):**

| Cycle | Functionality | Accessibility | Integration | Ease of use |
|---|---|---|---|---|
| 1 | 5 | 6 | 5 | 4 |
| 2 | 6 | 6 | 6 | 6 |
| 3 (final) | 7 | 7 | 6 | 7 |

After cycle 3 there was no CRITICAL or HIGH defect. **Group 1 is incomplete against the critic bar** (it needs all 10s, or three 10s and a 9). One post-cycle repair was made and has not been re-scored: ingest is reported only on change, and `interrupted_since` is tracked separately. Items still open:
- Feed and map show no "reconnecting" cue; only the room does.
- Old APKs map the new 42501 to "approval required".
- Org revocation can end another account that uses the same watch ID (this predates the branch).
- `is_hidden_from_discovery` and `live_ingest_state` are publicly readable (accepted).
- The phone-screen `_syncSessionIngest` has no widget test, because the native engine can't run in tests.

## Group 2: in progress (uncommitted)

**Done in the working tree:**
- `YouTubeApiService.fetchWatchStatus()` does a public `videos.list` read (`snippet.liveBroadcastContent`, `liveStreamingDetails.actualEndTime`, `channelId`; checked against the docs via Context7 `/websites/developers_google_youtube_v3`).
- `AppProvider` accepts an injectable `youTubeService` in `withServices`, and adds:
  - `verifyWatchLink()`, returning `WatchLinkCheck`/`WatchLinkVerdict`, with a channel check against the approved or organization handle;
  - `findMyLiveBroadcast()`, which replaces `autoDetectAmirLiveVideo` (the removed method searched one fixed channel for every account and faked LIVE).

**Next steps, in order:**
1. **The analyzer is currently BROKEN**, because `rtmp_ip_dialog.dart` still calls the removed `autoDetectAmirLiveVideo`/`isDetectingAmirLiveVideo`. Apply the prepared script `python brief/.runtime/p6s-wave3/handoff/edit_g2_studio.py`. It makes these studio changes:
   - The "OBS" tab becomes "Encoder" with two named senders, `obs_laptop` and `external_phone`, recorded as the session sender mode.
   - OBS mode no longer shows or copies a stream key or ingest URL; a note says the encoder holds the key.
   - The watch link is verified before listing (not found, ended, regular video and wrong channel are refused; "unverified" proceeds with a note).
   - A key pasted in the watch field, or a watch link pasted in the key field, is detected.
   - Helper text explains the public watch link versus the secret key, and the hard-coded English is localized.
   If an anchor has drifted, re-read the file and adapt the script.
2. Add the i18n keys the script uses, in both en and ar, with `i18n_set.py`:
   - mode and sender: `live_studio.mode_encoder`, `sender_label`, `sender_obs_laptop`, `sender_external_phone`, `sender_obs_laptop_help`, `sender_external_phone_help`, `encoder_key_note`;
   - find-live: `find_live_button`, `find_live_busy`, `find_live_no_channel`, `find_live_unavailable`, `find_live_none`;
   - fields: `watch_link_hint`, `watch_link_helper`, `title_hint`, `stream_key_helper`;
   - errors and checks: `error_key_in_watch_field`, `error_watch_in_key_field`, `watch_check_not_found`, `watch_check_ended`, `watch_check_not_live`, `watch_check_wrong_channel`, `watch_check_unverified_note`.
   Arabic uses يوتيوب but keeps "YouTube Studio". Label the external phone app as untested by us; never call it OBS.
3. Update tests that tap the literal `'OBS'`: `test/rtmp_ip_dialog_test.dart` lines 138/203/329/379, and possibly `broadcaster_studio_entry_test.dart`. Studio tests need a fake `YouTubeApiService` injected, or they will make real HTTP calls; fake `fetchWatchStatus` to return live. Add Group 2 tests: every verdict, the wrong-channel refusal, the unverified note, the swap detection, and the recorded sender mode.
4. `flutter analyze` (0), focused tests, the full suite, gates, then the **Group 2 critic loop** (maximum 3 cycles). Commit `feat(streaming): verified watch links and named external senders`.
5. **BLOCKED, owner only:** YouTube channel OAuth plus a server coordinator for create/bind/transition/end (D8). Keep the manual path.

## Groups 3–5: not started (planned scope)

- **Group 3 (Android media), safe slices only:**
  - a persistent, localized End control in portrait and landscape (landscape controls currently fade out and End sits in a "more" sheet; tooltips are hard-coded English);
  - Back/leave shows a confirm dialog (End broadcast / Stay); "Keep broadcasting" stays unavailable until service-owned capture is verified;
  - the 480p label says ~1.2 Mbps while the preset is 800 kbps (truthfulness);
  - record the 740/720 decision (D1);
  - native gaps, recorded as E4 and not implemented blind: `RtmpPublisherBridge.kt` `setOrientation` is a no-op; audio-only only mutes GL video (the camera is not released); the `RtmpStream` source-swap rewrite and fixed-canvas rotation need physical phones.
- **Group 4 (Local, privacy):** no transport is feasible without owner decisions D3/D4 and hardware. Keep Local visibly unavailable and deliver the decision record. "Remove from Feed" semantics are implemented in Group 1 as Hide (reversible) plus End-and-block.
- **Group 5 (playback):**
  - give the room's player a `GlobalKey` so normal, fullscreen and rotation keep one instance;
  - wire the play/pause/mute controls to real iframe postMessage commands (they only flip booleans today);
  - replace the fake mini-player (a stock-image card) with an honest "Return to broadcast" chip, or a real player on wide screens;
  - YouTube system PiP stays unavailable;
  - rewrite the quest-style `streamer_setup_guide_modal.dart` "More info" into mode-specific en/ar help (see research `06_STREAMER_GUIDANCE.md`).

## Remaining deliverables (on the branch)

1. A dated implementation and evidence report, for example `brief/evidence/2026-09-25/p6s-wave3/REPORT.md`. It needs one table per group (scope, commits, critic scores per cycle, tests, E4 still needed, risks, rollback), with P6S-1..7 mapped and the demo, Play and App Store checkpoints kept separate.
2. The owner-decision record, starting from `handoff/decisions_draft.md` (D1–D8).
3. The two-phone/Chrome/YouTube and Local retest script, starting from `handoff/retest_draft.md`, with expected sender, server and viewer results. Two-phone steps: transfer while viewing, admin End/Hide/Show/End-and-block, reconnect after End, refused Google sign-in, wrong-watch-link refusal. Local: verify it is shown as unavailable.
4. `HANDOFF_TO_ASTRA.md` at the worktree root: branch and path, base and tip, changed files and migrations, test commands and results, critic history, unresolved defects, owner-only checks, and likely merge conflicts. Conflicts: the main checkout's dirty `Core_files/STATUS.md`, `Core_files/progres.md`, `Roadmap.md`, `brief/LEDGER.md`, `issue_encountered.md` and `skill-observations/log.md` are not edited by this branch so far. If the branch edits those, expect conflicts, so prefer new files.

## Rules to keep

- Never run the app with `project/dart_define.local.json` (it points at hosted production) and never print it. No hosted migration, push, PR, merge or deploy.
- Stage explicit paths only.
- Before each commit, restore line-ending-only changes to the `project/windows/flutter/generated_*` files: `git checkout -- project/windows/flutter/`.
- Budget: Opus waiver §K in `brief/04_BUDGET_PROTOCOL.md`; no meter calls.
- Heredocs containing apostrophes break in the Bash tool. Write Python edit scripts with the Write tool instead.
