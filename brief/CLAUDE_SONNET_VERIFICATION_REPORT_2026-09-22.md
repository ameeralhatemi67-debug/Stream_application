# Claude Sonnet 5 verification pass — 2026-09-22

Verification-only pass over Astra's P6.4 work (admin user directory, device_sessions admin read, Arabic map/search fixes). No application code was modified. No git push, no `supabase db push`/`link`/`deploy`, no keystore created, no destructive git commands, no Astra working-tree changes reverted. Evidence tiers per `brief/06_VERIFICATION.md` §0 (E0 read-only … E4 real device/backend).

## 1. Commit and working-tree identity

- HEAD: `3939de4290fe0addf85fc4aad6b276da3fd06e8` (`docs(brief): record P8A results, limits and the P6.4 resume point`), branch `master`.
- Working tree at session start and session end is **identical** (verified `git status --porcelain` before and after): same 12 modified files, same 13 untracked paths (see below), no new modifications from this verification pass except the report and evidence files this task was asked to create.
- Modified (tracked): `Roadmap.md`, `brief/05_DECISIONS.md`, `brief/LEDGER.md`, `brief/OWNER_ACTIONS.md`, `project/assets/i18n/ar.json`, `project/assets/i18n/en.json`, `project/lib/core/config/app_identity.dart`, `project/lib/core/providers/app_provider.dart`, `project/lib/core/routing/app_router.dart`, `project/lib/core/services/admin_database_service.dart`, `project/lib/features/admin/presentation/admin_hub_screen.dart`, `project/lib/features/map/presentation/widgets/top_spatial_search_bar.dart`.
- Untracked: `brief/Health_And_Audit_Check_for_brief_Progress.md`, `brief/P64_CHECKPOINT.md`, `brief/analyzer-p64.txt`, `brief/assets/p64/`, `brief/chrome-p64.txt`, `brief/full-test-p64.txt`, `brief/gates-p64.txt`, `brief/layout-p4-results.txt`, `brief/test-p64-directory.txt`, `skill-observations/`, `supabase/migrations/20260922100000_document_public_venue_coordinates.sql`, `supabase/migrations/20260922110000_admin_user_directory.sql`, `supabase/tests/admin_user_directory.test.sql`, `project/lib/features/admin/presentation/widgets/admin_user_directory_view.dart`, `project/test/admin_user_directory_test.dart`.
- `git diff --check` → clean, exit 0 (no whitespace/conflict-marker errors). **[E2, PASS]**

This report and its evidence files add: `brief/CLAUDE_SONNET_VERIFICATION_REPORT_2026-09-22.md`, `brief/assets/claude-sonnet-verify-2026-09-22/*.png` (10 screenshots), `brief/analyzer-claude-verify.txt`, `brief/full-test-claude-verify.txt`, `brief/gates-claude-verify.txt`, `brief/supabase-test-db-claude-verify.txt`.

## 2. Environment

| Command | Result |
|---|---|
| `flutter doctor -v` | **No issues found.** Flutter 3.41.2 (stable), Dart 3.11.0, Android SDK 36.1.0 at `D:\app\Android\Sdk`, Chrome 153.0.8010.53, Visual Studio 2026 Community. |
| `flutter emulators` | 5 available: `Pixel_5`, `Pixel_9_Pro`, `Pixel_9a`, `Small_Phone`, `rtmp_spike_x86_64`. |
| `flutter devices` (before launch) | 3 connected: Windows desktop, Chrome, Edge. No Android device yet. |
| `flutter emulators --launch Pixel_9_Pro` | Booted directly to `adb` state `device` — **no offline→device transition was observed to record**; by the time the first `adb devices -l` check ran, the emulator was already fully booted (`emulator-5554  device  product:sdk_gphone16k_x86_64 ... device:emu64xa16k`). |
| `flutter devices` (after boot) | 4 connected, incl. `sdk gphone16k x86 64 (mobile) • emulator-5554 • android-x64 • Android 17 (API 37) (emulator)`. |

Both Chrome and one Android emulator (Pixel_9_Pro, Android 17/API 37) confirmed detected. **[E1/E2, PASS]**

## 3. Static and automated checks (from `project/`)

