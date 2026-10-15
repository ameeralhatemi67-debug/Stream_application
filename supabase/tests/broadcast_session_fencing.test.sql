-- P6S wave 3: session-scoped start, ingest reports and end (late-reconnect fencing).
--
-- Starts now follow the provider-confirmed path (20261001102758 revoked the
-- client start RPCs; 20261001111022 made LIVE provider-confirmed): the
-- presenter reserves an accepted session from its primary device and the
-- provider worker confirms the feed, broadcast and live status. Ingest
-- reports and End remain session-scoped client calls and are fenced as before.
begin;
select no_plan();
insert into auth.users(id,email) values
 ('67000000-0000-4000-8000-000000000001','admin2@example.invalid'),
 ('67000000-0000-4000-8000-000000000002','caster2@example.invalid'),
 ('67000000-0000-4000-8000-000000000003','other2@example.invalid');
insert into public.profiles(id,email,is_streamer,is_verified,personal_broadcast_approved,organization_broadcast_approved) values
 ('67000000-0000-4000-8000-000000000001','admin2@example.invalid',false,false,false,false),
 ('67000000-0000-4000-8000-000000000002','caster2@example.invalid',true,true,true,true),
 ('67000000-0000-4000-8000-000000000003','other2@example.invalid',true,true,true,false);
insert into public.user_roles(profile_id,role) values ('67000000-0000-4000-8000-000000000001','admin');
insert into auth.sessions(id,user_id) values
 ('67000000-0000-4000-8000-000000000011','67000000-0000-4000-8000-000000000001'),
 ('67000000-0000-4000-8000-000000000012','67000000-0000-4000-8000-000000000002'),
 ('67000000-0000-4000-8000-000000000013','67000000-0000-4000-8000-000000000003');
insert into public.device_sessions(user_id,device_id,is_primary_broadcaster,last_active_at) values
 ('67000000-0000-4000-8000-000000000002','phone1',true,now()),
 ('67000000-0000-4000-8000-000000000002','phone2',false,now()),
 ('67000000-0000-4000-8000-000000000003','o1',true,now());
insert into public.channel_connections(id,owner_profile_id,youtube_channel_id,channel_title) values
 ('67000000-0000-4000-8000-000000000021','67000000-0000-4000-8000-000000000002','UCffffffffffffffffffffff','Caster');
create temporary table ids(k text primary key, v uuid);
grant all on ids to authenticated;
-- The provider worker (service_role in production) confirms a reserved session.
create function pg_temp.confirm_live(p_id uuid,p_watch text) returns void language plpgsql as $$
declare v_token uuid;
begin
  select operation_token into v_token from private.broadcast_provider where session_id=p_id;
  perform public.broadcast_provider_step(p_id,v_token,'stream_create',
    jsonb_build_object('id','feed-'||p_id,'url','rtmps://a.rtmps.youtube.com/live2','key','fake-ingest'));
  perform public.broadcast_provider_step(p_id,v_token,'broadcast_create',jsonb_build_object('id',p_watch));
  perform public.broadcast_provider_step(p_id,v_token,'bind','{}');
  perform public.broadcast_provider_step(p_id,v_token,'observe','{"status":"live"}');
  perform public.broadcast_provider_step(p_id,v_token,'finish');
end $$;
-- The provider worker completes termination of an ending session.
create function pg_temp.provider_finished(p_id uuid) returns void language sql as $$
  update public.broadcast_sessions set state='completed',termination_pending=false,ended_at=coalesce(ended_at,now())
   where id=p_id and state='ending';
$$;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"67000000-0000-4000-8000-000000000012"}',true);
insert into ids select 's1', public.broadcast_create_personal('First','liveVideo');
select throws_ok($$select public.broadcast_reserve_confirmed((select v from ids where k='s1'),'phone1','obs','prepare','67000000-0000-4000-8000-000000000021',1)$$,'22023',null,'unknown sender refused');
select throws_ok($$select public.broadcast_reserve_confirmed((select v from ids where k='s1'),'phone2','phone_direct','prepare','67000000-0000-4000-8000-000000000021',1)$$,'42501',null,'non-primary device refused');
select public.broadcast_reserve_confirmed((select v from ids where k='s1'),'phone1','phone_direct','prepare','67000000-0000-4000-8000-000000000021',1);
reset role;
select throws_ok($$select public.broadcast_provider_step((select v from ids where k='s1'),
 (select operation_token from private.broadcast_provider where session_id=(select v from ids where k='s1')),
 'broadcast_create','{"id":"not-an-id"}')$$,'22023',null,'invalid watch ID refused');
