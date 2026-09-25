-- P6S wave 3: session-scoped start, ingest reports and end (late-reconnect fencing).
begin;
select no_plan();
insert into auth.users(id,email) values
 ('67000000-0000-4000-8000-000000000001','admin2@example.invalid'),
 ('67000000-0000-4000-8000-000000000002','caster2@example.invalid'),
 ('67000000-0000-4000-8000-000000000003','other2@example.invalid');
insert into public.profiles(id,email,is_streamer,is_verified) values
 ('67000000-0000-4000-8000-000000000001','admin2@example.invalid',false,false),
 ('67000000-0000-4000-8000-000000000002','caster2@example.invalid',true,true),
 ('67000000-0000-4000-8000-000000000003','other2@example.invalid',true,true);
insert into public.user_roles(profile_id,role) values ('67000000-0000-4000-8000-000000000001','admin');
insert into auth.sessions(id,user_id) values
 ('67000000-0000-4000-8000-000000000011','67000000-0000-4000-8000-000000000001');
insert into public.device_sessions(user_id,device_id,is_primary_broadcaster,last_active_at) values
 ('67000000-0000-4000-8000-000000000002','phone1',true,now()),
 ('67000000-0000-4000-8000-000000000002','phone2',false,now()),
 ('67000000-0000-4000-8000-000000000003','o1',true,now());
create temporary table ids(k text primary key, v uuid);
grant all on ids to authenticated;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.start_broadcast_session('liveVideo','AAAAAAAAAAA','phone1',null,'obs')$$,'22023',null,'unknown sender refused');
select throws_ok($$select public.start_broadcast_session('liveVideo','AAAAAAAAAAA','phone2',null,'phone_direct')$$,'42501',null,'non-primary device refused');
select throws_ok($$select public.start_broadcast_session('liveVideo','not-an-id','phone1',null,'phone_direct')$$,'P0001',null,'invalid watch ID refused');
insert into ids select 's1', public.start_broadcast_session('liveVideo','AAAAAAAAAAA','phone1',null,'phone_direct');
select ok((select v from ids where k='s1') is not null,'phone start returns the session id');
select is((select sender_mode from public.broadcast_sessions where state='live'),'phone_direct','sender recorded');
select is((select ingest_state from public.broadcast_sessions where state='live'),'sending','phone starts as sending');
select lives_ok($$select public.report_broadcast_ingest((select v from ids where k='s1'),'phone1','interrupted')$$,'phone reports interruption');
select is((select ingest_state from public.broadcast_sessions where state='live'),'interrupted','interruption recorded');
reset role;
select ok((select is_currently_live and live_ingest_state='interrupted' from public.streamer_public_profiles where id='67000000-0000-4000-8000-000000000002'),'viewers see the broadcast as live but interrupted');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.report_broadcast_ingest((select v from ids where k='s1'),'phone1','ended')$$,'22023',null,'unknown ingest state refused');
select throws_ok($$select public.report_broadcast_ingest((select v from ids where k='s1'),'phone2','sending')$$,'42501',null,'another device of the same account cannot report');
select lives_ok($$select public.report_broadcast_ingest((select v from ids where k='s1'),'phone1','sending')$$,'phone recovers');
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.report_broadcast_ingest((select v from ids where k='s1'),'o1','sending')$$,'42501',null,'another account cannot report');
select throws_ok($$select public.end_broadcast_session((select v from ids where k='s1'),'o1')$$,'42501',null,'another account cannot end it');
-- Admin End, then a late reconnect report is refused.
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000001","session_id":"67000000-0000-4000-8000-000000000011","role":"authenticated"}',true);
select lives_ok($$select public.admin_auth_account_action('67000000-0000-4000-8000-000000000002','force_end','test')$$,'admin ends it');
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.report_broadcast_ingest((select v from ids where k='s1'),'phone1','sending')$$,'55000',null,'late reconnect after admin End is refused');
select throws_ok($$select public.set_live_state(true,'liveVideo','AAAAAAAAAAA','phone1')$$,'42501',null,'a plain live write cannot undo the admin End');
reset role;
select ok(not (select is_currently_live from public.profiles where id='67000000-0000-4000-8000-000000000002'),'late reconnect did not revive LIVE');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
insert into ids select 's1b', public.start_broadcast_session('liveVideo','AAAAAAAAAAA','phone1',null,'phone_direct');
select ok((select v from ids where k='s1b') <> (select v from ids where k='s1'),'an explicit new start after admin End is a new session');
select lives_ok($$select public.end_broadcast_session((select v from ids where k='s1b'),'phone1')$$,'owner ends it again');
reset role;
-- OBS start: ingest unknown, never "sending".
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
insert into ids select 's2', public.start_broadcast_session('liveVideo','BBBBBBBBBBB','phone1',null,'obs_laptop');
select is((select ingest_state from public.broadcast_sessions where state='live'),'unknown','OBS ingest is not observed by the app');
-- A stale End for the old session does not end the new one.
select lives_ok($$select public.end_broadcast_session((select v from ids where k='s1'),'phone1')$$,'ending an old session is a no-op');
reset role;
select ok((select is_currently_live from public.profiles where id='67000000-0000-4000-8000-000000000002'),'new broadcast still live');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.end_broadcast_session((select v from ids where k='s2'),'phone1')$$,'owner ends the current session');
reset role;
select is((select end_reason from public.broadcast_sessions where id=(select v from ids where k='s2')),'owner_end','owner end recorded');
set local role anon;
select throws_ok($$select public.start_broadcast_session('liveVideo','CCCCCCCCCCC','phone1',null,'phone_direct')$$,'42501',null,'anon cannot start');
reset role;
-- An interruption that never recovers stops being listed after 120 s.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
insert into ids select 's3', public.start_broadcast_session('liveVideo','DDDDDDDDDDD','phone1',null,'phone_direct');
select lives_ok($$select public.report_broadcast_ingest((select v from ids where k='s3'),'phone1','interrupted')$$,'phone reports interruption');
reset role;
select is(public.sweep_stale_live_flags(),0,'a fresh interruption is not swept');
update public.broadcast_sessions set interrupted_since=now()-interval '3 minutes' where id=(select v from ids where k='s3');
select is(public.sweep_stale_live_flags(),1,'an old interruption is swept');
select is((select end_reason from public.broadcast_sessions where id=(select v from ids where k='s3')),'ingest_lost','recorded as ingest lost');
select ok(not (select is_currently_live from public.profiles where id='67000000-0000-4000-8000-000000000002'),'no longer listed live');
-- Sender type is not public.
select ok(not exists(select 1 from information_schema.columns where table_schema='public'
  and table_name in ('streamer_public_profiles','organization_public_profiles') and column_name like '%sender%'),'sender type is not in public views');
-- Organization revocation records its own reason.
insert into public.organizations(id,name_en,name_ar,owner_profile_id,is_verified) values
 ('67000000-0000-4000-8000-000000000040','Org','Org','67000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
insert into ids select 's4', public.start_broadcast_session('liveVideo','EEEEEEEEEEE','phone1','67000000-0000-4000-8000-000000000040','phone_direct');
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.admin_moderate_broadcaster('67000000-0000-4000-8000-000000000040',true,'revoke_organization','test')$$,'admin revokes the organization');
reset role;
select is((select end_reason from public.broadcast_sessions where id=(select v from ids where k='s4')),'organization_revoked','organization revocation recorded');
select * from finish();
rollback;