| Command | Result | Evidence |
|---|---|---|
| `flutter analyze` | **0 issues** (ran in 10.5s) | `brief/analyzer-claude-verify.txt` |
| `flutter test` (full suite) | **446/446 passed**, "All tests passed!" — exact match to Astra's own claim | `brief/full-test-claude-verify.txt` |
| `flutter test test/admin_user_directory_test.dart` | **7/7 passed** — exact match to claim | inline (see run log) |
| `node brief/tools/gates.mjs` | **1 gate failing: `G6=523`** (hard-coded English `Text('...')` literals) — matches Astra's own reported classification exactly; every other gate PASS or INFO (unchanged) | `brief/gates-claude-verify.txt` |
| `git diff --check` | Clean, exit 0 | — |

The full suite log includes `layout_sweep_test.dart` (e.g. "wizard organization 2 en", "sheet venue navigation ar", "live room starting soon ar" cases observed running), `theme_contrast_test.dart`, i18n key-symmetry coverage, and routing-guard coverage as part of the 446 — no separate re-run was needed since these are files inside the one suite that fully passed.

**Astra's static/automated claims are all independently reproduced. [E1/E2, PASS]**

Minor observation (non-blocking): several widget tests print live network fetch failures to `test/.../tile.openstreetmap.org` (`ClientException ... status 400`) during map-related tests. Tests still pass because the map widget tolerates tile-load failure, but this means some tests make real outbound HTTP calls in CI, which is a flakiness/hygiene risk unrelated to this session's diff. Not fixed (out of scope — no code defect requested).

## 4. Chrome verification — **partially blocked, methodology note**

