# 03 — Remaining work for Claude before the Google Play launch

Written 2026-10-10 from:
- `Core_files/STATUS.md`
- `brief/03_WORK_PLAN.md`
- `brief/management/RELEASE_SCOPE.md`
- the git log
- a read-only check of the hosted Supabase project `zkkmfjsjouqzibvnzkau`

Owner steps: [01_OWNER_STEPS.md](01_OWNER_STEPS.md). Testing: [02_TESTING_PLAN.md](02_TESTING_PLAN.md).

Rules that still apply:
- commit to `master` locally; the owner pushes
- every hosted Supabase change needs the owner's explicit yes, and goes through the MCP connector
- `flutter analyze` = 0 and `flutter test` green before each commit
- no secrets in chat, git or logs

**Blocked by** means: wait for that owner step or test result first.

---

## Snapshot of the hosted backend (checked 2026-10-10)

| Item | State |
|---|---|
| Migrations | All 80 local migrations applied (latest `20261008110548_reminder_dispatch_key`) |
| Edge functions live | `channel-authorization`, `broadcast-control`, `reconcile-broadcasts`, `dispatch-upcoming-reminders` |
| Edge function **missing** | `dispatch-organization-events` |
| Cron jobs | Only `hadayah-reconcile-broadcasts` (every minute) |
| Cron jobs **missing** | `dispatch-upcoming-reminders`, `dispatch-organization-events`, stale-live-flag sweep |
| Vault | Reconcile key + 2 YouTube connections. **Missing:** `upcoming_reminder_dispatch_key`, `upcoming_reminder_function_url` |
| Pilot organizations enabled | 0 |
| Firebase | No project, so no push can be delivered |

---

## 1. Bring the records up to date (do first, small)

- [x] Add a LEDGER RESUME block covering the ~23 commits since 2026-10-01: redesign port, streaming/RTMPS fixes, chat moderation, YouTube web proxy and deploy, skeletons, bookmarks, the reminder dispatch key. *(2026-10-15)*
- [x] Update `Roadmap.md` v1.0: *(2026-10-15)*
  - P7 tasks 1.0.8.1.1–1.0.8.1.3 are implemented by Organization V1 (pilot pending).
  - P2's "sample KPI" note is fixed: `ViewerAnalyticsModel.createDefault()` now returns zeros.
  - Refresh the checkpoint map table.
- [x] Update `Core_files/STATUS.md` header and `brief/management/RELEASE_SCOPE.md`: *(2026-10-15; STREAM-D8 recorded as implemented, owner to confirm account/channel)*
  - the owner has physically tested streaming, settings, chat, viewer counts, UI, map and admin
  - record STREAM-D8 as implemented server-side and verified by owner streaming tests (confirm with the owner which account and channel were used)
- [x] Link this `brief/launch/` folder from `brief/README.md` and `CLAUDE.md` as the active launch plan. *(2026-10-15)*

## 2. Finish the hosted backend for organizations, reminders and push

Blocked by 01 §4 (Firebase), 01 §5 (secrets) and the owner's approval.

- [ ] Deploy `dispatch-organization-events` (`verify_jwt=false`, authorized by `ORG_EVENTS_DISPATCH_KEY`).
- [ ] Run `supabase/functions/dispatch-upcoming-reminders/cron.sql`, with `<project-ref>` replaced. This creates both Vault secrets and the per-minute job.
- [ ] Write and run the matching Vault + cron SQL for `dispatch-organization-events`. Store the key in Vault, never in the job text.
- [ ] Schedule `public.sweep_stale_live_flags()` every minute (the stale-live-flag sweep from `OWNER_ACTIONS`), unless `reconcile-broadcasts` already clears those flags. Check that first.
- [ ] Call each job once and check function logs for a 200 response and no errors.
- [ ] Run the hosted **security** and **performance** advisors. Fix any new error-level findings with a new migration (owner approval).
- [ ] Record the evidence in `brief/evidence/<date>/hosted-launch-setup/README.md`.

## 3. Data rights (Play and PDPL requirements)

- [x] **Data export covers everything.** `AppProvider.exportMyData()` today reads `profiles`, `broadcaster_applications` and sent chat only. Add every user-linked table: *(2026-10-15; hosted as `20261015172851`)*
  - roles and permissions
  - device sessions
  - consent
  - follows and bookmarks (incl. saved library metadata)
  - chat reports filed, blocks, mutes and bans received
  - reminders and upcoming subscriptions, push devices and preferences
  - organization memberships, invitations, assignments and events
  - YouTube connection *metadata* (never tokens)

  Prefer one `security definer` RPC `export_my_data()` so it's complete and fast. Offer it as a downloadable JSON file, not only Copy. Show a warning if any part fails.
