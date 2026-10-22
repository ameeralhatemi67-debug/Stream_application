-- Admin access by email, and a lessons-only admin role (owner decisions
-- 2026-10-22).
--
-- * A master admin adds an email address. If an account with that verified
--   email already exists it becomes an admin now; otherwise it becomes one
--   the first time someone signs in with it (the profile insert trigger).
--   This replaces the hard-coded master admin list in bootstrap_admin_role(),
--   whose three addresses are carried over as master admin entries.
-- * lessons_admin: an admin who manages only preachers and lessons. It is not
--   admin tier (is_admin_tier() stays admin and master_admin);
--   is_lessons_admin() covers all three.

-- ---------------------------------------------------------------------------
-- Lessons admin role
-- ---------------------------------------------------------------------------
alter table public.user_roles drop constraint user_roles_role_check;
alter table public.user_roles add constraint user_roles_role_check
  check (role in ('master_admin', 'admin', 'lessons_admin', 'org_owner', 'org_co_owner'));
alter table public.user_roles drop constraint user_roles_org_scope_chk;
alter table public.user_roles add constraint user_roles_org_scope_chk check (
  (role in ('org_owner', 'org_co_owner') and organization_id is not null)
  or (role in ('master_admin', 'admin', 'lessons_admin') and organization_id is null));

create function public.is_lessons_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and not public.is_banned(auth.uid()) and exists (
    select 1 from public.user_roles
     where profile_id = auth.uid() and role in ('master_admin', 'admin', 'lessons_admin'));
$$;
comment on function public.is_lessons_admin() is
  'Admins, master admins and lessons-only admins: who manages preachers and lessons.';
revoke all on function public.is_lessons_admin() from public;
grant execute on function public.is_lessons_admin() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Emails that become admins
-- ---------------------------------------------------------------------------
create table public.admin_email_grants (
  email text primary key
    check (email = lower(btrim(email)) and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  role text not null default 'admin' check (role in ('admin', 'master_admin')),
  granted_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  applied_profile_id uuid references public.profiles(id) on delete set null,
  applied_at timestamptz
);
comment on table public.admin_email_grants is
  'Email addresses that become admins (or, for the original bootstrap list, master admins) when that verified account signs in. Written only through admin_add_email_grant / admin_remove_email_grant.';
alter table public.admin_email_grants enable row level security;
create policy admin_email_grants_select_master on public.admin_email_grants
  for select to authenticated using (public.is_master_admin());

insert into public.admin_email_grants(email, role) values
  ('polkgvd2@gmail.com', 'master_admin'),
  ('ameeralhatemi67@gmail.com', 'master_admin'),
  ('amir.alhatemi@gmail.com', 'master_admin')
on conflict (email) do nothing;

-- Gives the account its granted role if its verified email has an entry.
-- Banned accounts get nothing.
create function private.apply_admin_email_grant(p_profile uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_email text;
  g public.admin_email_grants;
begin
  select lower(u.email) into v_email from auth.users u
   where u.id = p_profile and u.email_confirmed_at is not null;
  if v_email is null or public.is_banned(p_profile) then return; end if;
  select * into g from public.admin_email_grants where email = v_email;
  if not found then return; end if;
  insert into public.user_roles(profile_id, role, granted_by)
  select p_profile, g.role, g.granted_by
   where not exists (select 1 from public.user_roles r
     where r.profile_id = p_profile and r.role = g.role and r.organization_id is null);
  update public.admin_email_grants
     set applied_profile_id = p_profile, applied_at = coalesce(applied_at, now())
   where email = v_email;
end; $$;
revoke all on function private.apply_admin_email_grant(uuid) from public, anon, authenticated;

-- The bootstrap trigger now reads the table instead of a list in code.
create or replace function public.bootstrap_admin_role() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform private.apply_admin_email_grant(new.id);
  return new;
end; $$;

-- Entries whose account already holds the role are marked as applied.
update public.admin_email_grants g
   set applied_profile_id = u.id, applied_at = now()
  from auth.users u
 where lower(u.email) = g.email
   and exists (select 1 from public.user_roles r
     where r.profile_id = u.id and r.role = g.role and r.organization_id is null);

-- Adds an email as a future admin. Returns 'granted' when the account
-- already exists (it is an admin now) or 'waiting'.
create function public.admin_add_email_grant(p_email text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_profile uuid;
begin
  if not public.is_master_admin() then
    raise exception 'Only a master admin adds admin emails' using errcode = '42501';
  end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Invalid email' using errcode = '22023';
  end if;
  insert into public.admin_email_grants(email, role, granted_by)
  values (v_email, 'admin', auth.uid())
  on conflict (email) do nothing;
  select p.id into v_profile
    from public.profiles p join auth.users u on u.id = p.id
   where lower(u.email) = v_email and u.email_confirmed_at is not null
   limit 1;
  if v_profile is null then return 'waiting'; end if;
  perform private.apply_admin_email_grant(v_profile);
  return 'granted';
end; $$;
revoke all on function public.admin_add_email_grant(text) from public, anon;
grant execute on function public.admin_add_email_grant(text) to authenticated;

-- Removes an email from the list. A role already given stays; it is revoked
-- from the Roles tab like any other.
create function public.admin_remove_email_grant(p_email text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_master_admin() then
    raise exception 'Only a master admin removes admin emails' using errcode = '42501';
  end if;
  delete from public.admin_email_grants where email = lower(btrim(coalesce(p_email, '')));
end; $$;
revoke all on function public.admin_remove_email_grant(text) from public, anon;
grant execute on function public.admin_remove_email_grant(text) to authenticated;