select pg_temp.confirm_live((select v from ids where k='s1'),'AAAAAAAAAAA');
set local role authenticated;
select ok((select id from public.broadcast_sessions where state='live')=(select v from ids where k='s1'),'phone start returns the session id');
select is((select sender_mode from public.broadcast_sessions where state='live'),'phone_direct','sender recorded');
select lives_ok($$select public.report_broadcast_ingest((select v from ids where k='s1'),'phone1','sending')$$,'phone reports its feed');
select is((select ingest_state from public.broadcast_sessions where state='live'),'sending','phone feed is recorded as sending');
select lives_ok($$select public.report_broadcast_ingest((select v from ids where k='s1'),'phone1','interrupted')$$,'phone reports interruption');
select is((select ingest_state from public.broadcast_sessions where state='live'),'interrupted','interruption recorded');
reset role;
select ok((select is_currently_live and live_ingest_state='interrupted' from public.streamer_public_profiles where id='67000000-0000-4000-8000-000000000002'),'viewers see the broadcast as live but interrupted');
set local role authenticated;
select throws_ok($$select public.report_broadcast_ingest((select v from ids where k='s1'),'phone1','ended')$$,'22023',null,'unknown ingest state refused');
select throws_ok($$select public.report_broadcast_ingest((select v from ids where k='s1'),'phone2','sending')$$,'42501',null,'another device of the same account cannot report');
select lives_ok($$select public.report_broadcast_ingest((select v from ids where k='s1'),'phone1','sending')$$,'phone recovers');
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000003","role":"authenticated","session_id":"67000000-0000-4000-8000-000000000013"}',true);
select throws_ok($$select public.report_broadcast_ingest((select v from ids where k='s1'),'o1','sending')$$,'42501',null,'another account cannot report');
select throws_ok($$select public.end_broadcast_session((select v from ids where k='s1'),'o1')$$,'42501',null,'another account cannot end it');
-- Admin End, then a late reconnect report is refused.
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000001","session_id":"67000000-0000-4000-8000-000000000011","role":"authenticated"}',true);
select lives_ok($$select public.admin_auth_account_action('67000000-0000-4000-8000-000000000002','force_end','test')$$,'admin ends it');
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"67000000-0000-4000-8000-000000000012"}',true);
select throws_ok($$select public.report_broadcast_ingest((select v from ids where k='s1'),'phone1','sending')$$,'55000',null,'late reconnect after admin End is refused');
select throws_ok($$select public.set_live_state(true,'liveVideo','AAAAAAAAAAA','phone1')$$,'42501',null,'a plain live write cannot undo the admin End');
reset role;
select ok(not (select is_currently_live from public.profiles where id='67000000-0000-4000-8000-000000000002'),'late reconnect did not revive LIVE');
select pg_temp.provider_finished((select v from ids where k='s1'));
set local role authenticated;
insert into ids select 's1b', public.broadcast_create_personal('Again','liveVideo');
select public.broadcast_reserve_confirmed((select v from ids where k='s1b'),'phone1','phone_direct','prepare','67000000-0000-4000-8000-000000000021',1);
reset role;
select pg_temp.confirm_live((select v from ids where k='s1b'),'AAAAAAAAAA2');
set local role authenticated;
select ok((select id from public.broadcast_sessions where state='live') <> (select v from ids where k='s1'),'an explicit new start after admin End is a new session');
select lives_ok($$select public.end_broadcast_session((select v from ids where k='s1b'),'phone1')$$,'owner ends it again');
reset role;
select pg_temp.provider_finished((select v from ids where k='s1b'));
-- OBS start: ingest unknown, never "sending".
set local role authenticated;
insert into ids select 's2', public.broadcast_create_personal('Laptop','liveVideo');
select public.broadcast_reserve_confirmed((select v from ids where k='s2'),'phone1','obs_laptop','prepare','67000000-0000-4000-8000-000000000021',1);
reset role;
select pg_temp.confirm_live((select v from ids where k='s2'),'BBBBBBBBBBB');
set local role authenticated;
select is((select ingest_state from public.broadcast_sessions where state='live'),'unknown','OBS ingest is not observed by the app');
select throws_ok($$select public.report_broadcast_ingest((select v from ids where k='s2'),'phone1','sending')$$,'42501',null,'an OBS session takes no phone ingest reports');
-- A stale End for the old session does not end the new one.
select lives_ok($$select public.end_broadcast_session((select v from ids where k='s1'),'phone1')$$,'ending an old session is a no-op');
reset role;
select ok((select is_currently_live from public.profiles where id='67000000-0000-4000-8000-000000000002'),'new broadcast still live');
set local role authenticated;
select lives_ok($$select public.end_broadcast_session((select v from ids where k='s2'),'phone1')$$,'owner ends the current session');
reset role;
select is((select end_reason from public.broadcast_sessions where id=(select v from ids where k='s2')),'owner_end','owner end recorded');
select pg_temp.provider_finished((select v from ids where k='s2'));
set local role anon;
select throws_ok($$select public.broadcast_create_personal('Anon','liveVideo')$$,'42501',null,'anon cannot start');
reset role;
-- An interruption that never recovers stops being listed after 120 s.
set local role authenticated;
insert into ids select 's3', public.broadcast_create_personal('Lost','liveVideo');
select public.broadcast_reserve_confirmed((select v from ids where k='s3'),'phone1','phone_direct','prepare','67000000-0000-4000-8000-000000000021',1);
reset role;
select pg_temp.confirm_live((select v from ids where k='s3'),'DDDDDDDDDDD');
set local role authenticated;
select lives_ok($$select public.report_broadcast_ingest((select v from ids where k='s3'),'phone1','interrupted')$$,'phone reports interruption');
reset role;
select is(public.sweep_stale_live_flags(),0,'a fresh interruption is not swept');
update public.broadcast_sessions set interrupted_since=now()-interval '3 minutes' where id=(select v from ids where k='s3');
select is(public.sweep_stale_live_flags(),1,'an old interruption is swept');
select is((select end_reason from public.broadcast_sessions where id=(select v from ids where k='s3')),'ingest_lost','recorded as ingest lost');
select ok(not (select is_currently_live from public.profiles where id='67000000-0000-4000-8000-000000000002'),'no longer listed live');
select pg_temp.provider_finished((select v from ids where k='s3'));
-- Sender type is not public.
select ok(not exists(select 1 from information_schema.columns where table_schema='public'
  and table_name in ('streamer_public_profiles','organization_public_profiles') and column_name like '%sender%'),'sender type is not in public views');