- [ ] **Consent withdrawal** works and is recorded (Settings → Privacy). *2026-10-15: still deletion-only; waiting on counsel question 7 before building a separate path.*
- [x] **Account deletion completeness:** *(2026-10-15, local)*
  - uploaded Storage objects (avatar, banner, application images) are deleted
  - push device tokens and reminders are removed
  - organization membership is handled
  - the audit log keeps no name or email beyond what the lawyer allows

  Test on a disposable local database.
- [~] **Web deletion page:** *(2026-10-16: rebranded to Hadayah Live and lists what is deleted; its request path is still a mailto link, so a form that writes to a table is the remaining improvement)* finish `project/web/delete-account.html` (Arabic + English) with a working request path, for example a form that writes to a request table, or a signed-in "delete my account" flow on the web build. It's served from the owner's final domain.
- [x] pgTAP tests for the export RPC and deletion cascade. *(`supabase/tests/data_rights.test.sql`, 39/39)*

## 4. Release-scope cleanup (truthful UI)

- [x] Re-confirm each unproven mode is visibly unavailable and can't be started: *(2026-10-15, source check)*
  - same-Wi-Fi Local
  - direct laptop capture
  - real picture-in-picture
  - private streams (`kPrivateStreamingEnabled = false`)
  - front camera ("Coming Soon")
- [x] **Reminders without Firebase:** `ReminderPushService` already skips when Firebase isn't configured, but the bell can still be turned on. Either hide the reminder controls when push isn't configured, or label them "in-app only". Depends on owner decision 0. *(hidden when the build has no Firebase values)*
- [x] **Organization broadcasting:** confirm it follows `organizations_v1_enabled` + the pilot list everywhere: studio, `/shows`, application forms, profile actions. Match owner decision 0. *(studio destinations now require the organization to be enabled)*
- [x] **Location:** the manifest now asks for `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` (used by `location_picker_modal.dart` "my location"). Confirm it's only requested on tap. Decide whether coarse location is enough. Document exactly what is sent to the server (only the chosen venue point) for Data Safety. *(on tap only; fine kept; recorded in `store/data_safety.md`)*
- [x] Remove any remaining dev or test labels from the release flavor: *(none in release; debug-only)*
  - "Hadayah Test"
  - the `.wave4v2` suffix (check it only applies to the test flavor)
  - debug-only admin tools

## 5. Android 16 (API 36) behaviour

The project targets API 36 (`playTargetSdkFloor = 36`), which Play requires for new apps from 2026-08-31.

- [x] On screens 600dp and wider, Android 16 ignores orientation locks. The live room and phone broadcast screen call `setPreferredOrientations(portraitUp)`. Check the tablet layouts in the live room, studio and broadcast screen still work when rotated. Fix the layout instead of relying on the lock. *(widget-tested; map row fixed; device run still owed)*
- [x] Edge-to-edge can no longer be switched off. Check the status/navigation bar insets on every main screen, especially the live room and studio bottom sheets. *(`android16_layout_test.dart`)*
- [x] Predictive back: check the back gesture exits the studio and live room cleanly (camera released, wakelock off). *(PopScope + dispose; existing system-Back test)*

## 6. Store and Google-verification documents

Blocked by: the owner's domain and pages for the final URLs.

- [x] Update `store/data_safety.md` to the current code: *(2026-10-16: copy-ready Play answer table added at the top of the file)*
  - location permission
  - Firebase Messaging SDK and push tokens
  - Vercel server proxy for YouTube reads
  - organizations, reminders, bookmarks
  - YouTube OAuth tokens kept server-side in Vault

  Produce a ready-to-copy answer table for the Play form.
