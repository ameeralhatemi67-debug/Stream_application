# Resume and integration handoff
Worktree: C:/Users/User/.codex/worktrees/p6s-wave4v2-repair/Streamer_app
Branch: codex/p6s-wave4v2-repair; base master 7b54cb5e565011c33dcd03351735b7cc45a0926a.
Current snapshot identities and build hashes: identity.json. Source commit is recorded there; later documentation commits do not change the built source.
No merge, push, deployment, hosted database operation, app install, stash operation or main-checkout switch was performed.

## Resume order
1. Recheck budget per brief/04_BUDGET_PROTOCOL.md §J. At this handoff 4% was the soft stop; 5% is absolute STOP. Do not invent a waiver/reset.
2. Read critic findings and finish defects in the current slice before expanding it.
3. Implement G2 sender recovery only with a fresh server authority check and generation fencing before every retry; serialize one episode with attempt and wall-clock bounds. Preserve manual End, remote End/block, transfer/revocation/sign-out/expiry/disposal fences. Do not merely enable SDK retries.
4. Measure RootEncoder 2.7.5 preview and encoded orientation; consider stable canvas with fitted transforms. Retain one capture/session through layout transitions; verify front/back on physical phones.
5. Finish shared channel validation/normalization and visible org/external-phone release gating. Resolve D8 with owner; no client-only security claim.
6. Finish viewer intent-preserving recovery and accessible native-control-safe tap toggle. Add draft/rotation/platform-view identity tests.
7. Re-run stable verification, configure isolated candidate, use remaining critic rounds (maximum three total), then physical matrix. No acceptance by score alone.

## Candidate preparation
Current build attempts are compile artifacts without backend credentials, not E2E candidates. Never install an APK with the production package ID over an existing owner app. No side-by-side package variant is supplied yet; preparing and verifying one is a remaining setup gate, including OAuth redirects.

Use a **new** disposable Supabase directory/project_id Streamer_wave4v2 and unique unused ports (proposed 55921 API, 55922 DB, 55923 Studio, 55924 mail; inspect availability first). Copy only committed config and migrations, change project_id/ports, then start that stack from its own directory. Never reset/reuse the audit or Opus stacks. Apply all committed migrations there; seed separate approved broadcaster, viewer and admin test accounts and primary devices using existing SQL fixtures. Confirm role/RLS negative tests before physical use. No new migration in this slice.
Create a gitignored project/dart_define.wave4v2.json containing only that stack's public URL and anon key plus an owner-provisioned restricted test YOUTUBE_API_KEY. For phones use the test host's reachable LAN address, not localhost; configure local test Auth redirects and permitted networking. Never copy/read dart_define.local.json, service-role keys or production signing. The owner must provision a test channel/key and any OAuth setup; stream keys stay out of evidence.
Build from project:
```powershell
flutter pub get --offline
flutter analyze
flutter test --concurrency=1
flutter build apk --debug --dart-define-from-file=dart_define.wave4v2.json
flutter build web --dart-define-from-file=dart_define.wave4v2.json
```
The APK command above still uses the existing application ID until a reviewed side-by-side variant exists. Do not install it over another app. Leave installation to the owner.
Record source/config hashes (never config contents), named backend identity, migration list and artifact hashes. A configured build must be rebuilt/reviewed for any source variant; do not transfer compile-only hashes to it.

## Integration with map work
Likely conflicts: shared en/ar catalogs, status/progress/ledger; later G2/G4 will also touch app_provider.dart. Current repair does not modify map files or provider. Do not rebase unfinished Opus work. After a separately authorized integration, rerun room/feed/map End convergence, same-watch replacement, offline restoration, account switching and retained-player rotation, plus analyzer/full tests/builds.



## Hard stop
Live Codex usage tool reached weekly5%, the binding absolute ceiling. No further work or rerun authorized under the existing budget. Full suite698passed/1stale expectation; test corrected in68394e9, rerun NOT RUN. Critic round1 scores5/6/4/6, NEEDS WORK; see CRITIC_REVIEW.md. Android then web compile-only builds were launched sequentially in exec session74545 and may still be running; logs and exit files will record completion. No installation. Artifacts observed at stop are in identity.json; they are not acceptance builds. Required source repairs/configuration and physical results remain missing. Protected54main/evidence hashes matched before hard stop.
