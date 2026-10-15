-- Primary-device and start authority for broadcasts.
--
-- Since 20261001102758 (STREAM-D8) clients can no longer assert LIVE with a
-- watch ID of their choosing (start_broadcast_session / set_live_state are
-- revoked), and since 20261001111022 LIVE is provider-confirmed: a presenter
-- reserves an accepted session from its primary device, and the provider
-- worker records the YouTube feed, broadcast and live status. Each assertion
-- below is the original primary-device contract expressed on that path.
begin;
select plan(22);
insert into auth.users(id,email) values
 ('30000000-0000-4000-8000-000000000001','viewer@broadcast.invalid'),
 ('30000000-0000-4000-8000-000000000002','streamer@broadcast.invalid'),
 ('30000000-0000-4000-8000-000000000003','member@broadcast.invalid');
insert into auth.sessions(id,user_id) values
 ('30000000-0000-4000-8000-000000000011','30000000-0000-4000-8000-000000000001'),
 ('30000000-0000-4000-8000-000000000012','30000000-0000-4000-8000-000000000002'),
 ('30000000-0000-4000-8000-000000000013','30000000-0000-4000-8000-000000000003');
insert into public.profiles(id,is_streamer,is_verified,personal_broadcast_approved,organization_broadcast_approved) values
 ('30000000-0000-4000-8000-000000000001',false,false,false,false),
 ('30000000-0000-4000-8000-000000000002',true,true,true,true),
 ('30000000-0000-4000-8000-000000000003',true,true,false,true);
insert into public.organizations(id,owner_profile_id,name_en,name_ar,is_verified) values
 ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002','Org','Org',true);
insert into private.organization_v1_pilots(organization_id) values('40000000-0000-4000-8000-000000000001');
-- The member may go live for the organization with audio only.
insert into public.org_memberships(organization_id,profile_id,role,status,permissions) values
 ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000003','broadcaster','active',
  '{"can_go_live_video":false,"can_go_audio_only":true}');
insert into public.channel_connections(id,owner_profile_id,organization_id,youtube_channel_id,channel_title) values
 ('30000000-0000-4000-8000-000000000021','30000000-0000-4000-8000-000000000002',null,'UCbbbbbbbbbbbbbbbbbbbbbb','Personal'),
 ('30000000-0000-4000-8000-000000000022','30000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000001','UCcccccccccccccccccccccc','Org');

create temporary table ids(k text primary key,v uuid);
grant all on ids to authenticated;
-- The provider worker (service_role in production) confirms the feed, the
-- YouTube broadcast and its live status for a reserved session.
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

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"30000000-0000-4000-8000-000000000011"}',true);
select throws_ok($$select public.claim_broadcaster_device('viewer','Viewer','web')$$,'42501','Broadcast not permitted','Viewer cannot claim primary');
select throws_ok($$insert into public.device_sessions(user_id,device_id,is_primary_broadcaster) values(auth.uid(),'forged',true)$$,
 '42501',null,'Direct device insert denied');
select throws_ok($$select public.broadcast_create_personal('Forged','liveVideo')$$,'42501','Personal broadcasting denied','Viewer cannot go live');
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"30000000-0000-4000-8000-000000000012"}',true);
select ok(public.claim_broadcaster_device('A','Phone A','android'),'Streamer claims A');
select ok(not public.claim_broadcaster_device('B','Phone B','android'),'Fresh primary requires explicit transfer');
select ok(public.device_heartbeat('A'),'Primary heartbeat succeeds');
insert into ids select 's1',public.broadcast_create_personal('First','liveVideo');
select public.broadcast_reserve_confirmed((select v from ids where k='s1'),'A','phone_direct','prepare',
 '30000000-0000-4000-8000-000000000021',1);
reset role;
-- The watch ID now comes from YouTube via the provider worker, never from the client.
select throws_ok($$select public.broadcast_provider_step((select v from ids where k='s1'),
 (select operation_token from private.broadcast_provider where session_id=(select v from ids where k='s1')),
 'broadcast_create','{"id":"bad"}')$$,'22023','Invalid provider broadcast','Invalid ID denied');
select pg_temp.confirm_live((select v from ids where k='s1'),'abcdefghijk');
select ok((select state='live' and stream_id='abcdefghijk' from public.broadcast_sessions where id=(select v from ids where k='s1'))
 and (select is_currently_live from public.profiles where id='30000000-0000-4000-8000-000000000002'),'P3 primary starts live');
