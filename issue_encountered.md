# Issues encountered during P6.4 item 1 verification

Updated: 2026-09-23. This is a local troubleshooting record, not proof that the database tests passed.

## Issue-name index — scan this list first

Agents: when investigating an error, scan only these short names for a match. If one matches, read that entry's section; do not reread the whole file by default. When you fix a new issue, append a concise entry under a clear heading and add its short, searchable error name here. Record the fix and how it was verified; label it `UNVERIFIED` if runtime confirmation is pending. Do not mark an unresolved issue fixed, and update an existing entry instead of creating a duplicate.

- **Docker Inference manager `dockerInference` socket bind collision** — currently operational; earlier root cause unresolved.
- **Supabase CLI telemetry temp-file `EPERM`** — workaround: `DO_NOT_TRACK=1`.
- **Git `.git/index.lock` access denied** — resolved by approved staging outside the sandbox.
- **`device_sessions` SELECT permission denied for `is_banned(uuid)`** — FIXED; disposable local SQL suite passed.
- **Malformed single-dollar pgTAP quoting in `admin_user_directory.test.sql`** — FIXED; all 33 assertions passed locally.

## Recording format

Use one entry per distinct root cause. Keep it searchable and actionable:

```text
## <Simple error name>
Status: FIXED | UNRESOLVED | UNVERIFIED
Observed: exact error or symptom, plus platform/tool/version when relevant.
Cause: confirmed root cause; say “suspected” if not confirmed.
Fix/workaround: concrete change or safe recovery steps.
Verification: command/scenario and result; state what was not verified.
Evidence: relevant local path or link, if available.
```

Add resolved issues to the index using the same simple error name. Keep the index brief; details belong in the matching section below. Never record secrets, tokens, private keys, or credentials.

## Docker Inference manager `dockerInference` socket bind collision

Status: **UNRESOLVED ROOT CAUSE; CURRENTLY OPERATIONAL**.

Docker is installed at `C:\Users\User\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe`, but that directory is not on the shell PATH. Use the full path to invoke the installed CLI. The first sandboxed invocation failed with `Access is denied`; an approved unsandboxed read was able to run the CLI.

The CLI reported client version 29.6.2, but no server. The local Linux engine pipe `npipe:////./pipe/dockerDesktopLinuxEngine` did not exist. `docker desktop start` launched Docker Desktop processes, but the command did not return promptly and the engine remained unavailable.

Docker Desktop displayed this error:

> Docker Desktop encountered an unexpected error and needs to close.
> Search our [troubleshooting documentation](https://docs.docker.com/desktop/troubleshoot/overview/?utm_source=docker_desktop_error_dialog) to find a solution or workaround. Alternatively, you can gather a diagnostics report and submit a support request or GitHub issue.
> starting services: initializing Inference manager: listening on unix://C:/Users/User/AppData/Local/Docker/run/dockerInference: listen unix C:/Users/User/AppData/Local/Docker/run/dockerInference: bind: Only one usage of each socket address (protocol/network address/port) is normally permitted. (listener: The filename, directory name, or volume label syntax is incorrect.)

`C:\Users\User\AppData\Local\Docker\backend.error.json` recorded the same inference-manager socket bind failure on both start attempts. `wsl --list --verbose` showed `docker-desktop` stopped. The supported `docker desktop stop --force --timeout 30` stopped the failed startup. The supported `docker desktop disable model-runner` failed because `dockerBackendApiServer` was unavailable. I backed up `%APPDATA%\Docker\settings-store.json` to `%APPDATA%\Docker\settings-store.p64-backup.json`, changed only `EnableDockerAI` from `true` to `false`, and retried `docker desktop start --timeout 60`. It still failed with the same inference socket error. I force-stopped Desktop and restored the exact original settings file from the backup; `EnableDockerAI` is again `true`. No Docker volumes, containers, or run-socket files were deleted. The visible `%LOCALAPPDATA%\Docker\run` directory had no `dockerInference` file after stop. **Unresolved as of this entry.**

The earlier local-only command `npx --no-install supabase test db --local supabase/tests/admin_user_directory.test.sql supabase/tests/broadcast_sessions.test.sql supabase/tests/application_and_ban_guards.test.sql supabase/tests/rls_catalog.test.sql` failed before any assertion with `ECONNREFUSED 127.0.0.1:54322`. No migration reset or local test run occurred in that session. The required database run succeeded in the follow-up below. Do not use `--linked` or production credentials to work around a local failure.

2026-09-23 follow-up: the user reported Docker Desktop running. The installed CLI returned both client and server version `29.6.2`. A fresh disposable Supabase project (`P64_item1_disposable`) started and completed its migration chain, and the local SQL suite passed. The earlier socket collision did not recur. This confirms usable tooling now; it does not identify which external action repaired Docker Desktop.

## Supabase CLI telemetry permission

Status: **WORKAROUND VERIFIED** (`DO_NOT_TRACK=1` permits the version query); normal telemetry write remains permission-blocked in the sandbox.

`npx supabase --version` initially failed because its telemetry writer could not create `C:\Users\User\.supabase\telemetry.json.tmp...` inside the sandbox (`EPERM`). Setting `DO_NOT_TRACK=1` allowed `npx --no-install supabase --version` to return `2.115.0`. An approved unsandboxed `npx --no-install supabase status` then reached its local Docker health check but failed because the Docker engine pipe was unavailable. The status command printed linked-project metadata; it did not access or modify the linked project.

## Git index permission

Status: **RESOLVED FOR THAT CHECKPOINT** (explicit-path staging succeeded in an approved unsandboxed call).

The sandbox could read Git state but could not create `.git/index.lock` for staging. An approved unsandboxed `git add` using the exact changed `brief/` paths succeeded. A first retry with `-c core.excludesfile=NUL` failed because Git rejected `NUL` as an exclude file; removing that override resolved the staging command. The documentation checkpoint was committed as `d659b95` before any SQL edits.

## SQL defects found in prior verification

Status: **FIXED AND VERIFIED ON A DISPOSABLE LOCAL DATABASE**.

### `device_sessions` SELECT permission denied for `is_banned(uuid)`

The 2026-09-22 verification report recorded that `device_sessions_select_admin` called the revoked `is_banned(uuid)` function directly in an RLS policy. An authenticated SELECT raised `permission denied for function is_banned`, including ordinary users reading their own devices. The new `20260923100000_admin_device_sessions_read_guard.sql` migration replaces the own and admin SELECT policies with the client-callable `is_current_user_banned()` check. On the disposable project, `supabase test db --local` passed the directory file (33 assertions), the four targeted files (86 assertions), and the complete 12-file SQL suite (212 assertions). The directory file checks own-row access, admin cross-account reads, and banned-admin denial.

### Malformed single-dollar pgTAP quoting in `admin_user_directory.test.sql`

Five assertions in `supabase/tests/admin_user_directory.test.sql` used malformed single-dollar strings. They now use `$$...$$`. The expanded file has 33 pgTAP calls, matching `plan(33)`, and covers authorization, self/Master Admin protection, ban, revocation, and audit cases. Its full `finish()` run passed on the disposable local database: `Files=1, Tests=33, Result: PASS`.
