-- P6S wave 3 group 1: broadcast session records, end reasons, admin End
-- without demotion, and reversible hide-from-discovery.
begin;
select no_plan();
insert into auth.users(id,email) values
 ('66000000-0000-4000-8000-000000000001','admin@example.invalid'),
 ('66000000-0000-4000-8000-000000000002','caster@example.invalid'),
 ('66000000-0000-4000-8000-000000000003','viewer@example.invalid'),
 ('66000000-0000-4000-8000-000000000004','other@example.invalid');
insert into public.profiles(id,email,is_streamer,is_verified) values
 ('66000000-0000-4000-8000-000000000001','admin@example.invalid',false,false),
 ('66000000-0000-4000-8000-000000000002','caster@example.invalid',true,true),
 ('66000000-0000-4000-8000-000000000003','viewer@example.invalid',false,false),
 ('66000000-0000-4000-8000-000000000004','other@example.invalid',true,true);
insert into public.user_roles(profile_id,role) values ('66000000-0000-4000-8000-000000000001','admin');
insert into auth.sessions(id,user_id) values
 ('66000000-0000-4000-8000-000000000011','66000000-0000-4000-8000-000000000001');
insert into public.device_sessions(user_id,device_id,is_primary_broadcaster,last_active_at) values
 ('66000000-0000-4000-8000-000000000002','phoneA',true,now()),
 ('66000000-0000-4000-8000-000000000002','phoneB',false,now()),
 ('66000000-0000-4000-8000-000000000004','otherA',true,now());

-- Caster goes live from the primary device.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.set_live_state(true,'liveVideo','AAAAAAAAAAA','phoneA')$$,'caster goes live');
select is((select count(*)::int from public.broadcast_sessions where state='live'),1,'owner sees one live session');
select is((select device_id from public.broadcast_sessions where state='live'),'phoneA','session records the sending device');
select is((select stream_id from public.broadcast_sessions where state='live'),'AAAAAAAAAAA','session records the exact watch ID');
select lives_ok($$select public.set_live_state(true,'liveVideo','AAAAAAAAAAA','phoneA')$$,'re-asserting the same broadcast is idempotent');
select is((select count(*)::int from public.broadcast_sessions),1,'re-assert does not open a second session');
select throws_ok($$insert into public.broadcast_sessions(owner_id,stream_id,broadcast_type) values('66000000-0000-4000-8000-000000000002','BBBBBBBBBBB','liveVideo')$$,'42501',null,'no direct insert');
select throws_ok($$update public.broadcast_sessions set hidden_from_discovery=true$$,'42501',null,'no direct update');
select throws_ok($$delete from public.broadcast_sessions$$,'42501',null,'no direct delete');
select is((public.my_broadcast_status()->>'live')::boolean,true,'status reports own live session');
select is(public.my_broadcast_status()->>'stream_id','AAAAAAAAAAA','status reports own watch ID');
reset role;
select ok((select live_session_id is not null and is_currently_live and not is_hidden_from_discovery
  from public.streamer_public_profiles where id='66000000-0000-4000-8000-000000000002'),'public view exposes live session id');

-- Another account cannot read the caster's sessions or status.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select is((select count(*)::int from public.broadcast_sessions),0,'viewer reads no other session rows');
select is((public.my_broadcast_status()->>'live')::boolean,false,'viewer status is only their own');
select throws_ok($$select public.admin_set_stream_discovery('66000000-0000-4000-8000-000000000002',true,'x')$$,'42501',null,'viewer cannot hide a stream');
reset role;
set local role anon;
select throws_ok($$select * from public.broadcast_sessions$$,'42501',null,'anon cannot read sessions');
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
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((public.my_broadcast_status()->>'hidden_from_discovery')::boolean,true,'owner sees the hide');
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
select ok((select is_streamer and is_verified from public.profiles where id='66000000-0000-4000-8000-000000000002'),'approval retained');
select is((select end_reason from public.broadcast_sessions where stream_id='AAAAAAAAAAA'),'admin_end','ended by admin');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is(public.my_broadcast_status()->'last_ended'->>'reason','admin_end','owner learns the end reason');
select throws_ok($$select public.admin_set_stream_discovery('66000000-0000-4000-8000-000000000001',true,'x')$$,'42501',null,'non-admin still denied');
-- The owner may deliberately start again after an admin End.
select lives_ok($$select public.set_live_state(true,'liveVideo','CCCCCCCCCCC','phoneA')$$,'owner starts a new broadcast');
select ok(not (select hidden_from_discovery from public.broadcast_sessions where state='live'),'a new session starts visible');
reset role;

