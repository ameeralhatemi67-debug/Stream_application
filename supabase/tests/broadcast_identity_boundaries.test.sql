-- Broadcast identity is the session, never a coincident watch ID.
--
-- Starts follow the provider-confirmed path (20261001102758 revoked the client
-- start RPCs; 20261001111022 made LIVE provider-confirmed). The provider
-- worker records the watch ID YouTube returns, so these assertions drive that
-- worker with a deliberately reused watch ID.
begin;
select no_plan();
insert into auth.users(id,email) values
 ('68000000-0000-4000-8000-000000000001','identity-admin@example.invalid'),
 ('68000000-0000-4000-8000-000000000002','identity-owner@example.invalid'),
 ('68000000-0000-4000-8000-000000000003','identity-other@example.invalid');
insert into public.profiles(id,email,is_streamer,is_verified,personal_broadcast_approved,organization_broadcast_approved) values
 ('68000000-0000-4000-8000-000000000001','identity-admin@example.invalid',false,false,false,false),
 ('68000000-0000-4000-8000-000000000002','identity-owner@example.invalid',true,true,false,true),
 ('68000000-0000-4000-8000-000000000003','identity-other@example.invalid',true,true,true,false);
insert into public.user_roles(profile_id,role) values ('68000000-0000-4000-8000-000000000001','admin');
insert into auth.sessions(id,user_id) values
 ('68000000-0000-4000-8000-000000000011','68000000-0000-4000-8000-000000000001'),
 ('68000000-0000-4000-8000-000000000012','68000000-0000-4000-8000-000000000002'),
 ('68000000-0000-4000-8000-000000000013','68000000-0000-4000-8000-000000000003');
insert into public.device_sessions(user_id,device_id,is_primary_broadcaster,last_active_at) values
 ('68000000-0000-4000-8000-000000000002','identity-device',true,now()),
 ('68000000-0000-4000-8000-000000000003','other-device',true,now());
insert into public.organizations(id,name_en,name_ar,owner_profile_id,is_verified) values
 ('68000000-0000-4000-8000-000000000030','First','First','68000000-0000-4000-8000-000000000002',true),
 ('68000000-0000-4000-8000-000000000031','Second','Second','68000000-0000-4000-8000-000000000002',true);
insert into private.organization_v1_pilots(organization_id) values
 ('68000000-0000-4000-8000-000000000030'),('68000000-0000-4000-8000-000000000031');
update public.org_memberships set permissions=permissions||'{"can_go_live_video":true}'
 where profile_id='68000000-0000-4000-8000-000000000002';
insert into public.channel_connections(id,owner_profile_id,organization_id,youtube_channel_id,channel_title) values
 ('68000000-0000-4000-8000-000000000020','68000000-0000-4000-8000-000000000002','68000000-0000-4000-8000-000000000030','UChhhhhhhhhhhhhhhhhhhhhh','First'),
 ('68000000-0000-4000-8000-000000000021','68000000-0000-4000-8000-000000000002','68000000-0000-4000-8000-000000000031','UCiiiiiiiiiiiiiiiiiiiiii','Second'),
 ('68000000-0000-4000-8000-000000000022','68000000-0000-4000-8000-000000000003',null,'UCjjjjjjjjjjjjjjjjjjjjjj','Other');
create temporary table identity_ids(k text primary key,v uuid);
grant all on identity_ids to authenticated;
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

-- The owner presents one short show for each organization it owns.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"68000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"68000000-0000-4000-8000-000000000012"}',true);
insert into identity_ids select 'first_schedule',public.broadcast_save_schedule('68000000-0000-4000-8000-000000000030',null,
 '68000000-0000-4000-8000-000000000002','once',((now()+interval '2 minutes') at time zone 'Asia/Riyadh')::time,'{}',
 now()+interval '2 minutes','First show','','liveVideo',15);
