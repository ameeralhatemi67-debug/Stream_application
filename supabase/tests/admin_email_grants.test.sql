-- Admin access by email: both admin pages, one of them, or master admin, set
-- and changed by a master admin (20261022124908_admin_email_grants.sql,
-- 20261101095553_admin_access_by_email.sql).
begin;
set local search_path = public, extensions;
select plan(49);

insert into auth.users(id, email, email_confirmed_at) values
  ('30000000-0000-4000-8000-0000000000b1', 'grants-master@example.invalid', now()),
  ('30000000-0000-4000-8000-0000000000b2', 'grants-admin@example.invalid', now()),
  ('30000000-0000-4000-8000-0000000000b3', 'grants-viewer@example.invalid', now()),
  ('30000000-0000-4000-8000-0000000000b4', 'grants-banned@example.invalid', now());
insert into public.profiles(id, email, display_name_en, display_name_ar) values
  ('30000000-0000-4000-8000-0000000000b1', 'grants-master@example.invalid', 'Master', 'رئيسي'),
  ('30000000-0000-4000-8000-0000000000b2', 'grants-admin@example.invalid', 'Admin', 'مشرف'),
  ('30000000-0000-4000-8000-0000000000b3', 'grants-viewer@example.invalid', 'Viewer', 'مستمع'),
  ('30000000-0000-4000-8000-0000000000b4', 'grants-banned@example.invalid', 'Banned', 'محظور');
insert into public.user_roles(profile_id, role) values
  ('30000000-0000-4000-8000-0000000000b1', 'master_admin'),
  ('30000000-0000-4000-8000-0000000000b2', 'admin');
insert into public.banned_users(profile_id, email, reason) values
  ('30000000-0000-4000-8000-0000000000b4', 'grants-banned@example.invalid', 'test');
insert into public.organizations(id, owner_profile_id, name_en, name_ar) values
  ('30000000-0000-4000-8000-00000000000f', '30000000-0000-4000-8000-0000000000b2', 'Grants Org', 'جهة');