-- End-and-block: same watch ID cannot be relisted; device kept.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","session_id":"66000000-0000-4000-8000-000000000011","role":"authenticated"}',true);
select lives_ok($$select public.admin_auth_account_action('66000000-0000-4000-8000-000000000002','remove_from_feed','block')$$,'admin ends and blocks');
select throws_ok($$select public.admin_set_stream_discovery('66000000-0000-4000-8000-000000000002',true,'x')$$,'22023',null,'no live session to hide');
reset role;
select is((select end_reason from public.broadcast_sessions where stream_id='CCCCCCCCCCC'),'admin_remove','ended and blocked by admin');
select ok((select is_primary_broadcaster from public.device_sessions where device_id='phoneA'),'device kept after block');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.set_live_state(true,'liveVideo','CCCCCCCCCCC','phoneA')$$,'42501',null,'blocked watch ID cannot be relisted');
select lives_ok($$select public.set_live_state(true,'liveVideo','DDDDDDDDDDD','phoneA')$$,'a different watch ID can start');
-- Owner end, then device transfer during a new broadcast.
select lives_ok($$select public.set_live_state(false,'liveVideo',null,'phoneA')$$,'owner ends');
reset role;
select is((select end_reason from public.broadcast_sessions where stream_id='DDDDDDDDDDD'),'owner_end','owner end recorded');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.set_live_state(true,'liveVideo','EEEEEEEEEEE','phoneA')$$,'live again');
select is((public.claim_broadcaster_device_state('phoneB','Phone B','android',true)->>'claimed')::boolean,true,'phone B takes over');
reset role;
select is((select end_reason from public.broadcast_sessions where stream_id='EEEEEEEEEEE'),'device_transfer','transfer recorded');
select ok(not (select is_currently_live from public.profiles where id='66000000-0000-4000-8000-000000000002'),'transfer clears live');

-- Stale expiry, revocation and ban each record their reason.
update public.device_sessions set last_active_at=now() where device_id='phoneB';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.set_live_state(true,'liveVideo','FFFFFFFFFFF','phoneB')$$,'live on phone B');
reset role;
update public.device_sessions set last_active_at=now()-interval '5 minutes' where device_id='phoneB';
select ok(public.sweep_stale_live_flags() >= 1,'sweep clears silent device');
select is((select end_reason from public.broadcast_sessions where stream_id='FFFFFFFFFFF'),'stale_expired','stale expiry recorded');
update public.device_sessions set last_active_at=now() where device_id='otherA';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select lives_ok($$select public.set_live_state(true,'liveVideo','GGGGGGGGGGG','otherA')$$,'second caster live');
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","session_id":"66000000-0000-4000-8000-000000000011","role":"authenticated"}',true);
select lives_ok($$select public.admin_update_account('66000000-0000-4000-8000-000000000004','revoke_streamer','test')$$,'admin revokes approval');
reset role;
select is((select end_reason from public.broadcast_sessions where stream_id='GGGGGGGGGGG'),'approval_revoked','revocation recorded');
update public.profiles set is_streamer=true,is_verified=true where id='66000000-0000-4000-8000-000000000004';
update public.profiles set is_currently_live=true,broadcast_type='liveVideo',active_stream_id='HHHHHHHHHHH' where id='66000000-0000-4000-8000-000000000004';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","session_id":"66000000-0000-4000-8000-000000000011","role":"authenticated"}',true);
select lives_ok($$select public.admin_update_account('66000000-0000-4000-8000-000000000004','ban','test')$$,'admin bans');
reset role;
select is((select end_reason from public.broadcast_sessions where stream_id='HHHHHHHHHHH'),'ban','ban recorded');
-- Two broadcasters expire in one sweep: both get the same recorded reason.
update public.profiles set is_streamer=true,is_verified=true where id='66000000-0000-4000-8000-000000000004';
delete from public.banned_users where profile_id='66000000-0000-4000-8000-000000000004';
update public.device_sessions set last_active_at=now(),is_primary_broadcaster=true where device_id in ('phoneB','otherA');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.set_live_state(true,'liveVideo','IIIIIIIIIII','phoneB')$$,'caster live for multi-sweep');
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select lives_ok($$select public.set_live_state(true,'liveVideo','JJJJJJJJJJJ','otherA')$$,'second caster live for multi-sweep');
reset role;
update public.device_sessions set last_active_at=now()-interval '5 minutes' where device_id in ('phoneB','otherA');
select is(public.sweep_stale_live_flags(),2,'one sweep clears both');
select is((select count(*)::int from public.broadcast_sessions where stream_id in ('IIIIIIIIIII','JJJJJJJJJJJ') and end_reason='stale_expired'),2,'every swept broadcaster records stale_expired');
select is((select count(*)::int from public.broadcast_sessions where state='live'),0,'no session left live');
select is((select count(*)::int from public.broadcast_sessions b where state='ended' and (ended_at is null or end_reason is null)),0,'every ended session has a time and reason');

-- Organization view: one row per organization, joined on its own session.
insert into public.organizations(id,name_en,name_ar,owner_profile_id,is_verified) values
 ('66000000-0000-4000-8000-000000000030','Org','Org','66000000-0000-4000-8000-000000000002',true);
update public.device_sessions set last_active_at=now() where device_id='phoneB';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.set_live_state(true,'liveVideo','KKKKKKKKKKK','phoneB','66000000-0000-4000-8000-000000000030')$$,'owner goes live as the organization');
reset role;
select is((select count(*)::int from public.organization_public_profiles where id='66000000-0000-4000-8000-000000000030'),1,'organization listed once');
select is((select live_session_id from public.organization_public_profiles where id='66000000-0000-4000-8000-000000000030'),
  (select id from public.broadcast_sessions where stream_id='KKKKKKKKKKK' and state='live'),'organization row carries its own session');
select is((select org_id from public.broadcast_sessions where stream_id='KKKKKKKKKKK'),'66000000-0000-4000-8000-000000000030'::uuid,'session records the organization');
select * from finish();
rollback;
