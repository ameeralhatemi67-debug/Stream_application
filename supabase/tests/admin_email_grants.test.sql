-- Admin access by email and the lessons-only admin role
-- (20261022100000_admin_email_grants.sql).
begin;
set local search_path = public, extensions;
select plan(20);

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

create function pg_temp.as_user(p uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
$$;
create function pg_temp.has_role(p uuid, r text) returns boolean language sql as $$
  select exists (select 1 from public.user_roles where profile_id = p and role = r and organization_id is null);
$$;

select is((select count(*)::int from public.admin_email_grants where role = 'master_admin'), 3,
  'E01 the three bootstrap addresses are master admin entries');

set local role authenticated;
select pg_temp.as_user('30000000-0000-4000-8000-0000000000b2');
select throws_ok($$select public.admin_add_email_grant('someone@example.invalid')$$, '42501', null,
  'E02 a plain admin cannot add admin emails');
select is((select count(*)::int from public.admin_email_grants), 0,
  'E03 a plain admin cannot read the list');

select pg_temp.as_user('30000000-0000-4000-8000-0000000000b3');
select is(public.is_lessons_admin(), false, 'E04 a viewer is not a lessons admin');

select pg_temp.as_user('30000000-0000-4000-8000-0000000000b1');
select throws_ok($$select public.admin_add_email_grant('not an email')$$, '22023', null,
  'E05 an invalid address is refused');
select is(public.admin_add_email_grant('  Grants-Viewer@Example.invalid '), 'granted',
  'E06 an existing account becomes an admin at once');
select is(pg_temp.has_role('30000000-0000-4000-8000-0000000000b3', 'admin'), true,
  'E07 its admin role is granted by the master admin');
select is(public.admin_add_email_grant('new-admin@example.invalid'), 'waiting',
  'E08 an address without an account waits');
select is(public.admin_add_email_grant('new-admin@example.invalid'), 'waiting',
  'E09 adding the same address twice is harmless');
select is((select count(*)::int from public.admin_email_grants where applied_at is null and email = 'new-admin@example.invalid'), 1,
  'E10 a master admin reads the list, with the address still waiting');
select is(public.admin_add_email_grant('grants-banned@example.invalid'), 'granted',
  'E11 a banned account can be listed');
reset role;
select is(pg_temp.has_role('30000000-0000-4000-8000-0000000000b4', 'admin'), false,
  'E12 but a banned account gets no role');

-- The waiting address signs in for the first time.
insert into auth.users(id, email, email_confirmed_at) values
  ('30000000-0000-4000-8000-0000000000b5', 'new-admin@example.invalid', now()),
  ('30000000-0000-4000-8000-0000000000b6', 'unverified@example.invalid', null);
insert into public.profiles(id, email, display_name_en, display_name_ar) values
  ('30000000-0000-4000-8000-0000000000b5', 'new-admin@example.invalid', 'New', 'جديد');
select is(pg_temp.has_role('30000000-0000-4000-8000-0000000000b5', 'admin'), true,
  'E13 the first sign-in with a listed address makes an admin');
select ok((select applied_at is not null from public.admin_email_grants where email = 'new-admin@example.invalid'),
  'E14 and marks the entry applied');

set local role authenticated;
select pg_temp.as_user('30000000-0000-4000-8000-0000000000b1');
select is(public.admin_add_email_grant('unverified@example.invalid'), 'waiting',
  'E15 an unverified email does not count as an account');
reset role;
insert into public.profiles(id, email, display_name_en, display_name_ar) values
  ('30000000-0000-4000-8000-0000000000b6', 'unverified@example.invalid', 'Unverified', 'غير موثق');
select is(pg_temp.has_role('30000000-0000-4000-8000-0000000000b6', 'admin'), false,
  'E16 and gets no role until the email is verified');

set local role authenticated;
select pg_temp.as_user('30000000-0000-4000-8000-0000000000b1');
select lives_ok($$select public.admin_remove_email_grant('new-admin@example.invalid')$$,
  'E17 a master admin removes an entry');
select is(pg_temp.has_role('30000000-0000-4000-8000-0000000000b5', 'admin'), true,
  'E18 an admin role already given stays');

-- Lessons-only admin
select lives_ok($$insert into public.user_roles(profile_id, role, granted_by) values
  ('30000000-0000-4000-8000-0000000000b3', 'lessons_admin', '30000000-0000-4000-8000-0000000000b1')$$,
  'E19 a master admin grants the lessons admin role');
reset role;
delete from public.user_roles where profile_id = '30000000-0000-4000-8000-0000000000b3' and role = 'admin';
set local role authenticated;
select pg_temp.as_user('30000000-0000-4000-8000-0000000000b3');
select results_eq($$select public.is_lessons_admin(), public.is_admin_tier()$$,
  $$values (true, false)$$, 'E20 a lessons admin manages lessons but is not admin tier');

select * from finish();
rollback;
