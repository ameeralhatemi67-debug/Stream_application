# RLS access matrix (P1.10)

Read back from the live `pg_policies` / `pg_class` / `information_schema`
catalog of a local Supabase stack with the whole migration chain applied, as of
`20260921110000_table_grants_and_audit_scope.sql`.

**Evidence tier: E2 (verified against a live catalog), 2026-09-21.** Docker was
available for the first time in this run, and the migration chain was made
applyable (see "The chain could not apply" below). Evidence:

| Check | Command | Result |
|---|---|---|
| Migrations | `npx supabase db reset --local` | all 45 apply, exit 0 |
| Behaviour + catalog probes | `npx supabase test db --local` | 9 files, **125 tests, all pass**, exit 0 |
| Linter | `npx supabase db advisors --local --type security` | 2 ERRORs, both the documented `security_definer_view` exceptions; nothing else |
| Static gates | `node brief/tools/gates.mjs` | G10a/c/d = 0, G11a-f = 0; G10b = `stream_viewers` only; G10e = the 3 documented anon `execute` grants |

Nothing was run against the linked production project.

## The chain could not apply (found 2026-09-21)

Every earlier session recorded this schema as `UNVERIFIED-STATIC` and blamed a
missing Docker. Docker was not the only blocker. With Docker available, the
chain still aborted twice, and both faults were invisible to a static read:

1. `20260830180000_map_visibility_toggle.sql` re-adds `latitude, longitude` to
   `streamer_public_profiles` in the **middle** of the select list using
   `create or replace view`, which PostgreSQL refuses (`42P16`: it may only
   append columns). Nothing after this migration had ever been applied to any
   database -- including the whole `20260831*` and `20260920*` set. Repaired by
   `20260830175000_realign_streamer_public_view.sql`, which re-establishes the
   view in the column order that migration expects.
2. `20260920140000_policy_quality.sql` revoked and granted
   `chat_sender_info(uuid[])`, a signature `20260830160000` had already dropped
   in favour of `chat_sender_info(uuid[], text default null)`. `42883`. The two
   dead statements were removed from that migration -- the only edit made to an
   existing migration file in this run, and safe because the migration provably
   could never have applied anywhere.

**Table privileges were missing everywhere.** Once the chain ran, 7 of 8 pgTAP
files died on `42501 permission denied for table ...` against tables whose
policies were correct. Only four objects had ever been granted to `anon` /
`authenticated`. Table privileges are checked *before* RLS, so all 110 policies
were unreachable and an app built from these migrations alone could not read or
write anything. `20260921110000` grants the minimal set, and R10/R11 in
`rls_catalog.test.sql` now assert privileges and policies agree in both
directions. See `brief/OWNER_ACTIONS.md` -- the production project predates the
CLI's `auto_expose_new_tables` default change, so this was latent, not a live
outage.

Columns are the four commands (**S**elect / **I**nsert / **U**pdate /
**D**elete). Actors:

| Actor | Meaning |
|---|---|
| anon | not signed in (PostgREST `anon` role) |
| viewer | signed in, no streamer/org/admin role |
| owner | the row's own subject (`auth.uid()` matches the row) |
| org | owner or member of the organization the row belongs to |
| admin | `is_admin_tier()` — Admin or Master Admin |
| master | `is_master_admin()` only |

`—` = denied. A cell that names an actor means only that actor.
Every write on `profiles`, `broadcaster_applications`, `affiliation_requests`,
`chat_messages`, `streamer_custom_placeholders` and the `streamer-assets`
bucket additionally passes the **restrictive** `*_not_banned` policies from
`20260920093000_enforce_bans_on_writes.sql`: a banned account is refused
regardless of any permissive policy below.

## Tables

