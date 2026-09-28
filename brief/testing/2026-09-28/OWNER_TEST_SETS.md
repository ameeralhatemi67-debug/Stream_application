# Hadayah owner test sets — 2026-09-28

Use this sheet for a **fresh build from `master`**. At planning time, local HEAD was `ca579a9`; the local `origin/master` reference was six commits behind. Neither Git nor an earlier phone screenshot proves which build is installed. Do not use the old diagnostic artifact hash as the identity of today's build. The 36-case [Wave4v2 retest](../../evidence/2026-09-27/hadayah-wave4v2-integration/WAVE4V2_RETEST_SCRIPT.md) remains the detailed protocol for streaming, chat, offline and integration cases; this sheet adds the recent UI/profile changes and gives you smaller work sessions. Earlier automated results are implementation evidence, not owner acceptance.

**How to record:** Leave each row `NOT RUN` until attempted. Use `PASS` only after the stated behavior is observed on the named device/role, `FAIL` for a reproducible deviation, and `BLOCKED` for an unmet prerequisite; put the reason and evidence in the last column. Record a screenshot/video or sanitized log, device model, OS/browser, locale, logical width/text scale, role, build ID and backend for each failure. Give related failures one issue ID and send a batch of 3–10 issues to the repair agent. Never paste stream keys, tokens or full private account details. When a fix changes the candidate, note its new commit/build identity and rerun the affected rows; retain old results as history.

