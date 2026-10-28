-- Due lesson reminders reach the Lessons inbox and the push devices
-- (20261028120000). Run as supabase_admin.
begin;
set local search_path = public, extensions;
select plan(11);

insert into auth.users(id, email, email_confirmed_at) values
  ('85000000-0000-4000-8000-000000000001', 'remind-ar@example.invalid', now()),
  ('85000000-0000-4000-8000-000000000002', 'remind-en@example.invalid', now()),
  ('85000000-0000-4000-8000-000000000003', 'remind-banned@example.invalid', now());
insert into public.profiles(id, email) values
  ('85000000-0000-4000-8000-000000000001', 'remind-ar@example.invalid'),
  ('85000000-0000-4000-8000-000000000002', 'remind-en@example.invalid'),
  ('85000000-0000-4000-8000-000000000003', 'remind-banned@example.invalid')
  on conflict (id) do nothing;
insert into public.banned_users(profile_id, email, reason) values
  ('85000000-0000-4000-8000-000000000003', 'remind-banned@example.invalid', 'test');
insert into public.preachers(id, name_ar, name_en) values
  ('85000000-0000-4000-8000-0000000000a1', 'فهد السالم', 'Fahd Al-Salem');
insert into public.mosques(id, name_ar, name_en, district_id) values
  ('85000000-0000-4000-8000-0000000000b1', 'جامع الإحسان', 'Al-Ihsan Mosque',
   (select id from public.mosque_districts order by sort, id limit 1));
insert into public.lessons(id, request_id, type, topic, title_ar, title_en, preacher_id, mosque_id,
  lesson_date, slot, status) values
  ('85000000-0000-4000-8000-0000000000c1', '85000000-0000-4000-8000-0000000000d1', 'lesson', 'tafsir',
   'تفسير سورة الكهف', 'Tafsir of Al-Kahf', '85000000-0000-4000-8000-0000000000a1',
   '85000000-0000-4000-8000-0000000000b1', public.lessons_today(), 'isha', 'approved'),
  ('85000000-0000-4000-8000-0000000000c2', '85000000-0000-4000-8000-0000000000d2', 'lesson', 'fiqh',
   'فقه الصيام', '', '85000000-0000-4000-8000-0000000000a1',
   '85000000-0000-4000-8000-0000000000b1', public.lessons_today() + 1, 'maghrib', 'cancelled');
insert into public.schedule_push_devices(token, viewer_profile_id, platform, language_code) values
  ('device-token-arabic-1', '85000000-0000-4000-8000-000000000001', 'android', 'ar'),
  ('device-token-english-1', '85000000-0000-4000-8000-000000000002', 'android', 'en');

insert into public.lesson_reminders(profile_id, lesson_id, lead, remind_at) values
  -- due now, Arabic viewer, at adhan
  ('85000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-0000000000c1', 'adhan', now() - interval '1 minute'),
  -- due now, English viewer, 30 minutes before
  ('85000000-0000-4000-8000-000000000002', '85000000-0000-4000-8000-0000000000c1', '30', now() - interval '2 minutes'),
  -- not due yet
  ('85000000-0000-4000-8000-000000000001', '85000000-0000-4000-8000-0000000000c2', 'day', now() + interval '3 hours'),
  -- due, but the viewer is banned
  ('85000000-0000-4000-8000-000000000003', '85000000-0000-4000-8000-0000000000c1', 'adhan', now() - interval '1 minute');

select throws_ok($$set local role authenticated; select public.claim_due_lesson_reminders()$$, '42501', null,
  'a signed-in account cannot claim reminders');
reset role;

set local role service_role;
create temporary table first_claim as select * from public.claim_due_lesson_reminders();
reset role;
select is((select count(*)::int from first_claim), 2, 'each due reminder is returned with its push device');
select ok((select title_ar = 'تذكير بدرس: تفسير سورة الكهف' and body_ar = 'اليوم بعد صلاة العشاء في جامع الإحسان.'
   and language_code = 'ar' from first_claim where token = 'device-token-arabic-1'),
 'the Arabic reminder names the lesson, the prayer and the mosque');
select ok((select title_en = 'Lesson reminder: Tafsir of Al-Kahf' and body_en = 'Starts in about 30 minutes at Al-Ihsan Mosque.'
   from first_claim where token = 'device-token-english-1'),
 'the English reminder says 30 minutes and the mosque');
select is((select count(*)::int from public.lesson_notifications where route = '/lessons/lesson/85000000-0000-4000-8000-0000000000c1'),
 2, 'both reminders are in the Lessons inbox');
select is((select count(*)::int from public.lesson_notifications where profile_id = '85000000-0000-4000-8000-000000000003'),
 0, 'a banned viewer gets nothing');

set local role service_role;
create temporary table second_claim as select * from public.claim_due_lesson_reminders();
reset role;
select is((select count(*)::int from second_claim), 0, 'a reminder is delivered once');

-- A cancelled lesson's reminder is skipped when it falls due.
update public.lesson_reminders set remind_at = now() - interval '1 minute'
 where lesson_id = '85000000-0000-4000-8000-0000000000c2';
set local role service_role;
create temporary table cancelled_claim as select * from public.claim_due_lesson_reminders();
reset role;
select ok((select count(*) = 0 from cancelled_claim) and (select sent_at is not null from public.lesson_reminders
   where lesson_id = '85000000-0000-4000-8000-0000000000c2'),
 'a cancelled lesson''s reminder is closed without a message');

-- A new time makes a delivered reminder due again.
update public.lesson_reminders set remind_at = now() + interval '1 hour'
 where profile_id = '85000000-0000-4000-8000-000000000002';
select ok((select sent_at is null from public.lesson_reminders where profile_id = '85000000-0000-4000-8000-000000000002'),
 'a changed reminder time re-arms the reminder');

-- A reminder more than six hours late is not sent stale.
update public.lesson_reminders set remind_at = now() - interval '7 hours'
 where profile_id = '85000000-0000-4000-8000-000000000002';
set local role service_role;
create temporary table late_claim as select * from public.claim_due_lesson_reminders();
reset role;
select is((select count(*)::int from late_claim), 0, 'a reminder six hours late is skipped');

-- The viewer reads their reminder through the inbox.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"85000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is((select count(*)::int from public.lesson_notifications), 1, 'the viewer sees only their own reminder');
reset role;

select * from finish();
rollback;
