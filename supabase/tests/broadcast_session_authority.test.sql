-- P6S wave 3 group 1: broadcast session records, end reasons, admin End
-- without demotion, and reversible hide-from-discovery.
--
-- Starts follow the provider-confirmed path (20261001102758 revoked the client
-- start RPCs; 20261001111022 made LIVE provider-confirmed): the caster
-- reserves an accepted personal session from its primary device and the
-- provider worker confirms the feed, broadcast and live status. Admin, owner,
-- transfer, expiry, revocation and ban ends are asserted on those sessions.
begin;
select no_plan();
insert into auth.users(id,email) values
 ('66000000-0000-4000-8000-000000000001','admin@example.invalid'),
 ('66000000-0000-4000-8000-000000000002','caster@example.invalid'),
 ('66000000-0000-4000-8000-000000000003','viewer@example.invalid'),
 ('66000000-0000-4000-8000-000000000004','other@example.invalid');
insert into public.profiles(id,email,is_streamer,is_verified,personal_broadcast_approved,organization_broadcast_approved) values
 ('66000000-0000-4000-8000-000000000001','admin@example.invalid',false,false,false,false),
 ('66000000-0000-4000-8000-000000000002','caster@example.invalid',true,true,true,true),
 ('66000000-0000-4000-8000-000000000003','viewer@example.invalid',false,false,false,false),
 ('66000000-0000-4000-8000-000000000004','other@example.invalid',true,true,true,false);
insert into public.user_roles(profile_id,role) values ('66000000-0000-4000-8000-000000000001','admin');
insert into auth.sessions(id,user_id) values
 ('66000000-0000-4000-8000-000000000011','66000000-0000-4000-8000-000000000001'),
 ('66000000-0000-4000-8000-000000000012','66000000-0000-4000-8000-000000000002'),
 ('66000000-0000-4000-8000-000000000014','66000000-0000-4000-8000-000000000004');
insert into public.device_sessions(user_id,device_id,is_primary_broadcaster,last_active_at) values
 ('66000000-0000-4000-8000-000000000002','phoneA',true,now()),
 ('66000000-0000-4000-8000-000000000002','phoneB',false,now()),
 ('66000000-0000-4000-8000-000000000004','otherA',true,now());
insert into public.channel_connections(id,owner_profile_id,youtube_channel_id,channel_title) values
 ('66000000-0000-4000-8000-000000000021','66000000-0000-4000-8000-000000000002','UCkkkkkkkkkkkkkkkkkkkkkk','Caster'),
 ('66000000-0000-4000-8000-000000000022','66000000-0000-4000-8000-000000000004','UCllllllllllllllllllllll','Other');
create temporary table ids(k text primary key,v uuid);
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
-- The provider worker completes termination of whatever the presenter has ending.
create function pg_temp.provider_finished(p_owner uuid) returns void language sql as $$
  update public.broadcast_sessions set state='completed',termination_pending=false,ended_at=coalesce(ended_at,now())
   where owner_id=p_owner and state='ending';
$$;
-- The presenter creates and reserves a personal session from a device. Runs
-- as the calling authenticated user.
create function pg_temp.reserve_personal(p_key text,p_device text,p_connection uuid) returns void language plpgsql as $$
begin
  insert into ids select p_key,public.broadcast_create_personal(p_key,'liveVideo');
  perform public.broadcast_reserve_confirmed((select v from ids where k=p_key),p_device,'phone_direct','prepare',p_connection,
    (select revision from public.channel_connections where id=p_connection));
end $$;

-- Caster goes live from the primary device.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"66000000-0000-4000-8000-000000000012"}',true);
select pg_temp.reserve_personal('a','phoneA','66000000-0000-4000-8000-000000000021');
reset role;
select lives_ok($$select pg_temp.confirm_live((select v from ids where k='a'),'AAAAAAAAAAA')$$,'caster goes live');
set local role authenticated;
select is((select count(*)::int from public.broadcast_sessions where state='live'),1,'owner sees one live session');
select is((select device_id from public.broadcast_sessions where state='live'),'phoneA','session records the sending device');
select is((select stream_id from public.broadcast_sessions where state='live'),'AAAAAAAAAAA','session records the exact watch ID');
reset role;
select lives_ok($$select public.broadcast_provider_step((select v from ids where k='a'),
 (select operation_token from private.broadcast_provider where session_id=(select v from ids where k='a')),'observe','{"status":"live"}')$$,
 're-asserting the same broadcast is idempotent');
