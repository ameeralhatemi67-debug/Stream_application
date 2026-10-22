-- Mosque lessons v2 (20261022110000): admins run everything, preachers act
-- only through one-time or timed links, edits and requests wait for an
-- admin, and the public sees approved lessons. Run as supabase_admin (one
-- test ends a timed link by editing it directly).
begin;
set local search_path = public, extensions;
select plan(52);

insert into auth.users(id, email, email_confirmed_at) values
  ('40000000-0000-4000-8000-0000000000c1', 'lessons-master@example.invalid', now()),
  ('40000000-0000-4000-8000-0000000000c2', 'lessons-admin@example.invalid', now()),
  ('40000000-0000-4000-8000-0000000000c3', 'lessons-only@example.invalid', now()),
  ('40000000-0000-4000-8000-0000000000c4', 'lessons-viewer@example.invalid', now()),
  ('40000000-0000-4000-8000-0000000000c5', 'lessons-banned@example.invalid', now()),
  ('40000000-0000-4000-8000-0000000000c6', 'lessons-owner@example.invalid', now());
insert into public.profiles(id, email, display_name_en, display_name_ar) values
  ('40000000-0000-4000-8000-0000000000c1', 'lessons-master@example.invalid', 'Master', 'رئيسي'),
  ('40000000-0000-4000-8000-0000000000c2', 'lessons-admin@example.invalid', 'Admin', 'مشرف'),
  ('40000000-0000-4000-8000-0000000000c3', 'lessons-only@example.invalid', 'Lessons admin', 'مشرف الدروس'),
  ('40000000-0000-4000-8000-0000000000c4', 'lessons-viewer@example.invalid', 'Viewer', 'مستمع'),
  ('40000000-0000-4000-8000-0000000000c5', 'lessons-banned@example.invalid', 'Banned', 'محظور'),
  ('40000000-0000-4000-8000-0000000000c6', 'lessons-owner@example.invalid', 'Owner', 'مالك');
insert into public.user_roles(profile_id, role) values
  ('40000000-0000-4000-8000-0000000000c1', 'master_admin'),
  ('40000000-0000-4000-8000-0000000000c2', 'admin'),
  ('40000000-0000-4000-8000-0000000000c3', 'lessons_admin');
insert into public.organizations(id, owner_profile_id, name_en, name_ar) values
  ('40000000-0000-4000-8000-00000000000f', '40000000-0000-4000-8000-0000000000c6', 'Hidayah Society', 'جمعية هداية');
insert into public.banned_users(profile_id, email, reason) values
  ('40000000-0000-4000-8000-0000000000c5', 'lessons-banned@example.invalid', 'test');

create temporary table ids(k text primary key, v text);
grant all on ids to public;

