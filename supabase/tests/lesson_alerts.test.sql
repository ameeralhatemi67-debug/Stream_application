-- Lesson alerts reach the phone (20261101170000_lesson_alerts_reach_the_phone).
-- Run as supabase_admin.
begin;
set local search_path = public, extensions;
select plan(44);

create function pg_temp.u(n integer) returns uuid language sql immutable as
  $$ select ('87000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.act_as(p uuid) returns void language sql as
  $$ select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true) $$;
-- As if each claim's two-minute lease had run out.
create function pg_temp.leases_over() returns void language sql as
  $$ update private.lesson_notification_deliveries set claimed_until = now() - interval '1 second' where sent_at is null $$;
create function pg_temp.notices(p uuid, p_title text) returns integer language sql as
  $$ select count(*)::int from public.lesson_notifications where profile_id = p and title_en = p_title $$;
create function pg_temp.lesson(p_id uuid, p_preacher uuid, p_mosque uuid, p_days integer, p_slot text, p_title text,
  p_streamed boolean default false, p_series uuid default null) returns void language sql as $$
  insert into public.lessons(id, request_id, series_id, seq, type, topic, title_ar, title_en, preacher_id, mosque_id,
    lesson_date, slot, streamed, status)
  values (p_id, gen_random_uuid(), p_series, case when p_series is null then null else 1 end, 'lesson', 'tafsir',
    p_title || ' بالعربية', p_title, p_preacher, p_mosque, public.lessons_today() + p_days, p_slot, p_streamed, 'approved');
$$;

-- 1 admin, 2 reminder, 3 follows the preacher, 4 the mosque, 5 the series,
-- 6 preacher and mosque, 7 lesson alerts off, 8 preacher and channel,
-- 9 the preacher's own account, 10 nobody in particular.
insert into auth.users(id, email, email_confirmed_at)
  select pg_temp.u(n), 'alert-' || n || '@example.invalid', now() from generate_series(1, 10) n;
insert into public.profiles(id, email, display_name_en, display_name_ar, is_streamer, is_verified)
  select pg_temp.u(n), 'alert-' || n || '@example.invalid', 'Account ' || n, 'حساب ' || n, n = 9, n = 9
  from generate_series(1, 10) n
  on conflict (id) do update set is_streamer = excluded.is_streamer, is_verified = excluded.is_verified;
insert into public.user_roles(profile_id, role) values (pg_temp.u(1), 'lessons_admin');
insert into public.preachers(id, name_ar, name_en, linked_profile_id) values
  (pg_temp.u(101), 'فهد السالم', 'Fahd Al-Salem', pg_temp.u(9)),
  (pg_temp.u(102), 'إقبال أحمد', 'Iqbal Ahmad', null),
  (pg_temp.u(103), 'سالم علي', 'Salem Ali', null);
insert into public.mosques(id, name_ar, name_en, district_id)
  select pg_temp.u(110 + n), 'جامع ' || n, 'Mosque ' || n, (select id from public.mosque_districts order by sort, id limit 1)
  from generate_series(1, 2) n;
insert into public.lesson_series(id, request_id, preacher_id, mosque_id, title_ar, title_en, type, topic, language,
  audience, slot, total, status)
values (pg_temp.u(121), gen_random_uuid(), pg_temp.u(101), pg_temp.u(111), 'سلسلة', 'Series', 'lesson', 'tafsir', 'ar',
  'all', 'isha', 3, 'approved');
select pg_temp.lesson(pg_temp.u(201), pg_temp.u(101), pg_temp.u(111), 3, 'isha', 'Tafsir of Al-Kahf', false, pg_temp.u(121));

insert into public.lesson_reminders(profile_id, lesson_id, lead, remind_at) values
  (pg_temp.u(2), pg_temp.u(201), 'adhan', now() + interval '3 days');
insert into public.lesson_follows(profile_id, kind, target_id) values
  (pg_temp.u(3), 'preacher', pg_temp.u(101)),
  (pg_temp.u(4), 'mosque', pg_temp.u(111)),
  (pg_temp.u(5), 'series', pg_temp.u(121)),
  (pg_temp.u(6), 'preacher', pg_temp.u(101)),
  (pg_temp.u(6), 'mosque', pg_temp.u(111)),
  (pg_temp.u(7), 'preacher', pg_temp.u(101)),
  (pg_temp.u(8), 'preacher', pg_temp.u(101));