set local role authenticated;
select is((select count(*)::int from public.broadcast_sessions),1,'re-assert does not open a second session');
select throws_ok($$insert into public.broadcast_sessions(owner_id,stream_id,broadcast_type) values('66000000-0000-4000-8000-000000000002','BBBBBBBBBBB','liveVideo')$$,'42501',null,'no direct insert');
select throws_ok($$update public.broadcast_sessions set hidden_from_discovery=true$$,'42501',null,'no direct update');
select throws_ok($$delete from public.broadcast_sessions$$,'42501',null,'no direct delete');
select is((public.my_broadcast_status()->>'live')::boolean,true,'status reports own live session');
select is(public.my_broadcast_status()->>'stream_id','AAAAAAAAAAA','status reports own watch ID');
reset role;
select ok((select live_session_id is not null and is_currently_live and not is_hidden_from_discovery
  from public.streamer_public_profiles where id='66000000-0000-4000-8000-000000000002'),'public view exposes live session id');

-- Another account cannot read the caster's private session rows or status.
-- Public sessions are readable by design (broadcast_is_public, 20261001111022).
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select is((select count(*)::int from public.broadcast_sessions where not public.broadcast_is_public(id)),0,'viewer reads no other session rows');
select is((public.my_broadcast_status()->>'live')::boolean,false,'viewer status is only their own');
select throws_ok($$select public.admin_set_stream_discovery('66000000-0000-4000-8000-000000000002',true,'x')$$,'42501',null,'viewer cannot hide a stream');
reset role;
set local role anon;
select is((select count(*)::int from public.broadcast_sessions where not public.broadcast_is_public(id)),0,'anon reads only public sessions');
select throws_ok($$select public.my_broadcast_status()$$,'42501',null,'anon cannot call status');
select throws_ok($$select public.admin_set_stream_discovery('66000000-0000-4000-8000-000000000002',true,'x')$$,'42501',null,'anon cannot hide a stream');
reset role;

-- Admin hides the live session from discovery: broadcast keeps running.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","session_id":"66000000-0000-4000-8000-000000000011","role":"authenticated"}',true);
select throws_ok($$select public.admin_set_stream_discovery('66000000-0000-4000-8000-000000000002',true,' ')$$,'22023',null,'reason required');
select lives_ok($$select public.admin_set_stream_discovery('66000000-0000-4000-8000-000000000002',true,'off-topic')$$,'admin hides from discovery');
select lives_ok($$select public.admin_set_stream_discovery('66000000-0000-4000-8000-000000000002',true,'again')$$,'repeat hide is a no-op');
reset role;
select ok((select is_currently_live and is_hidden_from_discovery and active_stream_id='AAAAAAAAAAA'
  from public.streamer_public_profiles where id='66000000-0000-4000-8000-000000000002'),'hidden session stays live with the same watch ID');
select ok((select is_primary_broadcaster from public.device_sessions where device_id='phoneA'),'hiding keeps the device');
select is((select count(*)::int from public.audit_logs where action='streamHiddenFromDiscovery'),1,'one audited hide');
set local role anon;
select is((select count(*)::int from public.broadcast_sessions),0,'anon cannot read a session hidden from discovery');
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"66000000-0000-4000-8000-000000000012"}',true);
select is((select hidden_from_discovery from public.broadcast_sessions where state='live'),true,'owner sees the hide');
select throws_ok($$select public.log_audit_event(null,'streamShownInDiscovery','x','x','{}')$$,'42501',null,'cannot forge discovery audit');
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","session_id":"66000000-0000-4000-8000-000000000011","role":"authenticated"}',true);
select lives_ok($$select public.admin_set_stream_discovery('66000000-0000-4000-8000-000000000002',false,'reinstated')$$,'admin shows it again');
reset role;
select ok((select is_currently_live and not is_hidden_from_discovery from public.streamer_public_profiles
  where id='66000000-0000-4000-8000-000000000002'),'reinstated session is discoverable');
