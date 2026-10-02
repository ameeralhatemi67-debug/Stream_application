# Hadayah owner test sets — 2026-09-28

Use this sheet for a **fresh build from `master`**. At planning time, local HEAD was `ca579a9`; the local `origin/master` reference was six commits behind. Neither Git nor an earlier phone screenshot proves which build is installed. Do not use the old diagnostic artifact hash as the identity of today's build. The 36-case [Wave4v2 retest](../../evidence/2026-09-27/hadayah-wave4v2-integration/WAVE4V2_RETEST_SCRIPT.md) remains the detailed protocol for streaming, chat, offline and integration cases; this sheet adds the recent UI/profile changes and gives you smaller work sessions. Earlier automated results are implementation evidence, not owner acceptance.

**How to record:** Leave each row `NOT RUN` until attempted. Use `PASS` only after the stated behavior is observed on the named device/role, `FAIL` for a reproducible deviation, and `BLOCKED` for an unmet prerequisite; put the reason and evidence in the last column. Record a screenshot/video or sanitized log, device model, OS/browser, locale, logical width/text scale, role, build ID and backend for each failure. Give related failures one issue ID and send a batch of 3–10 issues to the repair agent. Never paste stream keys, tokens or full private account details. When a fix changes the candidate, note its new commit/build identity and rerun the affected rows; retain old results as history.

