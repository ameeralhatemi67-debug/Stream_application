# Wave 4v2 acceptance results — camera follow-up, 2026-09-27

All subchecks start NOT RUN. Historical Wave 4 is retained in the main checkout and is not a pass for this build. Use PASS / FAIL / NOT RUN / DEFERRED (explicit owner reference required). Duplicate a row for every additional phone, locale, camera or fault; never collapse failing siblings into a PASS heading.

Date/operator: ___  Source commit: ___
APK/web/config SHA256 and variant: ___
Safe backend/migration identity: ___  D8: RELEASE BLOCKER (owner confirmed)
Phone A model/OS/WebView: ___  Phone B model/OS/WebView: ___
Chrome/OBS versions: ___  Test identity roles: ___
Media network/control-backend network/USB tunnel: ___
UTC clock alignment: ___  Approved scope decisions/references: ___

| Subcheck | Status | Sender/device observation | Server session/watch/authority | Viewer/device observation | Actual timing/count/gaps | Evidence/failing sibling |
|---|---|---|---|---|---|---|
| F01.1 A sender/B Android ended | NOT RUN | | | | | |
| F01.2 A sender/C Chrome ended | NOT RUN | | | | | |
| F01.3 B sender/A Android ended | NOT RUN | | | | | |
| F01.4 B sender/C Chrome ended | NOT RUN | | | | | |
| F01.5 approval and primary retained | NOT RUN | | | | | |
| F01.6 feed/map convergence | NOT RUN | | | | | |
| F02.1 offline viewer learns ordinary End | NOT RUN | | | | | |
| F02.2 same-watch/new-session never takes over old room | NOT RUN | | | | | |
| F03.1 A brief drop | NOT RUN | | | | | |
| F03.2 B brief drop | NOT RUN | | | | | |
| F03.3 A Wi-Fi to cellular | NOT RUN | | | | | |
| F03.4 B Wi-Fi to cellular | NOT RUN | | | | | |
| F04.1 Android muted and paused | NOT RUN | | | | | |
| F04.2 Android playing and unmuted | NOT RUN | | | | | |
| F04.3 Chrome unconfirmed reload/native Play, pause/mute | NOT RUN | | | | | |
| F05.1 sender exhaustion en | NOT RUN | | | | | |
| F05.2 sender exhaustion ar | NOT RUN | | | | | |
| F05.3 viewer exhaustion en | NOT RUN | | | | | |
| F05.4 viewer exhaustion ar | NOT RUN | | | | | |
| F05.5 sender manual Retry/Leave | NOT RUN | | | | | |
| F05.6 viewer manual Retry/Leave | NOT RUN | | | | | |
| F06.1 manual End during retry | NOT RUN | | | | | |
| F06.2 admin End during retry | NOT RUN | | | | | |
| F06.3 admin block during retry | NOT RUN | | | | | |
| F06.4 transfer during retry | NOT RUN | | | | | |
| F06.5 revocation during retry | NOT RUN | | | | | |
| F06.6 sign-out during retry | NOT RUN | | | | | |
| F06.7 expired session cannot revive | NOT RUN | | | | | |
| F07.1 A rear portrait/left/right preview | NOT RUN | | | | | |
| F07.2 A rear received media | NOT RUN | | | | | |
| F07.3 A front switching unavailable / Coming Soon | NOT RUN | | | | | |
| F07.4 B rear preview and received | NOT RUN | | | | | |
| F07.5 B front switching unavailable / Coming Soon | NOT RUN | | | | | |
| F07.6 repeated rotation one session/audio instance | NOT RUN | | | | | |
| F08.1 sender draft and real keyboard en/ar | NOT RUN | | | | | |
| F08.2 viewer draft and real keyboard en/ar | NOT RUN | | | | | |
| F09.1 sender media tap/End/Back | NOT RUN | | | | | |
| F09.2 Android viewer media tap/native controls | NOT RUN | | | | | |
| F09.3 Chrome iframe controls and app toggle | NOT RUN | | | | | |
| F09.4 TalkBack and keyboard focused controls | NOT RUN | | | | | |
| F10.1 short landscape settings en 2x | NOT RUN | | | | | |
| F10.2 short landscape settings ar 2x | NOT RUN | | | | | |
| F10.3 chat/menu/End/transfer transitions | NOT RUN | | | | | |
| F11.1 matching handle/URL | NOT RUN | | | | | |
| F11.2 mismatch correction | NOT RUN | | | | | |
| F11.3 canonical channel ID | NOT RUN | | | | | |
| F11.4 Unicode/legacy supported reference | NOT RUN | | | | | |
| F11.5 malformed/deceptive URL | NOT RUN | | | | | |
| F11.6 account switch/stale lookup | NOT RUN | | | | | |
| F11.7 full handle URL through actual submit/save | NOT RUN | | | | | |
| F12.1 missing API key | NOT RUN | | | | | |
| F12.2 HTTP503/quota403 controlled fixture | NOT RUN | | | | | |
| F12.3 wrong channel | NOT RUN | | | | | |
| F12.4 ended/VOD | NOT RUN | | | | | |
| F12.5 malformed watch/channel response | NOT RUN | | | | | |
| F12.6 far-future upcoming rejection | NOT RUN | | | | | |
| R01.1 admin End and role preservation | NOT RUN | | | | | |
| R02.1 Hide | NOT RUN | | | | | |
| R02.2 Show | NOT RUN | | | | | |
| R02.3 End-and-block | NOT RUN | | | | | |
| R02.4 same-ID relist denied | NOT RUN | | | | | |
| R02.5 new permitted ID allowed | NOT RUN | | | | | |
| R03.1 normal transfer | NOT RUN | | | | | |
| R03.2 transfer during confirmation | NOT RUN | | | | | |
| R03.3 transfer during recovery | NOT RUN | | | | | |
| R04.1 same-watch rapid restart | NOT RUN | | | | | |
| R04.2 late callback/End regression | NOT RUN | | | | | |
| R04.3 End during fullscreen/dialog | NOT RUN | | | | | |
| R05.1 A direct AV >=15min + interruption | NOT RUN | | | | | |
| R05.2 B direct AV >=15min + interruption | NOT RUN | | | | | |
| R06.1 OBS AV >=15min + interruption | NOT RUN | | | | | |
| R07.1 audio-only audibility | NOT RUN | | | | | |
| R07.2 camera indicator while hidden | NOT RUN | | | | | |
| R07.3 camera/mic release after End | NOT RUN | | | | | |
| R08.1 Home continuity | NOT RUN | | | | | |
| R08.2 lock continuity | NOT RUN | | | | | |
| R08.3 return foreground | NOT RUN | | | | | |
| R08.4 confirmed route exit releases resources | NOT RUN | | | | | |
| R09.1 normal native readiness | NOT RUN | | | | | |
| R09.2 reachable iframe/suppressed bridge timeout | NOT RUN | | | | | |
| R09.3 real Retry/mute/pause | NOT RUN | | | | | |
| R09.4 Chrome native transport | NOT RUN | | | | | |
| R10.1 org/external-phone unavailable | NOT RUN | | | | | |
| R10.2 Local/private/direct-laptop unavailable | NOT RUN | | | | | |
| R10.3 web Phone unavailable | NOT RUN | | | | | |
| R10.4 upcoming/return-chip/PiP claims | NOT RUN | | | | | |
| R11.1 camera denial | NOT RUN | | | | | |
| R11.2 microphone denial | NOT RUN | | | | | |
| R11.3 setup/key cancel | NOT RUN | | | | | |
| R11.4 Back/loading/offline/reconnect | NOT RUN | | | | | |
| R11.5 server refusal and End resource release | NOT RUN | | | | | |
| R12.1 guest and account switching | NOT RUN | | | | | |
| R12.2 approval/channel isolation | NOT RUN | | | | | |
| R12.3 device revocation | NOT RUN | | | | | |
| R12.4 deleted account/cache | NOT RUN | | | | | |
| P01.1 guest/read-only/offline draft | NOT RUN | | | | | |
| P01.2 muted/banned/slow/pause | NOT RUN | | | | | |
| P01.3 new message pill/scroll | NOT RUN | | | | | |
| P01.4 failed send retry/no duplicate | NOT RUN | | | | | |
| P01.5 badges/empty/no ghosts | NOT RUN | | | | | |
| P02.1 rate limit and Arabic keywords | NOT RUN | | | | | |
| P02.2 report enum/uniqueness | NOT RUN | | | | | |
| P02.3 stranger/nonadmin denial | NOT RUN | | | | | |
| P02.4 owner/moderator success | NOT RUN | | | | | |
| P02.5 current SQL suite | NOT RUN | | | | | |
| P03.1 viewer block persists across restart | NOT RUN | | | | | |
| P03.2 report reason and live admin queue | NOT RUN | | | | | |
| P03.3 delete/mute convergence | NOT RUN | | | | | |
| P03.4 audit evidence | NOT RUN | | | | | |
| P04.1 directory search/detail | NOT RUN | | | | | |
| P04.2 ban/unban | NOT RUN | | | | | |
| P04.3 streamer revoke | NOT RUN | | | | | |
| P04.4 session revoke | NOT RUN | | | | | |
| P04.5 account deletion | NOT RUN | | | | | |
| P04.6 lower-role denial | NOT RUN | | | | | |
| P05.1 live list/force-end | NOT RUN | | | | | |
| P05.2 audit filters | NOT RUN | | | | | |
| P05.3 keyword edits | NOT RUN | | | | | |
| P05.4 chat flag | NOT RUN | | | | | |
| P05.5 registration flag | NOT RUN | | | | | |
| P05.6 nonadmin RPC refusal | NOT RUN | | | | | |
| P06.1 guest/viewer heartbeat counts | NOT RUN | | | | | |
| P06.2 unrelated org features | NOT RUN | | | | | |
| P06.3 deferred org cannot start | NOT RUN | | | | | |

