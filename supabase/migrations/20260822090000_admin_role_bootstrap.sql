-- v0.5 Backend Foundation — Checkpoint 2, Phase 3 support
--
-- Two things AppProvider's new backend-derived admin check (Checkpoint 2
-- Phase 3) depends on that the Checkpoint 1 RLS migration didn't yet cover:

-- 1. Supabase's project template revokes EXECUTE on newly created functions
--    from PUBLIC by default. log_audit_event() already had an explicit grant;
--    is_admin_tier()/owns_organization()/is_org_member() didn't, which would
--    silently deny both the RPC call AppProvider makes AND every RLS policy
--    that references them for the `authenticated` role.
grant execute on function public.is_admin_tier() to authenticated;
grant execute on function public.owns_organization(uuid) to authenticated;
grant execute on function public.is_org_member(uuid) to authenticated;

-- 2. Bootstrap master_admin for the three emails previously hardcoded in
--    AppProvider._superAdminEmails (removed in this same phase). Runs once
--    per new profile row, so whoever signs in with one of these addresses
--    keeps admin access without a manual dashboard/SQL step -- role changes
--    for anyone else now go entirely through user_roles, not a compiled-in
--    email list. See doc/Audit/01_Security_Data_Protection_Audit.md VULN-RBAC-03.
create or replace function public.bootstrap_admin_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(new.email) in (
    'polkgvd2@gmail.com',
    'ameeralhatemi67@gmail.com',
    'amir.alhatemi@gmail.com'
  ) then
    insert into public.user_roles (profile_id, role)
    values (new.id, 'master_admin')
    on conflict (profile_id, role, organization_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger bootstrap_admin_role_on_profile_insert
  after insert on public.profiles
  for each row execute function public.bootstrap_admin_role();