| Table | S | I | U | D | Notes |
|---|---|---|---|---|---|
| profiles | owner, admin | owner | owner, admin | — | PII columns restricted by `20260822140000`; privileged columns forced by the `guard_broadcaster_columns` trigger; anon reads go through `streamer_public_profiles` only. |
| organizations | org, admin | admin | org owner, admin | — | anon reads go through `organization_public_profiles`. |
| org_venues | org, admin | org owner, admin | org owner, admin | org owner, admin | Split per command in `20260921100000`. |
| org_speakers | org, admin | org owner, admin | org owner, admin | org owner, admin | Split per command in `20260921100000`; P7 revisits roles/permissions here. |
| affiliation_requests | party | party | party | party | "party" = requester or the target org's owner; transition rules enforced by `guard_affiliation_transition` (P1.4), not by the policy alone. |
| broadcaster_applications | owner, admin | owner | owner (pending only), admin | owner, admin | `guard_application_review` forces `status='pending'` and nulls review fields on client writes. |
| user_roles | owner, admin | master; admin only for `org_owner`/`org_co_owner` | same | same | Split per command in `20260920140000`; `granted_by` must equal the acting admin. `org_owner` is auto-derived by `sync_org_owner_role` (ADR-007). |
| user_permissions | owner, admin | master | master | master | Split per command in `20260920140000`. |
| banned_users | owner, admin | admin | admin | admin | Delete = unban. Split per command in `20260920140000`. |
| device_sessions | owner | — | — | — | Writes are RPC-only since `20260920120000` dropped `device_sessions_write_own`: `claim_broadcaster_device`, `device_heartbeat`, `release_broadcaster_device`. |
| chat_messages | anon, viewer | owner | owner | owner, stream owner/moderator, admin | Rate limit, slow mode and chat-off enforced server-side by the `chat_enforce_rate_limit` trigger (P6.1), verified by `chat_rate_limit.test.sql`. |
| chat_reports | admin | viewer (own report) | — | admin | Reporter cannot read the queue back. |
| chat_muted_users | stream owner, admin | stream owner, admin | — | stream owner, admin | Delete = unmute. |
| chat_mute_audit_log | admin/moderator scope | own action rows | — | — | Append-only by design. |
| chat_banned_keywords | admin | admin | admin | admin | Split per command in `20260921100000`. The `for all` policy had been the only SELECT path too, so the split restates the admin read explicitly. |
| stream_moderators | relevant (stream owner, the moderator, admin) | stream owner, admin | stream owner, admin | stream owner, admin | Split per command in `20260921100000`, preserving the asymmetry of the original `for all` (loose `using`, strict `with check`). |
| streamer_custom_placeholders | anon+viewer (approved only), owner, admin | owner | admin | owner, admin | The real custom-card feature (01 invariants): kept. Only admins may change status, so a streamer cannot self-approve artwork. |
| audit_logs | admin | — (RPC only) | — | — | Written only through `log_audit_event()`, which refuses unauthenticated callers, banned accounts, and (since `20260921110000`) an organization the caller neither belongs to nor administers. No INSERT privilege is granted either. |
| platform_analytics | admin | admin | admin | admin | Split per command in `20260921100000`. |
| academic_categories | anon, viewer | admin | admin | admin | Public taxonomy read. |
| tags | anon+viewer (approved only), admin | viewer (pending only) | admin | admin | |
| terms_and_conditions | anon, viewer | admin | admin | admin | Public legal text: the one table whose SELECT policy names `anon` explicitly. Writes split per command in `20260921100000`. |
| follows | owner | owner | — | owner | Own-row only (D-07); no admin read path. A follow is created or deleted, never updated. |
| bookmarks | owner | owner | — | owner | Own-row only (D-07); `vod_id`/`streamer_id` are text because a VOD id comes from YouTube, not from this schema. |
| chat_stream_settings | anon, viewer | stream owner/moderator, admin | stream owner/moderator, admin | stream owner/moderator, admin | P6.1. Everyone who can read the chat can see that chat is off; only `chat_can_moderate()` may change it. Absent row = chat on, no slow mode. |
| stream_viewers | — | — | — | — | **Deny-all**: RLS on, no policy, nothing granted. Presence is written only by `viewer_heartbeat()` and read only by `get_viewer_counts()` (P3 / D-08). The intent is recorded in `comment on table`. |
| storage.objects (`streamer-assets`) | public bucket read (`to anon, authenticated`) | owner path / org owner, admin | same | same | Path scoping by `can_write_streamer_asset()` (P1.3). The read policy gained its explicit role clause and a consistent name (`streamer_assets_select_public`) in `20260921100000`. |

