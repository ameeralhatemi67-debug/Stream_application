-- v0.8 Admin Upgrade — Checkpoint 1, Phase 1: Role Hierarchy Schema
--
-- user_roles/user_permissions were scaffolded schema-only in v0.5 (see
-- 20260821203000_initial_schema.sql) specifically so this version wouldn't
-- need another table-shape migration round. The role enum
-- ('master_admin', 'admin', 'org_owner', 'org_co_owner') already IS the
-- four-tier hierarchy from doc/Roadmap/v0.8_Admin_Upgrade.md: 'org_owner'
-- and 'org_co_owner' together are that doc's "Permitted Admin" tier (kept as
-- two distinct DB values because owner vs co-owner is a real distinction
-- elsewhere in the org model), and "user" tier is the implicit case of
-- having no user_roles row at all -- there is no stored 'user' role value,
-- and no code should ever need to query "role = 'user'".
--
-- What v0.5's RLS actually shipped (20260821203100_row_level_security.sql)
-- was a single blanket policy: any admin-tier account (master_admin OR
-- admin) could insert/update/delete ANY user_roles row, including granting
-- itself or anyone else master_admin. That's short of the hierarchy this
-- version specifies: only a master_admin may grant/revoke master_admin or
-- admin; a plain admin may only write Permitted-Admin-tier rows
-- (org_owner/org_co_owner), never touch admin/master_admin rows (their own
-- or anyone else's). This migration replaces that one policy with two
-- tier-aware ones and closes an audit-trail gap alongside it (granted_by
-- was writable to any value, so a malicious admin could misattribute a
-- grant to someone else).

-- ---------------------------------------------------------------------------
-- is_master_admin() — same SECURITY DEFINER shape as is_admin_tier(), but
-- narrowed to the top tier only, for policies that must distinguish
-- master_admin from plain admin (is_admin_tier() intentionally treats both
-- as equivalent for the rest of the app -- see AppProvider.isAdminUser).
-- ---------------------------------------------------------------------------
create or replace function public.is_master_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_roles
    where profile_id = auth.uid() and role = 'master_admin'
  );
$$;

grant execute on function public.is_master_admin() to authenticated;

-- Replace the v0.5 blanket write policy with tier-aware ones.
drop policy if exists user_roles_write_admin on public.user_roles;

-- A master_admin may insert/update/delete any row (grant/revoke any tier,
-- including other master_admins and admins). granted_by must be the actor
-- themselves -- prevents misattributing a grant to a different profile_id.
create policy user_roles_write_master_admin
  on public.user_roles for all
  using (public.is_master_admin())
  with check (public.is_master_admin() and granted_by = auth.uid());

-- A plain admin may only write Permitted-Admin-tier rows (org_owner /
-- org_co_owner) -- both the row being changed (using) and its new shape
-- (with check) must stay in that tier, so an admin can neither promote an
-- existing org_owner row to admin/master_admin nor touch an existing
-- admin/master_admin row at all. Same granted_by integrity check as above.
create policy user_roles_write_admin_permitted_tier
  on public.user_roles for all
  using (
    public.is_admin_tier()
    and not public.is_master_admin()
    and role in ('org_owner', 'org_co_owner')
  )
  with check (
    public.is_admin_tier()
    and not public.is_master_admin()
    and role in ('org_owner', 'org_co_owner')
    and granted_by = auth.uid()
  );

comment on table public.user_roles is
  'Admin-tier role grants. role in (master_admin, admin, org_owner, org_co_owner); org_owner/org_co_owner together are the roadmap''s "Permitted Admin" tier, scoped by organization_id. No row = implicit "user" tier. Write access: master_admin manages any row; admin may only grant/revoke org_owner/org_co_owner rows. UI arrives in v0.8 Checkpoint 2.';