set local role authenticated;
select ok(public.owns_stream((select v from ids where k='s1')::text),'P4 real owner can moderate');
select ok(public.claim_broadcaster_device('B','Phone B','android',true),'Explicit transfer succeeds');
select ok((select state='ending' and end_reason='device_transfer' from public.broadcast_sessions where id=(select v from ids where k='s1'))
 and not (select is_currently_live from public.profiles where id=auth.uid()),'Transfer clears displaced live ownership');
reset role;
-- The provider worker completes termination of the displaced broadcast.
update public.broadcast_sessions set state='completed',termination_pending=false,ended_at=now() where id=(select v from ids where k='s1');
set local role authenticated;
insert into ids select 's2',public.broadcast_create_personal('Second','liveVideo');
select throws_ok($$select public.broadcast_reserve_confirmed((select v from ids where k='s2'),'A','phone_direct','prepare',
 '30000000-0000-4000-8000-000000000021',1)$$,'42501','Assigned primary presenter required','Displaced device cannot restart');
select is((select count(*) from public.device_sessions where user_id=auth.uid() and is_primary_broadcaster),1::bigint,'Exactly one primary');
reset role;
update public.device_sessions set last_active_at=now()-interval '91 seconds' where device_id='B';
set local role authenticated;
select ok(public.claim_broadcaster_device('A','Phone A','android'),'Stale primary claim needs no transfer approval');
select public.broadcast_reserve_confirmed((select v from ids where k='s2'),'A','phone_direct','prepare',
 '30000000-0000-4000-8000-000000000021',1);
reset role;
select pg_temp.confirm_live((select v from ids where k='s2'),'abcdefghij2');
select ok((select state='live' from public.broadcast_sessions where id=(select v from ids where k='s2')),'Reclaimed primary starts live');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-8000-000000000003","role":"authenticated","session_id":"30000000-0000-4000-8000-000000000013"}',true);
select ok(not public.owns_stream((select v from ids where k='s2')::text),'Non-owner cannot moderate');
select ok(public.claim_broadcaster_device('C','Phone C','android'),'Org audio member can claim');
-- Leadership cannot assign the audio-only member a video show; an audio show is accepted.
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"30000000-0000-4000-8000-000000000012"}',true);
select throws_ok($$select public.broadcast_save_schedule('40000000-0000-4000-8000-000000000001',null,
 '30000000-0000-4000-8000-000000000003','once',((now()+interval '5 minutes') at time zone 'Asia/Riyadh')::time,'{}',
 now()+interval '5 minutes','Video','','liveVideo')$$,'42501','Approved organization presenter and grant required',
 'Org audio permission does not authorize video');
insert into ids select 'audio_schedule',public.broadcast_save_schedule('40000000-0000-4000-8000-000000000001',null,
 '30000000-0000-4000-8000-000000000003','once',((now()+interval '5 minutes') at time zone 'Asia/Riyadh')::time,'{}',
 now()+interval '5 minutes','Audio','','liveAudio');
insert into ids select 'audio',id from public.broadcast_sessions where schedule_id=(select v from ids where k='audio_schedule');
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-8000-000000000003","role":"authenticated","session_id":"30000000-0000-4000-8000-000000000013"}',true);
select public.broadcast_accept_assignment(v,true,(select revision from public.broadcast_sessions where id=v)) from ids where k='audio';
-- Session and watch IDs are server-assigned; a member cannot point a session at another principal's watch ID.
select throws_ok($$update public.broadcast_sessions set stream_id='abcdefghij2' where id=(select v from ids where k='audio')$$,
 '42501',null,'Duplicate live stream ID denied across principals');
-- The show is inside its preflight window; the member starts it.
select public.broadcast_reserve_confirmed((select v from ids where k='audio'),'C','phone_direct','prepare',
 '30000000-0000-4000-8000-000000000022',1);
reset role;
select pg_temp.confirm_live((select v from ids where k='audio'),'lmnopqrstuv');
select ok((select state='live' and broadcast_type='liveAudio' from public.broadcast_sessions where id=(select v from ids where k='audio')),
 'Permitted org audio starts');
set local role authenticated;
select lives_ok($$select public.release_broadcaster_device('C')$$,'Release succeeds');
select ok((select state='ending' and end_reason='owner_end' from public.broadcast_sessions where id=(select v from ids where k='audio'))
 and not (select is_currently_live from public.profiles where id=auth.uid()),'Release clears live ownership');
reset role;
select * from finish();
rollback;
