-- Admin access as two switches (owner decision 2026-11-01): the platform admin
-- page and the lessons admin page. A master admin gives an email one, the other
-- or both, and can change it later.
--
-- * The admin role now means the platform page and lessons_admin the lessons
--   page. Both is the two rows; master_admin stays everything. Plain admins used
--   to manage lessons too, so each one is given lessons_admin here and loses
--   nothing.
-- * admin_email_grants becomes the one list of who has admin access, one line
--   per email. Changing a line applies at once to an existing account, and
--   removing it takes the access away. Platform roles can no longer be written
--   directly through the API, so the list cannot drift from user_roles and a
--   locked line cannot be gone around.
-- * The owner's two addresses are locked as master admins.

-- ---------------------------------------------------------------------------
-- The lessons page no longer comes with the admin role
-- ---------------------------------------------------------------------------
insert into public.user_roles(profile_id, role, granted_by)
select r.profile_id, 'lessons_admin', r.granted_by
  from public.user_roles r
 where r.role = 'admin' and r.organization_id is null
   and not exists (select 1 from public.user_roles x
     where x.profile_id = r.profile_id and x.role = 'lessons_admin' and x.organization_id is null);

create or replace function public.is_lessons_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and not public.is_banned(auth.uid()) and exists (
    select 1 from public.user_roles
     where profile_id = auth.uid() and role in ('master_admin', 'lessons_admin'));
$$;
comment on function public.is_lessons_admin() is
  'Who manages preachers and lessons: master admins and whoever holds lessons_admin.';

create or replace function private.lessons_admins() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select distinct r.profile_id from public.user_roles r
   where r.role in ('master_admin','lessons_admin') and r.organization_id is null
     and r.profile_id is distinct from auth.uid()
     and not public.is_banned(r.profile_id);
$$;

-- ---------------------------------------------------------------------------
-- One line per email
-- ---------------------------------------------------------------------------
alter table public.admin_email_grants drop constraint admin_email_grants_role_check;
alter table public.admin_email_grants rename column role to access;
alter table public.admin_email_grants alter column access set default 'both';
update public.admin_email_grants
   set access = case access when 'master_admin' then 'master' else 'both' end;
alter table public.admin_email_grants add constraint admin_email_grants_access_check
  check (access in ('master', 'both', 'platform', 'lessons'));
alter table public.admin_email_grants add column locked boolean not null default false;
alter table public.admin_email_grants add constraint admin_email_grants_locked_check
  check (not locked or access = 'master');
comment on table public.admin_email_grants is
  'Who has admin access, one line per email: master, both (platform and lessons pages), platform or lessons. Applied at once to an existing verified account, otherwise when that account signs in. Written only through admin_set_email_access / admin_remove_email_grant. Locked lines are the owner''s and cannot change.';

-- Anyone who already holds an admin role gets a line, so the list is complete.
insert into public.admin_email_grants(email, access, granted_by, applied_profile_id, applied_at)
select lower(u.email),
       case when bool_or(r.role = 'master_admin') then 'master'
            when bool_or(r.role = 'admin') and bool_or(r.role = 'lessons_admin') then 'both'
            when bool_or(r.role = 'admin') then 'platform'
            else 'lessons' end,
       (array_agg(r.granted_by))[1], r.profile_id, min(r.granted_at)
  from public.user_roles r
  join auth.users u on u.id = r.profile_id
 where r.organization_id is null and r.role in ('master_admin', 'admin', 'lessons_admin')
   and u.email is not null
 group by lower(u.email), r.profile_id
on conflict (email) do nothing;

create function private.admin_access_roles(p_access text) returns text[]
language sql immutable set search_path = '' as $$
  select case p_access
    when 'master' then array['master_admin']
    when 'both' then array['admin', 'lessons_admin']
    when 'platform' then array['admin']
    when 'lessons' then array['lessons_admin']
    else array[]::text[] end;
$$;