select is((select count(*)::int from public.audit_logs where action='streamShownInDiscovery'),1,'one audited reinstatement');

-- Admin End stops the broadcast, keeps device and approval.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","session_id":"66000000-0000-4000-8000-000000000011","role":"authenticated"}',true);
select lives_ok($$select public.admin_auth_account_action('66000000-0000-4000-8000-000000000002','force_end','test end')$$,'admin ends broadcast');
reset role;
select ok(not (select is_currently_live from public.profiles where id='66000000-0000-4000-8000-000000000002'),'live cleared');
select ok((select is_primary_broadcaster from public.device_sessions where device_id='phoneA'),'device ownership retained');
select ok((select is_streamer and is_verified and personal_broadcast_approved from public.profiles where id='66000000-0000-4000-8000-000000000002'),'approval retained');
select is((select end_reason from public.broadcast_sessions where stream_id='AAAAAAAAAAA'),'admin_end','ended by admin');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"66000000-0000-4000-8000-000000000012"}',true);
select is(public.my_broadcast_status()->'last_ended'->>'reason','admin_end','owner learns the end reason');
select throws_ok($$select public.admin_set_stream_discovery('66000000-0000-4000-8000-000000000001',true,'x')$$,'42501',null,'non-admin still denied');
reset role;
-- The owner may deliberately start again after an admin End.
select pg_temp.provider_finished('66000000-0000-4000-8000-000000000002');
set local role authenticated;
select pg_temp.reserve_personal('c','phoneA','66000000-0000-4000-8000-000000000021');
reset role;
select lives_ok($$select pg_temp.confirm_live((select v from ids where k='c'),'CCCCCCCCCCC')$$,'owner starts a new broadcast');
select ok(not (select hidden_from_discovery from public.broadcast_sessions where state='live'),'a new session starts visible');

-- End-and-block: same watch ID cannot be relisted; device kept.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","session_id":"66000000-0000-4000-8000-000000000011","role":"authenticated"}',true);
select lives_ok($$select public.admin_auth_account_action('66000000-0000-4000-8000-000000000002','remove_from_feed','block')$$,'admin ends and blocks');
select throws_ok($$select public.admin_set_stream_discovery('66000000-0000-4000-8000-000000000002',true,'x')$$,'22023',null,'no live session to hide');
reset role;
select is((select end_reason from public.broadcast_sessions where stream_id='CCCCCCCCCCC'),'admin_remove','ended and blocked by admin');
select ok((select is_primary_broadcaster from public.device_sessions where device_id='phoneA'),'device kept after block');
select pg_temp.provider_finished('66000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"66000000-0000-4000-8000-000000000012"}',true);
select pg_temp.reserve_personal('d','phoneA','66000000-0000-4000-8000-000000000021');
reset role;
select throws_ok($$select pg_temp.confirm_live((select v from ids where k='d'),'CCCCCCCCCCC')$$,'42501','Stream removed by moderation','blocked watch ID cannot be relisted');
select lives_ok($$select pg_temp.confirm_live((select v from ids where k='d'),'DDDDDDDDDDD')$$,'a different watch ID can start');
-- Owner end, then device transfer during a new broadcast.
set local role authenticated;
select lives_ok($$select public.end_broadcast_session((select v from ids where k='d'),'phoneA')$$,'owner ends');
reset role;
select is((select end_reason from public.broadcast_sessions where stream_id='DDDDDDDDDDD'),'owner_end','owner end recorded');
select pg_temp.provider_finished('66000000-0000-4000-8000-000000000002');
set local role authenticated;
select pg_temp.reserve_personal('e','phoneA','66000000-0000-4000-8000-000000000021');
reset role;
select lives_ok($$select pg_temp.confirm_live((select v from ids where k='e'),'EEEEEEEEEEE')$$,'live again');
set local role authenticated;
select is((public.claim_broadcaster_device_state('phoneB','Phone B','android',true)->>'claimed')::boolean,true,'phone B takes over');
reset role;
select is((select end_reason from public.broadcast_sessions where stream_id='EEEEEEEEEEE'),'device_transfer','transfer recorded');
select ok(not (select is_currently_live from public.profiles where id='66000000-0000-4000-8000-000000000002'),'transfer clears live');