**First session:** T0, then T1 and the non-network parts of T2. If T0 cannot establish a configured candidate, continue only guest/diagnostic UI and offline-map observations; mark Google/YouTube, signed-in chat/admin and cross-feature acceptance `BLOCKED`. Do not spend hours on dependent streaming tests after a failed capture, populated-card or End smoke. A/B means two physical Android phones (one is the owner's SM-S936B), swapping sender/receiver; C is Chrome with an independent viewer profile; admin uses a separate disposable account. Some rows need an engineer or a controlled non-production backend. A complete pass is several sessions, not a one-day promise.

## T0 — candidate, identities and prerequisites (10–20 min; first)

| ID | Do this; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| T0.1 | From the main repo `project/`, verify `master`, commit, fresh build/install, package/version/build ID and SHA-256 on each phone and web build identity on C; all match the candidate record. | NOT RUN | |
| T0.2 | Record A/B/C models, OS/browser, locale, logical width, text scale, role, timezone and network topology; confirm installed phone is today's build, not a cached/older app. | NOT RUN | |
| T0.3 | Confirm the intended **non-production** backend and ordered migrations, including `20260927010000`, `20260927020000` and profile-review `20260927030000`; a missing migration blocks its dependent tests. Do not inspect/copy `dart_define.local.json` or substitute production credentials. | NOT RUN | |
| T0.4 | On dedicated test identities only, confirm Google sign-in on A/B/C and approved streamer, viewer and admin roles; verify a permitted YouTube channel/event and restricted API key without exposing secrets. | NOT RUN | |
| T0.5 | Confirm the test event will not accidentally be public, and record whether phone backend traffic uses USB reverse, LAN or independent network. USB reverse is not proof of untethered behavior. | NOT RUN | |

## T1 — recent cards and basic navigation (30–45 min; guest/data where available)

| ID | Do this; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| T1.1 | Discovery: inspect several real profiles, including one with no tags. Banner, half-overlapping avatar, name and status fit; only saved tags appear, with no invented tags, Next Lecture, Follow or reminder controls. | NOT RUN | |
| T1.2 | Tap anywhere on an offline and a live Discovery card; each opens that streamer's channel/profile, not a player or dead button. | NOT RUN | |
| T1.3 | Spatial Map: real approved pinned profiles appear as pins **and** in the drawer after cold launch, city switch and return from Discovery. Include legacy records with valid coordinates and blank old city fields; do not special-case the owner's two accounts. | NOT RUN | |
| T1.4 | Select a pin: it remains visible and gently pulses while its card is open. Close, switch tab, re-enter and check pulse stops and selection clears as intended. | NOT RUN | |
| T1.5 | Map card: banner/avatar/name/status/venue fit. Card background opens the profile; tapping the venue instead opens Google Maps with that venue's exact coordinates. A missing venue must not route to `0,0`. | NOT RUN | |
| T1.6 | Card close control is visually smaller/translucent with a usable touch target; closing it does not open the profile. Soft shadow, drawer aligned with OpenStreetMap credit and hidden expand control match the current design. | NOT RUN | |
| T1.7 | Streamer profile: short details show no expand arrow; genuinely hidden details show a top-end arrow that expands/collapses. Follow and reminder work only here, with the card's intended wide/compact actions. | NOT RUN | |
| T1.8 | Settings identity card shows actual banner/avatar/name/@/email/description where present; the separate Edit Account Profile button works, with no redundant edit icon on the card. | NOT RUN | |
| T1.9 | Switch English/Arabic on all four card locations; labels and arrow/close positions mirror correctly, selected data remains, and no text is clipped. | NOT RUN | |
| T1.10 | Compare 320, 360, 412 logical-pixel phone widths, short landscape and 1280px Chrome with large text. Cards wrap/scroll without overflow; desktop cards are bounded around 420px rather than stretching across the window. | NOT RUN | |

## T2 — map truthfulness and offline use (45–75 min; guest tests can start early)

| ID | Do this; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| T2.1 | Search, city and topic filters show only actual matching approved profiles across Al Khobar, Dhahran and Dammam; drawer count/list agree with pins, including nearby/same-coordinate records. | NOT RUN | |
| T2.2 | Unpinned, unapproved, hidden or invalid-coordinate records do not acquire fabricated pins, venues, distance or directions; missing data is explained honestly. | NOT RUN | |
| T2.3 | Pan/zoom/select/close/reopen and switch tabs repeatedly; map viewport, clustering, selected pin and drawer remain coherent with no stale card or lost visible profile. | NOT RUN | |
| T2.4 | Check city selection at outskirts and adjacent towns. Only the agreed three-city scope is represented; approximate coverage is not described as an official municipal boundary. Record any wrongly included/excluded real venue. | NOT RUN | |
| T2.5 | Check OpenStreetMap attribution and pack/coverage status in English and Arabic, including a selected-card short screen. All credits, buttons and close/drawer actions remain reachable. | NOT RUN | |
| T2.6 | Android: save the map area, fully close/reboot the phone, turn off network and cold-start. Saved tiles, pins and available details work; unavailable data is labelled. Reconnect and check recovery. | NOT RUN | |
| T2.7 | Chrome: save, close every tab, turn off network and cold-start the same web build. Saved content and identity remain usable; a second tab does not corrupt the pack. | NOT RUN | |
| T2.8 | With an engineer and disposable cache, interrupt an update and simulate missing/corrupt content; the previous complete pack survives, incomplete versions are not promoted, and retry repairs it. | NOT RUN | |
| T2.9 | With an engineer, update to a new stamped web build, restart worker and test concurrent tabs; both adopt a complete matching version without mixing old and new tiles. | NOT RUN | |

## T3 — editing, application and review (45–90 min; requires configured backend and profile-review migration)

| ID | Do this; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| T3.1 | Viewer Edit Account Profile offers only name/avatar. Save, reload and see correct updates; it does not open broadcaster verification. | NOT RUN | |
| T3.2 | Existing approved streamer opens a distinct editor. Change name, biography, academic title/institution, category and actual tags; save/reload. Changes publish without new approval or loss of verification. | NOT RUN | |
| T3.3 | Change contact email or phone. A pending revision appears in admin review; the approved public profile and auth-provider email remain unchanged until approval. | NOT RUN | |
| T3.4 | Change city, venue or coordinates. Pending map pin/location remain the approved values; after admin approval the new exact location appears consistently in map, drawer, card and profile. | NOT RUN | |
| T3.5 | Change YouTube channel URL or handle. Pending channel is not allowed to broadcast or shown as approved; approval publishes the new value, subject to the still-open ownership blocker STREAM-D8. | NOT RUN | |
| T3.6 | Reject a sensitive revision; original approval, public details, map visibility and broadcast ability remain. Resubmit a corrected revision and approve once; no duplicate profile/organization is created. | NOT RUN | |
| T3.7 | Induce a save/review network or RPC failure on a disposable account; editor retains input and reports failure, with no false success, phantom pending state or partial public update. | NOT RUN | |
| T3.8 | Initial broadcaster and organization application: all fields are readable as a form on narrow phone and capped laptop; saved real city/venue/category/tags return after reopen. A legacy category such as `cs_tech` does not crash the dropdown. | NOT RUN | |
| T3.9 | Organization revision keeps the existing organization ID and approved public data until review. A lower-role user cannot self-approve or directly write protected approved fields. | NOT RUN | |
| T3.10 | Repeat editor and verification form in Arabic, English, large text, 320px phone and laptop; fields stack naturally, labels translate and no input/button is clipped. | NOT RUN | |

## T4 — studio and first real broadcast (45–75 min; requires T0 configured; W02–W04 smoke first)

| ID | Do this; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| T4.1 | Broadcaster Studio opens only for permitted account. Icon-only language toggle is top-right in English/top-left in Arabic; switching language preserves a partly entered form. | NOT RUN | |
| T4.2 | Phone tab: Live Link info opens page 1 with the public Share screenshot; Stream Key info opens page 2 with the Copy screenshot. Indicator, next/back, rounded image corners and translated instructions work. No secret is logged or shown in a screenshot. | NOT RUN | |
| T4.3 | Validate link/video ID, key and required title/category inputs. A viewer link is never treated as a key, and a key is never rendered to viewers or silently retained after intended cleanup. | NOT RUN | |
| T4.4 | On A, start permitted rear-camera video. B and C independently receive the **same real event** with audio/video; swap A/B. Compare preview and received orientation in portrait, landscape-left/right and back, using a TOP arrow and round object. | NOT RUN | |
| T4.5 | Hide/restore video in each orientation; received video goes black while one audio stream continues. Front-camera control explains Coming Soon in both languages without switching or interrupting the stream. | NOT RUN | |
| T4.6 | Landscape tap hides/shows only supported controls; End, settings and chat remain reachable without a keyboard trap. Portrait chat draft returns after rotation; Back does not end accidentally. | NOT RUN | |
| T4.7 | Test audio-only from phone through background and lock with B/C receiving; camera hardware/permission indicator must release, mic/audio persists as specified, and return foreground is safe. | NOT RUN | |
| T4.8 | OBS/encoder uses its own permitted exact event. Verify ingest starts, selected watch URL/channel is correct, and End/availability propagate. No key appears in evidence. | NOT RUN | |
| T4.9 | Try unsupported local same-Wi-Fi/private/external-phone/laptop/PiP paths and organization identity switching. They explain unavailability or Coming Soon without falsely creating a session or exposing keys; their feature scope remains separately open. | NOT RUN | |

## T5 — live lifecycle, resilience and physical performance (60–120+ min; after T4 smoke)

| ID | Do this; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| T5.1 | During a live event, viewer pause/resume and mute/unmute change real received media, not only icons. Sender mute survives a brief recoverable network interruption without duplicate audio. | NOT RUN | |
| T5.2 | Ordinary End on sender releases camera/mic; B room becomes ended/unavailable within 30s and C feed/map lose LIVE within 40s on healthy network, measured from server confirmation. | NOT RUN | |
| T5.3 | Enter live from selected map card and return repeatedly; map viewport/selection and only one playback session remain. After End, no ghost sound or stale LIVE remains. | NOT RUN | |
| T5.4 | Drop media network briefly, then over 60s; separately drop backend connection and switch Wi-Fi/cellular. Check bounded retry (roughly 3s cadence, at most 10 attempts/60s), explicit Retry/Leave after exhaustion and no stale authority. | NOT RUN | |
| T5.5 | From a second signed-in device attempt conflicting start, transfer and forced/revoked End during recovery. Exactly one authorized publisher survives; old device does not resume or show a false LIVE state. | NOT RUN | |
| T5.6 | Run two at least 30-minute real-phone sessions (one per physical model) at approved presets. Record receiver frames/audio, actual fps/dropped frames, battery/temperature, ANR/crash and memory. Do not infer success from preview or emulator. | NOT RUN | |
| T5.7 | Confirm quality choices and actual output match the approved product requirement; record the unresolved original 480/740/1080/Auto versus implemented 360/720/1080 difference as a scope decision, not an automatic PASS. | NOT RUN | |

## T6 — viewers, chat, moderation and roles (45–90 min; configured disposable accounts)

| ID | Do this; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| T6.1 | Open exact live watch ID, ended event, scheduled event and archive/VOD; titles/status/playback never fabricate a live video or substitute an unrelated channel stream. | NOT RUN | |
| T6.2 | Viewer chat send/reply/edit drafts across portrait/landscape, navigation, reconnect and English/Arabic; no duplicate send, keyboard in forbidden landscape path or lost draft. | NOT RUN | |
| T6.3 | On disposable identities, report/block/mute/delete and server keyword filtering behave consistently for viewer, broadcaster and admin. Another client sees moderated state; a blocked user cannot bypass with a restart. | NOT RUN | |
| T6.4 | Master Admin, Admin, Permitted Admin/org owner and ordinary viewer see only their permitted queues/actions. Batch approve/reject and chat moderation respect server roles, not just hidden buttons. | NOT RUN | |
| T6.5 | Concurrent moderation/approval and connection recovery do not resurrect removed messages, overwrite newer decisions or leak another organization's records. | NOT RUN | |
| T6.6 | Notification, follower/reminder, stream counts and organization labels update on a second device after actions; no fabricated count or stale approved/pending identity appears. | NOT RUN | |

## T7 — accessibility, regression and release gates (45–90 min plus engineering work)

| ID | Do this; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| T7.1 | Repeat key Map/Discovery/Profile/Settings/Studio/room actions at 320/360/412px, short landscape, tablet and laptop with 1×/1.6×/2× text; no overflow, unreachable submit/End or giant desktop card. | NOT RUN | |
| T7.2 | English/Arabic switch and RTL: real values survive, cards/forms/help/error messages translate, visual order and top-end actions mirror. | NOT RUN | |
| T7.3 | TalkBack/screen reader and keyboard traverse cards, map pins, status, close, language/help, forms, chat and modal actions with meaningful labels and touch targets; reduced-motion setting stops pin pulse. | NOT RUN | |
| T7.4 | Permissions denied/revoked mid-flow, app background/resume, repeated tab/room navigation and sign-out clear sensitive media/keys; no camera/mic leak, stale audio or accumulating player sessions. | NOT RUN | |
| T7.5 | Check saved-profile/admin/Discovery/Map/channel identity after a real application approval, safe edit and rejected revision. Same accepted data everywhere; no sample fallback values. | NOT RUN | |
| T7.6 | Engineer: verify STREAM-D8 server-side YouTube ownership, P7 remaining role/invitation/admin obligations and controlled authorization denial. Until proven, keep D8 HIGH and release blocked. | NOT RUN | |
| T7.7 | Owner/product: decide municipal-boundary source/licensing, three-city edge policy and quality preset semantics. A visual smoke test cannot waive these requirements. | NOT RUN | |
| T7.8 | Engineer/owner: P8B privacy/data-rights/store copy and P9 signing, signed AAB, artifact secret scan and final physical release smoke; use their separate checklists. Do not treat drafts or debug builds as publication readiness. | NOT RUN | |

## T8 — adjacent product regression (30–60 min; run as roles/configuration permit)

| ID | Do this; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| T8.1 | New viewer onboarding, sign-in, return session and sign-out lead to the correct screen; a signed-out user cannot open protected Settings/Admin routes via Back or a deep link. | NOT RUN | |
| T8.2 | Discovery category/filter changes, scrolling and return from a streamer profile retain the expected feed state; real profile counts and saved tags stay consistent with Map/Admin. | NOT RUN | |
| T8.3 | Streamer channel archived lectures, playlists and upcoming-live surfaces show only real saved items and accurate ended/scheduled states; tapping a video does not open an unrelated live event. | NOT RUN | |
| T8.4 | Follow/unfollow and reminder actions on the streamer page update on a second device, including notification state and permission-denied behavior; Discovery remains display/navigation only. | NOT RUN | |
| T8.5 | Existing organization owner/co-owner views and invites, where implemented and in release scope, enforce role boundaries and retain organization identity; deferred organization broadcasting remains unavailable. | NOT RUN | |
| T8.6 | Open legal/privacy/settings/data-rights screens and links in both languages; report missing content or actions against P8B rather than assuming draft text is approved. | NOT RUN | |
| T8.7 | Exercise offline/backend error overlays, retry, app resume and stale login. Failures are explained in-app, with no red Flutter exception screen, fabricated content or silent save success. | NOT RUN | |
| T8.8 | Repeat the affected neighboring flows after each repair batch, using the recorded build/role. Do not turn a prior build's PASS into a new build's result automatically. | NOT RUN | |

### Dependencies and historical coverage

The original **W00/W02–W06**, **S01–S10**, **C01–C07**, **M01–M07**, **A01–A02** and **I01–I04** remain detailed evidence requirements. T0→T4/T5, T2 and T6/T7 respectively group them; do not replace the detailed steps when running those cases. T8 catches adjacent product regressions when those flows are available. The recent [card](../../evidence/2026-09-27/unified-streamer-cards/VERIFICATION.md), [studio/pin](../../evidence/2026-09-27/studio-pin/VERIFICATION.md) and [profile-edit](../../evidence/2026-09-27/profile-edit-card-polish/VERIFICATION.md) records explain the newer claims. The [release scope](../../management/RELEASE_SCOPE.md) distinguishes explicitly deferred POST-01–04 from open blockers. P5 and P6 remain **NOT ACCEPTED**; P6S remains **INCOMPLETE / NOT ACCEPTED** until fresh physical/backend evidence supports a change.