insert into public.follows(follower_profile_id, target_id) values (pg_temp.u(8), pg_temp.u(9)::text);
insert into public.schedule_push_devices(token, viewer_profile_id, platform, language_code)
  select 'device-token-' || lpad(n::text, 8, '0'), pg_temp.u(n), 'android', case when n = 2 then 'ar' else 'en' end
  from generate_series(2, 10) n;
insert into public.notification_push_preferences(viewer_profile_id, lessons_enabled) values (pg_temp.u(7), false);

-- ---------------------------------------------------------------- new lesson
select pg_temp.act_as(pg_temp.u(1));
select public.lessons_add(jsonb_build_object('preacher_id', pg_temp.u(101), 'mosque_id', pg_temp.u(111),
  'title_ar', 'درس الفجر', 'title_en', 'Dawn lesson', 'type', 'lesson', 'topic', 'fiqh', 'slot', 'fajr',
  'dates', jsonb_build_array(public.lessons_today() + 9)));
select is(pg_temp.notices(pg_temp.u(3), 'New lesson from a preacher you follow'), 1, 'N01 the preacher''s follower hears why');
select is(pg_temp.notices(pg_temp.u(4), 'New lesson at a mosque you follow'), 1, 'N02 the mosque''s follower hears why');
select ok((select title_ar = 'درس جديد في مسجد تتابعه' from public.lesson_notifications where profile_id = pg_temp.u(4)),
  'N03 and in Arabic');
select is((select count(*)::int from public.lesson_notifications where profile_id = pg_temp.u(6)
    and title_en = 'New lesson from a preacher you follow'), 1, 'N04 following both gives one alert, for the preacher');
select is(pg_temp.notices(pg_temp.u(6), 'New lesson at a mosque you follow'), 0, 'N05 and not a second for the mosque');
select ok((select push_until between now() + interval '23 hours' and now() + interval '25 hours'
    from public.lesson_notifications where profile_id = pg_temp.u(3)), 'N06 a notice may go out as a push for a day');
delete from public.lesson_notifications;

-- ------------------------------------------------------------------ cancelled
select is(public.lessons_cancel_lesson(pg_temp.u(201), 'سفر الشيخ'), 7, 'C01 the count is everyone told');
select is((select count(distinct profile_id)::int from public.lesson_notifications
    where title_en = 'Cancelled: Tafsir of Al-Kahf' and route = '/lessons/lesson/' || pg_temp.u(201)),
  7, 'C02 reminder, preacher, mosque and series followers each get it');
select is(pg_temp.notices(pg_temp.u(5), 'Cancelled: Tafsir of Al-Kahf'), 1, 'C03 a series follower is told');
select is((select count(*)::int from public.lesson_notifications where profile_id in (pg_temp.u(1), pg_temp.u(10))),
  0, 'C04 the admin and a stranger are not');

-- ---------------------------------------------------------------- the queue
set local role service_role;
create temporary table claim_1 on commit drop as select * from public.claim_lesson_pushes();
reset role;
select is((select count(*)::int from claim_1), 7, 'Q01 one push per device: six viewers and the preacher''s account');
select is((select count(*)::int from claim_1 where profile_id = pg_temp.u(7)), 0, 'Q02 lesson alerts switched off: no push');
select is(pg_temp.notices(pg_temp.u(7), 'Cancelled: Tafsir of Al-Kahf'), 1, 'Q03 the inbox still has it');
select ok((select language_code = 'ar' and title_ar = 'أُلغي موعد: Tafsir of Al-Kahf بالعربية'
    and body_ar like '% — سفر الشيخ' and route = '/lessons/lesson/' || pg_temp.u(201) and ttl_seconds between 86000 and 86400
    from claim_1 where profile_id = pg_temp.u(2)), 'Q04 the push carries the words, the page and how long it is good for');

set local role service_role;
create temporary table claim_2 on commit drop as select * from public.claim_lesson_pushes();
reset role;
select is((select count(*)::int from claim_2), 0, 'Q05 a claimed push is not claimed again while its lease runs');

select pg_temp.leases_over();
update private.lesson_notification_deliveries set sent_at = now()
 where token <> 'device-token-00000003';