-- Ingest loss, revocation and ban each record their reason. (A heartbeat-only
-- stale expiry no longer exists: the sweep ends a phone sender only after its
-- own encoder reported the feed interrupted for 120 s.)
select pg_temp.provider_finished('66000000-0000-4000-8000-000000000002');
update public.device_sessions set last_active_at=now() where device_id='phoneB';
set local role authenticated;
select pg_temp.reserve_personal('f','phoneB','66000000-0000-4000-8000-000000000021');
reset role;
select lives_ok($$select pg_temp.confirm_live((select v from ids where k='f'),'FFFFFFFFFFF')$$,'live on phone B');
set local role authenticated;
select public.report_broadcast_ingest((select v from ids where k='f'),'phoneB','interrupted');
reset role;
update public.broadcast_sessions set interrupted_since=now()-interval '3 minutes' where id=(select v from ids where k='f');
select ok(public.sweep_stale_live_flags() >= 1,'sweep clears a lost phone feed');
select is((select end_reason from public.broadcast_sessions where stream_id='FFFFFFFFFFF'),'ingest_lost','ingest loss recorded');
update public.device_sessions set last_active_at=now() where device_id='otherA';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000004","role":"authenticated","session_id":"66000000-0000-4000-8000-000000000014"}',true);
select pg_temp.reserve_personal('g','otherA','66000000-0000-4000-8000-000000000022');
reset role;
select lives_ok($$select pg_temp.confirm_live((select v from ids where k='g'),'GGGGGGGGGGG')$$,'second caster live');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","session_id":"66000000-0000-4000-8000-000000000011","role":"authenticated"}',true);
select lives_ok($$select public.admin_update_account('66000000-0000-4000-8000-000000000004','revoke_streamer','test')$$,'admin revokes approval');
reset role;
select is((select end_reason from public.broadcast_sessions where stream_id='GGGGGGGGGGG'),'approval_revoked','revocation recorded');
-- Re-approve the second caster and bring it live again, then ban it.
select pg_temp.provider_finished('66000000-0000-4000-8000-000000000004');
update public.profiles set is_streamer=true,is_verified=true,personal_broadcast_approved=true where id='66000000-0000-4000-8000-000000000004';
update public.device_sessions set last_active_at=now(),is_primary_broadcaster=true where device_id='otherA';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000004","role":"authenticated","session_id":"66000000-0000-4000-8000-000000000014"}',true);
select pg_temp.reserve_personal('h','otherA','66000000-0000-4000-8000-000000000022');
reset role;
select pg_temp.confirm_live((select v from ids where k='h'),'HHHHHHHHHHH');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","session_id":"66000000-0000-4000-8000-000000000011","role":"authenticated"}',true);
select lives_ok($$select public.admin_update_account('66000000-0000-4000-8000-000000000004','ban','test')$$,'admin bans');
reset role;
select is((select end_reason from public.broadcast_sessions where stream_id='HHHHHHHHHHH'),'ban','ban recorded');
-- Two broadcasters lose their feeds in one sweep: both get the same recorded reason.
select pg_temp.provider_finished('66000000-0000-4000-8000-000000000002');
select pg_temp.provider_finished('66000000-0000-4000-8000-000000000004');
update public.profiles set is_streamer=true,is_verified=true,personal_broadcast_approved=true where id='66000000-0000-4000-8000-000000000004';
delete from public.banned_users where profile_id='66000000-0000-4000-8000-000000000004';
update public.device_sessions set last_active_at=now(),is_primary_broadcaster=true where device_id in ('phoneB','otherA');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"66000000-0000-4000-8000-000000000012"}',true);
select pg_temp.reserve_personal('i','phoneB','66000000-0000-4000-8000-000000000021');
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000004","role":"authenticated","session_id":"66000000-0000-4000-8000-000000000014"}',true);
select pg_temp.reserve_personal('j','otherA','66000000-0000-4000-8000-000000000022');
reset role;
select lives_ok($$select pg_temp.confirm_live((select v from ids where k='i'),'IIIIIIIIIII')$$,'caster live for multi-sweep');
select lives_ok($$select pg_temp.confirm_live((select v from ids where k='j'),'JJJJJJJJJJJ')$$,'second caster live for multi-sweep');
update public.broadcast_sessions set ingest_state='interrupted',interrupted_since=now()-interval '3 minutes'
 where id in ((select v from ids where k='i'),(select v from ids where k='j'));
