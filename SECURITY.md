# Security and release evidence

The app receives only the public Supabase URL and anon key through the ignored
`project/dart_define.local.json`. RLS and server authorization must protect every
operation. An anon key is not a substitute for access control. Never put a
privileged backend key, database password or Android signing material in the app,
source, logs, tests, documentation or build output.

Environment files, local build defines and signing files are ignored. Keep
examples value-free. Stage explicit paths and review staged filenames before
committing. If a credential is exposed, revoke/rotate it at its provider, replace
it in the owner's secure configuration, and inspect access logs. Deleting a file
or rewriting history does not invalidate an exposed credential.

Run the count-only scan from the repository root:

```text
node brief/tools/gates.mjs --history
node brief/tools/scan_build_secrets.mjs <release-aab-path>
```

The first command scans source/history and ignore coverage. The second must run
against the actual release AAB; source scans alone do not prove a clean build.
G11a-g must be zero before release. No release AAB has been verified in this run.

Database changes are new migrations. Validate them on local Supabase with the
SQL tests in `supabase/tests/` before owner review and production application.
SQL tests impersonate roles inside a rollback transaction and need no saved API
keys. If later HTTP probes need local credentials, obtain them in memory at run
time from local Supabase status; never echo them or save them to fixtures.

P1 is incomplete. Column and storage guards have local test scripts, but their
runtime database behavior is UNVERIFIED-STATIC until those scripts execute.
Live-state RPCs, device enforcement and the remaining P1 controls must be
completed before this app is described as release-ready. Owner-only actions are
listed in `brief/OWNER_ACTIONS.md`.
