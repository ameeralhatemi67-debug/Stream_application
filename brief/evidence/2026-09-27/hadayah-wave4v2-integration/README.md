# Hadayah Test — Wave4v2 integration

## Current starting point, 2026-09-27

The combined work is now merged into local **master** at `c9e441f` and pushed to GitHub through `df763da`. Use `C:/Users/User/Documents/Amir Ob/projects/Ideas/Current/Streamer_app/project` for the next full rebuild/relaunch. Do not switch to an old agent worktree. Application/database/build source is identical to reviewed `34d074a`; subsequent commits update documentation only.

Read this setup checklist, follow [WAVE4V2_RETEST_SCRIPT.md](WAVE4V2_RETEST_SCRIPT.md) starting at **W00**, and write observations in [WAVE4V2_ACCEPTANCE_RESULTS.md](WAVE4V2_ACCEPTANCE_RESULTS.md). These are the consolidated tests for the map and streaming changes. W00 must identify the newly installed build and authorized configuration/backend before dependent tests begin.

The identity table and isolated-worktree statements below describe Astra's original diagnostic delivery before the master merge. Its ignored APK/web archives and local setup remain in that original worktree; GitHub contains the source and committed test records, not those ignored artifacts. A master rebuild needs its own artifact/configuration identity. The existing phone installation was not updated by the merge or push. Google/YouTube acceptance setup is still unconfirmed; stop dependent tests if W00 cannot confirm it. No physical acceptance is claimed.

## Original diagnostic delivery

**Status: diagnostic candidate; source-review target met in cycle 2 and required local verification passed. Not checkpoint-accepted or release-ready.** Google/YouTube acceptance configuration is absent. D8 server-side YouTube authorization remains an explicitly retained HIGH release blocker. Accurate city outlines, physical received-video acceptance and resource/background evidence remain open.

Start with this file, then [WAVE4V2_RETEST_SCRIPT.md](WAVE4V2_RETEST_SCRIPT.md) at **W00**. Record only fresh results in [WAVE4V2_ACCEPTANCE_RESULTS.md](WAVE4V2_ACCEPTANCE_RESULTS.md). The short smoke comes before the longer tests and tells you where to stop.

## Candidate identity

| Field | Value |
|---|---|
| Branch | `codex/hadayah-wave4v2-integration` |
| Frozen source | `34d074a5c577cd35944813f0a3db5315f4c85e96` |
| Integrated source tips | streaming `818cc127f8d89f0f2c5a08bca7390cc50aa67368`; map `74157bad63279053774a01cfc5b2399bea390bd0` |
| Product / test label | Hadayah / **Hadayah Test** |
| Android package | `sa.hadayah.streamer_app.wave4v2` (existing test identity; owner package stays separate) |
| OAuth callback | `sa.hadayah.streamerapp.wave4v2://login-callback` |
| Web build identifier | `34d074a-local-diag-1` |
| Backend | `Hadayah_integration_20260927`, disposable local API `http://127.0.0.1:56021`, DB port 56022 (stopped with backup) |
| Configuration | ignored `brief/.runtime/hadayah-integration/defines.diagnostic.json`; generated local anon key, no YouTube key/Google provider configuration |
| Artifacts / hashes | [identity.json](identity.json): Android 1.0.0/code 1, debug-signed, APK SHA-256 `576ee96a860b5bcc1b5bde1c7875ee31f31943062c8cb6bd071482453c158b99`; web SHA-256 `720fa376cdc9a9f4a4b7c6b4fe50aa972bb0c9b84c217409bdb3feadfd709d57`. |
| Local master | Not merged; protected dirty owner docs overlap incoming paths. Final preservation/promotion assessment in HANDOFF. |

The worktree is `C:/Users/User/.codex/worktrees/hadayah-wave4v2-integration/Streamer_app`. The sole deliverable artifacts are [Hadayah-Test-34d074a-diagnostic.apk](../../../.runtime/hadayah-integration/candidate/Hadayah-Test-34d074a-diagnostic.apk) and [the matching web archive](../../../.runtime/hadayah-integration/candidate/Hadayah-Test-34d074a-diagnostic-web.zip). They stay in the ignored runtime directory and are not committed. Chrome retains the Hadayah Live page title; identify this test by its loopback origin, build ID and archive hash. No owner app has been installed/replaced. Do not follow the historical maptest package instructions: this integration uses the one existing `.wave4v2` identity.

To inspect this diagnostic web build on the PC, run from the integration repository root, then open `http://127.0.0.1:56090` in a dedicated Chrome test profile:

```powershell
& 'C:/Program Files/Python313/python.exe' -m http.server 56090 --bind 127.0.0.1 --directory project/build/web
```