-- Makes the account's platform roles exactly [p_access]; anything else removes
-- them all. has_permission() reads the capability checkboxes on their own, so
-- they go with the platform page.
create function private.set_admin_roles(p_profile uuid, p_access text, p_by uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_roles text[] := private.admin_access_roles(p_access);
begin
  delete from public.user_roles
   where profile_id = p_profile and organization_id is null
     and role in ('master_admin', 'admin', 'lessons_admin') and role <> all (v_roles);
  insert into public.user_roles(profile_id, role, granted_by)
  select p_profile, r, p_by from unnest(v_roles) r
   where not exists (select 1 from public.user_roles x
     where x.profile_id = p_profile and x.role = r and x.organization_id is null);
  if not v_roles && array['master_admin', 'admin'] then
    delete from public.user_permissions where profile_id = p_profile and organization_id is null;
  end if;
end; $$;

-- Gives the account what its verified email's line says. Banned accounts get
-- nothing.
create or replace function private.apply_admin_email_grant(p_profile uuid) returns void
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
  perform private.set_admin_roles(p_profile, g.access, g.granted_by);
  update public.admin_email_grants
     set applied_profile_id = p_profile, applied_at = coalesce(applied_at, now())
   where email = v_email;
end; $$;

-- A locked line, or one's own, cannot be changed or removed. Own lines are kept
-- from master admins so nobody locks themselves out by mistake.
create function private.guard_admin_line(p_line public.admin_email_grants, p_email text) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if p_line.locked then
    raise exception 'This line is locked' using errcode = '42501', hint = 'locked';
  end if;
  if p_email = (select lower(u.email) from auth.users u where u.id = auth.uid()) then
    raise exception 'Your own access cannot be changed' using errcode = '42501', hint = 'self';
  end if;
end; $$;

-- Adds an email or changes its line. Returns 'granted' when the account already
-- exists (it has this access now) or 'waiting'.
drop function public.admin_add_email_grant(text);
create function public.admin_set_email_access(p_email text, p_access text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_profile uuid;
  g public.admin_email_grants;
begin
  if not public.is_master_admin() then
    raise exception 'Only a master admin sets admin access' using errcode = '42501';
  end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Invalid email' using errcode = '22023';
  end if;
  if p_access is null or p_access not in ('master', 'both', 'platform', 'lessons') then
    raise exception 'Invalid access' using errcode = '22023';
  end if;
  select * into g from public.admin_email_grants where email = v_email for update;
  if found then perform private.guard_admin_line(g, v_email); end if;
  insert into public.admin_email_grants(email, access, granted_by)
  values (v_email, p_access, auth.uid())
  on conflict (email) do update set access = excluded.access, granted_by = excluded.granted_by;
  perform public.log_audit_event_internal(null, 'adminAccessChanged',
    format('Admin access for %s set to %s', v_email, p_access),
    format('تغيير صلاحية %s إلى %s', v_email, p_access),
    jsonb_build_object('email', v_email, 'access', p_access, 'previous', g.access));
  select p.id into v_profile
    from public.profiles p join auth.users u on u.id = p.id
   where lower(u.email) = v_email and u.email_confirmed_at is not null
   limit 1;
  if v_profile is null then return 'waiting'; end if;
  perform private.apply_admin_email_grant(v_profile);
  return 'granted';
end; $$;
revoke all on function public.admin_set_email_access(text, text) from public, anon;
grant execute on function public.admin_set_email_access(text, text) to authenticated;

-- Removes a line and the access it gave.
create or replace function public.admin_remove_email_grant(p_email text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_profile uuid;
  g public.admin_email_grants;
begin
  if not public.is_master_admin() then
    raise exception 'Only a master admin removes admin emails' using errcode = '42501';
  end if;
  select * into g from public.admin_email_grants where email = v_email for update;
  if not found then return; end if;
  perform private.guard_admin_line(g, v_email);
  delete from public.admin_email_grants where email = v_email;
  perform public.log_audit_event_internal(null, 'adminAccessRemoved',
    format('Admin access removed for %s', v_email),
    format('إزالة صلاحية %s', v_email),
    jsonb_build_object('email', v_email, 'previous', g.access));
  for v_profile in select u.id from auth.users u where lower(u.email) = v_email loop
    perform private.set_admin_roles(v_profile, 'none', auth.uid());
  end loop;
end; $$;

revoke all on function private.admin_access_roles(text), private.set_admin_roles(uuid, text, uuid),
  private.guard_admin_line(public.admin_email_grants, text), private.apply_admin_email_grant(uuid)
  from public, anon, authenticated;

-- The owner's two addresses stay master admins whatever else changes.
insert into public.admin_email_grants(email, access, locked) values
  ('polkgvd2@gmail.com', 'master', true),
  ('ameeralhatemi67@gmail.com', 'master', true)
on conflict (email) do update set access = 'master', locked = true;

do $$
declare v_profile uuid;
begin
  for v_profile in
    select u.id from auth.users u
     where lower(u.email) in ('polkgvd2@gmail.com', 'ameeralhatemi67@gmail.com')
  loop
    perform private.apply_admin_email_grant(v_profile);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Platform roles change only through the list
-- ---------------------------------------------------------------------------
drop policy user_roles_insert_master_admin on public.user_roles;
create policy user_roles_insert_master_admin on public.user_roles
  for insert to authenticated
  with check (public.is_master_admin() and role in ('org_owner', 'org_co_owner')
    and granted_by = (select auth.uid()));
drop policy user_roles_update_master_admin on public.user_roles;
create policy user_roles_update_master_admin on public.user_roles
  for update to authenticated
  using (public.is_master_admin() and role in ('org_owner', 'org_co_owner'))
  with check (public.is_master_admin() and role in ('org_owner', 'org_co_owner')
    and granted_by = (select auth.uid()));
drop policy user_roles_delete_master_admin on public.user_roles;
create policy user_roles_delete_master_admin on public.user_roles
  for delete to authenticated
  using (public.is_master_admin() and role in ('org_owner', 'org_co_owner'));

-- ---------------------------------------------------------------------------
-- Audit actions; only the server writes them
-- ---------------------------------------------------------------------------
do $$
declare v_constraint text;
begin
 select pg_get_constraintdef(oid) into v_constraint from pg_constraint
  where conrelid='public.audit_logs'::regclass and conname='audit_logs_action_check';
 execute 'alter table public.audit_logs drop constraint audit_logs_action_check';
 execute 'alter table public.audit_logs add constraint audit_logs_action_check CHECK (' ||
   substr(v_constraint,8,length(v_constraint)-8) ||
   ' OR action = ANY (ARRAY[''adminAccessChanged''::text,''adminAccessRemoved''::text]))';
end;
$$;

create or replace function public.log_audit_event(p_organization_id uuid,p_action text,
 p_description_en text,p_description_ar text,p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
begin
 if p_action in ('accountDeleted','accountSessionsRevoked','streamForceEnded','streamRemovedFromFeed',
   'appFlagChanged','chatKeywordAdded','chatKeywordUpdated','chatKeywordRemoved',
   'broadcasterHiddenFromMap','broadcasterShownOnMap','organizationVerificationRevoked',
   'streamHiddenFromDiscovery','streamShownInDiscovery',
   'recordingTakenDown','recordingRestored','recordingDeleted',
   'adminAccessChanged','adminAccessRemoved') then
   raise exception 'Server-only audit action' using errcode='42501';
 end if;
 return public.log_audit_event_internal(p_organization_id,p_action,p_description_en,p_description_ar,p_metadata);
end;
$$;
revoke all on function public.log_audit_event(uuid,text,text,text,jsonb) from public,anon;
grant execute on function public.log_audit_event(uuid,text,text,text,jsonb) to authenticated;