Temperature/readiness/AV notes: ___
Unexpected defects and reproduction: ___
Automated fixture result recorded separately from physical observations: ___
P6 decision: NOT ACCEPTED. Missing evidence/approved cuts: ___
P6S decision: NOT ACCEPTED. Missing evidence/approved cuts: ___
Owner/reviewer/date: ___

## Prior review and current release blocker

The previous candidate's review 3/3 found the unconfirmed notice intercepting the full-room eye toggle. This follow-up reserves its hit area and adds an unconfirmed-state tap regression. F09/F10/C10 still require physical confirmation; a standalone browser probe does not prove the full room. The old scores 8/7/7/7 do not apply to this changed source. Use the source identity in this folder's README/identity.json. All fresh physical rows remain NOT RUN. D8 remains HIGH and release-blocking by owner decision.

## New focused cases (run first; every observation initially NOT RUN)

Use PASS / FAIL / NOT RUN; repeat rows for each phone, locale and preset. Device/build/backend identity at the top is required. Never record ingest keys or access tokens.

| Case | State | Sender observation | Server/session continuity | Independent received video/chat | Timing / latency | Evidence |
|---|---|---|---|---|---|---|
| C01 portrait → left → portrait → right, medium, phone A | NOT RUN | | | | | |
| C01 same, phone B | NOT RUN | | | | | |
| C02 low/high presets and different supported camera ratios | NOT RUN | | | | | |
| C03 three controls, top-left End, media tap, chat height | NOT RUN | | | | | |
| C04 sender/viewer/admin draft + real keyboard + edit + studio rotation | NOT RUN | | | | | |
| C05 settings scroll, all rows/actions, en/ar, largest font, short laptop window | NOT RUN | | | | | |
| C06 front camera Coming Soon, unchanged preview/received feed | NOT RUN | | | | | |
| C07 End/Back with controls hidden, TalkBack/keyboard, cancel/end | NOT RUN | | | | | |
| C08 ordinary End + independent phone/Chrome + role retention | NOT RUN | | | | | |
| C09 rotate during reconnect, End/transfer while menu open | NOT RUN | | | | | |
| C10 unconfirmed viewer toggle / native player controls / Retry | NOT RUN | | | | | |

Front-camera operation is explicitly deferred by the owner's 2026-09-27 request. This changes scope; it is not a physical PASS. D8 is explicitly NOT deferred. Do not close P6/P6S on C01–C10 alone: the F/R/P rows above remain required according to the closure matrices.