**Process-level (reproduced twice — once unconfigured/guest-only like Astra's own session, once against the local Supabase stack described in §5):**
- `flutter run -d chrome --web-port=<port> --no-pub` compiled and connected to the debug service both times, Dart VM Service reachable, no unhandled Dart exceptions in console output.
- Against the local backend, console showed the *expected* `PostgrestException ... permission denied for table {broadcaster_applications, terms_and_conditions, platform_analytics, audit_logs, affiliation_requests}` and `permission denied for function sweep_stale_live_flags` — this is anon-role RLS correctly denying admin-only reads on app boot, with graceful fallback (per ADR-005), not a bug.

**Interactive UI checks (welcome, guest entry, feed, map, Arabic locale, Arabic map search, venue marker selection, Google Maps action, Settings guard, login screen, admin route protection, admin directory rendering): UNVERIFIED on Chrome.**

Reason, recorded in full: this Claude Code session has no browser-automation, computer-use, or screenshot tool for a specific window (confirmed by searching the available/deferred tool list — only `WebFetch`, `CronCreate`, `DesignSync`, plan/worktree tools, and `Monitor` are available; none can click a page or capture one window). One attempt was made to work around this by taking a **full Windows-desktop** screenshot via PowerShell (`System.Windows.Forms.Screen`/`CopyFromScreen`) to at least see the Flutter-launched Chrome window. That capture landed on a different, unrelated foreground window — the user's own personal browser session (a real YouTube Studio live-streaming dashboard and personal tabs) — not the Flutter debug Chrome window. The image was **deleted immediately**, was not analyzed beyond noticing it was the wrong window, and is not included anywhere in this report or its evidence folder. This method was then discontinued for the rest of the session as unsafe (no reliable way to target only the Flutter Chrome window without risking capture of unrelated personal content again). This mirrors — and is a stricter version of — the blocker the prior Codex session hit with Computer Use on Chrome.

Because the same UI code (same Flutter widgets, same router, same i18n catalogs) was exercised and visually confirmed on the Android emulator in §5 below, the underlying functionality is verified there at E3; Chrome itself is verified only at E1/E2 (compiles, launches, no runtime exceptions).

## 5. Android emulator verification (Pixel_9_Pro, Android 17 / API 37) — interactive, via `adb input`/`adb screencap`

No Computer Use / browser-automation tool was available here either, but `adb` gives a reliable, scriptable, and safe way to drive *only* the emulator (no risk of touching unrelated windows), so this pass is genuinely interactive: tap → screenshot → inspect, repeated. All screenshots below are saved under `brief/assets/claude-sonnet-verify-2026-09-22/`.

### 5a. Guest flow, unconfigured backend (mirrors Astra's own no-credentials approach — avoids any production access)

| Check | Result | Evidence |
|---|---|---|
| Launch → welcome screen | **PASS** — "Hadayah Live" branding, Google Sign Up / Log In / Guest entry / language toggle all render | `01_welcome.png` |
| Guest entry → consent dialog → viewer profile setup | **PASS** — "Before You Continue" privacy dialog (with the newly-set `privacyPolicyUrl` link visible), then avatar+display-name setup | (see shot 02–04, not copied individually; same flow shown in Arabic in §5b) |
| Feed | **PASS** — Discovery Feed renders, "0 Broadcasters" (correct, no backend) | `02_guest_feed_en.png` |
| Map | **PASS** — Al Khobar boundary renders, no markers (correct, no backend) | (equivalent to `04_map_ar.png` but in English) |
| Arabic locale switch | **PASS — confirms this session's fix.** Bottom nav labels flip from hardcoded English ("Discovery"/"Spatial Map") to correctly localized, RTL-mirrored Arabic ("دليل البث المباشر" / "الخريطة التفاعلية"). This was the exact regression described in `app_router.dart`'s diff (`context.tr('nav.feed')`/`context.tr('nav.map')` replacing hardcoded strings) and was left "inconclusive" in the last LEDGER RESUME block because screenshot capture had stopped responding in that session. Here it is definitively confirmed. | `03_feed_ar_rtl.png` |
| Arabic map search hint | **PASS — confirms the `top_spatial_search_bar.dart` fix.** Hint text renders as "ابحث عن المدن أو القاعات في الخبر..." and updates with locale (the fix changed `'map.search_placeholder'.tr()` to `context.tr(...)` specifically so this widget rebuilds on locale change). | `04_map_ar.png` |
| Settings guard (guest) | **PASS** — tapping the Settings gear as an unauthenticated guest redirects to the Welcome/Login screen, matching the documented `_authGuardedPaths` guard in `app_router.dart`. | `10_settings_guard_redirect.png` |
| Login screen reachable | **PASS** — same welcome screen exposes "Sign Up with Google" / "Already have an account? Log In". OAuth itself was not attempted (would require real Google credentials / production access, out of scope and explicitly to be avoided). | `01_welcome.png` |
| Admin route protection | **Not independently E3-verified.** No UI affordance reaches `/admin` as a guest (correct — it isn't linked anywhere for non-admins), and there is no app-registered deep-link scheme for arbitrary routes (only a Supabase OAuth callback scheme `sa.hadayah.streamerapp://login-callback` exists — checked `AndroidManifest.xml`). `/admin` and `/settings` share the exact same `_authGuardedPaths` list and redirect logic in `app_router.dart` (per source read), and `/settings` **was** empirically confirmed above, so this is high-confidence but E1 (code-path identity) + E3-by-proxy, not a literal E3 hit on `/admin` itself. |
| Admin directory rendering | **UNVERIFIED.** Requires a real, authenticated admin session. The app is Google-OAuth-only — there is no debug/dev auth bypass (checked `supabase_auth_service.dart` and the `kDebugMode`-gated "Testing tools" admin tab, which is a demo/pitch-mode toggle, not an auth shortcut, and is itself only reachable *after* already being an admin). Exercising a real Google OAuth consent flow was out of scope/unsafe for this pass. This matches the prior two sessions' conclusion. |

### 5b. Deeper pass against a **local-only** Supabase backend (new for this verification session)

To get real E3 coverage of venue-marker rendering and the Google Maps action (which need populated, guest-visible data, and which no prior session reached), this session:
1. Started the local Supabase stack (`npx supabase start` — Docker Desktop connected cleanly this time; see §6).
2. Applied both new migrations locally (`npx supabase migration up --local`).
3. Seeded **one** local-only test profile (`verify-streamer@example.invalid`, a guest-visible verified streamer with a venue in Al Khobar) directly via `docker exec ... psql`, confirmed independently readable by the `anon` role through `public.streamer_public_profiles` before use.
4. Re-launched the app on the emulator with `--dart-define-from-file` pointing at `http://10.0.2.2:54321` (the emulator's host-loopback alias) and the well-known local Supabase demo anon key (not a secret — identical on every local Supabase install). **No production credentials or production Supabase project were touched at any point in this sub-section.**

| Check | Result | Evidence |
|---|---|---|
| Feed shows seeded streamer | **PASS** — "مذيع التحقق" (Verification Streamer) card renders with verified badge, "الخبر • قاعة التحقق" location, count updates to "1 محاضرين" | `05_feed_seeded_venue.png` |
| Map shows venue marker | **PASS** — marker renders at the seeded lat/long inside the Al Khobar boundary | `06_map_marker.png` |
| Venue marker selection | **PASS** — tapping the marker opens the detail card: name, verified badge, venue name, "الملف الشخصي" (Profile) button, info icon, navigate icon, live/offline status ("غير متصل") | `07_venue_card.png` |
| Google Maps / navigation action | **PASS** — tapping the navigate icon launches the real `com.google.android.apps.maps` app via Android intent, confirmed via `adb shell dumpsys activity activities` showing `topResumedActivity=...com.google.android.apps.maps/...MapsActivity` immediately after the tap. The brief blank frame before Maps' own first-run screen appeared is Maps' own cold-start behavior (`GoogleApiManager` warnings in logcat are from the Maps app/Play Services stack on this fresh AVD, not from the Streamer app). | `08_google_maps_launched.png` |
| App survives return from external Maps intent | **PASS** — pressing back / relaunching via `am start` returns to the app with the venue card state preserved, no crash. | `09_settings_guard_redirect_map.png` |

No unhandled Flutter exceptions were observed in the Android run log at any point in either sub-pass (checked for `FlutterError`/`Unhandled exception`/`EXCEPTION CAUGHT` — none found).

**Tab-wiring static check (admin_hub_screen.dart):** independently re-derived the `TabBarView` children list (11 unconditional tabs + conditional `kDebugMode` testing tab + conditional master-admin roles tab + the new unconditional `AdminUserDirectoryView`) against the `TabBar` tabs list and the `TabController` length formula `(_isMasterAdminForTabs ? 13 : 12) + (kDebugMode ? 1 : 0)`. All four combinations of the two booleans check out arithmetically against the actual list lengths — no tab/content misalignment. **[E1, PASS]**

## 6. Database verification — Docker **was** available this session

Unlike the two prior sessions (which left Docker stopped after a persistent `dockerInference` socket failure), Docker Desktop connected cleanly here on a fresh start (`docker version` succeeded, Server: Docker Desktop 4.84.0). This may be transient/environment-specific — it is not evidence the prior failure is permanently resolved, only that it did not reproduce in this session.

| Command | Result |
|---|---|
| `npx supabase start` | Local Postgres/Auth/REST/Storage stack started successfully. |
| `npx supabase migration up --local` | **Both new migrations applied cleanly**: `20260922100000_document_public_venue_coordinates.sql`, `20260922110000_admin_user_directory.sql`. **[E2, PASS]** — the migration SQL itself is syntactically valid and runs. |
| `npx supabase test db` | **RAN. Result: FAIL.** 12 test files, 173 pgTAP tests total attempted. See critical findings below. Full output: `brief/supabase-test-db-claude-verify.txt`. |
| `npx supabase db advisors --local --type security` | 2 ERROR-level findings, both **pre-existing** (see §6c). |

This upgrades the P6.4 checkpoint's characterization from "UNVERIFIED-STATIC" to **VERIFIED-FAILING** for the SQL layer — a stronger and more actionable result than "not run," and it surfaces a real regression (§6a) that static reading alone would very plausibly have missed, since the failure only appears when the new policy is evaluated against a live authenticated query.

### 6a. CRITICAL — new RLS policy breaks all authenticated `device_sessions` reads (confirmed, reproduced)

`supabase/migrations/20260922110000_admin_user_directory.sql:4-6`:
```sql
create policy device_sessions_select_admin on public.device_sessions
  for select to authenticated
  using (public.is_admin_tier() and not public.is_banned(auth.uid()));
```
`public.is_banned(uuid)` has `EXECUTE` revoked from `public`, `anon`, and `authenticated` by design (`supabase/migrations/20260920110000_is_banned_helper.sql:36`), with an explicit comment: *"Not exposed to clients ... The RPCs that need it are SECURITY DEFINER and so execute it as the owner ... revoke from public/anon, grant back only what the access matrix needs — here, nothing."* Every other call site in the codebase (10+ locations, e.g. `guarded_broadcast_sessions.sql`, `live_flag_expiry_and_privilege_guards.sql`, `table_grants_and_audit_scope.sql`) only calls `is_banned()` from *inside* a `SECURITY DEFINER` function, which runs as the function owner and does not need caller-side `EXECUTE`.

This new migration is the **first** call site to invoke `is_banned()` directly inside an RLS **policy `USING` clause**, which Postgres evaluates as the *querying role*, not the definer. Result: **any** authenticated query against `public.device_sessions` — including the pre-existing, unrelated primary-device check used by the broadcast/go-live RPCs' own client-side reads — now raises `permission denied for function is_banned`, regardless of whether the querying user is an admin.

**Reproduced twice in the same `supabase test db` run:**
- `supabase/tests/admin_user_directory.test.sql:19` (Astra's own new test) — `select is((select count(*)::int from public.device_sessions),1,'viewer sees own device');` fails with `ERROR: permission denied for function is_banned`. Only 4 of the 23 planned assertions ran before the file aborted (`Bad plan. You planned 23 tests but ran 4.`).
- `supabase/tests/broadcast_sessions.test.sql:33` (**pre-existing test, unrelated to this session's diff**) — `select is((select count(*) from public.device_sessions where user_id=auth.uid() and is_primary_broadcaster),1::bigint,'Exactly one primary');` fails with the identical error. Only 12 of 22 planned assertions ran.

**Impact if this migration were pushed as-is:** the existing primary-device claim/heartbeat flow that already reads `device_sessions` as an authenticated (non-admin) user would break in production, not just the new admin directory feature. **[E2, CONFIRMED, blocking]**

*Not fixed, per instructions (document only).* Likely direction: wrap the `is_banned()` check for this one policy in a small `SECURITY DEFINER` helper (mirroring the existing pattern), or reference `public.is_current_user_banned()` (referenced in `chat_keyword_boundaries_and_normalization.sql:133` as the client-safe equivalent) instead of the raw `is_banned(auth.uid())` inside the policy.

### 6b. CRITICAL (latent) — malformed dollar-quoting in the new pgTAP file, 5 assertions cannot parse

`supabase/tests/admin_user_directory.test.sql` lines **31, 33, 35, 36, 40** use single-`$` delimiters instead of the doubled `$$...$$` used correctly everywhere else in the same file (e.g. line 12, 16–18, 24–26, 29):

```
line 31: select lives_ok($select public.admin_update_account(...)$,'admin revokes verification');
line 33: select lives_ok($select public.admin_update_account(...)$,'admin revokes personal streaming');
line 35: select throws_ok($select public.admin_update_account(...)$,'22023',null,'unsupported delete rejected');
line 36: select throws_ok($select public.admin_user_directory('',-1)$,'22023',null,'negative offset rejected');
line 40: select throws_ok($select public.admin_user_directory('',0)$,'42501',null,'banned admin denied directory');
```
Postgres dollar-quote tags may only contain identifier characters — no spaces, quotes, or parentheses — so `$select public.admin_update_account(...)$` is not a valid dollar-quoted string; it will raise a syntax error the moment execution reaches it.

**This was not directly observed failing in this run** because §6a's error aborts the transaction before line 31 is reached (only lines up to 19 executed). It is reported here as a confirmed **static** defect (E1, high confidence, exact line numbers) that will surface as an additional failure the moment §6a is fixed and the file is re-run. Both must be fixed together to get a genuine 23/23 pass. *Not fixed, per instructions.*

### 6c. Pre-existing findings, not part of this session's diff (context only)

- `npx supabase db advisors --local --type security` → 2 `ERROR`-level `security_definer_view` findings: `public.organization_public_profiles` and `public.streamer_public_profiles`. Both views were created in `20260821203000_row_level_security.sql` (Aug 21) and last redefined in `20260830180000_map_visibility_toggle.sql` (Aug 30) — well before this session's diff. Not documented as an accepted risk in `Core_files/decisions.md`. Flagging because `06_VERIFICATION.md` §2b explicitly asks for R4/R9 (security-invoker views, advisors summary) at every checkpoint; this has apparently been an open, unaddressed advisor ERROR since August. **[E2, pre-existing, open]**
- R5 check (`06_VERIFICATION.md`): expected only `viewer_heartbeat`/`get_viewer_counts` to be anon-executable; found a third, `chat_sender_info`. Investigated: this is a **deliberate, documented** exception (`supabase/migrations/20260920140000_policy_quality.sql:129`: *"chat_sender_info stays available to anon on purpose: guest viewers must see..."*) — not a defect, just a description in `06_VERIFICATION.md` that's stale relative to an intentional design decision made a month prior. No action needed beyond noting it.
- R1 (`select relname from pg_class where ... not relrowsecurity` → 0 rows) — **PASS**.
- R2 (every RLS table has ≥1 policy unless documented deny-all) — **PASS**, only `stream_viewers` has RLS-with-no-policy, matching the documented deny-all list.
- R6 (no write policy with `using(true)`/`with check(true)`/`roles={public}`) — **PASS**; the 4 policies found with `qual=true` are all `SELECT`, explicitly scoped to `{anon,authenticated}` (not the `public` pseudo-role), matching gate `G10c`'s PASS.

## 7. What remains unverified

- Chrome interactive UI (welcome/guest/feed/map/Arabic/venue/nav/settings-guard/login/admin) — no safe browser-automation tool in this session (see §4). The equivalent Flutter code was verified interactively on Android (§5).
- Admin directory **rendering** on any platform — requires a real authenticated Google OAuth admin session; no dev/debug bypass exists in the app. Widget-level coverage exists via `flutter test test/admin_user_directory_test.dart` (7/7, mocked provider) and via static tab-wiring analysis (§5a footnote), but no live, authenticated UI render was observed by any session to date, including this one.
- `/admin` route guard specifically (as opposed to `/settings`) — not independently executed; inferred from shared code path (§5a).
- Real-device (physical phone) RTMP/streaming behavior — out of scope for this pass, unchanged from prior sessions' status (v0.7 Checkpoint 4's own outstanding item, per `AGENTS.md`/`CLAUDE.md`).
- Whether the `is_banned` RLS regression (§6a) and the dollar-quote defect (§6b) are the *only* defects in the new SQL — the test file's execution stopped at assertion 4 of 23; assertions 20–30 (lines not yet reached) have not been exercised at all even by proxy.

## 8. Evidence tier per claim

| Claim | Tier | Verdict |
|---|---|---|
| `flutter analyze` = 0 issues | E1 | PASS |
| `flutter test` 446/446 | E1 | PASS |
| `flutter test test/admin_user_directory_test.dart` 7/7 | E1 | PASS |
| Gates: only G6 failing, unchanged | E2 | PASS |
| `git diff --check` clean | E2 | PASS |
| Migrations apply cleanly locally | E2 | PASS |
| New admin RLS policy breaks `device_sessions` reads for authenticated users | E2 | **FAIL (confirmed regression)** |
| pgTAP file has 5 unparseable assertions (dollar-quoting) | E1 (static, high confidence) | **FAIL (latent defect)** |
| 2 pre-existing SECURITY DEFINER view advisor errors | E2 | Open, pre-existing, out of this diff's scope |
| Chrome: process launches, no runtime exceptions | E1/E2 | PASS |
| Chrome: interactive UI flows | E0 | UNVERIFIED (tooling blocker, recorded) |
| Android: launch/welcome/guest/feed/map | E3 | PASS |
| Android: Arabic nav-label + search-hint fix | E3 | **PASS — confirms the fix Astra could not confirm** |
| Android: Settings guard, login screen | E3 | PASS |
| Android: venue marker, marker selection, Google Maps navigation action | E3 | PASS (new coverage, via local-only seeded backend) |
| Android: admin route guard | E1 (code-path identity) | Not independently E3-verified |
| Admin directory rendering (any platform) | E0 | UNVERIFIED (no auth path available) |
| Docker/Supabase availability | E2 | Available this session (contrast with prior sessions) |

## 9. Final tally

| | Count |
|---|---|
| **PASS** | 24 (env ×2, static/automated ×5, Android interactive ×13 incl. the Arabic-fix confirmation, DB structural R-checks ×3, migration-apply ×1) |
| **FAIL** | 2 (device_sessions RLS regression §6a; pgTAP dollar-quote defect §6b) |
| **BLOCKED** | 1 (Chrome interactive UI — tooling, not app, blocker) |
| **UNVERIFIED** | 3 (admin directory rendering any platform; `/admin` guard specifically; physical-device RTMP, unchanged from prior sessions and out of this pass's scope) |

**No release-readiness claim.** The two FAIL items in §6 are new information this pass surfaced that prior sessions' "UNVERIFIED-STATIC" characterization did not have: the admin-directory migration, if pushed to a real environment as-is, would break authenticated reads of `device_sessions` used elsewhere in the app, and its own regression test suite cannot fully execute even after that is fixed. Both should block considering P6.4 item 1 "done" until corrected.