insert into identity_ids select 'second_schedule',public.broadcast_save_schedule('68000000-0000-4000-8000-000000000031',null,
 '68000000-0000-4000-8000-000000000002','once',((now()+interval '20 minutes') at time zone 'Asia/Riyadh')::time,'{}',
 now()+interval '20 minutes','Second show','','liveVideo',15);
insert into identity_ids select 'first',id from public.broadcast_sessions where schedule_id=(select v from identity_ids where k='first_schedule');
insert into identity_ids select 'second',id from public.broadcast_sessions where schedule_id=(select v from identity_ids where k='second_schedule');
select public.broadcast_accept_assignment(v,true,(select revision from public.broadcast_sessions where id=v)) from identity_ids where k in ('first','second');
select public.broadcast_reserve_confirmed((select v from identity_ids where k='first'),'identity-device','phone_direct','prepare','68000000-0000-4000-8000-000000000020',1);
reset role;
select pg_temp.confirm_live((select v from identity_ids where k='first'),'IDENTITY001');
set local role authenticated;
select lives_ok($$select public.end_broadcast_session((select v from identity_ids where k='first'),'identity-device')$$,'owner ends the first organization broadcast');
reset role;
update public.broadcast_sessions set state='completed',termination_pending=false,ended_at=now() where id=(select v from identity_ids where k='first');
set local role authenticated;
select public.broadcast_reserve_confirmed((select v from identity_ids where k='second'),'identity-device','phone_direct','prepare','68000000-0000-4000-8000-000000000021',1);
reset role;
select pg_temp.confirm_live((select v from identity_ids where k='second'),'IDENTITY001');
set local role authenticated;
select isnt((select v from identity_ids where k='first'),(select id from public.broadcast_sessions where state='live'),'changing organization creates a new session even for the same watch ID');
select is((select org_id from public.broadcast_sessions where state='live'),'68000000-0000-4000-8000-000000000031'::uuid,'session belongs to selected organization');
-- Another account's provider-confirmed session cannot list the same watch ID concurrently.
select set_config('request.jwt.claims','{"sub":"68000000-0000-4000-8000-000000000003","role":"authenticated","session_id":"68000000-0000-4000-8000-000000000013"}',true);
insert into identity_ids select 'other',public.broadcast_create_personal('Other','liveVideo');
select public.broadcast_reserve_confirmed((select v from identity_ids where k='other'),'other-device','obs_laptop','prepare','68000000-0000-4000-8000-000000000022',1);
reset role;
select throws_ok($$select pg_temp.confirm_live((select v from identity_ids where k='other'),'IDENTITY001')$$,'23505',null,'two accounts cannot concurrently list one watch ID');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"68000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"68000000-0000-4000-8000-000000000012"}',true);
select lives_ok($$select public.end_broadcast_session((select v from identity_ids where k='second'),'identity-device')$$,'owner ends organization broadcast');
reset role;
update public.broadcast_sessions set state='completed',termination_pending=false,ended_at=now() where id=(select v from identity_ids where k='second');
select lives_ok($$select pg_temp.confirm_live((select v from identity_ids where k='other'),'IDENTITY001')$$,'another account may reuse an ended watch ID');
-- A stale legacy organization flag must not turn its watch ID into authority
-- over a different account. Such rows can exist at the migration boundary.
update public.organizations set is_currently_live=true,broadcast_type='liveVideo',active_stream_id='IDENTITY001' where id='68000000-0000-4000-8000-000000000030';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"68000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"68000000-0000-4000-8000-000000000011"}',true);
select lives_ok($$select public.admin_moderate_broadcaster('68000000-0000-4000-8000-000000000030',true,'revoke_organization','scope regression')$$,'revoke stale organization');
reset role;
select ok((select is_currently_live from public.profiles where id='68000000-0000-4000-8000-000000000003'),'organization revocation cannot end an unrelated account reusing its watch ID');
select * from finish();
rollback;