The directory must still match the stamped final build; compare it with the supplied archive/identity before testing. Stop this terminal server with Ctrl+C after use. It serves only built public app files on loopback. The [Python 3.13 command documentation](https://github.com/python/cpython/blob/v3.13.9/Doc/library/http.server.rst) was checked through Context7. Google/live tests remain blocked until the setup below is complete.

## Exact missing setup — owner checklist

No documented authorized acceptance credentials were found in the streaming handoffs/setup records. They explicitly describe a no-key local diagnostic build. `project/dart_define.local.json` was neither read nor copied. The existing public OAuth client identifier in HTML is not evidence of an authorized dedicated test setup.

1. **Provide a dedicated non-production Google OAuth web client and allowed test users.** Keep its client secret in an environment variable referenced by the ignored local `brief/.runtime/hadayah-integration/supabase/config.toml`, never in Dart defines. Enable `[auth.external.google]` there with the dedicated client ID and `secret = "env(HADAYAH_TEST_GOOGLE_CLIENT_SECRET)"`. Register `http://127.0.0.1:56021/auth/v1/callback` as the Google redirect for this local test setup. Confirm Google accepts that loopback callback with the chosen client type; do not bypass provider restrictions.
2. **Configure local redirects and test roles.** Retain local site URL `http://127.0.0.1:56090` and allow the same browser URL plus `sa.hadayah.streamerapp.wave4v2://login-callback`. Start/restart only this named local stack. Sign in with the permitted test users and provision viewer, ordinary approved streamer and admin/master-admin fixtures in this disposable database. Do not use production users or hosted administration. Both new migrations `20260927010000_application_city_selection.sql` and `20260927020000_organization_public_location.sql` must be present; no hosted rollout occurred here.
3. **Provide a dedicated eligible YouTube test channel/event and appropriately restricted Data API test key.** The client app needs `YOUTUBE_API_KEY` for watch/channel checks. Keep ingest keys in the operator's secure test setup and enter only through the intended app/OBS flow; never save them in this evidence pack. Confirm the exact watch event, channel eligibility and who may authorize a test broadcast. Google sign-in alone does not implement D8 server ownership; D8 remains blocked.
4. **Save client configuration securely and rebuild.** In the ignored runtime directory create `defines.acceptance.json` from the diagnostic file, retaining only its local URL/anon key and test callback; add the dedicated API key. Never add a service-role key, OAuth secret or ingest key. Use platform-appropriate API-key restrictions. Do not send credentials in chat. Record config hash and backend identity, build the same test package from the reviewed source, and hash/signature-check the new APK/web archive. The current diagnostic artifact does not become configured by editing a file after it was built.
5. **Verify phone routing before W00.** Each USB-connected test phone can reach this PC's local control backend through `adb -s <designated-test-serial> reverse tcp:56021 tcp:56021`. Test callback return on both phones before any long run. Chrome on the PC uses the local API directly. YouTube still needs internet. This separates control traffic over USB from media over Wi-Fi/mobile; record that topology. Full untethered backend/network-transition acceptance needs separately authorized reachable test infrastructure. Do not expose a local service with a tunnel or weaken broad cleartext rules as a shortcut.

This local backend can support phone accounts, roles, chat and session authority after OAuth/test-role setup and USB routing. It cannot supply YouTube media, channel eligibility or server-side D8 authorization, and it cannot by itself prove untethered backend connectivity. Diagnostic guest/offline map tests, native math, widget, local SQL and cache-fault checks remain independent of this missing setup.

After setup, from `project/`, build with `--dart-define-from-file=../brief/.runtime/hadayah-integration/defines.acceptance.json`; Android also requires `--android-project-arg=wave4v2TestApp=true`. Web additionally requires a unique `--dart-define=HADAYAH_BUILD_ID=<source-and-config-build-id>` and then `node tool/stamp_offline_build.mjs build/web <same-id>`. A web build without that stamp fails offline preparation rather than claiming ready. Updating configuration/build artifacts changes their identity and requires W00 and applicable smoke again.

Final critic: **8/8/8/8**, all provisional for physical/backend acceptance. Fresh checks: **847 Flutter tests**, analyzer 0, local SQL462 assertions/3 concurrency checks, gates 0 failures, Android/web builds and whole-app offline fault checks passed.

## Evidence pack

- [Audit, repairs and requirement/code/test table](AUDIT_AND_REPAIRS.md)
- [Fresh verification and limitations](VERIFICATION.md)
- [Independent critic — at most three rounds](CRITIC_REVIEW.md)
- [Consolidated owner script](WAVE4V2_RETEST_SCRIPT.md) and [blank matching results](WAVE4V2_ACCEPTANCE_RESULTS.md)
- [Separate P5/P6/P6S closure decisions](CLOSURE_MATRIX.md)
- [Handoff and preservation/merge state](HANDOFF.md)

No physical PASS, configuration readiness or scope acceptance is inferred from compilation, SQL tests or numerical review scores.
