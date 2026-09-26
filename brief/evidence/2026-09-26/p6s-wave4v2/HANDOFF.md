# Build and integration handoff

Worktree `C:/Users/User/.codex/worktrees/p6s-wave4v2-repair/Streamer_app`, branch `codex/p6s-wave4v2-repair`, base `7b54cb5e565011c33dcd03351735b7cc45a0926a`. Exact reviewed source, commits and artifact hashes are in VERIFICATION.md / identity.json.

No merge, push, deployment, hosted database operation, production configuration access, installed-owner-app replacement, stash operation or main-checkout branch switch is authorized. Preserve this worktree and its ignored build/runtime artifacts for review.

## Reproduce isolated setup

Run from this worktree root. The preparation script refuses an existing runtime and occupied ports; it never resets a database.

```powershell
./brief/tools/prepare_wave4v2.ps1 -SupabaseCli 'C:/Users/User/Documents/Amir Ob/projects/Ideas/Current/Streamer_app/node_modules/.bin/supabase.cmd'
```

It copies committed migrations/tests to `brief/.runtime/wave4v2/supabase`, starts only `Streamer_wave4v2` (API55921, DB55922), and writes only the local anon key to ignored `defines.no-key.json`. Raw CLI startup/status logs may contain local credentials and stay ignored. Existing P6/Opus/audit containers are untouched. No new migration was introduced.

Google sign-in and YouTube channel tests are **not configured** by this script. The normal app exposes Google OAuth, so email/password fixture accounts alone do not enable the owner UI.

Owner preparation for end-to-end tests:
1. Provision a disposable Google OAuth web client and test users, a dedicated YouTube test channel, a restricted test Data API key and test ingest keys. Never copy `project/dart_define.local.json`. Do not put secrets in results or chat.
2. In the ignored local config only, set `[auth] site_url = "http://127.0.0.1:55990"` (the existing diagnostic runtime was initially created with port3000), then enable `[auth.external.google]`, enter the test client ID and an environment-variable reference for its test secret. Register `http://127.0.0.1:55921/auth/v1/callback` on that test OAuth client. Keep the local redirect allowlist for `http://127.0.0.1:55990` and `sa.hadayah.streamerapp.wave4v2://login-callback`. Restart only this named stack after configuration; never reset shared stacks. OAuth on real phones is itself a setup check.
3. Copy ignored `defines.no-key.json` to `defines.acceptance.json`, set its test `YOUTUBE_API_KEY`; retain only the local URL/anon key and test callback. The APK's local URL uses `adb -s <test-phone-serial> reverse tcp:55921 tcp:55921` while USB-connected. Each viewer can use a different network for YouTube while the local control backend uses USB. Record that topology. No broad cleartext network exception was added.
4. Sign in distinct broadcaster, viewer and admin test identities. Bootstrap an admin only in `supabase_db_Streamer_wave4v2` using the exact local-only procedure below; verify the exact profile ID/email before assigning `master_admin`. Apply for broadcasting with the correct test channel, then approve through the admin UI. Role provisioning is setup, not an approval-security pass. Test both physical phones as sender and viewer.
5. Supply an actual live/upcoming-near-now watch ID from that channel and its corresponding test ingest key in the phone studio or OBS. Metadata matching does not prove that pairing. Record only watch/session IDs, never ingest keys.

## Build without replacing the owner app

From `project/` (PowerShell):

```powershell
$env:GRADLE_OPTS='-Dorg.gradle.workers.max=2 -Dorg.gradle.jvmargs=-Xmx3g'
flutter pub get --offline
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
flutter build apk --debug --no-pub --android-project-arg=wave4v2TestApp=true --dart-define-from-file=../brief/.runtime/wave4v2/defines.acceptance.json
flutter build web --no-pub --dart-define-from-file=../brief/.runtime/wave4v2/defines.acceptance.json
```

Verify APK ID `sa.hadayah.streamer_app.wave4v2`, label `Streamer Wave4v2`, callback `sa.hadayah.streamerapp.wave4v2`. Release/default application identity remains unchanged. Hash every artifact and config without displaying config contents. Installation of the owner test candidate is left to the owner. If that test ID already exists, preserve its data and coordinate replacement first.

The supplied no-key diagnostic variant supports backend/guest smoke and negative-key checks only. Build the acceptance variant after provisioning. Serve web with `python -m http.server 55990 --bind 127.0.0.1 --directory build/web` and use a separate Chrome profile. No hosting/deployment is needed.

