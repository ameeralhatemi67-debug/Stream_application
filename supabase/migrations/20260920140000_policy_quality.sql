-- P1.10 (policy quality, 05 D-21). Row-level security was already enabled on
-- all 22 public tables with 75+ policies; the work here is quality, not
-- "turning RLS on":
--   1. The three privilege tables (user_roles, user_permissions, banned_users)
--      were written as `for all` policies. Split per command, addressed
--      `to authenticated`, so a SELECT policy can never widen a write path.
--   2. Helper functions were executable by `public` (so also by `anon`).
--      Revoked, then granted back only to the roles that call them; trigger
--      functions are revoked from every client role.
--   3. The two public views intentionally run SECURITY DEFINER
--      (security_invoker = false) -- that intent is now recorded on the view
--      itself, not only in a migration comment.
-- The remaining `for all` policies (academic_categories, chat_banned_keywords,
-- org_speakers, org_venues, platform_analytics, stream_moderators,
-- terms_and_conditions) and the older policies without an explicit
-- `to authenticated` are listed in supabase/tests/policy_matrix.md as
-- reviewed and still open.
begin;

-- ---------------------------------------------------------------------------
-- 1. Privilege tables: one policy per command.
-- ---------------------------------------------------------------------------
drop policy if exists user_roles_write_master_admin on public.user_roles;
drop policy if exists user_roles_write_admin_permitted_tier on public.user_roles;
drop policy if exists user_permissions_write_master_admin on public.user_permissions;
drop policy if exists banned_users_write_admin on public.banned_users;

-- Master admin: full write authority over any role row; granted_by must be the
-- acting admin so the audit trail cannot be forged.
create policy user_roles_insert_master_admin on public.user_roles
  for insert to authenticated
  with check (public.is_master_admin() and granted_by = (select auth.uid()));

create policy user_roles_update_master_admin on public.user_roles
  for update to authenticated
  using (public.is_master_admin())
  with check (public.is_master_admin() and granted_by = (select auth.uid()));

create policy user_roles_delete_master_admin on public.user_roles
  for delete to authenticated
  using (public.is_master_admin());

-- Plain admin: may only write Permitted-Admin-tier rows (org_owner /
-- org_co_owner). Both the existing row and its new shape must stay in that
-- tier, so an admin can neither promote a row to admin/master_admin nor touch
-- an existing admin/master_admin row.
create policy user_roles_insert_admin_permitted_tier on public.user_roles
  for insert to authenticated
  with check (
    public.is_admin_tier()
    and not public.is_master_admin()
    and role in ('org_owner', 'org_co_owner')
    and granted_by = (select auth.uid())
  );

create policy user_roles_update_admin_permitted_tier on public.user_roles
  for update to authenticated
  using (
    public.is_admin_tier()
    and not public.is_master_admin()
    and role in ('org_owner', 'org_co_owner')
  )
  with check (
    public.is_admin_tier()
    and not public.is_master_admin()
    and role in ('org_owner', 'org_co_owner')
    and granted_by = (select auth.uid())
  );

create policy user_roles_delete_admin_permitted_tier on public.user_roles
  for delete to authenticated
  using (
    public.is_admin_tier()
    and not public.is_master_admin()
    and role in ('org_owner', 'org_co_owner')
  );

create policy user_permissions_insert_master_admin on public.user_permissions
  for insert to authenticated
  with check (public.is_master_admin() and granted_by = (select auth.uid()));

create policy user_permissions_update_master_admin on public.user_permissions
  for update to authenticated
  using (public.is_master_admin())
  with check (public.is_master_admin() and granted_by = (select auth.uid()));

create policy user_permissions_delete_master_admin on public.user_permissions
  for delete to authenticated
  using (public.is_master_admin());

create policy banned_users_insert_admin on public.banned_users
  for insert to authenticated
  with check (public.is_admin_tier() and banned_by = (select auth.uid()));

create policy banned_users_update_admin on public.banned_users
  for update to authenticated
  using (public.is_admin_tier())
  with check (public.is_admin_tier() and banned_by = (select auth.uid()));

-- Unbanning is deleting the row (the table's own "delete = undo" contract).
create policy banned_users_delete_admin on public.banned_users
  for delete to authenticated
  using (public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- 2. Function execution: default-deny, then grant what the matrix needs.
-- ---------------------------------------------------------------------------
-- Role/permission predicates: read by clients through policies, and called
-- directly by the app to decide what to render.
revoke execute on function public.is_admin_tier() from public, anon;
grant execute on function public.is_admin_tier() to authenticated;
revoke execute on function public.is_master_admin() from public, anon;
grant execute on function public.is_master_admin() to authenticated;
revoke execute on function public.has_permission(text, uuid) from public, anon;
grant execute on function public.has_permission(text, uuid) to authenticated;
revoke execute on function public.owns_organization(uuid) from public, anon;
grant execute on function public.owns_organization(uuid) to authenticated;
revoke execute on function public.is_org_member(uuid) from public, anon;
grant execute on function public.is_org_member(uuid) to authenticated;
revoke execute on function public.owns_stream(text) from public, anon;
grant execute on function public.owns_stream(text) to authenticated;
revoke execute on function public.chat_can_moderate(text) from public, anon;
grant execute on function public.chat_can_moderate(text) to authenticated;
revoke execute on function public.chat_is_muted(text, uuid) from public, anon;
grant execute on function public.chat_is_muted(text, uuid) to authenticated;
revoke execute on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;

-- chat_sender_info stays available to anon on purpose: guest viewers must see
-- sender display names and role badges in a public chat.
revoke execute on function public.chat_sender_info(uuid[]) from public;
grant execute on function public.chat_sender_info(uuid[]) to anon, authenticated;
revoke execute on function public.chat_sender_info(uuid[], text) from public;
grant execute on function public.chat_sender_info(uuid[], text) to anon, authenticated;

-- Trigger functions are invoked by the trigger as the definer; no client role
-- has any reason to call them directly.
revoke execute on function public.set_updated_at() from public, anon, authenticated;
revoke execute on function public.bootstrap_admin_role() from public, anon, authenticated;
revoke execute on function public.chat_check_banned_keywords() from public, anon, authenticated;
revoke execute on function public.sync_org_owner_role() from public, anon, authenticated;
revoke execute on function public.handle_profile_before_delete() from public, anon, authenticated;
revoke execute on function public.supersede_prior_approved_placeholder() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. The two public views are SECURITY DEFINER by design: they exist to expose
-- a non-PII column subset to anonymous viewers while the profiles /
-- organizations tables themselves stay closed (20260822140000_restrict_pii_rls).
-- ---------------------------------------------------------------------------
comment on view public.streamer_public_profiles is
  'Public, non-PII projection of streamer profiles for the feed and map. security_invoker = false is deliberate (D-21 exception): the base table restricts every column to the owner and admins, and this view is the only anon-readable path. It must never gain email, phone or any other PII column. Live columns (is_currently_live, active_stream_id) are server-owned via set_live_state and expired by sweep_stale_live_flags.';

comment on view public.organization_public_profiles is
  'Public, non-PII projection of organizations for the feed and map. security_invoker = false is deliberate (D-21 exception), same contract as streamer_public_profiles.';

commit;
