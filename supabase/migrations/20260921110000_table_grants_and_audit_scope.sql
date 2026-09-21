-- P1.10 / P1.11: table-level privileges, audit scope, function search_path.
--
-- ===========================================================================
-- WHY THIS MIGRATION EXISTS (the most important finding of the P1 run)
-- ===========================================================================
-- Until this migration the schema granted the API roles almost nothing. Only
-- four objects had ever been granted to `anon`/`authenticated`
-- (streamer_public_profiles, organization_public_profiles, academic_categories,
-- tags). Every other table -- profiles, chat_messages, broadcaster_applications,
-- device_sessions, follows, bookmarks, chat_stream_settings, user_roles, all of
-- them -- had zero SELECT/INSERT/UPDATE/DELETE privilege for either role, while
-- carrying 110 carefully written RLS policies.
--
-- Table privileges are checked BEFORE row-level security. With no GRANT, RLS is
-- never consulted: every request fails with
--   42501 permission denied for table <name>
-- So those 110 policies were unreachable, and an app built from these
-- migrations alone cannot read or write anything at all. This was not visible
-- in any static review -- the policies look right, and a static reader has no
-- reason to ask whether the underlying privilege exists. It surfaced the first
-- time the chain was actually executed and the pgTAP suite ran: 7 of 8 files
-- died on `permission denied`, on tables whose policies were correct.
--
-- The production project does not show this because it predates the CLI
-- default change: `[api] auto_expose_new_tables` is unset in config.toml, which
-- matches the current cloud behaviour where new entities are NOT auto-exposed.
-- Anything created under the old auto-expose default kept working. That makes
-- this a latent break, not a live outage -- but it means the schema cannot be
-- rebuilt from its own migrations, which is exactly what a disaster-recovery
-- or second-environment run would do. See brief/OWNER_ACTIONS.md.
--
-- The grants below are minimal and derived mechanically: for each table, only
-- the commands that actually have a permissive policy, only for the roles those
-- policies address. RLS still decides which rows. Where a table has no policy
-- for a command (no DELETE on profiles, no INSERT on audit_logs), no privilege
-- is granted for it, so the absence is enforced at two layers instead of one.
begin;

-- ---------------------------------------------------------------------------
-- 1. Public, pre-auth reads. These four are the deliberate anon surface,
--    alongside the two public views (already granted) and storage.objects.
-- ---------------------------------------------------------------------------
grant select on public.academic_categories to anon, authenticated;
grant select on public.tags to anon, authenticated;
grant select on public.terms_and_conditions to anon, authenticated;
grant select on public.chat_messages to anon, authenticated;
grant select on public.chat_stream_settings to anon, authenticated;
grant select on public.streamer_custom_placeholders to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Own-row and role-scoped tables: signed-in only.
-- ---------------------------------------------------------------------------
-- profiles: no DELETE policy -- an account is erased through
-- delete_own_account(), so DELETE is withheld at the privilege layer too.
grant select, insert, update on public.profiles to authenticated;

-- organizations: created by admins, updated by owner/admin, never deleted
-- through the API.
grant select, insert, update on public.organizations to authenticated;

grant select, insert, update, delete on public.org_venues to authenticated;
grant select, insert, update, delete on public.org_speakers to authenticated;

-- affiliation_requests: no DELETE policy -- a request is cancelled by status,
-- so the history survives.
grant select, insert, update on public.affiliation_requests to authenticated;

grant select, insert, update, delete on public.broadcaster_applications to authenticated;

-- audit_logs: admin read only. INSERT stays absent on purpose; the only writer
-- is log_audit_event(), which runs as the definer and does not need a grant.
grant select on public.audit_logs to authenticated;

grant select, insert, update, delete on public.platform_analytics to authenticated;

-- Privilege tables. The policies from 20260920140000 restrict these to master
-- admin (and plain admin for the org_owner/org_co_owner tier only).
grant select, insert, update, delete on public.user_roles to authenticated;
grant select, insert, update, delete on public.user_permissions to authenticated;
grant select, insert, update, delete on public.banned_users to authenticated;

-- device_sessions: reads only. Every write goes through
-- claim_broadcaster_device / device_heartbeat / release_broadcaster_device,
-- which is why 20260920120000 dropped the write policy. Withholding
-- INSERT/UPDATE/DELETE here makes that RPC-only contract structural.
grant select on public.device_sessions to authenticated;