- [x] Update `store/listing_draft_ar_en.md`: only features that ship; Arabic and English; within the 30/80/4000 character limits. *(2026-10-16, counts measured; organizations included)*
- [x] Update `store/permissions_and_fgs_declaration.md`: final text for the camera and microphone foreground-service declaration, plus a **demo-video shot list**. *(2026-10-16; the owner still records the video; the service notification is now mode-neutral)*
- [x] Write `store/oauth_verification.md`: *(2026-10-16; the YouTube OAuth client ID and a real custom domain are still owner inputs)*
  - scope justification for `youtube.force-ssl` (why narrower scopes aren't enough)
  - the list of every OAuth client on the project
  - the demo-video script (app name, client ID, full consent screen, connect → go live → end)
- [x] Write `store/reviewer_access.md`: *(2026-10-16; owner creates the reviewer account)* App-access instructions for Google's reviewer (guest path + reviewer account steps). No passwords in the file.
- [x] Prepare the privacy policy and home page HTML (Arabic + English) from counsel's final text, for the owner to publish. *(2026-10-16: `project/web/privacy.html` and `about.html` are drafted from the code, not from counsel text; counsel still reviews. They deploy with the web build on push.)*
- [x] Feature graphic 1024×500 and a screenshot shot list. *(2026-10-16: `store/assets/feature_graphic_1024x500.png`, `icon_512_fullbleed.png`, `store/screenshot_shot_list.md`; the owner takes the screenshots)*

## 7. Configuration for the release build

Blocked by: the signing key (01 §6), the new API key and Firebase values (01 §3–4).

- [x] Update `AppIdentity` with the final website, privacy, terms and delete-account URLs and the support email. *(2026-10-16: website, home, privacy and delete URLs on the Vercel origin; one constant changes when a custom domain arrives; no terms page yet; support email unchanged)*
- [ ] Give the owner the exact Supabase Auth redirect values (Android scheme `…://login-callback`, the web origin) for 01 §5.
- [ ] Check `dart_define.example.json` lists every key the release needs. The owner fills the real `dart_define.local.json`; Claude never reads or copies secret values into chat.
- [ ] Update the Vercel env vars list in `doc/YouTube_web_configuration.md` and `doc/organization-v1-owner-setup.md` for the final domain and Firebase.

## 8. Build the release candidate

- [ ] Bump `version:` in `pubspec.yaml` (`1.0.0+N`; N goes up for every upload).
- [ ] Run:
  ```bash
  flutter build appbundle --release --dart-define-from-file=dart_define.local.json
  ```
  The build must use the real upload key; it fails closed without `key.properties`.
- [ ] Run `node brief/tools/scan_build_secrets.mjs <aab>`: it must print `RESULT: clean`. Record the AAB size.
- [ ] Check 16 KB page alignment of the native `.so` files (RootEncoder, Flutter) inside the AAB.
- [ ] Install a universal APK from the AAB (bundletool) on an emulator and a phone. Smoke-test: launch, sign-in screen, feed, map, live room, studio open. Check R8 keep rules (RootEncoder, Supabase, WebView, Firebase) if anything crashes.
- [ ] Hand the `.aab` path to the owner for the internal-testing upload (01 §8).

## 9. Full verification (P9)

- [ ] `flutter analyze` (0), full `flutter test` (all green), `node brief/tools/gates.mjs --history`.
- [ ] Fix the known gate failures:
  - G2d gradients and G3 raised-hand glyphs in owner work
  - G11a secret-bearing files in the old nested `.claude/worktrees` (ask the owner before deleting anything)
- [ ] Start Docker and run the **whole local SQL/pgTAP suite** on a disposable database (Roadmap task 1.0.0.1.3, never rerun since the organization and reminder migrations). Include the organization V1 check `node brief/tools/organization_v1_db_check.mjs`.
- [ ] Review `git diff --stat pre-hardening-2026-09-19..HEAD` for stray files (runtime folders, keys, `.serena`, `hs_err_pid*.log` in `project/android/`).
- [ ] Clean up untracked clutter with the owner's OK: `project/android/hs_err_pid*.log`, `replay_pid*.log`, `_to_delete/`.

## 10. Fix what testing finds

- [ ] Fix each FAIL from [02_TESTING_PLAN.md](02_TESTING_PLAN.md) sections A–E in small commits, with a regression test where possible. Rebuild and hand back for re-test.
- [ ] Handle Play pre-launch report and Android vitals findings (crashes, ANRs, accessibility warnings).
- [ ] Watch for the older open items if they reappear in testing:
  - stale LIVE on the receiving phone after a device transfer (2026-09-24)
  - low frame rate / System UI "not responding" seen on the emulator

## 11. Close-out

- [ ] Write `brief/FINAL_REPORT.md` (one page: done / cut / verified / owner items).
- [ ] Update `CLAUDE.md`, `Core_files/STATUS.md`, `Core_files/decisions.md` (ADRs for any launch-scope cuts), and tick the Roadmap v1.0 tasks with evidence links.
- [ ] Tag `v1.0.0` locally after the production upload is approved. The owner pushes the tag.

---

## After the launch (not blocking)

- Organization broadcasting for everyone, after the 3-show pilot passes (02 §A5).
- Legacy publicly readable `streamer-assets` objects at old flat paths: migrate or delete.
- POST-01…04 deferrals in `RELEASE_SCOPE.md` (organization broadcast switching, advance YouTube scheduling, return-to-broadcast shortcut, front camera).
- Accurate licensed city boundaries for the map.
- v1.1 iOS.

## Suggested order

1 → 2 (as soon as the owner finishes Firebase/secrets) → 3 and 4 in parallel → 5 → 6 → 7 → 8 → owner tests (02) → 10 → 9 → 11.
