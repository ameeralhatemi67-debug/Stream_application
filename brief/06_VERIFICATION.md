# 06 — Verification playbook ("don't make mistakes")

## 0. Evidence tiers — a claim needs the right tier
| Tier | Meaning | Enough for |
|---|---|---|
| E0 | Read/reasoned only | nothing (write `UNVERIFIED`) |
| E1 | `flutter analyze` = 0 and unit/widget tests pass | pure logic, copy changes |
| E2 | Deterministic automated proof: `gates.mjs`, `layout_sweep_test`, pgTAP/SQL probes | **all security, RLS, layout, theme, placeholder claims** |
| E3 | Emulator/browser scenario you actually executed (steps + result in the ledger) | flows, offline behaviour, release smoke test |
| E4 | Real phones / real backend run by the owner | multi-device, RTMP on hardware, store submission |

Never write "fixed/verified" above the tier you reached. `UNVERIFIED-STATIC` (no Docker/emulator) is a legitimate result; a wrong "done" is not. Past `[x]` marks in `To_fix_log.md` were E1 on mocks and the owner still reproduced the bugs — do not repeat that.

## Current status reference (2026-09-23)

This is an acceptance/evidence catalog, not a competing phase plan; `03_WORK_PLAN.md` is canonical. The latest broad UI run recorded 463 passing tests, zero analyzer issues and a successful web build on 2026-09-22; these are inherited dated results, not a fresh run in this documentation checkpoint. The latest recorded gate review has one failure (G6, 528 regex matches); the 2026-09-23 analyzer attempt did not finish, so zero analyzer issues is inherited evidence. The P6.4 directory's local SQL run is **VERIFIED-FAILING** (policy regression and malformed pgTAP quoting). Physical-device streaming is unverified. Private access remains disabled because there is no enforceable entitlement/invite path. The release AAB and its secret scan are absent because owner signing material is absent.

Owner decisions superseding older audits: the supplied privacy policy URL is `https://ameeralhatemi67-debug.github.io/privacy/` and is configured in `AppIdentity`; hosting/content availability was not checked in this checkpoint. Exact coordinates for public venues are intentional by D-33; private/home addresses are outside that public venue path. The account-deletion page URL remains unconfirmed. These decisions do not certify SQL migration or store/legal readiness.

## 1. `project/test/layout_sweep_test.dart` (build once in P4, reuse in P9)
For every routed screen and key sheet/dialog: welcome · viewer setup · role select · each streamer-apply step · application pending · account banned · feed (empty + populated) · map (empty + populated) · streamer profile · org profile · live room (player adapter stubbed; chat/tabs visible) · phone broadcast screen · settings (viewer, streamer, org, admin variants) · admin hub (every tab) · org admin · notification sheet · consent / device-conflict / duplicate-channel dialogs · go-live studio sheet · filters sheet.
Matrix: sizes `320×568, 360×640, 412×915, 600×960, 800×1280, 1280×800, 568×320 (landscape)` × text scale `1.0, 1.3, 2.0` × locale `en, ar`.
Mechanics: set `tester.view.physicalSize`/`devicePixelRatio = 1`, use the existing harness (EasyLocalization + `DirectJsonAssetLoader` + seeded `AppProvider` from `test/fixtures/`), bounded `pump(Duration)` (never `pumpAndSettle` with looping animations), then drain `tester.takeException()` in a loop and fail on any "overflowed"/layout exception. Print a table of failing (screen,size,scale,locale). Keep the file fast: group by screen, skip combos that are meaningless (desktop rail on 320 px) with a comment.

## 1b. Theme contrast test (`project/test/theme_contrast_test.dart`, built in P4.0)
Loads the light `ThemeData` and the token classes and asserts: every text-on-surface pair used by the app reaches 4.5:1 (large text and UI parts 3:1); text on each `AppGradients` token reaches 4.5:1 against BOTH stops; disabled and hint colours are readable enough for their role; no dark token remains. Print a table of failing pairs. Together with gate G2d this is the E2 proof for "clean white theme" and "gradients used correctly".

## 2. Database probes (pgTAP via `npx supabase test db`, files in `supabase/tests/`; local stack only)
Impersonate with `set local role authenticated; select set_config('request.jwt.claims','{"sub":"<uuid>","role":"authenticated"}',true);` (anon = `set local role anon`). Seed three users (viewer, verified streamer, admin) + one org with owner/co-owner/broadcaster. If Docker is unavailable, still write the files and mark results `UNVERIFIED-STATIC`.

**Attacks — every one must be DENIED (error or no-op) after P1/P6/P7:**
A1 viewer `update profiles set is_verified=true` on self · A2 viewer `insert` own profile with `is_streamer/is_verified=true` (must be forced false) · A3 viewer sets own `active_stream_id` = victim's stream, then deletes/mutes in that chat · A4 user writes/overwrites/deletes `streamer-assets/<other uid>/…` · A5 applicant inserts an application with `status='approved'` / edits `reviewed_by` · A6 broadcaster updates own `affiliation_requests.status` or `permissions` · A7 banned user inserts chat / updates profile / submits application · A8 second primary device row for one user · A9 non-admin calls each admin RPC; anon calls anything except `viewer_heartbeat`/`get_viewer_counts` and public views · A10 6 chat messages in 1 s (rate limit) and a message during slow-mode · A11 muted sender inserts · A12 direct `select` on `stream_viewers` · A13 org broadcaster grants themselves `canChangeLocation` · A14 co-owner removes the owner.
**Positives — must still WORK:** P1 streamer edits own bio/venue/handle · P2 admin approves an application (profile becomes streamer/verified) · P3 verified streamer on primary device calls `set_live_state` · P4 real stream owner deletes/mutes in their own chat · P5 org owner/co-owner grants a permission and invites a member · P6 viewer + guest `viewer_heartbeat` ⇒ `get_viewer_counts` = 1 per person · P7 account deletion still cascades.
Also run `npx supabase db advisors --local --type security` and record the output summary.

