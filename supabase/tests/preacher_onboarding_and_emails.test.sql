-- Preachers invited or accepted, their emails, and the named action log
-- (20261029103349). Run as supabase_admin (the outbox is private).
begin;
set local search_path = public, extensions;
select plan(59);

insert into auth.users(id, email, email_confirmed_at) values
  ('29000000-0000-4000-8000-0000000000a1', 'po-admin@example.invalid', now()),
  ('29000000-0000-4000-8000-0000000000a2', 'po-applicant@example.invalid', now()),
  ('29000000-0000-4000-8000-0000000000a3', 'po-other@example.invalid', now()),
  ('29000000-0000-4000-8000-0000000000a4', 'po-gone@example.invalid', now());
insert into public.profiles(id, email, display_name_en, display_name_ar) values
  ('29000000-0000-4000-8000-0000000000a1', 'po-admin@example.invalid', 'Khalid Admin', 'خالد'),
  ('29000000-0000-4000-8000-0000000000a2', 'po-applicant@example.invalid', 'Yasser Applicant', 'ياسر'),
  ('29000000-0000-4000-8000-0000000000a3', 'po-other@example.invalid', 'Other Viewer', 'آخر'),
  ('29000000-0000-4000-8000-0000000000a4', 'po-gone@example.invalid', 'Gone Admin', 'راحل')
  on conflict (id) do update set display_name_en = excluded.display_name_en, email = excluded.email;
insert into public.user_roles(profile_id, role) values
  ('29000000-0000-4000-8000-0000000000a1', 'lessons_admin'),
  ('29000000-0000-4000-8000-0000000000a4', 'lessons_admin');
insert into public.mosques(id, name_ar, name_en, district_id, latitude, longitude) values
  ('29000000-0000-4000-8000-0000000000b1', 'جامع الهدى', 'Al-Huda Mosque', 'aqrabiyah', 26.29, 50.19),
  ('29000000-0000-4000-8000-0000000000b2', 'مسجد النور', 'Al-Noor Mosque', 'faisaliyah', 26.40, 50.05),
  ('29000000-0000-4000-8000-0000000000b3', 'مسجد مكرر', 'Duplicate Mosque', 'aqrabiyah', null, null);

