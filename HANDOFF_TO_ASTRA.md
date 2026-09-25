# Handoff to Astra: P6S wave 3

Date: 2026-09-26. Implementation engineer: Claude Opus 5.5. The branch is ready for review. It is **not pushed, not merged and not deployed**, and nothing has been physically accepted.

## Where it is

| | |
|---|---|
| Worktree | `C:\Users\User\Documents\Amir Ob\projects\Ideas\Current\Streamer_app\.claude\worktrees\p6s-wave3` |
| Branch | `opus/p6s-wave3-implementation` |
| Base | local `master` at `760a69b58b92d3eadeace34a15380820974f5a31` |
| Tip | the docs commit on top of `5fae669` (run `git log -1` in the worktree) |
| Main checkout | Untouched. Its dirty files (`Core_files/STATUS.md`, `Core_files/progres.md`, `Roadmap.md`, `brief/LEDGER.md`, `issue_encountered.md`, `skill-observations/log.md`), its untracked owner evidence and `brief/research/` are not part of this branch. The stashes `stash@{0}` (d646b94) and `stash@{1}` (d53c178) are untouched. |

## Commits (oldest first)

| Commit | Group | Title |
|---|---|---|
| `cb3caee` | 1 | fix(streaming): truthful live state, exact watch identity and admin controls |
| `ac8c45f` | docs | session handoff and continuation prompt for wave 3 |
| `39d40ca` | 2 | feat(streaming): verified watch links and named external senders |
| `9b59e22` | 3 | fix(streaming): persistent End, leave confirmation and truthful phone media copy |
| `d388a41` | 4 | fix(streaming): keep Local visibly unavailable and remove LAN leftovers |
| `5fae669` | 5 | feat(playback): real player commands, one retained room player and mode-specific help |
| (tip) | docs | the report, owner decisions, retest script and this handoff |

## What changed

**Migration (one, new):** `supabase/migrations/20260925100000_broadcast_sessions_and_live_controls.sql`. It adds:
- `broadcast_sessions` with sender mode, ingest state and end reasons;
- force_end and remove_from_feed without demotion;
- `admin_set_stream_discovery` (hide/show);
- `my_broadcast_status`;
- session-fenced `start_broadcast_session`, `report_broadcast_ingest` and `end_broadcast_session`;
- `ingest_lost` after 120 s;
- `organization_revoked`.

It is applied **only** to the disposable local stack. **Do not apply it to hosted production** until it has run on staging. pgTAP: `supabase/tests/broadcast_session_authority.test.sql`, `broadcast_session_fencing.test.sql` and `admin_safety_actions.test.sql` (updated).

**App (`project/lib`), by area:**
- Provider and services: `app_provider.dart`, `youtube_api_service.dart`, `admin_database_service.dart`, `admin_safety_backend.dart`.
- Shared widgets: `interactive_toast_overlay.dart`, `floating_stream_mini_player.dart`, `device_session_presenter.dart`, `app_router.dart`.
- Live stream: `abstract_video_player.dart`, `youtube_player_adapter.dart`, `live_broadcast_screen.dart`, `phone_broadcast_screen.dart`, `rtmp_ip_dialog.dart`, `streamer_setup_guide_modal.dart`, `live_player_overlay_controls.dart`.
- Admin: `admin_hub_screen.dart`, `admin_safety_view.dart`.
- Other: discovery feed, spatial map, streamer model, broadcaster profile, settings screens.
- Catalogs: `assets/i18n/en.json` and `ar.json`, key-symmetric.

The full list: `git diff --name-only 760a69b HEAD`.

**New tests:**
- `p6s_wave3_group1_test.dart`
- `youtube_watch_status_test.dart`
- `phone_broadcast_end_test.dart`
- `local_mode_unavailable_test.dart`
- `p6s_wave3_group5_test.dart`
- `youtube_embed_page_test.dart`

Several existing tests were updated where their behaviour changed on purpose.

## How to verify

From `project/`:

```
flutter analyze
flutter test
```

From the worktree root:

```
node brief/tools/gates.mjs --json
bash brief/.runtime/p6s-wave3/sqlrun.sh
```

`sqlrun.sh` needs the local disposable stack `P6S_wave3_20260925`. If Docker stopped it, restart it with the Supabase CLI and `--workdir brief/.runtime/p6s-wave3`. The `brief/.runtime/` folder is git-ignored and exists only in this worktree.

