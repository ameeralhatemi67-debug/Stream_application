-- v0.8 Admin Upgrade — Checkpoint 1, Phase 2: Granular Permission Checkboxes
--
-- user_permissions (profile_id, permission_key, organization_id, granted_by,
-- granted_at) was already scaffolded schema-only in v0.5 -- same shape the
-- roadmap describes (user_id -> profile_id, capability -> permission_key,
-- row existence = the checkbox being "on"). What's missing is the single
-- has_permission() question the rest of the app is supposed to be able to
-- ask instead of checking tier and permissions separately everywhere, and
-- RLS tight enough that granting a capability can't itself become a
-- privilege-escalation path.

-- ---------------------------------------------------------------------------
-- has_permission(capability, org_id) — the one function callers use.
-- master_admin implicitly passes every check ("unrestricted platform
-- control" per the roadmap). Everyone else needs an explicit
-- user_permissions row for that exact capability, either platform-wide
-- (organization_id is null) or scoped to the org being asked about
-- (organization_id = p_org_id). This is deliberately independent of
-- is_admin_tier()/owns_organization() -- those still gate the tier-level
-- surfaces; this only answers the "extra checkbox layered on top" question
-- (e.g. "can this specific Admin also edit platform Terms & Conditions").
-- ---------------------------------------------------------------------------
create or replace function public.has_permission(p_capability text, p_org_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_master_admin()
  or exists (
    select 1 from public.user_permissions
    where profile_id = auth.uid()
      and permission_key = p_capability
      and (organization_id is null or organization_id = p_org_id)
  );
$$;

grant execute on function public.has_permission(text, uuid) to authenticated;

-- Tighten user_permissions writes from v0.5's blanket "any admin-tier
-- account" policy to master_admin only. The roadmap's "(or an Admin, if
-- permitted to)" delegation isn't implemented here on purpose: doing it
-- recursively against this same table (an admin needs a manage_admins row
-- to grant manage_admins rows) would let a self-granted row bootstrap its
-- own authority -- the same self-escalation shape Checkpoint 1 Phase 1
-- just closed on user_roles. Revisit once Checkpoint 2's role/permission
-- management UI defines an actual delegation mechanism.
drop policy if exists user_permissions_write_admin on public.user_permissions;

create policy user_permissions_write_master_admin
  on public.user_permissions for all
  using (public.is_master_admin())
  with check (public.is_master_admin() and granted_by = auth.uid());

comment on table public.user_permissions is
  'Granular checkbox-style capability grants layered on top of user_roles, read via has_permission(capability, org_id). Currently master_admin-only to write (see 20260827100000). UI arrives in v0.8 Checkpoint 2.';
