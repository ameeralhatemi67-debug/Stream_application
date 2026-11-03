-- Restore, cancel a series, delete a lesson or a series
-- (20261103240000_restore_cancel_series_delete_lessons.sql).
begin;
set local search_path = public, extensions;
select plan(12);

insert into auth.users(id, email, email_confirmed_at) values
  ('31000000-0000-4000-8000-0000000000a1', 'undo-admin@example.invalid', now()),
  ('31000000-0000-4000-8000-0000000000a2', 'undo-viewer@example.invalid', now());
insert into public.profiles(id, email, display_name_en, display_name_ar, is_streamer, is_verified, personal_broadcast_approved) values
  ('31000000-0000-4000-8000-0000000000a1', 'undo-admin@example.invalid', 'Admin', 'مشرف', false, false, false),
  ('31000000-0000-4000-8000-0000000000a2', 'undo-viewer@example.invalid', 'Viewer', 'مشاهد', false, false, false);
insert into public.user_roles(profile_id, role) values ('31000000-0000-4000-8000-0000000000a1', 'master_admin');
insert into public.preachers(id, name_ar) values ('31000000-0000-4000-8000-0000000000b1', 'داعية');
insert into public.mosques(id, name_ar, district_id) values ('31000000-0000-4000-8000-0000000000c1', 'جامع تجريبي', 'aqrabiyah');

create function pg_temp.as_user(p uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
$$;

set local role authenticated;
select pg_temp.as_user('31000000-0000-4000-8000-0000000000a1');
select lives_ok($$select public.lessons_add(jsonb_build_object('preacher_id', '31000000-0000-4000-8000-0000000000b1',
  'mosque_id', '31000000-0000-4000-8000-0000000000c1', 'type', 'lesson', 'topic', 'fiqh', 'title_ar', 'سلسلة', 'slot', 'isha',
  'dates', jsonb_build_array(public.lessons_today() + 2, public.lessons_today() + 9, public.lessons_today() + 16)))$$, 'U01 a three-session series');

select is(public.lessons_cancel_series((select series_id from public.lessons where title_ar = 'سلسلة' limit 1), 'سفر'), 3, 'U02 cancelling the series cancels all three');
select throws_ok($$select public.lessons_cancel_series((select series_id from public.lessons where title_ar = 'سلسلة' limit 1), 'مرة أخرى')$$, '22023', null,
  'U03 with nothing upcoming left it is refused');
select is(public.lessons_restore_lesson((select id from public.lessons where title_ar = 'سلسلة' and seq = 1), false), 1, 'U04 one session is restored');
select is(public.lessons_restore_lesson((select id from public.lessons where title_ar = 'سلسلة' and seq = 2), true), 2, 'U05 then the rest of the series');
select throws_ok($$select public.lessons_restore_lesson((select id from public.lessons where title_ar = 'سلسلة' and seq = 1), false)$$, '22023', null,
  'U06 an approved session cannot be restored');
select throws_ok($$select public.lessons_delete_lesson((select id from public.lessons where title_ar = 'سلسلة' and seq = 1), null)$$, '22023', null,
  'U07 deleting an upcoming session needs a reason');
select lives_ok($$select public.lessons_delete_lesson((select id from public.lessons where title_ar = 'سلسلة' and seq = 1), 'خطأ')$$, 'U08 with a reason it goes');
select is((select total from public.lesson_series where title_ar = 'سلسلة'), 2, 'U09 the series is renumbered');
select lives_ok($$select public.lessons_delete_lesson((select id from public.lessons where title_ar = 'سلسلة' and seq = 1), 'خطأ')$$, 'U10 delete another');
select is((select count(*)::int from public.lesson_series where title_ar = 'سلسلة'), 0, 'U11 one left: it becomes a single lesson and the series goes');

reset role;
set local role authenticated;
select pg_temp.as_user('31000000-0000-4000-8000-0000000000a2');
select throws_ok($$select public.lessons_delete_lesson((select id from public.lessons where title_ar = 'سلسلة'), 'x')$$, '42501', null, 'U12 a non-admin cannot delete');

select * from finish();
rollback;
