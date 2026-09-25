# P6S wave 3: implementation and evidence report

Date: 2026-09-25. Branch `opus/p6s-wave3-implementation` on base `master` `760a69b`. The branch is not pushed and not merged. Engineer: Claude Opus 5.5 (implementation), with independent critic subagents (read-only) scoring every group.

**Evidence classes.** Only the owner's E4 run on physical phones accepts anything physically. E1–E3 are what this branch has.

| Class | Meaning | Present on this branch |
|---|---|---|
| E1 | Code reading and static analysis | `flutter analyze` 0 issues at every commit |
| E2 | Deterministic automated proof | Full Flutter suite, gates (`node brief/tools/gates.mjs`) and pgTAP on the disposable DB (Group 1) |
| E3 | Separate-process probe against a local backend | Group 1: two-client Realtime probe, 16/16 |
| E4 | Owner, physical devices, real YouTube | **None yet.** Script: `RETEST_SCRIPT.md` |

**Critic bar.** A group passes when its four scores are all 10, or three are 10 and one is 9, with no critical defect. Each group got at most 3 cycles, and scores were never inflated. **No group reached the bar.** Every group ended with no critical or high defect; the remaining items are listed per group. Where fixes were made after the last scored cycle, they are marked "post-cycle, not re-scored".

## Summary

| Group | Commit | Scope | Final critic (F / A / I / E) | Full suite | Gates |
|---|---|---|---|---|---|
| 1 | `cb3caee` | Truthful live state, exact watch identity, admin controls | 7 / 7 / 6 / 7 | 615 pass | PASS/INFO |
| 2 | `39d40ca` | Verified watch links and named external senders | 9 / 8 / 8 / 8 | 652 pass | PASS/INFO |
| 3 | `9b59e22` | Persistent End, leave confirmation, truthful phone media copy | 8 / 8 / 8 / 8 | 664 pass | PASS/INFO |
| 4 | `d388a41` | Local kept visibly unavailable; LAN leftovers removed | 9 / 9 / 8 / 9 | 665 pass | PASS/INFO |
| 5 | `5fae669` | Real player commands, one retained player, honest return chip, mode-specific help | 8 / 7 / 8 / 8 | 688 pass | PASS/INFO |

Score columns: F = functionality; A = accessibility and platform compatibility; I = integration and connectivity; E = ease of use. The gate INFO items are the same five on every run (G2c, G10b, G10e, G11c, G11g) and are informational by design.

## Group 1: truthful live state, exact watch identity, admin controls (`cb3caee`)

| Item | Detail |
|---|---|
| Scope | The room plays only the exact `active_stream_id`; there is no IFrame sample video, failover or borrowed streamer. Stale LIVE is cleared by fresh catalog reads (20 s room poll, 30 s feed/map lease, follow-up read). The server-side `broadcast_sessions` table has end reasons. Admin End/Remove no longer demote the broadcaster. Hide from discovery is reversible and audited. The ingest session is fenced (55000 after end), and ingest is marked lost after 120 s. A refused Google sign-up shows its reason. |
| Migration | `supabase/migrations/20260925100000_broadcast_sessions_and_live_controls.sql`. Local disposable DB only; **not applied to hosted**. |
| Critic cycles | 5/6/5/4 → 6/6/6/6 → 7/7/6/7. One post-cycle repair (ingest reported only on change) was not re-scored. |
| Tests | pgTAP: 20 files, 433 assertions pass on a fresh disposable DB. E3 probe 16/16. Flutter 615 pass. |
| Still open | Feed and map show no "reconnecting" cue. Old APKs map 42501 to "approval required". Org revocation can end another account that shares the watch ID (predates this branch). `is_hidden_from_discovery` and `live_ingest_state` are publicly readable (accepted). The phone `_syncSessionIngest` has no widget test. |
| E4 needed | Transfer while viewing; admin End, Hide, Show and End-and-block; reconnect after End; refused sign-in (script rows 4, 5, 9). |
| Risks | The migration must be applied to a staging project before hosted. Old clients during the rollout. |
| Rollback | Revert the commit and drop the migration's objects on a non-production DB. The app degrades to the legacy `set_live_state` path, which is still supported. |

## Group 2: verified watch links and named external senders (`39d40ca`)

