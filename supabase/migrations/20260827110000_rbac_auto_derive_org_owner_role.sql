-- v0.8 Admin Upgrade — Checkpoint 1, Phase 3: Permitted Admin <-> Organization
-- Ownership
--
-- Wires org_owner user_roles rows (the "Permitted Admin" tier for the actual
-- organization owner -- see ADR-007) to organizations.owner_profile_id
-- automatically, so nothing needs a manual admin action every time an org
-- is created or changes hands.
--
-- Scope note (user decision, 2026-08-23): org_co_owner is intentionally NOT
-- auto-derived here. There is no existing "co-owner" concept anywhere in the
-- schema or app -- organizations has a single owner_profile_id, and neither
-- org_speakers nor affiliation_requests carry a co-owner flag (proposed_role
-- is free text, not structured). Inventing that designation mechanism now
-- would be new product surface, not "wiring the existing flow" as the
-- roadmap describes. org_co_owner remains a role value the schema and RLS
-- already support (see ADR-007) but nothing populates automatically until
-- Checkpoint 2/3 build a real co-owner designation UI -- track that as a
-- known gap, not a silent omission.

create or replace function public.sync_org_owner_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.user_roles (profile_id, role, organization_id)
    values (new.owner_profile_id, 'org_owner', new.id)
    on conflict (profile_id, role, organization_id) do nothing;
    return new;
  end if;

  -- tg_op = 'UPDATE': only act when ownership actually changed -- move the
  -- org_owner row from the previous owner to the new one. (organization
  -- deletion needs no handling here: user_roles.organization_id already
  -- cascades on delete, see 20260821203000_initial_schema.sql.)
  if new.owner_profile_id is distinct from old.owner_profile_id then
    delete from public.user_roles
    where organization_id = old.id
      and role = 'org_owner'
      and profile_id = old.owner_profile_id;

    insert into public.user_roles (profile_id, role, organization_id)
    values (new.owner_profile_id, 'org_owner', new.id)
    on conflict (profile_id, role, organization_id) do nothing;
  end if;

  return new;
end;
$$;

create trigger sync_org_owner_role_on_organizations
  after insert or update of owner_profile_id on public.organizations
  for each row execute function public.sync_org_owner_role();

-- Backfill: any organization created before this migration existed gets its
-- owner's org_owner row created now, same as new orgs get going forward.
insert into public.user_roles (profile_id, role, organization_id)
select owner_profile_id, 'org_owner', id
from public.organizations
on conflict (profile_id, role, organization_id) do nothing;
