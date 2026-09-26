# Independent verification record

Executed in `.claude/worktrees/p6s-astra-audit`. App source tip `6c0e7c9`; SQL fixes `ecc992b` and `f83c8dd`. Evidence-only files and the standalone backend probe were added afterward. No result below is copied from an Opus run.

Tools used: Flutter 3.41.2, Dart 3.11.0 on Windows x64, Node 22.19.0, Supabase CLI 2.115.0, PostgreSQL major 17. Docker reported server 29.6.2 during the final probe. The SQL database was the new project `P6S_astra_20260926`, container `supabase_db_P6S_astra_20260926`, API `127.0.0.1:55811`, database port `55812`. Existing Opus/P6 stacks were not reset or removed.

## Evidence levels

- E1: source, migrations, permission checks, native bridge, catalogs and plan inspection.
- E2: deterministic Flutter/SQL/JavaScript regressions, static analysis, repository gates and builds. Mocks prove a contract, not physical delivery.
- E3: separate psql processes, authenticated REST/Realtime clients against a running disposable stack, and the real Chrome adapter probe.
- E4: physical Android sender/viewer and real external-encoder acceptance. **Not run by this audit.** Use E4_RETEST_SCRIPT.md.

## Commands and outcomes

Flutter commands ran from `project/`, using `C:/Users/User/sru/flutter/bin/flutter.bat`. No command used `dart_define.local.json` or another production configuration.

| Command / check | Independent outcome | Saved evidence |
|---|---|---|
| `flutter pub get --offline` | Sandbox attempt hung with no output and was stopped. Approved local retry succeeded using cached dependencies. No dependency upgrade requested. | Runtime pub-get logs; this failed attempt is not a pass. |
| `flutter analyze --no-pub` | **0 issues**, 20.2 s on final app source. Earlier lint failures were corrected. | `flutter-analyze.txt` |
| `flutter test --no-pub --concurrency=1 --reporter expanded` | **695 passed**, 5m21s. No E4 claimed. | `flutter-tests.txt`, `flutter-full-log-hash.json`; full output remains in audit worktree `brief/.runtime/p6s-astra/flutter-serial.log`. |
| `node brief/tools/gates.mjs --json` | **26 PASS, 5 INFO, no failing mandatory gate** in isolated audit source. Final evidence scan repeated before integration. | `gates.json` |
| `supabase db reset --workdir brief/.runtime/p6s-astra --local` | Applied complete historical migration chain plus both repair migrations to the fresh disposable stack. | Runtime `reset.log`; SQL suite below validates resulting schema. |
| `supabase test db --workdir brief/.runtime/p6s-astra --local` | **21 files, 440 assertions, PASS**. | `sql-suite.txt` |
| `node brief/tools/broadcast_session_concurrency.mjs <docker-executable>` | **3/3 interleavings pass** after fresh reset. Old End fails before repair with different and same watch IDs; expiry also fails before its repair. | `race-before.txt`, `race-after.txt`, `sweep-before.txt`, `concurrency-final.txt` |
| Identity pgTAP cases before/after repair | Wrong org affiliation and unrelated account termination reproduced before repair; all **7 boundary assertions pass** afterward and are included in the full 440. | `identity-before.txt`, `identity-after.txt` |
| `dart --packages=project/.dart_tool/package_config.json brief/tools/p6s_backend_probe.dart` from audit root | Final warm run **19/19 PASS**. Cold restart run **18 PASS / 1 FAIL**, owner event absent at 10 s; direct reads and all state/permission checks passed. Cause not proven. Warm repeat used unchanged code and observed owner event at 23 ms. | `backend-probe.txt`, `backend-probe-cold-start.txt` |
| `P6S_EMBED_EXPORT` set for `youtube_embed_page_test.dart`, then `node brief/tools/youtube_embed_runtime.test.mjs brief/.runtime/p6s-astra/embed.html` | PASS: exact player identity, pre-ready refusal, delivery versus state, mute reporting, errors and command allowlist. Executed actual generated script with SDK stub. | `embed-runtime.txt` |
| `flutter run --no-pub -d web-server -t tool/p6s_browser_probe.dart --web-hostname 127.0.0.1 --web-port 55890` | Real Chrome reproduced/retested loading-cover defect, exact watch URL and responsive embedded Play control. No backend credentials. Temporary server/tab closed. | `BROWSER_PROBE.md` |
| `flutter build apk --debug --no-pub` | PASS. Initial build took 148.3 s; final audited-source repeat took 58.5 s. No installation or physical run. | `android-build.txt`, `android-initial-build.txt`, `build-hashes.json` |
| `flutter build web --no-pub` | PASS, 100.6 s; Wasm dry run succeeded. No deployment. | `web-build.txt` |
| `git diff --check` | PASS for audit changes. Generated Windows plugin files showed line-ending/stat dirt with no semantic diff and were not committed. | Git checkpoint in integration record. |