create function pg_temp.as_user(p uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
$$;
create function pg_temp.as_anon() returns void language sql as $$
  select set_config('request.jwt.claims', '{"role":"anon"}', true);
$$;
create function pg_temp.id(p text) returns uuid language sql as $$ select v::uuid from ids where k = p $$;
create function pg_temp.t(p text) returns text language sql as $$ select v from ids where k = p $$;

-- ---------------------------------------------------------------------------
-- Who runs the programme
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('40000000-0000-4000-8000-0000000000c4');
select throws_ok($$select public.lessons_upsert_preacher('{"name_ar":"فهد السالم"}')$$, '42501', null,
  'L01 a viewer cannot add a preacher');
select pg_temp.as_user('40000000-0000-4000-8000-0000000000c6');
select throws_ok($$select public.lessons_upsert_preacher('{"name_ar":"فهد السالم"}')$$, '42501', null,
  'L02 an organization owner cannot add a preacher');
select is(public.lessons_my_roles()->>'admin', 'false', 'L03 an organization owner is not a lessons admin');

select pg_temp.as_user('40000000-0000-4000-8000-0000000000c3');
insert into ids select 'p1', public.lessons_upsert_preacher(
  '{"name_ar":"فهد السالم","name_en":"Fahd Al-Salem","city":"khobar","phone":"0500000101","languages":["ar","en"]}');
select ok(pg_temp.id('p1') is not null, 'L04 a lessons-only admin adds a preacher');
select is(public.lessons_my_roles()->>'admin', 'true', 'L05 and is a lessons admin');
select pg_temp.as_user('40000000-0000-4000-8000-0000000000c2');
insert into ids select 'p2', public.lessons_upsert_preacher('{"name_ar":"سعد الحربي","listed":false}');
select ok(pg_temp.id('p2') is not null, 'L06 a plain admin adds an unlisted preacher');

select is((select r->>'phone_mask' from public.lessons_roster() r where r->>'id' = pg_temp.t('p1')),
  '05•• ••• 101', 'L07 admins see a masked phone in the roster');
select is(public.lessons_reveal_phone(pg_temp.id('p1')), '0500000101', 'L08 revealing the phone returns it');
select is((select action from public.lesson_audit order by id desc limit 1), 'phone', 'L09 and the reveal is logged');
select throws_ok($$select phone from private.preacher_contacts$$, '42501', null,
  'L10 phone numbers are not readable directly');

select pg_temp.as_user('40000000-0000-4000-8000-0000000000c4');
select is((select count(*)::int from public.lessons_roster()), 0, 'L11 a viewer gets no roster');
reset role;
set local role anon;
select pg_temp.as_anon();
select is((select count(*)::int from public.preachers), 1, 'L12 guests see listed preachers only');

-- ---------------------------------------------------------------------------
-- Mosques and lessons entered by admins
-- ---------------------------------------------------------------------------
reset role;
set local role authenticated;
select pg_temp.as_user('40000000-0000-4000-8000-0000000000c4');
select throws_ok($$select public.lessons_upsert_mosque('{"name_ar":"جامع","district_id":"aqrabiyah"}')$$, '42501', null,
  'L13 a viewer cannot add a mosque');
select pg_temp.as_user('40000000-0000-4000-8000-0000000000c2');
insert into ids select 'm1', public.lessons_upsert_mosque(
  '{"name_ar":"جامع الهدى","name_en":"Al-Huda Mosque","district_id":"aqrabiyah","latitude":26.28,"longitude":50.2}');
insert into ids select 'm2', public.lessons_upsert_mosque(
  '{"name_ar":"مسجد التقوى","district_id":"thuqbah","verified":false}');
select throws_ok($$select public.lessons_add(jsonb_build_object('preacher_id', pg_temp.t('p1'), 'title_ar', 'درس بلا مسجد',
  'type', 'lesson', 'topic', 'fiqh', 'slot', 'isha', 'dates', jsonb_build_array(public.lessons_today() + 1)))$$,
  '22023', null, 'L14 a lesson needs a mosque');
insert into ids select 'series', public.lessons_add(jsonb_build_object('preacher_id', pg_temp.t('p1'),
  'mosque_id', pg_temp.t('m1'), 'title_ar', 'شرح كتاب التوحيد', 'type', 'lesson', 'topic', 'aqeedah', 'slot', 'maghrib',
  'dates', jsonb_build_array(public.lessons_today() + 1, public.lessons_today() + 8, public.lessons_today() + 15)));
select is((select count(*)::int from public.lessons where request_id = pg_temp.id('series') and status = 'approved'), 3,
  'L15 an admin publishes a weekly series at once');
select is((select status from public.lesson_series where request_id = pg_temp.id('series')), 'approved',
  'L16 and its series');
insert into ids select 'l1', (select id::text from public.lessons where request_id = pg_temp.id('series') and seq = 1);

reset role;
set local role anon;
select pg_temp.as_anon();
select is((select count(*)::int from public.lessons), 3, 'L17 guests see the approved lessons');
select is((select count(*)::int from public.mosques), 1, 'L18 guests do not see hidden mosques');

-- ---------------------------------------------------------------------------
-- Preacher links
-- ---------------------------------------------------------------------------
reset role;
set local role authenticated;
select pg_temp.as_user('40000000-0000-4000-8000-0000000000c4');
select throws_ok($$select public.lessons_create_key(pg_temp.id('p1'), 'once')$$, '42501', null,
  'L19 a viewer cannot create a preacher link');
select pg_temp.as_user('40000000-0000-4000-8000-0000000000c3');
select throws_ok($$select public.lessons_create_key(pg_temp.id('p1'), 'window', now() - interval '1 hour', null)$$,
  '22023', null, 'L20 a timed link needs an end');
insert into ids select 'once', public.lessons_create_key(pg_temp.id('p1'), 'once')->>'token';
insert into ids select 'later', public.lessons_create_key(pg_temp.id('p1'), 'window',
  now() + interval '1 day', now() + interval '2 days')->>'token';
insert into ids select 'now', public.lessons_create_key(pg_temp.id('p1'), 'window',
  now() - interval '1 hour', now() + interval '1 day')->>'token';
with k as (select public.lessons_create_key(pg_temp.id('p1'), 'once') as r)
insert into ids select 'revoked', r->>'token' from k union all select 'revoked_id', r->>'id' from k;
select lives_ok($$select public.lessons_revoke_key(pg_temp.id('revoked_id'))$$, 'L21 an admin revokes a link');
select is(char_length(pg_temp.t('once')), 64, 'L22 a link carries a 64-character key');
reset role;
select is((select count(*)::int from private.preacher_keys where token_hash = pg_temp.t('once')), 0,
  'L23 only a hash of the key is stored');

set local role anon;
select pg_temp.as_anon();
select is((public.lessons_key_open(pg_temp.t('once'), 'device-aaaaaaaaaaaaaaaa')->'preacher'->>'name_ar'), 'فهد السالم',
  'L24 the first phone opens a one-time link');
select is(jsonb_array_length(public.lessons_key_open(pg_temp.t('once'), 'device-aaaaaaaaaaaaaaaa')->'lessons'), 3,
  'L25 the same phone keeps access and sees his lessons');
select throws_ok($$select public.lessons_key_open(pg_temp.t('once'), 'device-bbbbbbbbbbbbbbbb')$$, '28000',
  'This link was already used on another phone', 'L26 another phone is refused');
select throws_ok($$select public.lessons_key_open(pg_temp.t('later'), null)$$, '28000',
  'This link is not active yet', 'L27 a timed link waits for its start');
select lives_ok($$select public.lessons_key_open(pg_temp.t('now'), null);
  select public.lessons_key_open(pg_temp.t('now'), 'any-other-phone-1234')$$,
  'L28 an active timed link works on any phone');
select throws_ok($$select public.lessons_key_open(pg_temp.t('revoked'), 'device-cccccccccccccccc')$$, '28000',
  'This link is not valid', 'L29 a revoked link is refused');
select throws_ok($$select public.lessons_key_open('not-a-key', 'device-cccccccccccccccc')$$, '28000',
  'This link is not valid', 'L30 an unknown key is refused');
reset role;
update private.preacher_keys set valid_from = now() - interval '3 days', valid_until = now() - interval '1 day'
 where token_hash = private.sha256_hex(pg_temp.t('now'));
set local role anon;
select pg_temp.as_anon();
select throws_ok($$select public.lessons_key_open(pg_temp.t('now'), null)$$, '28000', 'This link has ended',
  'L31 a timed link stops at its end');
select throws_ok($$select key from private.preacher_keys$$, '42501', null, 'L32 guests cannot read the keys');

-- Through the link: card changes and lesson requests wait for an admin.
select ok(public.lessons_key_update_profile(pg_temp.t('once'), 'device-aaaaaaaaaaaaaaaa',
  '{"title_ar":"إمام وخطيب","bio_ar":"خطيب جامع الهدى"}') is not null, 'L33 a preacher proposes a card change');
select lives_ok($$select public.lessons_key_update_profile(pg_temp.t('once'), 'device-aaaaaaaaaaaaaaaa',
  '{"title_ar":"إمام وخطيب جامع"}')$$, 'L34 a new proposal replaces the waiting one');
select throws_ok($$select public.lessons_key_update_profile(pg_temp.t('once'), 'device-aaaaaaaaaaaaaaaa', '{"name_ar":"ف"}')$$,
  '22023', null, 'L35 a too-short name is refused');
reset role;
select is((select count(*)::int from public.preacher_edits where status = 'pending'), 1, 'L36 one change waits');
select is((select title_ar from public.preachers where id = pg_temp.id('p1')), '', 'L37 the public card is unchanged');

set local role anon;
select pg_temp.as_anon();
insert into ids select 'req', public.lessons_key_request_lesson(pg_temp.t('once'), 'device-aaaaaaaaaaaaaaaa',
  jsonb_build_object('title_ar', 'فضل صلاة الفجر', 'type', 'talk', 'topic', 'raqaiq', 'slot', 'fajr',
    'note', 'في جامع الحي', 'dates', jsonb_build_array(public.lessons_today() + 3, public.lessons_today() + 10)));
insert into ids select 'req2', public.lessons_key_request_lesson(pg_temp.t('once'), 'device-aaaaaaaaaaaaaaaa',
  jsonb_build_object('title_ar', 'حق الجار', 'type', 'talk', 'topic', 'family', 'slot', 'asr',
    'dates', jsonb_build_array(public.lessons_today() + 4)));
insert into ids select 'req3', public.lessons_key_request_lesson(pg_temp.t('once'), 'device-aaaaaaaaaaaaaaaa',
  jsonb_build_object('title_ar', 'آداب المسجد', 'type', 'talk', 'topic', 'fiqh', 'slot', 'isha',
    'dates', jsonb_build_array(public.lessons_today() + 5)));
select is((select count(*)::int from public.lessons), 3, 'L38 requests are not public');
reset role;
select is((select count(*)::int from public.lessons where request_id = pg_temp.id('req') and status = 'pending' and mosque_id is null), 2,
  'L39 a requested series waits, without a mosque');
select is((select count(*)::int from public.lesson_notifications where route = '/admin/lessons/approvals'),
  (select count(*)::int * 5 from private.lessons_admins()),
  'L40 every lessons admin is told about both card proposals and the three requests');
insert into ids select 'req2_lesson', (select id::text from public.lessons where request_id = pg_temp.id('req2') limit 1);

set local role authenticated;
select pg_temp.as_user('40000000-0000-4000-8000-0000000000c3');
select lives_ok($$select public.lessons_decide_edit((select id from public.preacher_edits where status = 'pending'), true)$$,
  'L41 an admin approves the card change');
select is((select title_ar from public.preachers where id = pg_temp.id('p1')), 'إمام وخطيب جامع', 'L42 and it is applied');
select throws_ok($$select public.lessons_review(array[pg_temp.id('req')], 'approve')$$, '22023', null,
  'L43 approving a request needs a mosque');
select is(public.lessons_review(array[pg_temp.id('req')], 'approve', null, pg_temp.id('m1')), 1,
  'L44 the admin chooses the mosque and approves');
select is((select count(*)::int from public.lessons where request_id = pg_temp.id('req') and status = 'approved' and mosque_id = pg_temp.id('m1')), 2,
  'L45 every session gets the mosque');
select is(public.lessons_review(array[pg_temp.id('req2')], 'reject', 'التاريخ متعارض'), 1, 'L46 an admin rejects with a reason');
select is(public.lessons_undo_review(array[pg_temp.id('req2')]), 1, 'L47 and can undo within 15 minutes');

reset role;
set local role anon;
select pg_temp.as_anon();
select lives_ok($$select public.lessons_key_withdraw(pg_temp.t('once'), 'device-aaaaaaaaaaaaaaaa', pg_temp.id('req3'))$$,
  'L48 the preacher withdraws his own waiting request');

-- ---------------------------------------------------------------------------
-- Viewers, cancellations and removal
-- ---------------------------------------------------------------------------
reset role;
set local role authenticated;
select pg_temp.as_user('40000000-0000-4000-8000-0000000000c4');
insert into public.lesson_reminders(lesson_id, lead, remind_at) values (pg_temp.id('l1'), '30', now() + interval '1 day');
select throws_ok($$insert into public.lesson_reminders(lesson_id, lead, remind_at)
  values (pg_temp.id('req2_lesson'), '30', now())$$, '42501', null,
  'L49 no reminder on a lesson that is not approved');
select pg_temp.as_user('40000000-0000-4000-8000-0000000000c2');
select is(public.lessons_cancel_lesson(pg_temp.id('l1'), 'سفر الشيخ'), 1, 'L50 cancelling counts the reminded viewers');
select pg_temp.as_user('40000000-0000-4000-8000-0000000000c5');
select throws_ok($$select public.lessons_flag(pg_temp.id('l1'), 'time', 'x')$$, '42501', null, 'L51 a banned account cannot report');
select pg_temp.as_user('40000000-0000-4000-8000-0000000000c1');
select is(public.lessons_remove_preacher(pg_temp.id('p1')), 7, 'L52 removing a preacher removes all 7 of his lessons');

select * from finish();
rollback;