set local role service_role;
create temporary table claim_3 on commit drop as select * from public.claim_lesson_pushes();
reset role;
select ok((select count(*) = 1 and bool_and(profile_id = pg_temp.u(3)) from claim_3),
  'Q06 an unsent push is retried once its lease ends, and a sent one is not');

set local role service_role;
select public.lesson_push_sent(notification_id, token) from claim_3;
reset role;
select ok((select sent_at is not null and claimed_until is null from private.lesson_notification_deliveries
    where token = 'device-token-00000003'), 'Q07 a sent push is recorded');

-- Read, stale, given up on and banned: nothing more goes out.
delete from private.lesson_notification_deliveries;
select pg_temp.act_as(pg_temp.u(3));
select public.lessons_mark_notifications_read(array(select id from public.lesson_notifications where profile_id = pg_temp.u(3)));
update public.lesson_notifications set push_until = now() - interval '1 minute' where profile_id = pg_temp.u(5);
insert into public.banned_users(profile_id, email, reason) values (pg_temp.u(6), 'alert-6@example.invalid', 'test');
set local role service_role;
create temporary table claim_4 on commit drop as select * from public.claim_lesson_pushes();
reset role;
select is((select count(*)::int from claim_4 where profile_id in (pg_temp.u(3), pg_temp.u(5), pg_temp.u(6))),
  0, 'Q08 a read, stale or banned account''s notice is not sent');
delete from public.banned_users where profile_id = pg_temp.u(6);
update private.lesson_notification_deliveries set attempts = 5, claimed_until = null where token = 'device-token-00000004';
set local role service_role;
create temporary table claim_5 on commit drop as select * from public.claim_lesson_pushes();
reset role;
select is((select count(*)::int from claim_5 where profile_id = pg_temp.u(4)), 0, 'Q09 five failed sends end the retries');
delete from public.lesson_notifications;

-- ---------------------------------------------------------------------- moved
select pg_temp.lesson(pg_temp.u(203), pg_temp.u(102), pg_temp.u(111), 5, 'maghrib', 'Moved lesson');
insert into public.lesson_reminders(profile_id, lesson_id, lead, remind_at, sent_at) values
  (pg_temp.u(2), pg_temp.u(203), 'adhan', now() + interval '5 days', now());
insert into public.lesson_follows(profile_id, kind, target_id) values (pg_temp.u(10), 'mosque', pg_temp.u(112));
select pg_temp.act_as(pg_temp.u(1));
select public.lessons_edit_lesson(pg_temp.u(203), jsonb_build_object('title_en', 'Moved lesson, new title'));
select is((select count(*)::int from public.lesson_notifications), 0, 'M01 a new title alone tells nobody');
select public.lessons_edit_lesson(pg_temp.u(203), jsonb_build_object('mosque_id', pg_temp.u(112),
  'lesson_date', public.lessons_today() + 6));
select is((select count(distinct profile_id)::int from public.lesson_notifications
    where title_en = 'A lesson time or place changed' and profile_id in (pg_temp.u(2), pg_temp.u(4), pg_temp.u(10))),
  3, 'M02 the reminder, the old mosque''s and the new mosque''s followers are told');
select ok((select body_en = 'Moved lesson, new title, ' || to_char(public.lessons_today() + 6, 'YYYY-MM-DD')
    from public.lesson_notifications where profile_id = pg_temp.u(2)), 'M03 the notice names the new date');
select ok((select remind_at > now() + interval '5 days 23 hours' and sent_at is null from public.lesson_reminders
    where lesson_id = pg_temp.u(203)), 'M04 the reminder moves with the lesson and is due again');
delete from public.lesson_notifications;

-- ---------------------------------------------------------- preacher removed
select pg_temp.lesson(pg_temp.u(204), pg_temp.u(103), pg_temp.u(111), 2, 'isha', 'First');
select pg_temp.lesson(pg_temp.u(205), pg_temp.u(103), pg_temp.u(111), 4, 'isha', 'Second');
select public.lessons_remove_preacher(pg_temp.u(103));
select is(pg_temp.notices(pg_temp.u(4), 'Lessons cancelled: Salem Ali'), 1, 'R01 a follower hears once, however many lessons went');
delete from public.lesson_notifications;

-- ----------------------------------------------------------------- going live
insert into public.lessons(id, request_id, type, topic, title_ar, title_en, preacher_id, mosque_id, lesson_date, slot,
  exact_time, streamed, status)
