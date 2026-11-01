-- Lesson length and the map's schedule read
-- (20261101095634_lesson_length_and_map_schedules.sql).
begin;
set local search_path = public, extensions;
select plan(14);

insert into auth.users(id, email, email_confirmed_at) values
  ('31000000-0000-4000-8000-0000000000a1', 'map-admin@example.invalid', now()),
  ('31000000-0000-4000-8000-0000000000a2', 'map-channel@example.invalid', now()),
  ('31000000-0000-4000-8000-0000000000a3', 'map-hidden@example.invalid', now());
insert into public.profiles(id, email, display_name_en, display_name_ar, is_streamer, is_verified, personal_broadcast_approved) values
  ('31000000-0000-4000-8000-0000000000a1', 'map-admin@example.invalid', 'Admin', 'مشرف', false, false, false),
  ('31000000-0000-4000-8000-0000000000a2', 'map-channel@example.invalid', 'Channel', 'قناة', true, true, true),
  ('31000000-0000-4000-8000-0000000000a3', 'map-hidden@example.invalid', 'Hidden', 'مخفي', true, true, true);
insert into public.user_roles(profile_id, role) values
  ('31000000-0000-4000-8000-0000000000a1', 'master_admin');
insert into public.preachers(id, name_ar) values ('31000000-0000-4000-8000-0000000000b1', 'داعية');
insert into public.mosques(id, name_ar, district_id, verified) values
  ('31000000-0000-4000-8000-0000000000c1', 'مسجد', 'aqrabiyah', true);
insert into public.upcoming_schedules(id, streamer_profile_id, kind, local_time, weekdays, title_en, title_ar) values
  ('31000000-0000-4000-8000-0000000000d1', '31000000-0000-4000-8000-0000000000a2', 'weekly', '20:00', '{1,3}', 'Weekly', 'أسبوعي'),
  ('31000000-0000-4000-8000-0000000000d2', '31000000-0000-4000-8000-0000000000a3', 'weekly', '20:00', '{1}', 'Hidden', 'مخفي');
insert into public.upcoming_schedules(id, streamer_profile_id, kind, local_time, one_time_start_at, title_en, title_ar)
select v.id::uuid, '31000000-0000-4000-8000-0000000000a2', 'once',
  (date_trunc('minute', now() + v.after) at time zone 'Asia/Riyadh')::time,
  date_trunc('minute', now() + v.after), v.en, v.ar
from (values
  ('31000000-0000-4000-8000-0000000000d3', interval '1 day', 'Soon', 'قريبًا'),
  ('31000000-0000-4000-8000-0000000000d4', interval '2 days', 'Cancelled', 'ملغى')) v(id, after, en, ar);
update public.upcoming_schedules set cancelled_at = now() where id = '31000000-0000-4000-8000-0000000000d4';
-- This channel was banned after publishing.
insert into public.banned_users(profile_id, email, reason) values
  ('31000000-0000-4000-8000-0000000000a3', 'map-hidden@example.invalid', 'test');

create function pg_temp.as_user(p uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
$$;
create function pg_temp.lesson_body(p_minutes text) returns jsonb language sql as $$
  select jsonb_build_object('preacher_id', '31000000-0000-4000-8000-0000000000b1',
    'mosque_id', '31000000-0000-4000-8000-0000000000c1', 'type', 'talk', 'topic', 'fiqh', 'title_ar', 'درس',
    'slot', 'isha', 'dates', jsonb_build_array(public.lessons_today() + 2))
    || case when p_minutes is null then '{}'::jsonb else jsonb_build_object('duration_minutes', p_minutes) end;
$$;

set local role authenticated;
select pg_temp.as_user('31000000-0000-4000-8000-0000000000a1');

select lives_ok($$select public.lessons_add(pg_temp.lesson_body(null))$$, 'D01 a lesson can be added without a length');
select is((select duration_minutes from public.lessons where title_ar = 'درس' limit 1), null,
  'D02 and then has none, so the default for its type applies');
select throws_ok($$update public.lessons set duration_minutes = 10$$, '42501', null, 'D03 the table stays closed to direct writes');
reset role;
delete from public.lessons where title_ar = 'درس';
set local role authenticated;
select pg_temp.as_user('31000000-0000-4000-8000-0000000000a1');

select lives_ok($$select public.lessons_add(pg_temp.lesson_body('90'))$$, 'D04 an admin sets a length');
select is((select duration_minutes from public.lessons where title_ar = 'درس' limit 1), 90, 'D05 and it is stored');
select lives_ok($$select public.lessons_edit_lesson((select id from public.lessons where title_ar = 'درس' limit 1),
  '{"duration_minutes": 45}'::jsonb)$$, 'D06 an admin changes it');
select is((select duration_minutes from public.lessons where title_ar = 'درس' limit 1), 45, 'D07 and the change is stored');
select lives_ok($$select public.lessons_edit_lesson((select id from public.lessons where title_ar = 'درس' limit 1),
  '{"title_en": "Lesson"}'::jsonb)$$, 'D08 another edit');
select is((select duration_minutes from public.lessons where title_ar = 'درس' limit 1), 45, 'D09 leaves the length alone');
select throws_ok($$select public.lessons_edit_lesson((select id from public.lessons where title_ar = 'درس' limit 1),
  '{"duration_minutes": 1000}'::jsonb)$$, '23514', null, 'D10 an impossible length is refused');

-- The schedule read is public and shows only what a channel may publish.
reset role;
set local role anon;
select set_config('request.jwt.claims', '', true);
select is((select count(*)::int from public.list_map_schedules() j
  where j->>'streamer_profile_id' = '31000000-0000-4000-8000-0000000000a2'), 2,
  'D11 a guest reads a channel''s weekly and one-time schedules, not the cancelled one');
select is((select count(*)::int from public.list_map_schedules() j
  where j->>'streamer_profile_id' = '31000000-0000-4000-8000-0000000000a3'), 0,
  'D12 a channel that may not publish stays out');
select is((select j->>'title_en' from public.list_map_schedules() j where j->>'kind' = 'weekly'
  and j->>'streamer_profile_id' = '31000000-0000-4000-8000-0000000000a2'), 'Weekly', 'D13 with what the map needs');
select ok((select bool_and(not (j ? 'description_en') and not (j ? 'created_by')) from public.list_map_schedules() j),
  'D14 and nothing more');

select * from finish();
rollback;