`stream_viewers` is the one deny-all table (RLS on, zero policies), which is
its whole design: presence rows are reachable only through the two SECURITY
DEFINER functions, and the table carries a `comment on table` saying so. Gate
G10b lists it by name, as that gate's own text anticipated.

## Views

Both views run with `security_invoker = false` on purpose and are the only
anon-readable path to profile/organization data. The justification now lives on
the views themselves (`comment on view`, `20260920140000`):
`streamer_public_profiles`, `organization_public_profiles`. Neither may ever
gain a PII column. These are the only two findings `npx supabase db advisors
--local --type security` reports (`security_definer_view`, level ERROR), and R4
asserts that any such view carries a justifying comment. Note open item 5:
`streamer_public_profiles` currently carries exact coordinates, which is a PII
question the comment does not settle.

## Functions

| Function | Security | anon | authenticated |
|---|---|---|---|
| `is_admin_tier`, `is_master_admin`, `has_permission`, `owns_organization`, `is_org_member`, `owns_stream`, `chat_can_moderate`, `chat_is_muted`, `is_current_user_banned` | definer | — | execute |
| `chat_sender_info(uuid[])`, `chat_sender_info(uuid[], text)` | definer | execute | execute | Guests must see sender names/badges in public chat. |
| `can_broadcast`, `claim_broadcaster_device`, `device_heartbeat`, `set_live_state`, `release_broadcaster_device`, `sweep_stale_live_flags`, `log_audit_event`, `delete_own_account`, `can_write_streamer_asset` | definer | — | execute |
| `is_banned(uuid)` | definer | — | — | Called only from other definer functions; a per-uuid ban probe is not exposed to clients. |
| `viewer_heartbeat(text,text)`, `get_viewer_counts(text[])` | definer | execute | execute | The two deliberate anon exceptions D-21 names: guests watch streams and are counted. `viewer_heartbeat` refuses a stream that is not live, keys signed-in viewers by user id whatever the client sends, and refuses the broadcaster's own account. |
| `chat_enforce_rate_limit` | invoker, trigger, `search_path=''` | — | — | SECURITY INVOKER on purpose (D-21): `current_user` still separates an ordinary API write from a trusted owner-executed RPC, so server-side tooling is not rate limited. Enforces the 1.2 s floor, slow mode, the 30/minute ceiling and "chat off". `search_path` pinned in `20260921110000` so the enforcement cannot be neutered by resolving `chat_stream_settings` or `chat_can_moderate` through another schema. |
| `set_updated_at` (`search_path=''` since `20260921110000`), `bootstrap_admin_role`, `chat_check_banned_keywords`, `sync_org_owner_role`, `handle_profile_before_delete`, `supersede_prior_approved_placeholder`, `guard_broadcaster_columns`, `guard_application_review`, `guard_affiliation_transition` | definer, trigger | — | — | Revoked from every client role. |

## Realtime publication

`supabase_realtime` carries: `chat_messages`, `broadcaster_applications`,
`profiles`, `academic_categories`, `tags`, `banned_users`, `device_sessions`.
Realtime respects RLS, so each subscriber sees only rows its policies allow.
`chat_reports` is **not** published — the admin moderation queue polls; P6.3
decides whether to publish it or keep polling.

## Data API exposure

`supabase/config.toml` exposes `["public", "graphql_public"]` only. No other
schema is reachable through PostgREST.

## Table privileges (added 2026-09-21)