## 2b. RLS and secrets probes (local stack; write as `supabase/tests/rls_catalog.test.sql`, pgTAP; static-only ⇒ UNVERIFIED-STATIC)
R1 no ordinary table in `public` has `relrowsecurity = false` (`select relname from pg_class where relnamespace = 'public'::regnamespace and relkind = 'r' and not relrowsecurity` returns 0 rows), and `storage.objects` has RLS on · R2 every RLS table has at least one policy unless it is on the documented deny-all list (`stream_viewers`) · R3 as `anon`, `select` on every table returns permission denied or 0 rows except the explicit public views/tables listed in the policy matrix · R4 every view in `public` has `security_invoker = true` (or a comment justifying otherwise) · R5 `has_function_privilege('anon', oid, 'execute')` is true only for `viewer_heartbeat` and `get_viewer_counts`, and for every `security definer` function `proconfig` contains a `search_path` · R6 no write policy has `roles = {public}`, `using (true)` or `with check (true)`; each policy is `to authenticated` (or a justified `anon`) · R7 `storage.buckets`: only intended buckets are `public`; per-bucket policies exist for insert/update/delete · R8 `pg_publication_tables` (supabase_realtime) lists only the intended tables · R9 `npx supabase db advisors --local --type security` output summarised (0 errors; every warning justified).
Secrets: `node brief/tools/gates.mjs --history` (G11 all 0 / reviewed), and after the release build `node brief/tools/scan_build_secrets.mjs <the .aab>` must print `RESULT: clean`. Never paste key values anywhere; counts and file names only.

## 3. Scenario scripts (E3/E4; write the result of each into the ledger)
- **MD-1** Streamer signs in on A (becomes primary) then on B ⇒ conflict dialog; choose B ⇒ A stops live/RTMP within ~5 s and explains why; A may continue as viewer.
- **MD-2** Kill the app on A, wait >90 s, sign in on B ⇒ B claims silently.
- **MD-3** Same viewer account on two devices ⇒ no dialog; viewer count includes them once.
- **ID-1** Three different Google accounts: each sees only its own channel state; none shows "Amir Al-Hatemi" unless it owns it; a non-streamer has no "My Profile" and no cell-tower button; admins can see but not hijack another streamer's controls.
- **VC-1** Two clients watch one live stream ⇒ 2; one leaves ⇒ 1 within ~60 s; offline ⇒ "—".
- **OFF-1** Airplane mode cold start: cached feed + map basemap + markers + offline banner; Retry recovers; no red screens.
- **CH-1** Slow mode countdown, muted/banned composer states, guest read-only, report → appears in admin queue live, admin delete disappears for viewers.
- **REL-1** Release (R8) build launches on an emulator: splash → welcome → guest → feed → map; Google login screen reachable.
- **P6S-1** OBS workflow on laptop and an OBS-compatible phone sender, each with a real test channel: ingest connects; viewer sees and hears the stream; feed/live state matches reality; stop clears it; one network interruption recovers or ends with an exit. Record the sender actually available on each platform.
- **P6S-2** Direct Android camera/mic to YouTube on a physical phone: valid key and watch ID, start, viewer playback, portrait/landscape, audio-only, disconnect/reconnect and clean stop. Inspect logs for accidental stream-key output.
- **P6S-3** Direct route in web/desktop never throws the `Platform._operatingSystem` error shown in [`Screenshot 2026-09-22 143939.png`](evidence/2026-09-22/screenshots/Screenshot%202026-09-22%20143939.png); it presents supported choices or a clear unavailable state. Direct Laptop on its declared supported platform: capture permission, camera/mic capture, encode/ingest, viewer playback, end and device release. If unavailable, the app must show that plainly and the release scope must not claim laptop direct broadcast.
- **P6S-4** Same-Wi-Fi local stream for each promised host/viewer combination (phone/laptop): discovery or address entry, view and hear, host stop, viewer leave/rejoin, Wi-Fi change and network loss; no public live listing if the mode promises local isolation.
- **P6S-5** Public/private and invites on all three modes: outsider denied by direct URL/API/chat path; invited second account admitted; invite expires/revokes; host end removes access. Verify privacy claims against the actual YouTube visibility setting and LAN behavior.
- **P6S-6** Viewer and broadcaster viewport matrix: normal → fullscreen → normal → mini-player → room → close; portrait/landscape and back gesture at every step; stream ends mid-transition. Playback/mute commands affect real media and camera/mic/wakelock/system chrome return to normal.
- **P6S-7** Escape and identity matrix: cancel/back/close/end from every modal, setup, permission, loading, offline and reconnect state; approved streamer signs in again without an apply prompt; switching accounts never carries another account's channel or controls.

## 4. Gates (`node brief/tools/gates.mjs`) — run at every checkpoint
The scoreboard for placeholders (G1), theme (G2), emoji (G3), identity (G4), dead code (G5), hard-coded strings (G6), i18n symmetry (G7), signing (G8), dev tooling (G9), RLS in migrations (G10a-e, static reading of the SQL), secrets and the service key (G11a-g; G11g needs `--history`). G2c is informational until you define the allowlist of on-media files. Extend the script if you add a new class of check; do not weaken a gate to make it pass.
