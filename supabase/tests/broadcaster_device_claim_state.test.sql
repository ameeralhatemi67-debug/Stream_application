-- Local-only pgTAP for 20260924100000_broadcaster_device_claim_state.sql.
begin;
select plan(16);
insert into auth.users(id,email) values
 ('31000000-0000-4000-8000-000000000001','viewer@claimstate.invalid'),
 ('31000000-0000-4000-8000-000000000002','streamer@claimstate.invalid'),
 ('31000000-0000-4000-8000-000000000003','banned@claimstate.invalid');
insert into public.profiles(id,is_streamer,is_verified,personal_broadcast_approved) values
 ('31000000-0000-4000-8000-000000000001',false,false,false),
 ('31000000-0000-4000-8000-000000000002',true,true,true),
 ('31000000-0000-4000-8000-000000000003',true,true,true);
-- LIVE is provider-confirmed (20261001111022): the streamer reserves a personal
-- session from its primary device on its connected channel, then the provider
-- worker confirms it. Starting requires a live Auth session (session_id claim).
insert into auth.sessions(id,user_id) values('31000000-0000-4000-8000-000000000012','31000000-0000-4000-8000-000000000002');
insert into public.channel_connections(id,owner_profile_id,youtube_channel_id,channel_title) values
 ('31000000-0000-4000-8000-000000000021','31000000-0000-4000-8000-000000000002','UCdddddddddddddddddddddd','Claim state');
create temporary table ids(k text primary key,v uuid);
grant all on ids to authenticated;
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
insert into public.banned_users(profile_id,email,reason) values
 ('31000000-0000-4000-8000-000000000003','banned@claimstate.invalid','test');

select ok(not has_function_privilege('anon','public.claim_broadcaster_device_state(text,text,text,boolean)','execute'),
 'Anonymous callers cannot claim');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"31000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.claim_broadcaster_device_state('V','Viewer','web')$$,'42501','Broadcast not permitted',
 'Viewer cannot claim');
select set_config('request.jwt.claims','{"sub":"31000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.claim_broadcaster_device_state('X','Banned','web')$$,'42501','Broadcast not permitted',
 'Banned broadcaster cannot claim');

select set_config('request.jwt.claims','{"sub":"31000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"31000000-0000-4000-8000-000000000012"}',true);
select is(public.claim_broadcaster_device_state('A','Phone A','android')->>'claimed','true','First device claims');
select is(public.claim_broadcaster_device_state('A','Phone A','android')->>'claimed','true','Primary device re-claim is idempotent');
insert into ids select 's1',public.broadcast_create_personal('First','liveVideo');
select public.broadcast_reserve_confirmed((select v from ids where k='s1'),'A','phone_direct','prepare',
 '31000000-0000-4000-8000-000000000021',1);
reset role;
select pg_temp.confirm_live((select v from ids where k='s1'),'abcdefghijk');
set local role authenticated;
select ok((select is_currently_live from public.profiles where id=auth.uid()),'Primary A goes live');

select is(public.claim_broadcaster_device_state('B','Phone B','android')->'primary'->>'device_id','A',
 'Second device learns which device is primary');
select is((select is_primary_broadcaster from public.device_sessions where user_id=auth.uid() and device_id='A'),true,
 'Unforced conflict leaves A primary');
select ok((select is_currently_live from public.profiles where id=auth.uid()),'Unforced conflict leaves A live');

reset role;
update public.device_sessions set last_active_at=now()-interval '5 minutes' where device_id='A';
set local role authenticated;
select is(public.claim_broadcaster_device_state('B','Phone B','android')->'primary'->>'stale','true',
 'A silent primary is still reported, flagged stale, instead of being taken over silently');
select is((select count(*) from public.device_sessions where user_id=auth.uid() and device_id='B'),0::bigint,
 'Unforced conflict writes no row for the second device');

select is(public.claim_broadcaster_device_state('B','Phone B','android',true)->>'claimed','true','Forced transfer claims B');
select ok(not (select is_currently_live from public.profiles where id=auth.uid()),'Transfer clears the displaced live state');
select ok(not public.device_heartbeat('A'),'Displaced heartbeat reports not primary');
reset role;
-- The provider worker completes termination of the displaced broadcast.
update public.broadcast_sessions set state='completed',termination_pending=false,ended_at=now() where id=(select v from ids where k='s1');
set local role authenticated;
insert into ids select 's2',public.broadcast_create_personal('Second','liveVideo');
select throws_ok($$select public.broadcast_reserve_confirmed((select v from ids where k='s2'),'A','phone_direct','prepare',
 '31000000-0000-4000-8000-000000000021',1)$$,'42501','Assigned primary presenter required',
 'Displaced device cannot restart');
select is(public.claim_broadcaster_device_state('A','Phone A','android')->'primary'->>'device_id','B',
 'Displaced device does not silently reclaim');
reset role;
select * from finish();
rollback;