The web build warns about a referenced CupertinoIcons font not included in the font set. Android emits Java 8 source/target deprecation warnings. Neither is counted as a failure or as proof of runtime compatibility. They remain lower-priority build/UI debt outside these streaming fixes.

Saved console text has trailing alignment whitespace removed; values and results are unchanged. The initial captured-output whitespace check failed, was corrected in the evidence files, and the complete branch diff then passed `git diff --check`. Original runtime logs remain in the audit worktree.

Gate INFO review: G2c=0 color exceptions; G10b=2 intentional deny-all tables (`stream_viewers`, `removed_live_streams`); G10e=3 anonymous public helpers reviewed in REPORT.md; G11c=0 unexpected-role token shapes; G11g is a skipped historical secret scan. This is not a P0/P9 history or signed-release-artifact secret audit. Main-checkout pre-existing ignored credential-shaped files were not imported, opened as configuration, removed or committed; clean audit-source gate results must not be described as sanitizing that checkout.

## Failed or interrupted attempts retained as limitations

The first full test run had 694 passing tests and one failure in the newly added missing-RPC test fixture. Its mocked HTTP error lacked request metadata required by the installed PostgREST client. After adding that metadata, the focused test and complete 695-test run passed. Initial focused player tests also expected the old optimistic UI and were changed to emit actual fake-player confirmations; a separate test proves dispatch without confirmation does not change state.

A subsequent parallel full-suite attempt terminated with PowerShell “Out of memory” before completion, while builds/browser verification were also active. It was **not** counted as a pass. The orphan worker was identified by the audit worktree path and stopped. The disposable audit stack was stopped with backup, builds completed, and the full suite then passed with one worker. There is no claim that this machine reliably supports the previous concurrent workload.

An initial extension to the backend probe used an invalid sender-mode argument and treated any error as a successful block. That assertion was not adequate. Before final evidence, it was corrected to `obs_laptop` and required exactly `42501 / Stream removed by moderation`. Random watch IDs now prevent one run's moderation record from contaminating another, and cleanup removes its own synthetic users/block entry. The corrected assertion passed in both final cold and warm runs. Only the corrected transcripts are supplied as final evidence.

The cold-start Realtime miss remains visible in the report and score. The prior project issue about restarting Realtime/Kong involved join timeouts; this run joined successfully, so that suspected cause was not asserted and containers were not speculatively reconfigured. Existing app recovery performs a catalog read after transfer and checks remote End on the broadcaster heartbeat. Physical latency/failure recovery remains E4.

When work resumed, Docker was stopped and the first local-stack restart failed because its named pipe was absent. Starting the existing Docker Desktop runtime recovered it. No prior SQL result was substituted for this probe retry.

## Reproduce the local database evidence

`local-stack.toml` is the tested local-only configuration, with no embedded credentials. From the audit root, create `brief/.runtime/p6s-astra/supabase`, copy that file to `config.toml`, and copy the repository's `supabase/migrations` and `supabase/tests` into that runtime Supabase directory. Do not copy linked-project metadata or any define file. The runtime location is gitignored.

Set `DO_NOT_TRACK=1`, then use the installed Supabase CLI:

```powershell
supabase start --workdir brief/.runtime/p6s-astra --exclude studio,pgadmin-schema-diff,migra,postgres-meta,logflare,vector,imgproxy,edge-runtime,supavisor,inbucket
supabase db reset --workdir brief/.runtime/p6s-astra --local
supabase test db --workdir brief/.runtime/p6s-astra --local
node brief/tools/broadcast_session_concurrency.mjs 'C:/Users/User/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe'
dart --packages=project/.dart_tool/package_config.json brief/tools/p6s_backend_probe.dart
supabase stop --workdir brief/.runtime/p6s-astra
```

On this workstation the installed CLI is `C:/Users/User/Documents/Amir Ob/projects/Ideas/Current/Streamer_app/node_modules/.bin/supabase.cmd`. The probes deliberately pin the audit container/API port; they reject a non-loopback API. The backend probe fetches local service/anon credentials at runtime from CLI status and does not print or persist them. Capture start/status output only in the ignored runtime folder, since CLI status includes local credentials.

The audit stack was stopped with its backup retained after verification. Docker Desktop was left available; other project stacks and data were not removed. The source merge requires no running database and applies no migration.

## Fix commits

| Commit | Scope |
|---|---|
| `ecc992b` | End read after common lock; separate-connection regression. |
| `f83c8dd` | Expiry/ingest lock order; organization/device session identity; scoped org revocation and SQL regressions. |
| `f677f32` | Fail-closed watch validation and session RPC compatibility; stale client response fencing; bilingual errors/tests. |
| `5b59f7c` | End above portrait keyboard; ignore post-stop native connection callbacks; remote-End/ingest tests. |
| `6c0e7c9` | Official YouTube readiness/state flow, truthful controls/fallback, web reload/input repairs and regression probes. |

The later evidence/probe commit and final local integration commit are listed in INTEGRATION.md. E4 and D1–D8 remain pending independently of these commits.
