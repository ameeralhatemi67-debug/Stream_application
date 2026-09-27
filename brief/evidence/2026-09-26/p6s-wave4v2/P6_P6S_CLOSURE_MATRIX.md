# Separate P6 / P6S closure matrices
Current status: both NOT ACCEPTED. Final critic8/7/7/7 after3 rounds; review target not met. Historical counts in roadmap/audits are historical only. Full source verification results are in VERIFICATION.md. Physical tests in this build are all NOT RUN. The owner explicitly retained D8 as a release blocker; no scope deferral is inferred.

## P6
| Requirement | Implementation / automated evidence | Historical evidence | Fresh case | Closure |
|---|---|---|---|---|
| 6.1 rate limits/index/slow mode/chat enable | Existing migrations/chat tests; fresh local SQL 21 files/440 assertions PASS | Prior disposable SQL audit | P02 | Physical pending |
| 6.1 Arabic keyword normalization | Existing trigger and keyword tooling | Prior audit; no fresh Arabic physical probe | P02 | Pending |
| 6.1 report enum/uniqueness/live queue | Existing report/admin tests | Prior audit | P02/P03 | Pending |
| 6.1 server viewer blocks | Existing chat_block_sync_test | Prior source evidence | P03 | Pending fresh persistence/sync |
| 6.2 guest/muted/banned/offline/slow composer | chat_composer_state_test; landscape now read-only | Wave 4 streaming evidence cannot close chat | F08/P01 | Pending |
| 6.2 report/block/hide, scroll pill, optimistic retry, status, badges, empty/no ghosts | Existing chat feature and tests; not independently exhaustive this slice | Prior source evidence only | P01/P03 | Pending |
| 6.3 admin report queue/delete/mute/audit | Existing admin tests; server functions unchanged | Prior audit | P03 | Pending real convergence/audit |
| 6.4 directory search/details/ban/unban/revoke/delete | admin_user_directory_test, admin_database_service_test | Prior directory SQL and owner account evidence | P04/R12 | Pending |
| 6.4 live list/force-end/remove feed | admin moderation/safety tests | Wave 4 admin End/Hide/Show/block PASS subchecks | R01/R02/P05 | Pending fresh run |
| 6.4 audit viewer/keyword manager/app flags | admin_safety_console_test, admin_hub_screen_test; existence/tests do not prove complete acceptance | Roadmap completion statements are stale/uneven | P05 | Pending feature-by-feature evidence |
| 6.4 deleted-account cache and issued-session limits | Existing account/device tests | Prior audit | R12/P04 | Pending |
| Server nonadmin/stranger denial and real-owner success | Fresh disposable SQL suite PASS (21 files/440 assertions); no new migration | Prior SQL and fresh local SQL, no fresh physical pass | P02/P04/P06 | Pending; not waived by UI tests |

## P6S
| Requirement | Implementation / automation | Historical physical evidence | Fresh case | Closure / decision |
|---|---|---|---|---|
| 1 OBS laptop AV/End/recovery | Existing setup/watch gates; no external encoder control | Wave 4 received AV PASS | R06/F01/R01/F04 | Pending 15min and recovery |
| 1 OBS-compatible external phone | Visible disabled selection; provider rejects activation | None accepted | R10 | D6 formal exclusion pending; mode is gated |
| 2 direct Android permissions/AV/End | Existing native bridge and phone tests; G1 repaired | Wave 4 AV passed, ordinary End failed | F01/F02/R05/R11 | Pending each phone |
| 2 native orientation/aspect/front/back | RtmpStream fixed canvas / fitted GL transform; Kotlin compile and native probe evidence tracked separately | Wave 4 failures/screenshots | F07 | Physical preview/received-video evidence and D7 pending |
| 2 bounded sender recovery/authorization | Dart-only 3s/10-attempt/60s episode, fresh server permission/session/device check; engine/provider race tests | Wave 4 recovery failed | F03/F05/F06 | Physical recovery/terminal-state evidence pending |
| 2 audio-only/camera/background | GL mute, camera stays active; notification service | Audibility passed, resource claim unproven | R07/R08 | Separate scope/evidence required |
| 3 web Phone unavailable/direct laptop | Existing unavailable states; no desktop transport | Prior route evidence | R10/R11 | D5 scope exclusion needs explicit approval |
| 4 Local transport | Unavailable | No positive transport evidence | R10 | D3 unresolved; unavailable exclusion required |
| 5 private/invites/access | Private media disabled; no authenticated media service | No private transport acceptance | R10/P02 | D4 unresolved; no unlisted privacy claim |
| 6 retained viewer/transport/fullscreen | Retained adapter, mute/pause-preserving Android retries, muted Chrome reload with explicitly unconfirmed playback; native readiness fault flag | Wave 4 transport/rotation subchecks PASS | F04/R09/R08 | Fault fixture supplied; real readiness and transport observations pending |
| 6 sender/viewer landscape usability | Read-only composers; sender controls and sheet repairs | Five screenshots identify defects | F08/F09/F10 | BLOCKED by introduced P2 unconfirmed-banner/toggle overlap; physical/TalkBack/retention pending |
| 6 PiP/mini-player | Unavailable; return chip owner-deferred | No real floating-player acceptance | R10 | Do not claim PiP; return-chip deferral only |
| 7 exits/end/transfer/generations | Existing phone/device tests plus same-watch regression | Wave 4 transfer/admin End PASS | F01/F02/F06/R03/R04/R11 | Pending |
| 7 account/channel identity/watch validation | Shared channel parser + save consistency; existing fail-closed client validation; server bypass remains | Wave 4 malformed/stale channel finding | F11/F12/R12 | D8 HIGH release blocker explicitly retained by owner; F11/F12/R12 physical pending |
| Organization broadcasting | Owner explicitly deferred post-release; entry selectors disabled and provider denies selection | Owner Wave 4 deferral | R10/P06 | Exclusion implemented; unrelated org regressions pending |
| Upcoming management | Owner explicitly deferred; negative scheduled checks retained | Owner Wave 4 deferral | F12/R10 | Management deferred, negative safety still required |
| Required resource/long-duration evidence | No physical runtime this slice | Short AV historical passes insufficient | R05/R06/R07/R08 | NOT RUN |
| Approved platform/mode matrix | D1–D8 listed in REPAIR_REPORT | No blanket scope approval | R10 + owner decisions | Release gate open |

No score, APK compilation, mock test or historical PASS closes either matrix.