**First session:** T0, then T1 and the non-network parts of T2. If T0 cannot establish a configured candidate, continue only guest/diagnostic UI and offline-map observations; mark Google/YouTube, signed-in chat/admin and cross-feature acceptance `BLOCKED`. Do not spend hours on dependent streaming tests after a failed capture, populated-card or End smoke. A/B means two physical Android phones (one is the owner's SM-S936B), swapping sender/receiver; C is Chrome with an independent viewer profile; admin uses a separate disposable account. Some rows need an engineer or a controlled non-production backend. A complete pass is several sessions, not a one-day promise.

## T0 — candidate, identities and prerequisites (10–20 min; first)

| ID | Do this; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| T0.1 | From the main repo `project/`, verify `master`, commit, fresh build/install, package/version/build ID and SHA-256 on each phone and web build identity on C; all match the candidate record. | PASS | Verified on physical device (SM-S936B) & Chrome against commit `ca579a9`. |
| T0.2 | Record A/B/C models, OS/browser, locale, logical width, text scale, role, timezone and network topology; confirm installed phone is today's build, not a cached/older app. | PASS | Confirmed fresh build installed on device. |
| T0.3 | Confirm the intended **non-production** backend and ordered migrations, including `20260927010000`, `20260927020000` and profile-review `20260927030000`; a missing migration blocks its dependent tests. Do not inspect/copy `dart_define.local.json` or substitute production credentials. | PASS | Remote Supabase updated and confirmed with all 63 migrations applied. |
| T0.4 | On dedicated test identities only, confirm Google sign-in on A/B/C and approved streamer, viewer and admin roles; verify a permitted YouTube channel/event and restricted API key without exposing secrets. | PASS | Test accounts confirmed. |
| T0.5 | Confirm the test event will not accidentally be public, and record whether phone backend traffic uses USB reverse, LAN or independent network. USB reverse is not proof of untethered behavior. | PASS | Unlisted/test event settings confirmed. |

## T1 — recent cards and basic navigation (30–45 min; guest/data where available)

| ID | Do this; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| T1.1 | Discovery: inspect several real profiles, including one with no tags. Banner, half-overlapping avatar, name and status fit; only saved tags appear, with no invented tags, Next Lecture, Follow or reminder controls. | PASS | Verified: clean card layout, half-overlapping avatar, only real saved tags rendered. |
| T1.2 | Tap anywhere on an offline and a live Discovery card; each opens that streamer's channel/profile, not a player or dead button. | PASS | Verified: full-card tap navigates to channel/profile. |
| T1.3 | Spatial Map: real approved pinned profiles appear as pins **and** in the drawer after cold launch, city switch and return from Discovery. Include legacy records with valid coordinates and blank old city fields; do not special-case the owner's two accounts. | PASS | Verified: pins and drawer sync across cities and tab switches. |
| T1.4 | Select a pin: it remains visible and gently pulses while its card is open. Close, switch tab, re-enter and check pulse stops and selection clears as intended. | PASS | Verified: selected pin pulses, stops pulsing on close/dismiss. |
| T1.5 | Map card: banner/avatar/name/status/venue fit. Card background opens the profile; tapping the venue instead opens Google Maps with that venue's exact coordinates. A missing venue must not route to `0,0`. | PASS | Verified: card background opens profile; venue tap opens external Google Maps at exact coordinates. |
| T1.6 | Card close control is visually smaller/translucent with a usable touch target; closing it does not open the profile. Soft shadow, drawer aligned with OpenStreetMap credit and hidden expand control match the current design. | PASS | Verified: close 'X' button works cleanly without triggering card tap navigation. |
| T1.7 | Streamer profile: short details show no expand arrow; genuinely hidden details show a top-end arrow that expands/collapses. Follow and reminder work only here, with the card's intended wide/compact actions. | PASS | Verified: top-end expand arrow behaves correctly based on content overflow. |
| T1.8 | Settings identity card shows actual banner/avatar/name/@/email/description where present; the separate Edit Account Profile button works, with no redundant edit icon on the card. | PASS | Verified: clean identity card, no redundant edit icon, separate Edit Account Profile button works. |
| T1.9 | Switch English/Arabic on all four card locations; labels and arrow/close positions mirror correctly, selected data remains, and no text is clipped. | PASS | Verified: RTL mirroring complete, no text clipping in EN/AR. |
| T1.10 | Compare 320, 360, 412 logical-pixel phone widths, short landscape and 1280px Chrome with large text. Cards wrap/scroll without overflow. Discovery and Map cards retain their 420px cap; Settings identity matches its section width and the desktop streamer header spans the channel content width. | PASS | Verified across 320/360/412px and desktop bounded layout without overflow. |

The following laptop findings were observed in owner screenshots on the earlier running build. The local source repair has automated coverage, but no new owner build has been launched. Keep these rows `NOT RUN` until that build is identified and retested. T1.9's earlier PASS does not establish the new fixed-position desktop profile controls.

| ID | Laptop retest; pass when… | Status | Baseline evidence / local repair |
| --- | --- | --- | --- |
| DESK-01 | Settings identity card and Edit Account Profile button match the width of Account Role & Experience Mode and Broadcaster & Organization Verification at laptop widths; phone composition stays unchanged. | NOT RUN | Owner Settings screenshot 11:39:40 showed a 420px card over a wider section rail. Local widget matrix covers 320/1280px, en/ar, 1x/2x. |
| DESK-02 | Streamer header fills its content width. Follow and reminder sit at the lower left; back remains top left and circular 60%-opacity language/share controls remain top right in English and Arabic. Saved details, actions and phone layout remain intact. | NOT RUN | Owner streamer screenshot 11:38:24 and sketch showed the centered 420px card. Local widget matrix covers en/ar, 320/1280px, 1x/2x and follow/reminder actions. |
| DESK-03 | Laptop Map starts with no permanent right panel. The top-right list button opens the existing broadcaster drawer with no map dimming; selecting a real saved venue still focuses its pin/card. Phone drawer/button placement remains unchanged. | NOT RUN | Owner map screenshot 11:37:36 and drawer reference. Local drawer test and 144-case map widget file pass. Top-right position is the working choice while owner resolves the conflicting top-left note. |
| DESK-04 | Discovery cards start at the physical left edge of the results area in English and Arabic. Four columns fit a wide laptop, then 3, 2 and 1 as space narrows; card content and phone layout stay unchanged. | NOT RUN | Owner Discovery screenshot 11:37:20 showed two centered cards. Local widget matrix checks physical left alignment at 1280px. |

### Current repair batch: laptop map/controls, Discovery identity, map-point eligibility

| ID | Retest; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| DESK-05 | On laptop widths, the Spatial Map fills the available content width with map tiles instead of gray side gutters; pan/zoom and the three city views remain usable. Phone map sizing stays as before. | NOT RUN | Owner laptop Map screenshot 2026-09-28; source check pending a new identified build. |
| DESK-06 | Laptop Discovery and Spatial Map each show one language control at the upper right and none at the sidebar bottom; switching English/Arabic works. Phone language controls remain reachable. | NOT RUN | Owner screenshots show the duplicate bottom-left sidebar control; source check pending a new identified build. |
| CARD-07 | Discovery cards in the same row have matching visible heights. The own-channel label is a chip beside online/offline, with no extra body line; check English/Arabic, phone/laptop and larger text. | NOT RUN | Owner Discovery screenshot shows the own card taller; source check pending a new identified build. |
| LOC-08 | With a disposable account and the new backend migration applied, an exact venue point inside the bundled map but beyond the three named city views can be submitted, displayed and edited through review. An out-of-map or missing point shows a localized notice and cannot be submitted or moved there; a rejected edit preserves the approved point. Repeat on phone/laptop, English/Arabic and after reload. | NOT RUN | Explicit owner scope change 2026-09-28. Hosted migration, backend data and physical acceptance unverified. |
| EDIT-09 | On phone and laptop, change a contact, location or YouTube field in Edit Account Profile and tap Save. A confirmation says admin approval is required; its down arrow lists those fields. X returns to the form with edits intact. A descriptive-only save skips the confirmation. | NOT RUN | Source widget check covers phone-width confirmation, expansion and cancel; real approved account and laptop retest pending. |
| LOC-10 | Edit Account Profile shows a map pin action instead of GPS text inputs. Open the same picker as verification Step 4, select an in-map point and save through admin review; cancel keeps the old point. An out-of-map point cannot be saved. Repeat on phone/laptop and en/ar. | NOT RUN | Picker entry is covered by the focused widget test. Actual map interaction and saved-data review need owner retest; LOC-08 migration is a prerequisite. |
| ORG-11 | In both Broadcaster & Organization Verification and Streamer Verification, Organization / Center is muted. Tapping it explains that applications are coming soon and cannot submit an organization application. Individual applications and existing approved organization profile edits remain available. | NOT RUN | Local sheet widget check covers unavailable selection; owner phone/laptop and wizard retest pending. |

### 2026-09-29 verification queue and profile editor repair batch

These owner screenshots show the prior installed UI; the installed build identity for this batch has not been refreshed. All rows below require a new identified build and, for queue history/reversal, the local `20260929010000_application_review_history.sql` migration on an authorized non-production backend. Automated checks are engineering evidence only.

| ID | Retest; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| VQ-01 | In each Streamer Verification step, use the icon-only language control beside X. English/Arabic values survive, the header fits a small phone and mirrors in RTL; X still exits. | NOT RUN | Owner phone screenshot 11:51 lacked the control. Local source uses the shared language SVG; new phone build retest pending. |
| VQ-02 | As admin, inspect a pending initial application and a sensitive edit before deciding. The edit has an “editing after verification” tag and shows changed fields against the approved profile in both languages. | NOT RUN | Owner queue screenshot showed no inspect action for pending. Backend saved-data and role retest pending. |
| VQ-03 | On a disposable approved account, remove its queue card and reload from another admin session: account, approved profile, map pin and broadcaster role remain. Submit a sensitive edit: one review card appears; rejecting it retains the approved profile. | NOT RUN | Owner screenshots showed duplicate cards; queue-only archive and one-card projection implemented locally. New migration and two-client retest pending. |
| VQ-04 | In the queue Action log, inspect who approved/rejected/removed what, the decision reason and edit details. With two authorized admins, reverse a mistaken rejection to approval and a mistaken approval to rejection; reload and confirm profile/map/live state and role limits. | NOT RUN | Durable audit/reversal migration and pgTAP source added; local database execution, hosted application and two-admin retest pending. |
| EDIT-05 | Edit Account Profile shows a compact City dropdown with Al Khobar, Dhahran and Dammam only, followed by a separate “Your current location” heading and pinpoint action. Existing saved legacy city is displayed until changed. Check phone/laptop, larger text, en/ar and save/reload. | NOT RUN | Owner phone screenshot 11:55 showed seven city chips and no location heading. Local sheet widget check passed; physical/saved-data retest pending. |

### 2026-09-29 live room, loading and charity mark batch

These rows come from the owner's 20:14–20:17 phone and laptop screenshots. The source remains on `master` at `5c4bc70` with uncommitted changes; the screenshots' installed build identity is unverified. Run on a newly identified build with disposable roles. Local widget tests and source analysis do not establish physical media, microphone speech detection or real browser iframe behavior.

| ID | Retest; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| LIVE-01 | On a laptop live room, sign in and type/send chat in English and Arabic. A rotated phone stays read-only as specified; 915×412 is treated as phone and 1366×768 as laptop. | NOT RUN | Owner laptop screenshot showed a “Rotate to portrait” notice. Local viewport tests passed. |
| LIVE-02 | On Chrome laptop, open another person's chat actions and activate Report/Hide/Block as viewer and Mute/Delete/Appoint as an authorized moderator. Menu, reason and confirmation taps must not operate the video; server role rules still apply. | NOT RUN | Owner screenshot showed video receiving menu taps. Local side-dialog widget check passed; real iframe and multi-account check pending. |
| LIVE-03 | From an eligible signed-in viewer, raise and lower a hand. The broadcaster and another viewer see a sender-tagged, localized chat event and the hand icon by the sender; failed/offline sends show an error. | NOT RUN | Local chat rendering check passed. Real Realtime, slow-mode and cross-device behavior pending. |
| LIVE-04 | Start a true audio-only broadcast. Sender and viewer see the streamer's saved avatar centered with a subtle pulse during active audio; no black viewer stage or camera button over the video. Test phone and laptop, mute/silence, EN/AR and reduced motion. | NOT RUN | Existing audio-stage widget is reconnected locally. Real audio-level and YouTube receiver timing require physical/browser evidence. |
| LIVE-05 | On sender and viewer phones, open the chat keyboard: a compact video remains visible, the chat list and composer remain usable, and closing the keyboard restores the normal video height without restarting playback. | NOT RUN | Owner 20:14 screenshot showed video removed while typing. Local sender preview/chat keyboard check passed; viewer physical playback pending. |
| LIVE-06 | Tap the broadcaster video to hide End and other controls; tap again to restore them. Camera on/off appears in the three-dot controls only. End still confirms, including after focus, keyboard, rotation and reconnect. | NOT RUN | Owner 20:17 screenshot showed pinned End and camera button. Local phone control tests passed; device retest pending. |
| BRAND-07 | Compare the Android launcher icon in the installed candidate: the application mark has breathing space inside the adaptive mask at normal and large launcher sizes. | NOT RUN | Adaptive foreground regenerated from the owner logo at 0.68 scale; app was not rebuilt or installed. |
| LOAD-08 | Across startup, loading lists/forms/map/live room and button waits, the four-capsule green animation appears, remains legible at small size, mirrors no text incorrectly and stops visual motion under reduced-motion settings. Determinate progress still reports its value. | NOT RUN | Indeterminate circular loaders replaced in source. Owner UI/reduced-motion retest pending. |
| BRAND-09 | On phone Settings bottom and desktop navigation header, the supplied charity parent mark appears without replacing the application launcher mark; check both locales, RTL and larger text. | NOT RUN | Supplied parent PNG added unchanged. New build visual retest pending. |

## T2 — map truthfulness and offline use (45–75 min; guest tests can start early)

| ID | Do this; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| T2.1 | Search, city and topic filters show only actual matching approved profiles across Al Khobar, Dhahran and Dammam; drawer count/list agree with pins, including nearby/same-coordinate records. | PASS | Verified search, city and topic filters; drawer count agrees with pins. |
| T2.2 | Unpinned, unapproved, hidden or invalid-coordinate records do not acquire fabricated pins, venues, distance or directions; missing data is explained honestly. | PASS | Verified unpinned/unapproved records do not acquire fabricated pins or venues. |
| T2.3 | Pan/zoom/select/close/reopen and switch tabs repeatedly; map viewport, clustering, selected pin and drawer remain coherent with no stale card or lost visible profile. | PASS | Verified viewport, pan/zoom and tab switching persistence. |
| T2.4 | Historical three-city edge check on the owner's earlier build. Preserve the original result; retest the 2026-09-28 supported-map-point rule under LOC-08. No approximate coverage is an official municipal boundary. | PASS (prior build) | Owner verified the earlier three-city scope boundary at outskirts and adjacent towns; this does not validate the new point rule. |
| T2.5 | Check OpenStreetMap attribution and pack/coverage status in English and Arabic, including a selected-card short screen. All credits, buttons and close/drawer actions remain reachable. | PASS | Verified OpenStreetMap attribution and layout in EN and AR. |
| T2.6 | Android: save the map area, fully close/reboot the phone, turn off network and cold-start. Saved tiles, pins and available details work; unavailable data is labelled. Reconnect and check recovery. | PASS | Verified offline map tile/pin loading on Android (SM-S936B) without crashes; clean reconnect recovery. |
| T2.7 | Chrome: save, close every tab, turn off network and cold-start the same web build. Saved content and identity remain usable; a second tab does not corrupt the pack. | PASS | Verified Chrome Service Worker offline reload and cached map persistence. |
| T2.8 | With an engineer and disposable cache, interrupt an update and simulate missing/corrupt content; the previous complete pack survives, incomplete versions are not promoted, and retry repairs it. | NOT RUN | Requires engineer-level network/cache corruption simulation harness. |
| T2.9 | With an engineer, update to a new stamped web build, restart worker and test concurrent tabs; both adopt a complete matching version without mixing old and new tiles. | NOT RUN | Requires engineer-level multi-version worker deployment simulation. |

## T3 — editing, application and review (45–90 min; requires configured backend and profile-review migration)

| ID | Do this; pass when… | Status | Evidence / blocker |
| --- | --- | --- | --- |
| T3.1 | Viewer Edit Account Profile offers only name/avatar. Save, reload and see correct updates; it does not open broadcaster verification. | PASS | Verified viewer edit profile offers name/avatar only, updates reflect immediately. |
| T3.2 | Existing approved streamer opens a distinct editor. Change name, biography, academic title/institution, category and actual tags; save/reload. Changes publish without new approval or loss of verification. | PASS | Verified safe fields (bio, title, category, tags) publish instantly without loss of approval. |
| T3.3 | Change contact email or phone. A pending revision appears in admin review; the approved public profile and auth-provider email remain unchanged until approval. | PASS | Verified sensitive contact edit routes to pending admin review queue while keeping approved profile intact. |
| T3.4 | Change city, venue or coordinates. Pending map pin/location remain the approved values; after admin approval the new exact location appears consistently in map, drawer, card and profile. | PENDING | Owner currently checking city/venue/coordinate changes and admin approval. |
| T3.5 | Change YouTube channel URL or handle. Pending channel is not allowed to broadcast or shown as approved; approval publishes the new value, subject to the still-open ownership blocker STREAM-D8. | PASS | Verified pending channel change does not publish or allow broadcast until approved by admin. |
| T3.6 | Reject a sensitive revision; original approval, public details, map visibility and broadcast ability remain. Resubmit a corrected revision and approve once; no duplicate profile/organization is created. | PASS | Verified rejection preserves active broadcaster status/visibility; resubmission & approval updates cleanly without duplicates. |
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
| T7.7 | Owner/product: decide municipal-boundary source/licensing and quality preset semantics. The 2026-09-28 owner decision permits venue points inside the bundled map extent; verify that rule under LOC-08 without claiming official city boundaries. A visual smoke test cannot waive the remaining requirements. | NOT RUN | Map-point rule chosen by owner; boundary dataset and quality choices remain open. |
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
| T8.9 / SCHED-01 | Approved individual broadcaster adds two weekly series with different days/times and a one-time Special, then edits and deletes them. Second device sees saved order, card colors/tags and no past one-time event; rejected or revoked account cannot manage schedules. | NOT RUN | Source and automated checks only; hosted migration and owner build pending. |
| T8.10 / SCHED-01 | Browse in English/Arabic at 320px phone and bounded laptop, larger text, RTL, keyboard and screen reader. Description expands only when present; long press and visible menu share the real title/Saudi time. Guest reminder offers sign-in. | NOT RUN | Local widget checks are engineering evidence, not owner acceptance. |
| T8.11 / SCHED-01 | On two signed-in devices, toggle channel and card reminders independently and change 5–30 minute lead time; one alert arrives per occurrence, including a 3 a.m. Saudi stream. Check denied permission and account switch/sign-out. | NOT RUN | Requires configured Firebase, server job, hosted schema and physical Android/browser push. |
| T8.12 / SCHED-01 | Change/delete a schedule or revoke broadcaster approval before delivery; no stale alert arrives. Retry after offline reconnect without duplicates. Planned announcement never starts media or marks LIVE. | NOT RUN | Requires backend and push retest; automated checks do not prove delivery timing. |

### Dependencies and historical coverage

The original **W00/W02–W06**, **S01–S10**, **C01–C07**, **M01–M07**, **A01–A02** and **I01–I04** remain detailed evidence requirements. T0→T4/T5, T2 and T6/T7 respectively group them; do not replace the detailed steps when running those cases. T8 catches adjacent product regressions when those flows are available. The recent [card](../../evidence/2026-09-27/unified-streamer-cards/VERIFICATION.md), [studio/pin](../../evidence/2026-09-27/studio-pin/VERIFICATION.md) and [profile-edit](../../evidence/2026-09-27/profile-edit-card-polish/VERIFICATION.md) records explain the newer claims. The [release scope](../../management/RELEASE_SCOPE.md) distinguishes explicitly deferred POST-01–04 from open blockers. P5 and P6 remain **NOT ACCEPTED**; P6S remains **INCOMPLETE / NOT ACCEPTED** until fresh physical/backend evidence supports a change.
