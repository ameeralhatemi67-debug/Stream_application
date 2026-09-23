# Review packet: `20260923130000_audit_chat_keyword_changes.sql` (and follow-up `20260923140000`)

For the owner's production decision. Reviewed 2026-09-23 by Claude Opus 5.5 against the migration chain in `master` (`f581329`). Catalog facts below came from a fresh disposable local stack, `P6_accept_disposable`. Nothing was applied to a linked or production project.

## Recommendation

**Apply `20260923130000` together with the new `20260923140000`, never `130000` alone.** On its own, `130000` is correct. However, API roles still hold TRUNCATE on the keyword table and on `audit_logs`, which predates this migration. TRUNCATE is not covered by RLS or by row triggers, so the keyword audit's promise that every change is recorded would have a hole. `140000` closes it. Before pushing, run the pre-push check below against production.

## What `130000` does

1. It widens `audit_logs_action_check` by exactly three actions: `chatKeywordAdded`, `chatKeywordUpdated` and `chatKeywordRemoved`. It keeps the existing predicate text as returned by `pg_get_constraintdef`.
2. It redefines the public `log_audit_event` so those three, plus the five existing server-only actions, cannot be forged by clients (42501). Grants are restated.
3. It adds `audit_chat_keyword_change()`, a SECURITY DEFINER function owned by `postgres` with `search_path=''`, and an AFTER INSERT/UPDATE/DELETE row trigger on `chat_banned_keywords`.

## Findings

| # | Area | Finding | Verdict |
|---|------|---------|---------|
| 1 | Actor attribution | API writes carry `auth.uid()` and go through `log_audit_event_internal`, which stamps actor id, email and name from `profiles`. Verified with real sessions: `appFlagChanged` and `streamForceEnded` rows name *Master Admin P6*. The keyword path uses the same writer. | OK |
| 2 | Writes with no `auth.uid()` | Recorded as actor `system` / "Server maintenance". These can come only from privileged database roles (migrations, `service_role`, SQL editor or Studio). **Studio or SQL-editor keyword edits by a person show as `system`, not as the person.** | Accept; owner should know |
| 3 | Banned or removed admins | `is_admin_tier()` does not check bans, so a banned admin passes the keyword RLS policies. However, `log_audit_event_internal` raises for banned callers, which rolls the keyword write back. The net effect is that banned admins cannot change keywords, which is correct but only a side effect. | OK (side effect; see note) |
| 4 | Permissions | Trigger function execute is revoked from public, anon, authenticated and service_role (checked). `log_audit_event_internal` is not executable by any API role (checked). Keyword metadata, including the keyword text, is readable only through `audit_logs_select_admin` (`is_admin_tier()`), the same audience as the keyword list itself. | OK |
| 5 | Rollback | The trigger is AFTER ROW in the same transaction, so an audit failure aborts the keyword statement. Tested: `audit failure rejects keyword add` and `keyword not stored without audit`. The whole migration is one `begin … commit`; any failure, such as a missing constraint, aborts cleanly. | OK |
| 6 | Constraint rewrite | The `do $$` block builds the new CHECK from `substr(pg_get_constraintdef(...), 8, len-8)`. That assumes the definition is exactly `CHECK (…)`. If production's constraint were `NOT VALID` or had drifted, the string would be malformed and the migration would **fail and roll back**; it cannot silently corrupt. The new constraint is validated against every `audit_logs` row, with a brief ACCESS EXCLUSIVE lock and a full scan (small table today). The predicate nests one more `OR` per migration, which is cosmetic. | OK with pre-push check |
| 7 | **TRUNCATE gap (pre-existing)** | `anon` and `authenticated` hold TRUNCATE, TRIGGER and REFERENCES on **27 of 29** public tables, including `chat_banned_keywords` and `audit_logs`. These are Supabase default grants; `20260921110000` narrowed only SELECT, INSERT, UPDATE and DELETE, and catalog test R3c checks only those. TRUNCATE ignores RLS and fires no row trigger. PostgREST and pg_graphql expose no TRUNCATE or DDL, so **no API exploit is known**, but a TRUNCATE would bypass both the admin-only policies and the audit. | **Fixed by `20260923140000`** |
| 8 | Operational | An UPDATE that changes nothing still writes a `chatKeywordUpdated` row. Bulk deletes write one row per keyword. | Accept |
| 9 | Ordering and dependencies | Requires `log_audit_event_internal` (`110000`), `match_mode` (`20260921120000`) and the `appFlagChanged` constraint (`120000`). All precede `130000`. | OK |

Note on #3: `is_admin_tier()` ignoring bans is a wider, pre-existing policy question for every admin-tier RLS policy, not only keywords. I recorded it and did not change it here.

## Follow-up migration `20260923140000_revoke_api_truncate_trigger_references.sql`

- `revoke truncate, trigger, references on all tables in schema public from anon, authenticated`, plus `alter default privileges for role postgres …` so later tables don't regain them.
- A statement-level AFTER TRUNCATE trigger on `chat_banned_keywords` that writes one `chatKeywordRemoved` row, `{truncate: true, db_role}`, for the privileged truncate that remains possible.
- Tests: `rls_catalog.test.sql` gains **R3d**, which checks that no API role holds any of the three privileges on any table, and `chat_keyword_audit.test.sql` gains two denials (admin API-role truncate of the blocklist and of `audit_logs`) plus the privileged-truncate audit.
- Risk: API roles never need these privileges; realtime, storage and PostgREST don't use them. `alter default privileges` affects only objects later created by `postgres`.

## Pre-push checks for production (owner)

Run these as read-only queries in the production SQL editor before `db push`:

```sql
-- 1. Constraint is the expected validated CHECK (convalidated must be true)
select convalidated, left(pg_get_constraintdef(oid), 7) from pg_constraint where conname = 'audit_logs_action_check';
-- expected: t | CHECK (

-- 2. Every existing action is already allowed (must return 0 rows)
select distinct action from public.audit_logs
 where action not in (select unnest(regexp_matches(pg_get_constraintdef(c.oid), '''([A-Za-z]+)''', 'g'))
                      from pg_constraint c where conname = 'audit_logs_action_check');

-- 3. Size, to judge lock time
select count(*) from public.audit_logs;
```

Then apply `20260923130000` and `20260923140000` in the same push.