**Results at the tip:**
- Analyzer: 0 issues.
- Flutter: 688 passed.
- Gates: PASS, with the same five INFO items as on master (G2c, G10b, G10e, G11c, G11g).
- pgTAP: 20 files, 433 assertions, PASS.
- E3 probe (Group 1): 16/16.

Never run the app with `project/dart_define.local.json`: it points at hosted production.

## Critic history

Each group was scored by an independent, read-only critic subagent, for at most 3 cycles. Scores are functionality / accessibility and platform / integration / ease of use. **No group reached the bar** (all 10s, or three 10s and a 9). Every group ended with no critical or high defect.

| Group | Cycle 1 | Cycle 2 | Cycle 3 (final) |
|---|---|---|---|
| 1 | 5/6/5/4 | 6/6/6/6 | 7/7/6/7 |
| 2 | 7/7/6/7 | 8/7/8/8 | 9/8/8/8 |
| 3 | 7/6/6/7 | 8/8/7/8 | 8/8/8/8 |
| 4 | 7/6/6/7 | 8/8/7/8 | 9/9/8/9 |
| 5 | 6/5/6/7 | 8/7/7/8 | 8/7/8/8 |

Small post-cycle fixes were made after some final cycles and were not re-scored. They are listed per group in `brief/evidence/2026-09-25/p6s-wave3/REPORT.md`.

## Unresolved defects (none critical or high)

- **G1:** feed and map have no "reconnecting" cue; old APKs map 42501 to "approval required"; org revocation can end another account that shares a watch ID (predates this branch); the phone `_syncSessionIngest` has no widget test.
- **G2:** the phone-screen note can sit behind permission prompts; the search cooldown lasts for one app session; timeouts cover the studio lookups only; the link check runs in the app only (BLOCKED, D8).
- **G3:** End is hidden in portrait while the keyboard is open; no test covers a remote end flipping End to Leave.
- **G4:** `localRtmp` and `WebLivePlayerAdapter` are unreachable but still present (follow-up); the key name `live.rtmp_ip_tooltip`.
- **G5:** the 10 s "silent player" fallback can show a pause icon over a stopped video; the page script is tested only as text; a brief mute-icon flicker is possible.

## Owner-only (BLOCKED or E4)

- **E4 physical run:** `brief/evidence/2026-09-25/p6s-wave3/RETEST_SCRIPT.md` (two phones, Chrome, YouTube, Local). Run it on a **non-production** backend with the migration applied, using a `YOUTUBE_API_KEY` build.
- **Decisions D1–D8:** `brief/evidence/2026-09-25/p6s-wave3/OWNER_DECISIONS.md`, including the Local decision record.
- **Native, not implemented blind:**
  - `setOrientation` is a no-op (D7);
  - audio-only does not release the camera;
  - the `RtmpStream` source swap;
  - a foreground service for "Keep broadcasting".
- **Needs Google Cloud and OAuth:** YouTube channel OAuth and a server coordinator (D8).
- **Needs D3 and hardware:** any Local transport.

## Likely merge conflicts

- The branch edits **none** of the main checkout's dirty files, so those cannot conflict.
- If `master` has moved since `760a69b`, expect conflicts in the high-churn shared files:
  - `project/lib/core/providers/app_provider.dart`;
  - `project/assets/i18n/en.json` and `ar.json`;
  - `rtmp_ip_dialog.dart`;
  - `live_broadcast_screen.dart`;
  - `phone_broadcast_screen.dart`.
- When resolving the catalogs:
  - keep en and ar key-symmetric;
  - keep the copyright sign escaped as `\u00A9` (gate G3 counts a raw ©).
- A new migration on `master` with a later timestamp is fine. One with an earlier timestamp that touches `profiles` or the `admin_*` RPCs needs a re-run of the pgTAP suite.

## Evidence files on the branch

`brief/evidence/2026-09-25/p6s-wave3/`:
- `REPORT.md`: one table per group, the P6S-1..7 mapping, and the demo, Play and App Store checkpoints;
- `OWNER_DECISIONS.md`: D1–D8 and the Local record;
- `RETEST_SCRIPT.md`: the E4 script;
- `SESSION_HANDOFF.md` and `CONTINUE_PROMPT.md`: the mid-run handoff.
