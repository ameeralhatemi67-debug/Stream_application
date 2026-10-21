-- Taysir lessons programme (20261021120000): authority, privacy and the
-- request -> review -> public journey.
begin;
set local search_path = public, extensions;
select plan(62);

-- ---------------------------------------------------------------------------
-- Fixture: one organization (owner, a manager who becomes coordinator, a
-- moderator who does not), a preacher account, a viewer, an outsider, and a
-- master admin.
-- ---------------------------------------------------------------------------
insert into auth.users(id, email) values
  ('20000000-0000-4000-8000-0000000000a1', 'taysir-admin@example.invalid'),
  ('20000000-0000-4000-8000-0000000000a2', 'taysir-owner@example.invalid'),
  ('20000000-0000-4000-8000-0000000000a3', 'taysir-coord@example.invalid'),
  ('20000000-0000-4000-8000-0000000000a4', 'taysir-preacher@example.invalid'),
  ('20000000-0000-4000-8000-0000000000a5', 'taysir-viewer@example.invalid'),
  ('20000000-0000-4000-8000-0000000000a6', 'taysir-outsider@example.invalid'),
  ('20000000-0000-4000-8000-0000000000a7', 'taysir-moderator@example.invalid');
insert into public.profiles(id, email, display_name_en, display_name_ar) values
  ('20000000-0000-4000-8000-0000000000a1', 'taysir-admin@example.invalid', 'Admin', 'المشرف'),
  ('20000000-0000-4000-8000-0000000000a2', 'taysir-owner@example.invalid', 'Owner', 'المالك'),
  ('20000000-0000-4000-8000-0000000000a3', 'taysir-coord@example.invalid', 'Khalid', 'خالد'),
  ('20000000-0000-4000-8000-0000000000a4', 'taysir-preacher@example.invalid', 'Fahd', 'فهد'),
  ('20000000-0000-4000-8000-0000000000a5', 'taysir-viewer@example.invalid', 'Viewer', 'مستمع'),
  ('20000000-0000-4000-8000-0000000000a6', 'taysir-outsider@example.invalid', 'Out', 'خارجي'),
  ('20000000-0000-4000-8000-0000000000a7', 'taysir-moderator@example.invalid', 'Mod', 'مشرف');
insert into public.user_roles(profile_id, role) values ('20000000-0000-4000-8000-0000000000a1', 'master_admin');
insert into public.organizations(id, owner_profile_id, name_en, name_ar) values
  ('20000000-0000-4000-8000-00000000000f', '20000000-0000-4000-8000-0000000000a2', 'Hidayah Society', 'جمعية هداية');
insert into public.org_memberships(organization_id, profile_id, role) values
  ('20000000-0000-4000-8000-00000000000f', '20000000-0000-4000-8000-0000000000a3', 'manager'),
  ('20000000-0000-4000-8000-00000000000f', '20000000-0000-4000-8000-0000000000a7', 'moderator');

create temporary table ids(k text primary key, v text);
grant all on ids to public;

