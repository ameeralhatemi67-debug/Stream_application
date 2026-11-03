-- Guest preachers, public reads of preachers with public lessons, and the
-- "Not set yet" area (20261103120000_guest_preachers_and_unassigned_area.sql).
begin;
set local search_path = public, extensions;
select plan(9);

insert into auth.users(id, email, email_confirmed_at) values
  ('31000000-0000-4000-8000-0000000000a1', 'guest-admin@example.invalid', now()),
  ('31000000-0000-4000-8000-0000000000a2', 'guest-viewer@example.invalid', now());
insert into public.profiles(id, email, display_name_en, display_name_ar, is_streamer, is_verified, personal_broadcast_approved) values
  ('31000000-0000-4000-8000-0000000000a1', 'guest-admin@example.invalid', 'Admin', 'مشرف', false, false, false),
  ('31000000-0000-4000-8000-0000000000a2', 'guest-viewer@example.invalid', 'Viewer', 'مشاهد', false, false, false);
insert into public.user_roles(profile_id, role) values ('31000000-0000-4000-8000-0000000000a1', 'master_admin');
insert into public.mosques(id, name_ar, district_id) values
  ('31000000-0000-4000-8000-0000000000c1', 'جامع تجريبي', 'unassigned');

create function pg_temp.as_user(p uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
$$;

select ok(exists (select 1 from public.mosque_districts where id = 'unassigned' and city = 'khobar'),
  'G01 the "Not set yet" area exists in Khobar');

set local role authenticated;
select pg_temp.as_user('31000000-0000-4000-8000-0000000000a1');

select lives_ok($$select public.lessons_add_guest_preacher('  الشيخ الضيف  ')$$, 'G02 an admin names a guest preacher');
select ok((select one_off and not listed and name_ar = 'الشيخ الضيف' from public.preachers where one_off),
  'G03 he is trimmed, hidden and flagged one-off');
select throws_ok($$select public.lessons_add_guest_preacher('ab')$$, '22023', null, 'G04 a name that short is refused');
select lives_ok($$select public.lessons_upsert_preacher('{"name_ar":"داعية مسجل","email":"listed@example.invalid"}'::jsonb)$$,
  'G05 a preacher with an email is saved the normal way');
select is((select count(*)::int from public.lessons_roster() x where x->>'name_ar' in ('الشيخ الضيف', 'داعية مسجل')), 1,
  'G06 the roster shows the saved preacher, not the guest');

reset role;
set local role anon;
select is((select count(*)::int from public.preachers where one_off), 0, 'G07 the public cannot read a guest with no public lesson');
reset role;
insert into public.lessons(request_id, type, topic, title_ar, preacher_id, mosque_id, lesson_date, slot, status)
  select gen_random_uuid(), 'lesson', 'fiqh', 'درس تجريبي', id, '31000000-0000-4000-8000-0000000000c1',
    public.lessons_today() + 3, 'isha', 'approved' from public.preachers where one_off;
set local role anon;
select is((select count(*)::int from public.preachers where one_off), 1, 'G08 once his lesson is public, his name can be read');

reset role;
set local role authenticated;
select pg_temp.as_user('31000000-0000-4000-8000-0000000000a2');
select throws_ok($$select public.lessons_add_guest_preacher('داعية غير مخول')$$, '42501', null, 'G09 a non-admin cannot add one');

select * from finish();
rollback;