| Item | Detail |
|---|---|
| Scope | Before listing, YouTube `videos.list` checks the link. Refused: not found, ended, regular video, scheduled more than 1 h ahead, another channel than the approved application's or organization's. If YouTube cannot be asked (no key, quota, network, 8 s timeout) or no channel could be compared, the link is listed with an explicit note: a warning toast, announced to screen readers, and shown on the phone screen too. The Encoder tab has two named senders, `obs_laptop` and `external_phone` (untested by us, never called OBS), recorded as the server session sender mode. Encoder mode never shows or copies the key or ingest URL. A key pasted into the watch field, or a link, video ID or `rtmp://` address pasted into the key field, is caught before anything is sent. `findMyLiveBroadcast` replaces the fixed-channel auto-detect: this account only, never marks live, 30 s cooldown, and an outage is not reported as "none". |
| Critic cycles | 7/7/6/7 → 8/7/8/8 → 9/8/8/8. Post-cycle, not re-scored: the note toast uses a warning icon and colour. |
| Tests | `broadcaster_studio_entry_test.dart` (verdicts, channel checks, swap detection, sender modes, Arabic layout, phone path). `youtube_watch_status_test.dart` (real JSON parsing with MockClient, timeout). |
| Still open (LOW) | The phone-screen note can be hidden behind the permission prompts. A video with no channel ID gets the "lookup failed" note. The cooldown lasts for one app session only. Timeouts cover the studio lookups only (VOD, playlist and viewer-count calls have none). No test checks that the toast is announced to screen readers. |
| BLOCKED | Server-side re-validation of the link (a modified client can skip the check). It needs channel OAuth and a coordinator (D8). |
| E4 needed | Wrong-link refusals, OBS and optional Larix listing (script rows 6–8). |
| Risks | The public API key's shared quota. Without `YOUTUBE_API_KEY` every link is "not fully checked". |
| Rollback | Revert the commit. There is no schema change. |

## Group 3: persistent End, leave confirmation, truthful phone media copy (`9b59e22`)

| Item | Detail |
|---|---|
| Scope | A localized End control is always visible on the phone broadcast screen: pinned on the viewport in portrait, bottom-end in landscape, never faded, 48 px, also shown in the setup-error view. It reads Leave when nothing is sending and "Ending..." while stopping. Back (the gesture and the app-bar arrow) while sending asks End broadcast or Stay, and says background broadcasting is not available yet. A closing latch prevents double pops. An open dialog closes if the device is displaced. An end the server does not confirm is reported plainly. The studio's End, opened from the phone screen, now stops that screen's encoder: before, the encoder could relist. The studio cannot open a second camera screen. Studio preset labels come from the real encoder bitrate (480p used to say about 1.2 Mbps for a 0.8 Mbps preset). The non-functional custom-poster picker is removed, and the audio-only copy says the camera stays on. Tooltips and the controls sheet are localized. A 360 px heading overflow is fixed. |
| Critic cycles | 7/6/6/7 → 8/8/7/8 → 8/8/8/8. Post-cycle, not re-scored: the unconfirmed-End warning is based on this End's own outcome, and the "Ending..." button contrast is fixed. |
| Tests | `phone_broadcast_end_test.dart` (portrait/landscape End, Back, Stay/End, double Back, displacement with the dialog open, studio End, a listing ended elsewhere, 360 px muted layout, failed server end, no second camera screen, Arabic). `rtmp_ip_dialog_test.dart` updated. |
| Still open | End is hidden in portrait while the keyboard is open (the app-bar back arrow still works). No test covers a remote end flipping End to Leave. |
| BLOCKED / E4 | The native `setOrientation` is a no-op (D7). Audio-only only mutes GL video; the camera is not released. The `RtmpStream` source-swap rewrite, fixed-canvas rotation and a foreground service for "Keep broadcasting" are not implemented blind. |
| Decision | D1 (740 vs 720): the presets are unchanged. Recommendation: 720p. |
| Rollback | Revert the commit. There is no schema change. |

## Group 4: Local kept visibly unavailable (`d388a41`)

| Item | Detail |
|---|---|
| Scope | The studio's Local tab says "not available in this version" in en and ar and points to Phone or Encoder using the tab words. It has a "Not available" screen-reader hint, and the mode pills report button and selected semantics. Removed because they implied Local could be configured: the admin testing tools' laptop RTMP IP field, the unused `rtmpStreamUrl` and laptop-IP state, the old guide's same-Wi-Fi steps and their keys, and the "RTMP IP Settings" tooltip (now "Broadcaster Studio"). |
| Critic cycles | 7/6/6/7 → 8/8/7/8 → 9/9/8/9. Post-cycle, not re-scored: the decision-record wording and the pill semantics. |
| Tests | `local_mode_unavailable_test.dart` (rendered card in en and ar, no fields, admin tab without RTMP, tooltip wording). The studio tests assert that no field exists in Local mode. |
| Still open (LOW) | The tooltip test checks the catalog, not the rendered button. The key name `live.rtmp_ip_tooltip`. The unreachable `localRtmp` and `WebLivePlayerAdapter` (tracked for removal). |
| BLOCKED | Any Local transport: D3 topology, the offline-identity policy and physical devices. See the Local section of `OWNER_DECISIONS.md`. |
| Rollback | Revert the commit. |

## Group 5: playback and guidance (`5fae669`)

