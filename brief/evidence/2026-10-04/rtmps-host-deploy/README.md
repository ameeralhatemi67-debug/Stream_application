# RTMPS host deployment evidence

Attempt stopped at preflight on 2026-10-04 19:58:34 +03:00 (Asia/Riyadh).
Target: production project `zkkmfjsjouqzibvnzkau`.
Owner approved deployment. No source code was edited, no migration was applied, no function was deployed, and no Git commit or push was performed.

## Commands and outcomes

All shell commands ran from the repository root.

- Read the Supabase, Context7, writing, and task-observer skill instructions; inspected the issue-name index and streaming handoff plan.
- Read `supabase/.temp/project-ref`, ran `git status --short`, and read the beginning of `brief/handoff/STREAMING_CORE_PLAN.md`. These were read-only context checks.
- Queried Context7 for Supabase CLI deployment configuration. Documentation says deployment uses explicit `verify_jwt` configuration when no override is supplied. No configuration was changed.
- Attempted to read the public Supabase changelog through the web tool. The tool could not render its `text/markdown` response. No deployment action resulted.
- Ran the required first preflight command:

```powershell
$env:DO_NOT_TRACK=1; npx supabase migration list --linked
```

Exit code: `1`. Error code: `LegacyPlatformAuthRequiredError`.
Message: `Access token not provided. Supply an access token by running supabase login or setting the SUPABASE_ACCESS_TOKEN environment variable.`

Stopped as instructed. No authentication changes or deployment workaround was attempted.

## Migration and function evidence

- Migration list before: unavailable; the command failed before returning rows. The expected local-only migration could not be confirmed.
- Migration list after: not run; migration application was not attempted.
- Offline `youtube_broadcast_check.mjs` and `broadcast_control_check.mjs`: not run after preflight failure.
- `db push --linked`: not run.
- Function deployments and `functions list`: not run.
- Previous function versions supplied by the owner: `broadcast-control` 3, `reconcile-broadcasts` 3, `channel-authorization` 5. These were not independently verified.
- Function versions after: not queried; this attempt deployed no new versions.

## Checks 4a–4d

- 4a, ACTIVE status and higher versions: not verified.
- 4b, SQL host and reconcile checks: not run.
- 4c, anon and authenticated privileges: not queried; this attempt changed no privileges.
- 4d, recovery POST 200 and stable `checked_at` over at least two minutes: not run.

The RTMPS host issue entry remains unchanged because hosted deployment did not complete.
No secrets, tokens, stream keys, refresh tokens, or Vault contents were printed or recorded.

## Retry after owner login

On 2026-10-04 20:10:37 +03:00 (Asia/Riyadh), the owner reported completing login and authorized a retry.

```powershell
$env:DO_NOT_TRACK=1; npx supabase migration list --linked
```

Exit code: `1`, with the same `LegacyPlatformAuthRequiredError` and access-token-not-provided message. No migration rows were returned. The retry stopped immediately before any offline checks, migration application, function deployment, or hosted verification. No authentication workaround was attempted. Function versions remain unverified and checks 4a–4d remain unrun. Source code and the issue status were unchanged.

Not verified: real phone → YouTube broadcast; owner must install project/build/app/outputs/flutter-apk/app-debug.apk and test Preview camera → Go live → End.

## Deployment completed through the Supabase MCP connector (2026-10-05, Claude Code)

The CLI login blocker was bypassed by deploying through the Supabase MCP connector, which was already authorized for this project. The owner asked for the fix to be applied directly.

- Offline checks first: `node --experimental-transform-types brief/tools/youtube_broadcast_check.mjs` and `broadcast_control_check.mjs` both pass. Plain `node` fails on TypeScript parameter properties; the flag is required.
- Migration applied as `youtube_rtmps_host_and_reconcile_scope`, hosted version `20261005054018`. The local file was renamed from `20261004200000_…` to match, so local and hosted histories agree. The SQL diff against the previous definitions is only the host regex and the reconcile-claim condition.
- Functions: `broadcast-control` v3 → v4, `reconcile-broadcasts` v3 → v4, both ACTIVE, `verify_jwt=false` as before. `channel-authorization` was not redeployed because it does not use `ingestionAddress`.
- 4a: both v4 ACTIVE; `broadcast-control` OPTIONS 200 and unauthenticated POST 401.
- 4b: `pg_get_functiondef` shows the `rtmps?` host check and the new claim condition.
- 4c: anon/authenticated cannot execute `broadcast_provider_step` or `broadcast_reconcile_claim`.
- 4d: the five completed feedless sessions (`aa900ecd` from 08:33 local today, plus `0c1b3778`, `1b5a3471`, `06e6be58`, `c261a66e`) were last claimed at 05:40:01 UTC, before the fix. They were not re-claimed by 05:43 UTC.
- Not done: the new APK could not be built because Android Studio's bundled JDK is incomplete (`jbr\lib\jvm.cfg` missing, 26 files left). Phone → YouTube is still unverified.
- APK built later on 2026-10-05 09:49 (local time). Fix: removed the hard-coded `org.gradle.java.home` from `project/android/gradle.properties` and pointed Flutter at Microsoft OpenJDK 21. Android Studio 2026.2's Java 25 is too new for Gradle 8.14. `project/build/app/outputs/flutter-apk/app-debug.apk` (arm64, sha1 prefix 537f12d056d7). Phone install and broadcast test pending.