RLS narrows rows; the table privilege decides whether the request is considered
at all. `20260921110000` grants, per table, only the commands that have a
permissive policy, to only the roles those policies address:

| Grant | Tables |
|---|---|
| `select` to `anon, authenticated` | `academic_categories`, `tags`, `terms_and_conditions`, `chat_messages`, `chat_stream_settings`, `streamer_custom_placeholders`, plus the two public views (granted earlier) |
| `select, insert, update` to `authenticated` | `profiles` (no DELETE: erasure goes through `delete_own_account()`), `organizations`, `affiliation_requests` (no DELETE: cancelled by status) |
| `select, insert, update, delete` to `authenticated` | `org_venues`, `org_speakers`, `broadcaster_applications`, `platform_analytics`, `user_roles`, `user_permissions`, `banned_users`, `chat_messages`, `chat_banned_keywords`, `chat_stream_settings`, `stream_moderators`, `streamer_custom_placeholders`, `tags`, `terms_and_conditions` |
| `select, insert, delete` to `authenticated` | `follows`, `bookmarks`, `chat_reports`, `chat_muted_users` |
| `select, insert` to `authenticated` | `chat_mute_audit_log` (append-only) |
| `select` only to `authenticated` | `audit_logs` (RPC-only writes), `device_sessions` (RPC-only writes) |
| nothing | `stream_viewers` — `revoke all`, reinforcing the deny-all design |

`anon` holds no INSERT/UPDATE/DELETE on any table (asserted by R3c). The one
place an anonymous caller writes is `viewer_heartbeat()`, a SECURITY DEFINER
function writing to the deny-all `stream_viewers` table.

## Open items

1. ~~Seven tables still use one `for all` write policy~~ — **done**
   (`20260921100000`). No permissive policy in `public` uses `for all` any more;
   R6b asserts it.
2. ~~Policies created before `20260920` mostly omit `to authenticated`~~ —
   **done** (`20260921100000`). All 32 were dropped and recreated with an
   explicit role clause, predicates copied from the live catalog and
   `auth.uid()` rewritten as `(select auth.uid())`. No policy in `public` is
   addressed to PUBLIC any more; R6a asserts it. `terms_select_public` and
   `streamer_assets_select_public` are the two that deliberately name `anon`.
3. `log_audit_event()` — **partly done**. It no longer accepts an organization
   the caller is unrelated to: `20260921110000` refuses unless the organization
   is null (a platform-level event), the caller `is_org_member()`, or the caller
   is admin-tier. The richer per-capability organization authorization model is
   still **NOT DONE** and belongs to P7.
4. `banned_users` is in the realtime publication and its select policy allows
   `profile_id = auth.uid() or is_admin_tier()`, which is intended (the banned
   account must see its own reason) — confirmed, no change.
5. **NOT DONE — VULN-COMP-02 is reopened.** `streamer_public_profiles` exposes
   individual broadcasters' exact `latitude`/`longitude` to `anon`.
   `20260822140000` had deliberately removed those columns, noting that a public
   map path "will need its own answer for how a streamer's location is shown
   publicly without exposing exact GPS (fuzzing/rounding, a radius query)".
   `20260830180000` put them back without that answer, and the map read path in
   `admin_database_service.dart` now consumes them. Restoring them was
   unavoidable to make the chain apply, so the exposure stands. Choosing between
   rounding, fuzzing and a radius query changes what the map shows, so it is an
   owner decision — see `brief/OWNER_ACTIONS.md`.
6. **NOT DONE (P6) — the banned-keyword filter matches bare substrings.**
   `chat_check_banned_keywords` does a substring match against
   `chat_banned_keywords`, whose seeded list includes `hell`. So the message
   `Hello` is rejected as profanity. Found by running `chat_rate_limit.test.sql`
   for the first time; that file now uses `Salaam` so it tests the rate limiter
   rather than the filter. The fix (word boundaries, plus the Arabic-aware
   normalisation already listed as a P6.1 remainder) is P6 work.