| Item | Detail |
|---|---|
| Scope | **Player commands.** The live room's play, pause and mute send IFrame API commands to the embedded YouTube player (`PlayerTransport`). They used to flip booleans only. A command counts only when the loaded page took it; a refusal says "the player is not ready yet"; taps wait for a pending command. The room follows the player's own state and mute: `onStateChange` and `infoDelivery`, after a `listening` handshake repeated until the player answers. Where the app has no command channel (web, desktop), the room's buttons are hidden and YouTube's own controls are used. A viewer's mute carries into a new player (`mute=1`). The buttons are 48 dp with localized tooltips. **Player lifetime.** One player per watch identity (GlobalKey), so rotation and fullscreen don't restart the video. Retry really reloads. **Return shortcut.** The fake mini-player (a stock photo and a mute button with no audio) is now an honest "Return to broadcast" chip that says playback stopped. No picture-in-picture is claimed. **Guide.** The quest-style "Streamer Academy" and its clipboard key shortcut are replaced by concise en/ar help per mode: OBS on a computer, another phone app, this phone, and Local (unavailable). Each has a watch-link vs key explanation. **Testability.** The embed page is now a pure, tested function. |
| Critic cycles | 6/5/6/7 → 8/7/7/8 → 8/7/8/8. Post-cycle, not re-scored: the page reports "ready", and unstarted or cued players show as paused, so a blocked autoplay is not shown as playing. |
| Tests | `p6s_wave3_group5_test.dart` covers: commands; refusal; hidden transport; mute across Retry; the player's own mute; the in-flight guard; rotation keeps one instance; Retry reloads; 48 dp and tooltips in Arabic at 360 px; the return chip; the guide per mode in en and ar. `youtube_embed_page_test.dart` covers the page. The mini-player and old guide tests were updated. |
| Still open | The fallback for a player that never answers (10 s) shows the player as live, so it can show a pause icon over a stopped video in that degraded case. The page script's behaviour is only tested as source text. A brief mute-icon flicker is possible between a command and YouTube's confirmation. |
| BLOCKED / E4 | Whether Android's web view survives the layout move; the handshake and event flow on real YouTube; web clicks reaching the iframe; a real floating player on wide screens (deferred); YouTube system PiP (stays unavailable). |
| E4 needed | Script row 10. |
| Rollback | Revert the commit. There is no schema change. |

## P6S acceptance mapping

| P6S | Research meaning | What this branch contributes | Status |
|---|---|---|---|
| P6S-1 | Internet senders (OBS on a laptop, an external phone app) → YouTube → Android/Chrome, with sender, server and viewer agreeing | Exact watch identity (G1); verified links, named senders, sender mode on the server session, key/link swap detection (G2) | E2 done. **E4 required** (rows 6–8). Coordinator/OAuth BLOCKED (D8). |
| P6S-2 | Direct Android camera → YouTube with a truthful lifecycle; End in both orientations | Session fencing and ingest states (G1); persistent End, leave confirmation, studio End routed through the screen, truthful presets and audio-only copy (G3) | E2 done. **E4 required** (rows 1–3, 12). Service-owned capture, rotation (D7) and camera release: BLOCKED (native, E4). |
| P6S-3 | Direct laptop (Windows) → Local sender | Kept unavailable, with nothing implying otherwise (G4) | BLOCKED (D3, D5). |
| P6S-4 | Local peer rooms between Android and Windows | Kept unavailable; decision record (G4) | BLOCKED (D3, identity policy, hardware). |
| P6S-5 | Privacy and admission: Remove from Feed, private rooms | Hide from discovery (reversible) versus End and block, with no demotion (G1); private stays off and unlisted is never called private | Hide/End: E2 done, **E4 required** (row 5). Private: BLOCKED (D4). |
| P6S-6 | Normal, fullscreen and in-app mini playback with one real player and real controls | Real commands, one retained player, real Retry, honest return chip (G5) | E2 done. **E4 required** (row 10). A real floating player is deferred. |
| P6S-7 | PiP, and exit/identity sweep | YouTube PiP stays unavailable and is not claimed (G5). The end/leave paths are covered in G3. | Local PiP BLOCKED (no Local). A full exit/identity sweep is still to do after E4. |

## Release checkpoints (kept separate)

| Checkpoint | Where this branch stands | What is still needed |
|---|---|---|
| **Presentation demo** | OBS or phone → YouTube → viewer rooms play the exact broadcast. Admin controls behave. Wrong links are refused. Local is shown honestly as unavailable. | Owner E4 run (`RETEST_SCRIPT.md`) on a **non-production** backend with the Group 1 migration applied, and a `YOUTUBE_API_KEY` build. |
| **Google Play (v1.0)** | Not ready from this branch alone. | Review and merge; the hosted migration applied after staging; physical E4 on the two phones; decisions D1, D6 and D7; the store listing and policy work in the main run (not touched here). No store action was taken. |
| **App Store (v1.1 iOS)** | Out of scope. No iOS phone-broadcast work was done (Android first, per the roadmap). | The v1.1 iOS integration. |

## Commands and results

From `project/`:
- `flutter analyze` reports 0 issues.
- `flutter test` gives the counts in the summary table.

From the worktree root:
- `node brief/tools/gates.mjs --json` gives PASS, plus the five INFO items.
- `bash brief/.runtime/p6s-wave3/sqlrun.sh` (Group 1 pgTAP; the local disposable stack `P6S_wave3_20260925`) gives 433 assertions passing.

Nothing was run against `dart_define.local.json` or hosted Supabase. No push, PR, merge, deploy or store action was taken.