values (pg_temp.u(206), gen_random_uuid(), 'lesson', 'tafsir', 'درس مباشر', 'Live lesson', pg_temp.u(101), pg_temp.u(111),
  public.lessons_today(), 'isha', (now() at time zone 'Asia/Riyadh')::time, true, 'approved');
insert into public.lesson_reminders(profile_id, lesson_id, lead, remind_at) values
  (pg_temp.u(10), pg_temp.u(206), 'day', now() + interval '1 day');
insert into public.broadcast_sessions(id, owner_id, state, broadcast_type, stream_id, device_id, sender_mode, accepted_at,
  scheduled_start_at, expected_end_at, title_en, title_ar)
values (pg_temp.u(301), pg_temp.u(9), 'preparing', 'liveVideo', 'eeeeeeeeee1', 'obs', 'obs_laptop', now(), now(),
  now() + interval '1 hour', 'Live', 'مباشر');
select is((select count(*)::int from public.lesson_notifications where title_en like 'Live now%'), 0, 'L01 preparing says nothing');
update public.broadcast_sessions set state = 'live' where id = pg_temp.u(301);
select is((select count(distinct profile_id)::int from public.lesson_notifications where title_en = 'Live now: Live lesson'
    and profile_id in (pg_temp.u(3), pg_temp.u(4), pg_temp.u(10))), 3, 'L02 followers and the reminder hear it is live');
select is(pg_temp.notices(pg_temp.u(8), 'Live now: Live lesson'), 0, 'L03 a channel follower hears through the channel, not twice');
select is((select count(*)::int from public.org_v1_events where kind = 'show_live' and recipient_profile_id = pg_temp.u(8)),
  1, 'L04 and does hear through the channel');
select is(pg_temp.notices(pg_temp.u(9), 'Live now: Live lesson'), 0, 'L05 the preacher is not told of their own live');
select ok((select body_en = 'With Fahd Al-Salem' and route = '/lessons/lesson/' || pg_temp.u(206) and icon = 'radio'
    and push_until between now() + interval '29 minutes' and now() + interval '31 minutes'
    from public.lesson_notifications where profile_id = pg_temp.u(3)), 'L06 a live alert goes stale in half an hour');
update public.broadcast_sessions set state = 'preparing' where id = pg_temp.u(301);
update public.broadcast_sessions set state = 'live' where id = pg_temp.u(301);
select is(pg_temp.notices(pg_temp.u(3), 'Live now: Live lesson'), 1, 'L07 coming back on air does not alert again');

update public.broadcast_sessions set state = 'ended' where id = pg_temp.u(301);
delete from public.lesson_notifications;
insert into public.broadcast_sessions(id, owner_id, state, broadcast_type, stream_id, device_id, sender_mode, accepted_at,
  scheduled_start_at, expected_end_at, title_en, title_ar, hidden_from_discovery)
values (pg_temp.u(302), pg_temp.u(9), 'live', 'liveVideo', 'eeeeeeeeee2', 'obs', 'obs_laptop', now(), now(),
  now() + interval '1 hour', 'Hidden', 'مخفي', true);
select is((select count(*)::int from public.lesson_notifications where title_en like 'Live now%'), 0, 'L08 a hidden broadcast says nothing');
update public.broadcast_sessions set state = 'ended' where id = pg_temp.u(302);

update public.lessons set exact_time = ((now() at time zone 'Asia/Riyadh') + interval '3 hours')::time where id = pg_temp.u(206);
insert into public.broadcast_sessions(id, owner_id, state, broadcast_type, stream_id, device_id, sender_mode, accepted_at,
  scheduled_start_at, expected_end_at, title_en, title_ar)
values (pg_temp.u(303), pg_temp.u(9), 'live', 'liveVideo', 'eeeeeeeeee3', 'obs', 'obs_laptop', now(), now(),
  now() + interval '1 hour', 'Earlier', 'قبل');
select is((select count(*)::int from public.lesson_notifications where title_en like 'Live now%'), 0, 'L09 a stream hours before the lesson is not the lesson');
update public.broadcast_sessions set state = 'ended' where id = pg_temp.u(303);

-- A broken alert must never stop a broadcast.
update public.lessons set exact_time = (now() at time zone 'Asia/Riyadh')::time where id = pg_temp.u(206);
alter function private.lesson_audience(public.lessons) rename to lesson_audience_away;
insert into public.broadcast_sessions(id, owner_id, state, broadcast_type, stream_id, device_id, sender_mode, accepted_at,
  scheduled_start_at, expected_end_at, title_en, title_ar)