For readiness fault R09, build a **separate diagnostic APK** using the same safe configuration plus `--dart-define=WAVE4V2_SUPPRESS_PLAYER_READY=true`. This debug-only flag ignores the native JavaScript bridge; it leaves the YouTube iframe and network reachable. Save it under a distinct filename/hash. Install only on the designated test app after preserving its state. Run normal and suppressed variants separately; the flag is compiled out in release.

The local native probe entrypoint `project/tool/wave4v2_native_probe.dart` has no backend or real channel. It sends only to the emulator host on port55935; its authorization callback is a local fixture. It measures SDK lifecycle/output, not P6S server authorization or physical AV. See NATIVE_PROBE.md.

## After testing and integration

D8 remains a release blocker by explicit owner decision. Populate the results and separate matrices before accepting either checkpoint. Maximum three critic rounds across this task; do not retain old scores after a source fix.

Likely conflicts with Opus: `app_provider.dart`, en/ar catalogs and status/ledger. Map code was not imported or edited. No rebase against unfinished map work. After separately authorized integration run analyzer, full Flutter suite, gates, debug APK/web builds, room/feed/map End convergence, same-watch restart, offline/reconnect, account/channel switching, disabled org mode and retained-player rotation. Shared provider merges need special review around catalog timeouts and session-generation fences.

No database rollout step is proposed by this branch because no migration changed. Future D8 server work requires its own design/provisioning, disposable SQL suite/races and owner-reviewed rollout; it cannot be waived by this pack.

## Local-only admin bootstrap and resume

After the test admin has signed in once, from the worktree root run the read-only query below. This displays only identities in the disposable local database. Replace the example UUID/email only with the matching test identity from that query; do not run these commands against any other database.

```powershell
docker exec supabase_db_Streamer_wave4v2 psql -U postgres -d postgres -c "select u.id, u.email from auth.users u join public.profiles p on p.id=u.id order by u.created_at;"
```

Open an interactive local psql session (no hosted connection):

```powershell
docker exec -it supabase_db_Streamer_wave4v2 psql -U postgres -d postgres -v ON_ERROR_STOP=1
```

Run with the test UUID/email substituted. The double identity check must match exactly one signed-in test profile; inspect `RETURNING`. No result means stop and correct the identity. This is bootstrap fixture setup, not evidence that ordinary users can grant roles.

```sql
insert into public.user_roles(profile_id,role,granted_by)
select p.id,'master_admin',p.id
from public.profiles p join auth.users u on u.id=p.id
where p.id='REPLACE_WITH_TEST_UUID'::uuid
  and u.email='REPLACE_WITH_TEST_EMAIL'
  and not exists (select 1 from public.user_roles r
                  where r.profile_id=p.id and r.role='master_admin')
returning profile_id,role;
```

Sign the test admin out/in, then use the normal admin approval UI. Run local SQL again with `supabase test db --workdir brief/.runtime/wave4v2 --local`; the preserved run in this pack passed21 files/440 assertions. No new migrations or independent-session SQL race changes were introduced. Historical race logs are not fresh results.

The existing runtime must not be recreated by the preparation script. To resume it, use `supabase start --workdir brief/.runtime/wave4v2 --exclude studio,pgadmin-schema-diff,migra,postgres-meta,logflare,vector,imgproxy,edge-runtime,supavisor,inbucket`. To stop just this stack with data backup, use `supabase stop --workdir brief/.runtime/wave4v2`. Do not use `--all`, `--no-backup`, `db reset`, `link`, or a hosted URL. Use these same stop/start commands after supplying local test OAuth config.

## Supplied artifact locations

App source `5162addcc8a659d3c66dafde3f243565cc85acf7`. Side-by-side Android diagnostic: `brief/.runtime/wave4v2/streamer-wave4v2-5162add-no-key.apk`. Web archive: `brief/.runtime/wave4v2/streamer-wave4v2-5162add-web-no-key.zip`; unarchived files remain in `project/build/web`. These are **no-key local diagnostic builds**. Hashes and commands are in VERIFICATION/identity.json. They cannot complete Google login/live-channel acceptance until the documented disposable credentials are provisioned and a newly hashed acceptance build is produced. The named local backend was stopped with backup after SQL verification; resume it using the command above.

## Known source defect before physical testing

Final review3/3 found an unresolved P2: in the full room, the unconfirmed notice overlaps/intercepts the eye button used to hide/reveal controls. Chrome normally remains unconfirmed. F09/F10 must record this separately; do not treat the standalone browser probe as a full-room pass. All fresh physical rows remain NOT RUN. Review scores8/7/7/7 did not meet the target. Source is frozen at5162add; no post-review source fix is included. D8 remains HIGH and release-blocking by owner decision.