-- Chat and moderation.
grant select, insert, update, delete on public.chat_messages to authenticated;
grant select, insert, delete on public.chat_reports to authenticated;
grant select, insert, delete on public.chat_muted_users to authenticated;
grant select, insert on public.chat_mute_audit_log to authenticated;
grant select, insert, update, delete on public.chat_banned_keywords to authenticated;
grant select, insert, update, delete on public.chat_stream_settings to authenticated;
grant select, insert, update, delete on public.stream_moderators to authenticated;

grant select, insert, update, delete on public.streamer_custom_placeholders to authenticated;
grant select, insert, update, delete on public.tags to authenticated;
grant select, insert, update, delete on public.terms_and_conditions to authenticated;
grant insert, update, delete on public.academic_categories to authenticated;

-- follows / bookmarks (D-07): own-row only, and a follow is created or
-- deleted, never updated.
grant select, insert, delete on public.follows to authenticated;
grant select, insert, delete on public.bookmarks to authenticated;

-- ---------------------------------------------------------------------------
-- 3. stream_viewers stays deny-all, now enforced at the privilege layer too
--    (P3 / D-08). RLS is on with zero policies; this makes the intent
--    explicit and survives anyone later adding a policy by accident.
--    viewer_heartbeat() and get_viewer_counts() are SECURITY DEFINER and so
--    reach the table as their owner without any client privilege.
-- ---------------------------------------------------------------------------
revoke all on public.stream_viewers from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. log_audit_event: smallest safe organization guard.
--
-- The function accepted any p_organization_id from any signed-in caller, so an
-- account could file audit entries against an organization it has nothing to
-- do with -- an integrity problem in the one table meant to be trustworthy.
-- The guard is deliberately minimal: a null organization (a platform-level
-- event), an organization the caller actually belongs to, or an admin. The
-- richer per-capability org authorization model is P7 work and is recorded as
-- NOT DONE; this only closes the "unrelated organization ID" hole.
-- ---------------------------------------------------------------------------
create or replace function public.log_audit_event(
  p_organization_id uuid,
  p_action text,
  p_description_en text,
  p_description_ar text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_email text;
  v_actor_name text;
  v_id uuid;
begin
  if auth.uid() is null or public.is_banned(auth.uid()) then
    raise exception 'Not permitted' using errcode = '42501';
  end if;

  -- An audit entry may be platform-level (null org), about an organization the
  -- caller belongs to, or written by an admin. Anything else is a caller
  -- claiming a scope it does not have.
  if p_organization_id is not null
     and not public.is_org_member(p_organization_id)
     and not public.is_admin_tier() then
    raise exception 'Not permitted for that organization' using errcode = '42501';
  end if;

  select email, coalesce(display_name_en, email, 'Unknown')
    into v_actor_email, v_actor_name
    from public.profiles where id = auth.uid();

  insert into public.audit_logs (
    organization_id, actor_profile_id, actor_email, actor_name,
    action, description_en, description_ar, metadata
  ) values (
    p_organization_id, auth.uid(), coalesce(v_actor_email, 'unknown'), coalesce(v_actor_name, 'Unknown'),
    p_action, p_description_en, p_description_ar, p_metadata
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke execute on function public.log_audit_event(uuid, text, text, text, jsonb) from public, anon;
grant execute on function public.log_audit_event(uuid, text, text, text, jsonb) to authenticated;

comment on function public.log_audit_event(uuid, text, text, text, jsonb) is
  'Appends to audit_logs as the definer. Refuses unauthenticated and banned callers, and refuses an organization the caller is neither a member of nor an admin over. Per-capability organization authorization is P7.';

-- ---------------------------------------------------------------------------
-- 5. search_path on the two functions that lacked it.
--
-- D-21 requires it for `security definer`; every definer function already has
-- it. These two are SECURITY INVOKER, so a hijacked search_path cannot
-- escalate privilege -- but chat_enforce_rate_limit IS the chat rate limit,
-- slow mode and chat-off enforcement, and resolving `chat_stream_settings` or
-- `chat_can_moderate` through a caller-controlled schema would be a way to
-- neuter it. Both stay SECURITY INVOKER: chat_enforce_rate_limit needs
-- `current_user` to keep telling an ordinary API write from a trusted
-- owner-executed RPC (D-21), which a definer function could not do.
-- ---------------------------------------------------------------------------
alter function public.chat_enforce_rate_limit() set search_path = '';
alter function public.set_updated_at() set search_path = '';

commit;