values (pg_temp.u(304), pg_temp.u(9), 'preparing', 'liveVideo', 'eeeeeeeeee4', 'obs', 'obs_laptop', now(), now(),
  now() + interval '1 hour', 'Broken', 'معطل');
select lives_ok($$update public.broadcast_sessions set state = 'live' where id = pg_temp.u(304)$$,
  'L10 the broadcast goes live when the alert fails');
alter function private.lesson_audience_away(public.lessons) rename to lesson_audience;
update public.broadcast_sessions set state = 'ended' where id = pg_temp.u(304);

select ok((select bool_and(ok) from (values
    (private.lesson_is_near((select l from public.lessons l where l.id = pg_temp.u(203)),
      (select lesson_date from public.lessons where id = pg_temp.u(203)) + time '18:30'), true),
    (private.lesson_is_near((select l from public.lessons l where l.id = pg_temp.u(203)),
      (select lesson_date from public.lessons where id = pg_temp.u(203)) + time '09:00'), false)) v(got, want),
    lateral (select got = want as ok) x), 'W01 a Maghrib lesson matches the evening, not the morning');

-- --------------------------------------------------------------------- digest
delete from public.lesson_notifications;
delete from private.lesson_digest_days;
select pg_temp.lesson(pg_temp.u(211), pg_temp.u(101), pg_temp.u(111), 1, 'isha', 'Fourth', false, null);
select pg_temp.lesson(pg_temp.u(212), pg_temp.u(101), pg_temp.u(111), 1, 'fajr', 'First', false, null);
select pg_temp.lesson(pg_temp.u(213), pg_temp.u(101), pg_temp.u(111), 1, 'dhuhr', 'Second', false, pg_temp.u(121));
select pg_temp.lesson(pg_temp.u(214), pg_temp.u(101), pg_temp.u(111), 1, 'asr', 'Third', false, null);
select pg_temp.lesson(pg_temp.u(215), pg_temp.u(102), pg_temp.u(112), 1, 'isha', 'Only one', false, null);
insert into public.lesson_preferences(profile_id, evening_digest) values (pg_temp.u(7), false);

select private.lessons_emit_digests((public.lessons_today() + time '20:59') at time zone 'Asia/Riyadh');
select is((select count(*)::int from public.lesson_notifications where title_en = 'Tomorrow''s lessons'), 0, 'D01 nothing before nine in the evening');

select private.lessons_emit_digests((public.lessons_today() + time '21:01') at time zone 'Asia/Riyadh');
select ok((select body_en = 'First, Second, Third and more' and body_ar like '% وغيرها' and route = '/lessons'
    from public.lesson_notifications where profile_id = pg_temp.u(3) and title_en = 'Tomorrow''s lessons'),
  'D02 several lessons: the first three in prayer order, and more');
select ok((select body_en = 'Only one' and route = '/lessons/lesson/' || pg_temp.u(215) and title_ar = 'دروس الغد'
    from public.lesson_notifications where profile_id = pg_temp.u(10) and title_en = 'Tomorrow''s lessons'),
  'D03 one lesson: its name and its page');
select ok((select body_en = 'Second' from public.lesson_notifications where profile_id = pg_temp.u(5)),
  'D04 a series follower hears of the series'' session');
select is(pg_temp.notices(pg_temp.u(7), 'Tomorrow''s lessons'), 0, 'D05 the switch turns it off');
select is(pg_temp.notices(pg_temp.u(1), 'Tomorrow''s lessons'), 0, 'D06 nothing to tell, nothing sent');
select private.lessons_emit_digests((public.lessons_today() + time '21:02') at time zone 'Asia/Riyadh');
select is(pg_temp.notices(pg_temp.u(3), 'Tomorrow''s lessons'), 1, 'D07 once an evening');

-- ---------------------------------------------------------------- who may run
select throws_ok($$set local role authenticated; select public.lesson_push_sent('87000000-0000-4000-8000-000000000999', 'x')$$,
  '42501', null, 'P01 a signed-in account cannot mark a push sent');
reset role;
select ok(not has_table_privilege('authenticated', 'private.lesson_notification_deliveries', 'select'),
  'P02 nobody reads the delivery list through the API');

select * from finish();
rollback;