create function pg_temp.as_user(p uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
$$;
create function pg_temp.roles_of(p uuid) returns text language sql as $$
  select coalesce(string_agg(role, ',' order by role), '') from public.user_roles
   where profile_id = p and organization_id is null;
$$;

select is((select count(*)::int from public.admin_email_grants where access = 'master'), 3,
  'E01 the three bootstrap addresses are master admin lines');
select is((select string_agg(email, ',' order by email) from public.admin_email_grants where locked),
  'ameeralhatemi67@gmail.com,polkgvd2@gmail.com', 'E02 the owner''s two addresses are locked');

set local role authenticated;
select pg_temp.as_user('30000000-0000-4000-8000-0000000000b2');
select throws_ok($$select public.admin_set_email_access('someone@example.invalid', 'lessons')$$, '42501', null,
  'E03 a plain admin cannot set admin access');
select throws_ok($$select public.admin_remove_email_grant('someone@example.invalid')$$, '42501', null,
  'E04 nor remove it');
select is((select count(*)::int from public.admin_email_grants), 0, 'E05 nor read the list');

select pg_temp.as_user('30000000-0000-4000-8000-0000000000b3');
select is(public.is_lessons_admin(), false, 'E06 a viewer is not a lessons admin');

-- Choosing what an account may open
select pg_temp.as_user('30000000-0000-4000-8000-0000000000b1');
select throws_ok($$select public.admin_set_email_access('not an email', 'both')$$, '22023', null,
  'E07 an invalid address is refused');
select throws_ok($$select public.admin_set_email_access('a@example.invalid', 'everything')$$, '22023', null,
  'E08 an unknown access is refused');
select throws_ok($$select public.admin_set_email_access('a@example.invalid', null)$$, '22023', null,
  'E09 a missing access is refused');
select is(public.admin_set_email_access('  Grants-Viewer@Example.invalid ', 'lessons'), 'granted',
  'E10 an existing account gets its access at once');
select is(pg_temp.roles_of('30000000-0000-4000-8000-0000000000b3'), 'lessons_admin', 'E11 lessons only is the lessons role');
select pg_temp.as_user('30000000-0000-4000-8000-0000000000b3');
select results_eq($$select public.is_lessons_admin(), public.is_admin_tier()$$,
  $$values (true, false)$$, 'E12 a lessons admin manages lessons but is not admin tier');

select pg_temp.as_user('30000000-0000-4000-8000-0000000000b1');
select is(public.admin_set_email_access('grants-viewer@example.invalid', 'both'), 'granted', 'E13 changed to both pages');
select is(pg_temp.roles_of('30000000-0000-4000-8000-0000000000b3'), 'admin,lessons_admin', 'E14 both is the two roles');
select pg_temp.as_user('30000000-0000-4000-8000-0000000000b3');
select results_eq($$select public.is_lessons_admin(), public.is_admin_tier()$$,
  $$values (true, true)$$, 'E15 and opens both pages');

select pg_temp.as_user('30000000-0000-4000-8000-0000000000b1');
reset role;
insert into public.user_permissions(profile_id, permission_key, granted_by) values
  ('30000000-0000-4000-8000-0000000000b3', 'edit_terms', '30000000-0000-4000-8000-0000000000b1');
set local role authenticated;
select pg_temp.as_user('30000000-0000-4000-8000-0000000000b1');
select is(public.admin_set_email_access('grants-viewer@example.invalid', 'platform'), 'granted', 'E16 changed to the platform page');
select is(pg_temp.roles_of('30000000-0000-4000-8000-0000000000b3'), 'admin', 'E17 the lessons role is gone');
select is((select count(*)::int from public.user_permissions where profile_id = '30000000-0000-4000-8000-0000000000b3'), 1,
  'E18 capability checkboxes stay with the platform page');
select pg_temp.as_user('30000000-0000-4000-8000-0000000000b3');
select results_eq($$select public.is_lessons_admin(), public.is_admin_tier()$$,
  $$values (false, true)$$, 'E19 a platform admin no longer manages lessons');
select throws_ok($$select public.lessons_remove_preacher('00000000-0000-4000-8000-000000000000')$$, '42501', null,
  'E20 and the lessons functions refuse it');

select pg_temp.as_user('30000000-0000-4000-8000-0000000000b1');
select is(public.admin_set_email_access('grants-viewer@example.invalid', 'lessons'), 'granted', 'E21 changed back to lessons');
select is((select count(*)::int from public.user_permissions where profile_id = '30000000-0000-4000-8000-0000000000b3'), 0,
  'E22 leaving the platform page clears the checkboxes');
select is(public.admin_set_email_access('grants-viewer@example.invalid', 'master'), 'granted', 'E23 changed to master admin');
select is(pg_temp.roles_of('30000000-0000-4000-8000-0000000000b3'), 'master_admin', 'E24 master replaces the other roles');
select is(public.admin_set_email_access('grants-viewer@example.invalid', 'both'), 'granted', 'E25 and master can be taken back');
select is(pg_temp.roles_of('30000000-0000-4000-8000-0000000000b3'), 'admin,lessons_admin', 'E26 to exactly the new access');

-- Who may not be changed
select throws_ok($$select public.admin_set_email_access('polkgvd2@gmail.com', 'lessons')$$, '42501', null,
  'E27 a locked line cannot change');
select throws_ok($$select public.admin_remove_email_grant('ameeralhatemi67@gmail.com')$$, '42501', null,
  'E28 nor be removed');
reset role;
insert into public.admin_email_grants(email, access, granted_by) values
  ('grants-master@example.invalid', 'master', '30000000-0000-4000-8000-0000000000b1');
set local role authenticated;
select pg_temp.as_user('30000000-0000-4000-8000-0000000000b1');
select throws_ok($$select public.admin_set_email_access('grants-master@example.invalid', 'lessons')$$, '42501', null,
  'E29 a master admin cannot change their own line');
select throws_ok($$select public.admin_remove_email_grant('grants-master@example.invalid')$$, '42501', null,
  'E30 nor remove it');

-- Platform roles only change through the list
select throws_ok($$insert into public.user_roles(profile_id, role, granted_by) values
  ('30000000-0000-4000-8000-0000000000b4', 'lessons_admin', '30000000-0000-4000-8000-0000000000b1')$$, '42501', null,
  'E31 a master admin cannot write a platform role directly');
delete from public.user_roles where profile_id = '30000000-0000-4000-8000-0000000000b3' and role = 'admin';
select is(pg_temp.roles_of('30000000-0000-4000-8000-0000000000b3'), 'admin,lessons_admin', 'E32 nor delete one directly');
select lives_ok($$insert into public.user_roles(profile_id, role, organization_id, granted_by) values
  ('30000000-0000-4000-8000-0000000000b3', 'org_co_owner', '30000000-0000-4000-8000-00000000000f', '30000000-0000-4000-8000-0000000000b1')$$,
  'E33 organization roles still work');

-- Addresses without an account
select is(public.admin_set_email_access('new-admin@example.invalid', 'lessons'), 'waiting', 'E34 an address without an account waits');
select is(public.admin_set_email_access('new-admin@example.invalid', 'platform'), 'waiting', 'E35 and can be changed while it waits');
select is((select count(*)::int from public.admin_email_grants where applied_at is null and email = 'new-admin@example.invalid' and access = 'platform'), 1,
  'E36 a master admin reads the list, with the address still waiting');
select is(public.admin_set_email_access('grants-banned@example.invalid', 'both'), 'granted', 'E37 a banned account can be listed');
reset role;
select is(pg_temp.roles_of('30000000-0000-4000-8000-0000000000b4'), '', 'E38 but gets no role');

-- The waiting address signs in for the first time.
insert into auth.users(id, email, email_confirmed_at) values
  ('30000000-0000-4000-8000-0000000000b5', 'new-admin@example.invalid', now()),
  ('30000000-0000-4000-8000-0000000000b6', 'unverified@example.invalid', null);
insert into public.profiles(id, email, display_name_en, display_name_ar) values
  ('30000000-0000-4000-8000-0000000000b5', 'new-admin@example.invalid', 'New', 'جديد');
select is(pg_temp.roles_of('30000000-0000-4000-8000-0000000000b5'), 'admin', 'E39 the first sign-in gets the line''s access');
select ok((select applied_at is not null from public.admin_email_grants where email = 'new-admin@example.invalid'),
  'E40 and marks the line applied');

set local role authenticated;
select pg_temp.as_user('30000000-0000-4000-8000-0000000000b1');
select is(public.admin_set_email_access('unverified@example.invalid', 'both'), 'waiting',
  'E41 an unverified email does not count as an account');
reset role;
insert into public.profiles(id, email, display_name_en, display_name_ar) values
  ('30000000-0000-4000-8000-0000000000b6', 'unverified@example.invalid', 'Unverified', 'غير موثق');
select is(pg_temp.roles_of('30000000-0000-4000-8000-0000000000b6'), '', 'E42 and gets no role until the email is verified');

-- Removing a line takes the access away
set local role authenticated;
select pg_temp.as_user('30000000-0000-4000-8000-0000000000b1');
select lives_ok($$select public.admin_remove_email_grant('grants-viewer@example.invalid')$$, 'E43 a master admin removes a line');
select is(pg_temp.roles_of('30000000-0000-4000-8000-0000000000b3'), '', 'E44 the access goes with it');
select is((select count(*)::int from public.user_roles where profile_id = '30000000-0000-4000-8000-0000000000b3'), 1,
  'E45 organization roles stay');

-- Who hears about lessons, and the record of changes
reset role;
select is((select count(*)::int from private.lessons_admins() a where a = '30000000-0000-4000-8000-0000000000b5'), 0,
  'E46 a platform admin is not told about lessons');
select is((select count(*)::int from public.audit_logs where action = 'adminAccessChanged' and actor_email = 'grants-master@example.invalid'),
  10, 'E47 every change is in the audit log');
select is((select metadata->>'email' from public.audit_logs where action = 'adminAccessRemoved' order by created_at desc limit 1),
  'grants-viewer@example.invalid', 'E48 and so is the removal');
set local role authenticated;
select pg_temp.as_user('30000000-0000-4000-8000-0000000000b1');
select throws_ok($$select public.log_audit_event(null, 'adminAccessChanged', 'x', 'x', '{}')$$, '42501', null,
  'E49 nobody can forge those entries');

select * from finish();
rollback;
