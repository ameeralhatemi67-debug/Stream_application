# RLS access matrix (P1.10)

Derived by reading every `create policy` / `drop policy` / `grant` statement in
`supabase/migrations/*.sql` as of migration `20260920140000_policy_quality.sql`
(93 policy statements, 6 dropped, 22 public tables plus `storage.objects`).

**Evidence tier: UNVERIFIED-STATIC.** No Docker was available in this session,
so nothing here was read back from a live catalog. To promote it, run the
R-probes in `brief/06` §2b and `npx supabase test db` on the local stack and
record the result under each table that changes.

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
| org_venues | org, admin | org owner, admin | org owner, admin | org owner, admin | Still a single `for all` write policy — open item below. |
| org_speakers | org, admin | org owner, admin | org owner, admin | org owner, admin | Same `for all` shape; P7 revisits roles/permissions here. |
| affiliation_requests | party | party | party | party | "party" = requester or the target org's owner; transition rules enforced by `guard_affiliation_transition` (P1.4), not by the policy alone. |
| broadcaster_applications | owner, admin | owner | owner (pending only), admin | owner, admin | `guard_application_review` forces `status='pending'` and nulls review fields on client writes. |
| user_roles | owner, admin | master; admin only for `org_owner`/`org_co_owner` | same | same | Split per command in `20260920140000`; `granted_by` must equal the acting admin. `org_owner` is auto-derived by `sync_org_owner_role` (ADR-007). |
| user_permissions | owner, admin | master | master | master | Split per command in `20260920140000`. |
| banned_users | owner, admin | admin | admin | admin | Delete = unban. Split per command in `20260920140000`. |
| device_sessions | owner | — | — | — | Writes are RPC-only since `20260920120000` dropped `device_sessions_write_own`: `claim_broadcaster_device`, `device_heartbeat`, `release_broadcaster_device`. |
| chat_messages | anon, viewer | owner | owner | owner, stream owner/moderator, admin | Rate limiting and slow mode are P6.1, not yet enforced. |
| chat_reports | admin | viewer (own report) | — | admin | Reporter cannot read the queue back. |
| chat_muted_users | stream owner, admin | stream owner, admin | — | stream owner, admin | Delete = unmute. |
| chat_mute_audit_log | admin/moderator scope | own action rows | — | — | Append-only by design. |
| chat_banned_keywords | admin | admin | admin | admin | Single `for all` admin policy — open item below. |
| stream_moderators | relevant (stream owner, the moderator, admin) | stream owner, admin | stream owner, admin | stream owner, admin | Single `for all` scoped policy — open item below. |
| streamer_custom_placeholders | anon+viewer (approved only), owner, admin | owner | admin | owner, admin | The real custom-card feature (01 invariants): kept. Only admins may change status, so a streamer cannot self-approve artwork. |
| audit_logs | admin | — (RPC only) | — | — | Written only through `log_audit_event()`, which now refuses banned accounts. |
| platform_analytics | admin | admin | admin | admin | Single `for all` admin policy — open item below. |
| academic_categories | anon, viewer | admin | admin | admin | Public taxonomy read. |
| tags | anon+viewer (approved only), admin | viewer (pending only) | admin | admin | |
| terms_and_conditions | anon, viewer | admin | admin | admin | Public legal text; single `for all` admin write policy — open item below. |
| storage.objects (`streamer-assets`) | public bucket read | owner path / org owner, admin | same | same | Path scoping by `can_write_streamer_asset()` (P1.3). |

No table in `public` currently has RLS enabled with zero policies, so there is
no deny-all table to justify yet. `stream_viewers` (P3) is planned as exactly
that: RLS on, no policy, reachable only through `viewer_heartbeat` and
`get_viewer_counts`. It must ship with a `comment on table` stating that.

## Views

Both views run with `security_invoker = false` on purpose and are the only
anon-readable path to profile/organization data. The justification now lives on
the views themselves (`comment on view`, `20260920140000`):
`streamer_public_profiles`, `organization_public_profiles`. Neither may ever
gain a PII column.

## Functions

| Function | Security | anon | authenticated |
|---|---|---|---|
| `is_admin_tier`, `is_master_admin`, `has_permission`, `owns_organization`, `is_org_member`, `owns_stream`, `chat_can_moderate`, `chat_is_muted`, `is_current_user_banned` | definer | — | execute |
| `chat_sender_info(uuid[])`, `chat_sender_info(uuid[], text)` | definer | execute | execute | Guests must see sender names/badges in public chat. |
| `can_broadcast`, `claim_broadcaster_device`, `device_heartbeat`, `set_live_state`, `release_broadcaster_device`, `sweep_stale_live_flags`, `log_audit_event`, `delete_own_account`, `can_write_streamer_asset` | definer | — | execute |
| `is_banned(uuid)` | definer | — | — | Called only from other definer functions; a per-uuid ban probe is not exposed to clients. |
| `set_updated_at`, `bootstrap_admin_role`, `chat_check_banned_keywords`, `sync_org_owner_role`, `handle_profile_before_delete`, `supersede_prior_approved_placeholder`, `guard_broadcaster_columns`, `guard_application_review`, `guard_affiliation_transition` | definer, trigger | — | — | Revoked from every client role. |

## Realtime publication

`supabase_realtime` carries: `chat_messages`, `broadcaster_applications`,
`profiles`, `academic_categories`, `tags`, `banned_users`, `device_sessions`.
Realtime respects RLS, so each subscriber sees only rows its policies allow.
`chat_reports` is **not** published — the admin moderation queue polls; P6.3
decides whether to publish it or keep polling.

## Data API exposure

`supabase/config.toml` exposes `["public", "graphql_public"]` only. No other
schema is reachable through PostgREST.

## Open items (reviewed, not fixed in P1c)

1. Seven tables still use one `for all` write policy instead of per-command
   policies: `academic_categories`, `chat_banned_keywords`, `org_speakers`,
   `org_venues`, `platform_analytics`, `stream_moderators`,
   `terms_and_conditions`. All are admin-only or owner-scoped, so this is
   shape, not an open door. The three privilege tables were split first.
2. Policies created before `20260920` mostly omit `to authenticated`, so they
   are addressed to `PUBLIC` and are evaluated for `anon` too. They deny anon
   in practice because every predicate resolves through `auth.uid()`, which is
   null for anon — but that is one predicate away from a hole, and D-21 asks
   for the explicit role. Affected: `profiles`, `organizations`, `org_venues`,
   `org_speakers`, `affiliation_requests`, `broadcaster_applications`,
   `audit_logs`, `platform_analytics`, `terms_and_conditions`, `user_roles`
   (select), `user_permissions` (select).
3. `log_audit_event()` still accepts any `p_organization_id` from any signed-in
   caller, so an account could file an audit entry against an organization it
   does not belong to. It now refuses banned accounts; the membership check
   belongs with P7's org-role work.
4. `banned_users` is in the realtime publication and its select policy allows
   `profile_id = auth.uid() or is_admin_tier()`, which is intended (the banned
   account must see its own reason) — confirmed, no change.