create temporary table ids(k text primary key, v text);
grant all on ids to public;
create function pg_temp.as_user(p uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
$$;
create function pg_temp.id(p text) returns uuid language sql as $$ select v::uuid from ids where k = p $$;
create function pg_temp.queued(p_kind text) returns integer language sql as $$
  select count(*)::int from private.preacher_emails where kind = p_kind and status = 'queued' $$;

-- ---------------------------------------------------------------------------
-- An invited preacher: email, initial mosque, masked, logged by name
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a1');
select throws_ok($$select public.lessons_upsert_preacher('{"name_ar":"فهد السالم","email":"not-an-email"}')$$,
  '22023', 'Check the email address', 'P01 a malformed email is refused');
insert into ids select 'p1', public.lessons_upsert_preacher(jsonb_build_object('name_ar', 'فهد السالم',
  'name_en', 'Fahd Al-Salem', 'city', 'khobar', 'phone', '0500000101', 'email', ' Fahd@Example.Invalid ',
  'home_mosque_id', '29000000-0000-4000-8000-0000000000b1'));
insert into ids select 'p2', public.lessons_upsert_preacher('{"name_ar":"بدر بلا بريد","city":"dammam"}');
select is((select r->>'email_mask' from public.lessons_roster() r where r->>'id' = pg_temp.id('p1')::text),
  'fa•••@example.invalid', 'P02 the list shows the email masked');
select is((select r->>'home_mosque_id' from public.lessons_roster() r where r->>'id' = pg_temp.id('p1')::text),
  '29000000-0000-4000-8000-0000000000b1', 'P03 with his initial mosque');
select is(public.lessons_reveal_email(pg_temp.id('p1')), 'fahd@example.invalid', 'P04 an admin can show it, trimmed and lower case');
reset role;
select is((select action || '|' || actor_name || '|' || actor_email from public.lesson_audit order by id desc limit 1),
  'email|Khalid Admin|po-admin@example.invalid', 'P05 the reveal is logged with the admin''s name and email');
select is((select preacher_id from public.lesson_audit where action = 'addPreacher' order by id desc limit 1),
  pg_temp.id('p2'), 'P06 adding a preacher is logged against his card');

set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a1');
select throws_ok($$select public.lessons_create_key(pg_temp.id('p2'), 'once', p_email => true)$$, '22023',
  'This preacher has no email address', 'P07 no invitation to a preacher without an email');
insert into ids select 'k1', public.lessons_create_key(pg_temp.id('p1'), 'once', p_email => true)->>'id';
insert into ids select 'k2', public.lessons_create_key(pg_temp.id('p1'), 'once', p_email => true)->>'id';
reset role;
select is((select count(*)::int from private.preacher_emails where kind = 'invite' and status = 'queued'
   and payload ? 'token' and send_after <= now()), 2, 'P08 each invitation is queued at once with its key');
select is((select count(*)::int from public.lesson_audit where action = 'invite'), 2, 'P09 and logged');
set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a1');
select public.lessons_revoke_key(pg_temp.id('k2'));
reset role;
select is((select status || '|' || (payload ? 'token')::text from private.preacher_emails where ref_id = pg_temp.id('k2')),
  'cancelled|false', 'P10 revoking the link cancels its invitation and drops the key');

-- ---------------------------------------------------------------------------
-- Applying
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a2');
select throws_ok($$select public.lessons_apply(jsonb_build_object('name_ar','ياسر القرني','city','khobar',
    'mosque_id','29000000-0000-4000-8000-0000000000b2','phone','0500000202','email','yasser@example.invalid'))$$,
  '22023', 'Choose a mosque in your city', 'P11 the mosque must be in the chosen city');
select throws_ok($$select public.lessons_apply(jsonb_build_object('name_ar','ياسر القرني','city','khobar',
    'phone','0500000202','email','yasser@example.invalid'))$$,
  '22023', 'Choose your mosque, or name it and its area', 'P12 a mosque is required');
select throws_ok($$select public.lessons_apply(jsonb_build_object('name_ar','ياسر القرني','city','khobar',
    'mosque_id','29000000-0000-4000-8000-0000000000b1','phone','0500000202','email','yasser'))$$,
  '22023', 'A valid email is required', 'P13 a valid email is required');
select throws_ok($$select public.lessons_apply(jsonb_build_object('name_ar','ياسر القرني','city','khobar',
    'mosque_id','29000000-0000-4000-8000-0000000000b1','phone','0500000202','email','yasser@example.invalid',
    'photo_url','https://x.supabase.co/storage/v1/object/public/streamer-assets/29000000-0000-4000-8000-0000000000a3/a.png'))$$,
  '22023', 'Upload the photo from the form', 'P14 only a photo from the applicant''s own folder');
insert into ids select 'app1', public.lessons_apply(jsonb_build_object('name_ar', 'ياسر القرني',
  'name_en', 'Yasser Al-Qarni', 'city', 'khobar', 'new_mosque_name', 'مسجد الرحمة', 'new_mosque_district', 'thuqbah',
  'phone', '0500000202', 'email', 'yasser@example.invalid', 'languages', jsonb_build_array('ar','en'),
  'experience', 'إمام وخطيب منذ عشر سنوات',
  'photo_url', 'https://x.supabase.co/storage/v1/object/public/streamer-assets/29000000-0000-4000-8000-0000000000a2/preacher/1.png'));
select ok(pg_temp.id('app1') is not null, 'P15 a signed-in person applies, naming a mosque not yet listed');
select throws_ok($$select public.lessons_apply(jsonb_build_object('name_ar','ياسر القرني','city','khobar',
    'mosque_id','29000000-0000-4000-8000-0000000000b1','phone','0500000202','email','yasser@example.invalid'))$$,
  '23505', 'An application is already waiting', 'P16 one waiting application at a time');
select is(public.lessons_my_roles()->'application'->>'status', 'pending', 'P17 his roles show the waiting application');
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a3');
select is((select count(*)::int from public.preacher_applications), 0, 'P18 another account cannot read it');
select throws_ok($$select public.lessons_decide_application(pg_temp.id('app1'), true)$$, '42501', null,
  'P19 a viewer cannot decide applications');
reset role;
select is(pg_temp.queued('application_received'), 1, 'P20 the applicant is emailed that it arrived');
select is((select count(*)::int from public.lesson_notifications
   where profile_id = '29000000-0000-4000-8000-0000000000a1' and route = '/admin/lessons/approvals'), 1,
  'P21 admins are told in the app');

set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a1');
select is((select count(*)::int from public.preacher_applications where status = 'pending'), 1, 'P22 admins read applications');
select throws_ok($$select public.lessons_decide_application(pg_temp.id('app1'), false, 'no')$$, '22023',
  'A reason is required to decline', 'P23 declining needs a reason');
select lives_ok($$select public.lessons_decide_application(pg_temp.id('app1'), false, 'نحتاج تزكية من المكتب')$$,
  'P24 an admin declines with a reason');
reset role;
select is((select status from private.preacher_emails where kind = 'application_rejected'), 'queued', 'P25 the decline email waits');
select ok((select send_after > now() + interval '14 minutes' from private.preacher_emails where kind = 'application_rejected'),
  'P26 for the 15-minute undo window');
select is((select note from public.lesson_audit where action = 'applicationRejected'), 'نحتاج تزكية من المكتب',
  'P27 the log keeps the reason');
set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a4');
select throws_ok($$select public.lessons_undo_application(pg_temp.id('app1'))$$, '22023', null,
  'P28 only the admin who decided can undo');
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a1');
select public.lessons_undo_application(pg_temp.id('app1'));
reset role;
select is((select status from private.preacher_emails where kind = 'application_rejected'), 'cancelled',
  'P29 undoing cancels the decline email');
set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a1');
insert into ids select 'p3', public.lessons_decide_application(pg_temp.id('app1'), true, null, '{"affiliation":"ministry"}');
reset role;
select is((select linked_profile_id::text || '|' || joined_via || '|' || affiliation || '|' || array_to_string(languages, ',')
   from public.preachers where id = pg_temp.id('p3')),
  '29000000-0000-4000-8000-0000000000a2|application|ministry|ar,en', 'P30 approving creates his card linked to his account');
select is((select m.name_ar || '|' || m.district_id from public.preachers p join public.mosques m on m.id = p.home_mosque_id
   where p.id = pg_temp.id('p3')), 'مسجد الرحمة|thuqbah', 'P31 the mosque he named is added as his initial mosque');
select is((select phone || '|' || email from private.preacher_contacts where preacher_id = pg_temp.id('p3')),
  '0500000202|yasser@example.invalid', 'P32 his contacts are kept privately');
select is(pg_temp.queued('application_approved'), 1, 'P33 the approval email is queued');

-- ---------------------------------------------------------------------------
-- His own page through his account
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a3');
select throws_ok($$select public.lessons_me_page()$$, '42501', null, 'P34 an account without a card has no preacher page');
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a2');
select is(public.lessons_my_roles()->>'preacher_id', pg_temp.id('p3')::text, 'P35 his roles name his card');
select is(public.lessons_me_page()->'key'->>'kind', 'account', 'P36 he opens his page without a link');
select throws_ok($$select public.lessons_me_request_lesson(jsonb_build_object('title_ar','درس في مسجد مخفي','type','lesson',
    'topic','fiqh','slot','isha','dates',jsonb_build_array(public.lessons_today() + 3),'mosque_id','29000000-0000-4000-8000-0000000000ff'))$$,
  '22023', 'Choose a mosque', 'P37 a suggested mosque must be listed');
insert into ids select 'r1', public.lessons_me_request_lesson(jsonb_build_object('title_ar', 'شرح الأربعين النووية',
  'type', 'lesson', 'topic', 'hadith', 'slot', 'isha', 'dates', jsonb_build_array(public.lessons_today() + 3),
  'mosque_id', '29000000-0000-4000-8000-0000000000b2'));
reset role;
select is((select mosque_id from public.lessons where request_id = pg_temp.id('r1')),
  '29000000-0000-4000-8000-0000000000b2'::uuid, 'P38 he can ask for any mosque, not only his first one');
set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a2');
select lives_ok($$select public.lessons_me_update_profile('{"title_ar":"إمام وخطيب","email":"new@example.invalid"}')$$,
  'P39 he proposes a card change with a new email');
reset role;
select is((select actor_name from public.lesson_audit where action = 'request' order by id desc limit 1),
  'Yasser Applicant', 'P40 his request is logged under his name');

set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a1');
select public.lessons_review(array[pg_temp.id('r1')], 'approve');
reset role;
select is(pg_temp.queued('request_approved'), 1, 'P41 approving his request queues an email');
select is((select count(*)::int from public.lesson_notifications where profile_id = '29000000-0000-4000-8000-0000000000a2'
   and route = '/lessons/me/preacher' and title_en like 'Your request was approved%'), 1, 'P42 and tells him in the app');
set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a1');
select public.lessons_undo_review(array[pg_temp.id('r1')]);
reset role;
select is(pg_temp.queued('request_approved'), 0, 'P43 undoing the approval cancels its email');
set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a1');
select public.lessons_review(array[pg_temp.id('r1')], 'reject', 'المسجد مشغول ذلك اليوم');
select public.lessons_decide_edit((select id from public.preacher_edits where preacher_id = pg_temp.id('p3') and status = 'pending'), true);
reset role;
select is((select note from public.lesson_audit where action = 'reject' order by id desc limit 1), 'المسجد مشغول ذلك اليوم',
  'P44 a declined request keeps its reason in the log');
select is((select email from private.preacher_contacts where preacher_id = pg_temp.id('p3')), 'new@example.invalid',
  'P45 an approved card change can update his email');

-- ---------------------------------------------------------------------------
-- Lessons an admin adds, cancels and moves
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a1');
insert into ids select 'req2', public.lessons_add(jsonb_build_object('preacher_id', pg_temp.id('p1'),
  'mosque_id', '29000000-0000-4000-8000-0000000000b1', 'title_ar', 'تفسير جزء عم', 'type', 'lesson',
  'topic', 'tafsir', 'slot', 'maghrib', 'dates',
  jsonb_build_array(public.lessons_today() + 2, public.lessons_today() + 9, public.lessons_today() + 16)));
reset role;
select is((select count(*)::int from private.preacher_emails where kind = 'lesson_assigned' and ref_id = pg_temp.id('req2')), 1,
  'P46 a weekly series assigned to him is one email');
set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a1');
select public.lessons_edit_lesson((select id from public.lessons where request_id = pg_temp.id('req2') and seq = 2),
  jsonb_build_object('slot', 'isha'));
select public.lessons_edit_lesson((select id from public.lessons where request_id = pg_temp.id('req2') and seq = 2),
  jsonb_build_object('mosque_id', '29000000-0000-4000-8000-0000000000b3'));
select public.lessons_cancel_lesson((select id from public.lessons where request_id = pg_temp.id('req2') and seq = 3), 'سفر');
reset role;
select is(pg_temp.queued('lesson_changed'), 1, 'P47 a session moved twice is one email');
select is(pg_temp.queued('lesson_cancelled'), 1, 'P48 a cancelled session is emailed');
select is((select note from public.lesson_audit where action = 'cancel' order by id desc limit 1), 'سفر',
  'P49 with the reason in the log');

-- ---------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a1');
select throws_ok($$select * from public.claim_preacher_emails()$$, '42501', null, 'P50 a signed-in account cannot claim emails');
reset role;
update private.preacher_emails set send_after = now() - interval '1 second' where status = 'queued';
set local role service_role;
create temporary table claimed as select * from public.claim_preacher_emails(100);
reset role;
select is((select to_email || '|' || (data->>'title_ar') || '|' || (data->>'count') || '|' || (data->>'mosque_en')
   from claimed where kind = 'lesson_assigned'),
  'fahd@example.invalid|تفسير جزء عم|2|Al-Huda Mosque',
  'P51 the email is read when sent: address, lesson, the sessions still on (one was cancelled), mosque');
select is((select data->>'mosque_en' from claimed where kind = 'lesson_changed'), 'Duplicate Mosque',
  'P52 a moved lesson names its new place');
select ok((select data ? 'token' from claimed where kind = 'invite'), 'P53 an invitation carries its link key');
select ok(not exists (select 1 from claimed where kind = 'application_rejected'), 'P54 an undone decision is not sent');
set local role service_role;
select public.preacher_email_result(c.id, true, null, 'prov-1') from claimed c where c.kind = 'invite';
select public.preacher_email_result(c.id, false, 'timeout') from claimed c where c.kind = 'lesson_cancelled';
reset role;
select is((select status || '|' || (payload ? 'token')::text from private.preacher_emails where kind = 'invite' and status = 'sent'),
  'sent|false', 'P55 a sent invitation no longer keeps its key');
select ok((select status = 'queued' and send_after > now() and last_error = 'timeout'
   from private.preacher_emails where kind = 'lesson_cancelled'), 'P56 a failure waits and is retried');

-- ---------------------------------------------------------------------------
-- Merging and account deletion
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('29000000-0000-4000-8000-0000000000a1');
select public.lessons_upsert_preacher(jsonb_build_object('id', pg_temp.id('p2'), 'home_mosque_id', '29000000-0000-4000-8000-0000000000b3'));
select public.lessons_remove_mosque('29000000-0000-4000-8000-0000000000b3', '29000000-0000-4000-8000-0000000000b1');
reset role;
select is((select home_mosque_id from public.preachers where id = pg_temp.id('p2')), '29000000-0000-4000-8000-0000000000b1'::uuid,
  'P57 merging a mosque moves the preachers who start there');
delete from public.profiles where id = '29000000-0000-4000-8000-0000000000a2';
select is((select photo_url from public.preachers where id = pg_temp.id('p3')), null,
  'P58 a deleted account''s photo leaves the card');
select is((select actor_name || '|' || actor_email from public.lesson_audit where action = 'request' order by id desc limit 1),
  'Deleted account|deleted', 'P59 and the log forgets its name and email');

select * from finish();
rollback;
