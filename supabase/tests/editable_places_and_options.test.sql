-- Admin-added topics, languages, audiences, cities and areas
-- (20261103200000_editable_places_and_options.sql).
begin;
set local search_path = public, extensions;
select plan(14);

insert into auth.users(id, email, email_confirmed_at) values
  ('31000000-0000-4000-8000-0000000000a1', 'places-admin@example.invalid', now()),
  ('31000000-0000-4000-8000-0000000000a2', 'places-viewer@example.invalid', now());
insert into public.profiles(id, email, display_name_en, display_name_ar, is_streamer, is_verified, personal_broadcast_approved) values
  ('31000000-0000-4000-8000-0000000000a1', 'places-admin@example.invalid', 'Admin', 'مشرف', false, false, false),
  ('31000000-0000-4000-8000-0000000000a2', 'places-viewer@example.invalid', 'Viewer', 'مشاهد', false, false, false);
insert into public.user_roles(profile_id, role) values ('31000000-0000-4000-8000-0000000000a1', 'master_admin');
insert into public.preachers(id, name_ar) values ('31000000-0000-4000-8000-0000000000b1', 'داعية');
insert into public.mosques(id, name_ar, district_id) values ('31000000-0000-4000-8000-0000000000c1', 'جامع تجريبي', 'aqrabiyah');

create function pg_temp.as_user(p uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
$$;
create function pg_temp.lesson_body(p_topic text, p_language text) returns jsonb language sql as $$
  select jsonb_build_object('preacher_id', '31000000-0000-4000-8000-0000000000b1',
    'mosque_id', '31000000-0000-4000-8000-0000000000c1', 'type', 'lesson', 'topic', p_topic, 'title_ar', 'درس',
    'language', p_language, 'slot', 'isha', 'dates', jsonb_build_array(public.lessons_today() + 2));
$$;

select is((select count(*)::int from public.mosque_cities), 5, 'E01 the five cities are rows');
select is((select count(*)::int from public.lesson_options where built_in), 20, 'E02 the built-in topics, languages and audiences are rows');
select is((select count(*)::int from public.mosque_districts where latitude is not null), 13, 'E03 the thirteen areas have a map centre');
select throws_ok($$insert into public.preachers(name_ar, city) values ('داعية', 'nowhere')$$, '23503', null, 'E04 a preacher city must be a real city');

set local role authenticated;
select pg_temp.as_user('31000000-0000-4000-8000-0000000000a1');

select is(public.lessons_add_option('topic', 'علوم الآلة', '', false), public.lessons_add_option('topic', 'علوم الآلة', '', false),
  'E05 the same name gives the same option');
select ok((select not permanent from public.lesson_options where name_ar = 'علوم الآلة'), 'E06 an option for one lesson is not kept');
select lives_ok($$select public.lessons_add_option('topic', 'علوم الآلة', '', true)$$, 'E07 asking again to keep it');
select ok((select permanent from public.lesson_options where name_ar = 'علوم الآلة'), 'E08 keeps it');
select lives_ok($$select public.lessons_add(pg_temp.lesson_body((select code from public.lesson_options where name_ar = 'علوم الآلة'), 'ar'))$$,
  'E09 a lesson can use an added topic');
select throws_ok($$select public.lessons_add(pg_temp.lesson_body('nope', 'ar'))$$, '23514', null, 'E10 an unknown topic is refused');
select lives_ok($$select public.lessons_add_district(public.lessons_add_city('الجبيل', 'Jubail', 27.01, 49.66), 'حي تجريبي', '', 27.02, 49.65)$$,
  'E11 an admin adds a city and an area');
select throws_ok($$select public.lessons_add_city('الجبيل', '', null, null)$$, '23505', null, 'E12 the same city twice is refused');

reset role;
set local role anon;
select is((select count(*)::int from public.mosque_cities), 6, 'E13 the public can read the cities');

reset role;
set local role authenticated;
select pg_temp.as_user('31000000-0000-4000-8000-0000000000a2');
select throws_ok($$select public.lessons_add_option('topic', 'موضوع', '', true)$$, '42501', null, 'E14 a non-admin cannot add an option');

select * from finish();
rollback;