select is(public.sweep_stale_live_flags(),2,'one sweep clears both');
select is((select count(*)::int from public.broadcast_sessions where stream_id in ('IIIIIIIIIII','JJJJJJJJJJJ') and end_reason='ingest_lost'),2,'every swept broadcaster records ingest_lost');
select is((select count(*)::int from public.broadcast_sessions where state='live'),0,'no session left live');
select is((select count(*)::int from public.broadcast_sessions b where (state in ('ending','processing_replay','completed') and end_reason is null)
  or (state='completed' and ended_at is null)),0,'every ended session has a time and reason');

-- Organization view: one row per organization, joined on its own session.
select pg_temp.provider_finished('66000000-0000-4000-8000-000000000002');
insert into public.organizations(id,name_en,name_ar,owner_profile_id,is_verified) values
 ('66000000-0000-4000-8000-000000000030','Org','Org','66000000-0000-4000-8000-000000000002',true);
insert into private.organization_v1_pilots(organization_id) values('66000000-0000-4000-8000-000000000030');
insert into public.channel_connections(id,owner_profile_id,organization_id,youtube_channel_id,channel_title) values
 ('66000000-0000-4000-8000-000000000023','66000000-0000-4000-8000-000000000002','66000000-0000-4000-8000-000000000030','UCmmmmmmmmmmmmmmmmmmmmmm','Org');
update public.org_memberships set permissions=permissions||'{"can_go_live_video":true}'
 where organization_id='66000000-0000-4000-8000-000000000030' and profile_id='66000000-0000-4000-8000-000000000002';
update public.device_sessions set last_active_at=now() where device_id='phoneB';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"66000000-0000-4000-8000-000000000012"}',true);
insert into ids select 'org_schedule',public.broadcast_save_schedule('66000000-0000-4000-8000-000000000030',null,
 '66000000-0000-4000-8000-000000000002','once',((now()+interval '70 minutes') at time zone 'Asia/Riyadh')::time,'{}',
 now()+interval '70 minutes','Org show','','liveVideo');
insert into ids select 'k',id from public.broadcast_sessions where schedule_id=(select v from ids where k='org_schedule');
select public.broadcast_accept_assignment((select v from ids where k='k'),true,(select revision from public.broadcast_sessions where id=(select v from ids where k='k')));
reset role;
-- Earlier test sessions still occupy the next hour; move the show into its preflight window.
update public.broadcast_sessions set scheduled_start_at=now(),expected_end_at=now()+interval '1 hour' where id=(select v from ids where k='k');
set local role authenticated;
select public.broadcast_reserve_confirmed((select v from ids where k='k'),'phoneB','phone_direct','prepare','66000000-0000-4000-8000-000000000023',1);
reset role;
select lives_ok($$select pg_temp.confirm_live((select v from ids where k='k'),'KKKKKKKKKKK')$$,'owner goes live as the organization');
select is((select count(*)::int from public.organization_public_profiles where id='66000000-0000-4000-8000-000000000030'),1,'organization listed once');
select is((select live_session_id from public.organization_public_profiles where id='66000000-0000-4000-8000-000000000030'),
  (select id from public.broadcast_sessions where stream_id='KKKKKKKKKKK' and state='live'),'organization row carries its own session');
select is((select org_id from public.broadcast_sessions where stream_id='KKKKKKKKKKK'),'66000000-0000-4000-8000-000000000030'::uuid,'session records the organization');
select * from finish();
rollback;