create function pg_temp.as_user(p uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
$$;

-- ---------------------------------------------------------------------------
-- Module and coordinators
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a2');
select throws_ok($$select public.taysir_set_org_enabled('20000000-0000-4000-8000-00000000000f', true)$$,
  '42501', null, 'T01 an organization owner cannot switch Taysir on');
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a1');
select lives_ok($$select public.taysir_set_org_enabled('20000000-0000-4000-8000-00000000000f', true)$$,
  'T02 a master admin switches Taysir on for the organization');

select pg_temp.as_user('20000000-0000-4000-8000-0000000000a3');
select is(public.taysir_is_coordinator('20000000-0000-4000-8000-00000000000f'), false,
  'T03 a manager is not a coordinator until granted');
select throws_ok($$select public.taysir_set_coordinator('20000000-0000-4000-8000-00000000000f',
  '20000000-0000-4000-8000-0000000000a3', true)$$, '42501', null, 'T04 nobody grants themselves coordinator');

select pg_temp.as_user('20000000-0000-4000-8000-0000000000a2');
select is(public.taysir_is_coordinator('20000000-0000-4000-8000-00000000000f'), true,
  'T05 the organization owner coordinates without a grant');
select throws_ok($$select public.taysir_set_coordinator('20000000-0000-4000-8000-00000000000f',
  '20000000-0000-4000-8000-0000000000a6', true)$$, '22023', null, 'T06 coordinators must be organization members');
select lives_ok($$select public.taysir_set_coordinator('20000000-0000-4000-8000-00000000000f',
  '20000000-0000-4000-8000-0000000000a3', true)$$, 'T07 the owner grants coordinator to a member');

select pg_temp.as_user('20000000-0000-4000-8000-0000000000a3');
select is(public.taysir_is_coordinator('20000000-0000-4000-8000-00000000000f'), true,
  'T08 the grant is an organization-scoped activities.coordinate permission');
select throws_ok($$select public.taysir_set_coordinator('20000000-0000-4000-8000-00000000000f',
  '20000000-0000-4000-8000-0000000000a7', true)$$, '42501', null, 'T09 a coordinator cannot grant coordinator');

-- ---------------------------------------------------------------------------
-- Roster and phone privacy
-- ---------------------------------------------------------------------------
insert into ids select 'preacher', public.taysir_upsert_preacher(jsonb_build_object(
  'organization_id', '20000000-0000-4000-8000-00000000000f', 'name_ar', 'الشيخ فهد العتيبي',
  'name_en', 'Sheikh Fahd', 'city', 'khobar', 'languages', jsonb_build_array('ar', 'en'),
  'phone', '0500 000 101'))::text;
insert into ids select 'other_preacher', public.taysir_upsert_preacher(jsonb_build_object(
  'organization_id', '20000000-0000-4000-8000-00000000000f', 'name_ar', 'الشيخ عمر الحربي'))::text;
select is((select count(*)::int from public.taysir_preachers), 2, 'T10 a coordinator adds preachers to the roster');

select is((select r->>'phone_mask' from public.taysir_roster('20000000-0000-4000-8000-00000000000f') r
    where r->>'id' = (select v from ids where k = 'preacher')), '05•• ••• 101',
  'T11 the roster shows a masked phone');
select is(public.taysir_reveal_phone((select v::uuid from ids where k = 'preacher')), '0500000101',
  'T12 revealing returns the number');
select is((select count(*)::int from public.taysir_audit where action = 'phone'), 1,
  'T13 every reveal is written to the action log');
select throws_ok($$select * from private.taysir_preacher_contacts$$, '42501', null,
  'T14 the phone table is unreachable from the API');

select pg_temp.as_user('20000000-0000-4000-8000-0000000000a5');
select throws_ok($$select public.taysir_upsert_preacher(jsonb_build_object('organization_id',
  '20000000-0000-4000-8000-00000000000f', 'name_ar', 'دخيل'))$$, '42501', null, 'T15 a viewer cannot edit the roster');
select is((select count(*)::int from public.taysir_roster('20000000-0000-4000-8000-00000000000f')), 0,
  'T16 a viewer sees no roster rows');
select throws_ok($$select public.taysir_reveal_phone((select v::uuid from ids where k = 'preacher'))$$,
  '42501', null, 'T17 a viewer cannot reveal a phone');

-- ---------------------------------------------------------------------------
-- Invitation replaces the shared default password
-- ---------------------------------------------------------------------------
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a3');
insert into ids select 'token', public.taysir_create_invite((select v::uuid from ids where k = 'preacher'))->>'token';

reset role;
select is((select count(*)::int from private.taysir_invites
  where token_hash = (select v from ids where k = 'token')), 0, 'T18 only a hash of the token is stored');
set local role anon;
select is(public.taysir_invite_info((select v from ids where k = 'token'))->>'name_en', 'Sheikh Fahd',
  'T19 a guest opening the link sees whose invitation it is');
select is(public.taysir_invite_info('not-a-token'), null, 'T20 a wrong token reveals nothing');

set local role authenticated;
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a4');
select lives_ok($$select public.taysir_claim_invite((select v from ids where k = 'token'), array['ar','en','ur'])$$,
  'T21 the preacher signs in and accepts the invitation');
select ok((public.taysir_my_roles()->'preacher'->0->>'can_submit')::boolean,
  'T22 accepting grants activities.submit for that organization');
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a6');
select throws_ok($$select public.taysir_claim_invite((select v from ids where k = 'token'))$$, '55000', null,
  'T23 an invitation works once');

-- ---------------------------------------------------------------------------
-- Mosques
-- ---------------------------------------------------------------------------
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a3');
insert into ids select 'mosque', public.taysir_upsert_mosque(jsonb_build_object('name_ar', 'جامع الهدى',
  'name_en', 'Al-Huda', 'district_id', 'aqrabiyah', 'latitude', 26.292, 'longitude', 50.198,
  'facilities', jsonb_build_array('women', 'parking')))::text;
select throws_ok($$select public.taysir_upsert_mosque(jsonb_build_object('name_ar', 'مسجد', 'district_id', 'aqrabiyah',
  'maps_url', 'javascript:alert(1)'))$$, '23514', null, 'T24 only https Google Maps links are stored');
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a5');
select throws_ok($$select public.taysir_upsert_mosque(jsonb_build_object('name_ar', 'مسجد', 'district_id', 'aqrabiyah'))$$,
  '42501', null, 'T25 a viewer cannot add mosques');

-- ---------------------------------------------------------------------------
-- Submitting
-- ---------------------------------------------------------------------------
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a5');
insert into public.taysir_follows(kind, target_id) select 'preacher', v::uuid from ids where k = 'preacher';

select pg_temp.as_user('20000000-0000-4000-8000-0000000000a4');
insert into ids select 'single', public.taysir_submit(jsonb_build_object(
  'preacher_id', (select v from ids where k = 'preacher'), 'type', 'lecture', 'topic', 'raqaiq',
  'title_ar', 'قيمة الوقت', 'title_en', 'The value of time', 'mosque_id', (select v from ids where k = 'mosque'),
  'slot', 'isha', 'language', 'ar', 'dates', jsonb_build_array(public.taysir_today() + 3)))::text;
select is((select status from public.taysir_lessons where request_id = (select v::uuid from ids where k = 'single')),
  'pending', 'T26 a preacher''s request starts pending');
select throws_ok($$select public.taysir_submit(jsonb_build_object('preacher_id', (select v from ids where k = 'other_preacher'),
  'type', 'talk', 'topic', 'fiqh', 'title_ar', 'ليس لي', 'mosque_id', (select v from ids where k = 'mosque'),
  'slot', 'asr', 'dates', jsonb_build_array(public.taysir_today() + 2)))$$, '42501', null,
  'T27 a preacher submits only for their own card');
select throws_ok($$select public.taysir_submit(jsonb_build_object('preacher_id', (select v from ids where k = 'preacher'),
  'type', 'talk', 'topic', 'fiqh', 'title_ar', 'نشر مباشر', 'mosque_id', (select v from ids where k = 'mosque'),
  'slot', 'asr', 'direct', true, 'dates', jsonb_build_array(public.taysir_today() + 2)))$$, '42501', null,
  'T28 only coordinators publish without review');
select throws_ok($$select public.taysir_submit(jsonb_build_object('preacher_id', (select v from ids where k = 'preacher'),
  'type', 'talk', 'topic', 'fiqh', 'title_ar', 'في الماضي', 'mosque_id', (select v from ids where k = 'mosque'),
  'slot', 'asr', 'dates', jsonb_build_array(public.taysir_today() - 1)))$$, '22023', null,
  'T29 dates in the past are refused');

insert into ids select 'series', public.taysir_submit(jsonb_build_object(
  'preacher_id', (select v from ids where k = 'preacher'), 'type', 'lesson', 'topic', 'seerah',
  'title_ar', 'السيرة للمبتدئين', 'slot', 'isha', 'language', 'ur', 'interpretation', 'en',
  'new_mosque', jsonb_build_object('name_ar', 'مسجد الإيمان', 'district_id', 'golden_belt'),
  'dates', (select jsonb_agg(public.taysir_today() + 7 * g) from generate_series(1, 8) g)))::text;
select is((select count(*)::int from public.taysir_lessons where request_id = (select v::uuid from ids where k = 'series')),
  8, 'T30 a weekly series is one request with eight sessions');
select is((select total from public.taysir_series where request_id = (select v::uuid from ids where k = 'series')),
  8, 'T31 the series records its length');
select is((select verified from public.taysir_mosques m join public.taysir_lessons l on l.mosque_id = m.id
    where l.request_id = (select v::uuid from ids where k = 'series') limit 1), false,
  'T32 a mosque a preacher suggests stays unverified');
select is((select count(*)::int from public.taysir_lessons), 9, 'T33 the preacher sees their own pending sessions');

select pg_temp.as_user('20000000-0000-4000-8000-0000000000a3');
select is((select count(*)::int from public.taysir_notifications where icon = 'inbox'), 2,
  'T34 coordinators are told about each new request');

set local role anon;
select is((select count(*)::int from public.taysir_lessons), 0, 'T35 guests never see pending requests');
select is((select count(*)::int from public.taysir_mosques), 1, 'T36 guests see verified mosques only');
set local role authenticated;

-- ---------------------------------------------------------------------------
-- Reviewing
-- ---------------------------------------------------------------------------
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a5');
select throws_ok($$select public.taysir_review(array[(select v::uuid from ids where k = 'single')], 'approve')$$,
  '42501', null, 'T37 a viewer cannot review');

select pg_temp.as_user('20000000-0000-4000-8000-0000000000a3');
select throws_ok($$select public.taysir_review(array[(select v::uuid from ids where k = 'series')], 'reject', '')$$,
  '22023', null, 'T38 rejecting needs a reason');
select is(public.taysir_review(array[(select v::uuid from ids where k = 'series')], 'reject',
  'تتعارض مع محاضرة الجمعية'), 1, 'T39 a coordinator rejects with a reason');
select is(public.taysir_review(array[(select v::uuid from ids where k = 'single')], 'approve'), 1,
  'T40 a coordinator approves');
select is(public.taysir_undo_review(array[(select v::uuid from ids where k = 'single')]), 1,
  'T41 the coordinator can undo the decision');
select is(public.taysir_review(array[(select v::uuid from ids where k = 'single')], 'approve'), 1,
  'T42 and approve it again');

select pg_temp.as_user('20000000-0000-4000-8000-0000000000a4');
select is((select body_en from public.taysir_notifications where icon = 'x'), 'Reason: تتعارض مع محاضرة الجمعية',
  'T43 the preacher receives the rejection reason');
select ok(exists(select 1 from public.taysir_notifications where icon = 'check'),
  'T44 the preacher is told about the approval');
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a5');
select ok(exists(select 1 from public.taysir_notifications where icon = 'sparkle'),
  'T45 followers hear about the newly approved lesson');

set local role anon;
select is((select count(*)::int from public.taysir_lessons), 1, 'T46 guests see the approved session only');
set local role authenticated;

-- ---------------------------------------------------------------------------
-- Viewer data, cancellation and reports
-- ---------------------------------------------------------------------------
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a5');
select lives_ok($$insert into public.taysir_reminders(lesson_id, lead, remind_at)
  select id, 'adhan', now() + interval '3 days' from public.taysir_lessons
   where request_id = (select v::uuid from ids where k = 'single')$$, 'T47 a viewer sets a reminder');
select throws_ok($$insert into public.taysir_lessons(organization_id, request_id, type, topic, title_ar,
  preacher_id, mosque_id, lesson_date, slot, status) values ('20000000-0000-4000-8000-00000000000f', gen_random_uuid(),
  'talk', 'fiqh', 'تسلل', (select v::uuid from ids where k = 'preacher'), (select v::uuid from ids where k = 'mosque'),
  current_date + 1, 'asr', 'approved')$$, '42501', null, 'T48 clients cannot write lessons directly');
select throws_ok($$select public.taysir_cancel_lesson((select id from public.taysir_lessons
  where request_id = (select v::uuid from ids where k = 'single')), 'سفر')$$, '42501', null,
  'T49 a viewer cannot cancel a session');
select lives_ok($$select public.taysir_flag((select id from public.taysir_lessons
  where request_id = (select v::uuid from ids where k = 'single')), 'time', 'صار بعد العصر')$$,
  'T50 a viewer reports a wrong time');

select pg_temp.as_user('20000000-0000-4000-8000-0000000000a6');
select is((select count(*)::int from public.taysir_reminders), 0, 'T51 reminders are private to their owner');

select pg_temp.as_user('20000000-0000-4000-8000-0000000000a4');
select is(public.taysir_cancel_lesson((select id from public.taysir_lessons
  where request_id = (select v::uuid from ids where k = 'single')), 'سفر'), 1,
  'T52 the preacher cancels and the reminder holder count is returned');
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a5');
select ok(exists(select 1 from public.taysir_notifications where icon = 'alert'),
  'T53 reminder holders are told at once');
set local role anon;
select is((select status from public.taysir_lessons), 'cancelled',
  'T54 a cancelled session stays visible, marked cancelled');
set local role authenticated;

select pg_temp.as_user('20000000-0000-4000-8000-0000000000a3');
select lives_ok($$select public.taysir_resolve_flag((select id from public.taysir_flags limit 1))$$,
  'T55 a coordinator resolves the report');

reset role;
insert into public.taysir_lessons(id, organization_id, request_id, type, topic, title_ar, preacher_id, mosque_id,
  lesson_date, slot, status) values ('20000000-0000-4000-8000-0000000000b1', '20000000-0000-4000-8000-00000000000f',
  gen_random_uuid(), 'lesson', 'fiqh', 'درس سابق', (select v::uuid from ids where k = 'preacher'),
  (select v::uuid from ids where k = 'mosque'), public.taysir_today() - 2, 'maghrib', 'approved');
set local role authenticated;
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a4');
select lives_ok($$select public.taysir_post_report('20000000-0000-4000-8000-0000000000b1', 85, 20, 'none', '')$$,
  'T56 the preacher reports attendance after the lesson');
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a5');
select is((select count(*)::int from public.taysir_lesson_reports), 0, 'T57 viewers cannot read lesson reports');
select is((select count(*)::int from public.taysir_audit), 0, 'T58 viewers cannot read the action log');

-- ---------------------------------------------------------------------------
-- Mosque merge, permission revocation, module switch-off, export
-- ---------------------------------------------------------------------------
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a3');
select lives_ok($$select public.taysir_reject_mosque((select mosque_id from public.taysir_lessons
  where request_id = (select v::uuid from ids where k = 'series') limit 1), (select v::uuid from ids where k = 'mosque'))$$,
  'T59 a duplicate suggestion merges into a verified mosque, with its sessions');
select lives_ok($$select public.taysir_set_submit((select v::uuid from ids where k = 'preacher'), false)$$,
  'T60 a coordinator revokes the submit permission');
select pg_temp.as_user('20000000-0000-4000-8000-0000000000a4');
select throws_ok($$select public.taysir_submit(jsonb_build_object('preacher_id', (select v from ids where k = 'preacher'),
  'type', 'talk', 'topic', 'fiqh', 'title_ar', 'بعد السحب', 'mosque_id', (select v from ids where k = 'mosque'),
  'slot', 'asr', 'dates', jsonb_build_array(public.taysir_today() + 2)))$$, '42501', null,
  'T61 without the permission the preacher can no longer submit');

select pg_temp.as_user('20000000-0000-4000-8000-0000000000a5');
select ok(jsonb_array_length(public.export_my_data()->'taysir'->'reminders') = 1,
  'T62 the account export includes Taysir reminders');

select * from finish();
rollback;