-- Organization revocation records its own reason. The org show is scheduled
-- by its owner for itself, accepted, and confirmed by the provider.
insert into public.organizations(id,name_en,name_ar,owner_profile_id,is_verified) values
 ('67000000-0000-4000-8000-000000000040','Org','Org','67000000-0000-4000-8000-000000000002',true);
insert into private.organization_v1_pilots(organization_id) values('67000000-0000-4000-8000-000000000040');
insert into public.channel_connections(id,owner_profile_id,organization_id,youtube_channel_id,channel_title) values
 ('67000000-0000-4000-8000-000000000022','67000000-0000-4000-8000-000000000002','67000000-0000-4000-8000-000000000040','UCgggggggggggggggggggggg','Org');
update public.org_memberships set permissions=permissions||'{"can_go_live_video":true}'
 where organization_id='67000000-0000-4000-8000-000000000040' and profile_id='67000000-0000-4000-8000-000000000002';
set local role authenticated;
insert into ids select 'org_schedule', public.broadcast_save_schedule('67000000-0000-4000-8000-000000000040',null,
 '67000000-0000-4000-8000-000000000002','once',((now()+interval '5 minutes') at time zone 'Asia/Riyadh')::time,'{}',
 now()+interval '5 minutes','Org show','','liveVideo');
insert into ids select 's4', id from public.broadcast_sessions where schedule_id=(select v from ids where k='org_schedule');
select public.broadcast_accept_assignment((select v from ids where k='s4'),true,(select revision from public.broadcast_sessions where id=(select v from ids where k='s4')));
select public.broadcast_reserve_confirmed((select v from ids where k='s4'),'phone1','phone_direct','prepare','67000000-0000-4000-8000-000000000022',1);
reset role;
select pg_temp.confirm_live((select v from ids where k='s4'),'EEEEEEEEEEE');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000001","session_id":"67000000-0000-4000-8000-000000000011","role":"authenticated"}',true);
select lives_ok($$select public.admin_moderate_broadcaster('67000000-0000-4000-8000-000000000040',true,'revoke_organization','test')$$,'admin revokes the organization');
reset role;
select is((select end_reason from public.broadcast_sessions where id=(select v from ids where k='s4')),'organization_revoked','organization revocation recorded');
select * from finish();
rollback;
