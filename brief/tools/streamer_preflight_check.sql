-- Owner-authorized, rollback-only account preflight.
-- Uses an existing session/primary device and a synthetic channel/refresh token.
-- Never contacts Google or YouTube; every allocated row/secret is rolled back.
-- Refreshes the chosen device timestamp inside this transaction only, to model
-- the app heartbeat after the owner returns from Google. The original is restored.
begin;
create temporary table streamer_check(name text primary key,value jsonb);
grant all on streamer_check to authenticated, service_role;
select set_config('request.jwt.claims',jsonb_build_object(
  'sub',s.user_id,'role','authenticated','session_id',s.id)::text,true)
from auth.sessions s join public.profiles p on p.id=s.user_id
where p.youtube_handle='amiralhatime4831' and p.personal_broadcast_approved
order by s.created_at desc limit 1;
insert into streamer_check select 'device',to_jsonb(device_id)
from public.device_sessions where user_id=auth.uid() and is_primary_broadcaster
order by last_active_at desc limit 1;
do $check$ begin
  if auth.uid() is null or not exists(select 1 from streamer_check where name='device') then
    raise exception 'An approved signed-in account and primary device are required';
  end if;
end $check$;
update public.device_sessions set last_active_at=now() where user_id=auth.uid()
  and device_id=(select value#>>'{}' from streamer_check where name='device');
set local role authenticated;
insert into streamer_check values('begin',public.channel_oauth_begin(null));
set local role service_role;
insert into streamer_check select 'consumed',public.channel_oauth_consume(value->>'state')
from streamer_check where name='begin';
insert into streamer_check select 'connected',to_jsonb(public.channel_oauth_commit(
  (value->>'id')::uuid,'UC0000000000000000000000','Rollback-only verification',
  'synthetic-refresh-not-a-credential')) from streamer_check where name='consumed';
set local role authenticated;
insert into streamer_check values('session',to_jsonb(public.broadcast_create_personal('Rollback-only preflight','liveVideo')));
insert into streamer_check select 'reservation',public.broadcast_reserve_confirmed(
  (select (value#>>'{}')::uuid from streamer_check where name='session'),
  (select value#>>'{}' from streamer_check where name='device'),'phone_direct','prepare',
  c.id,c.revision) from public.channel_connections c
where c.id=(select (value#>>'{}')::uuid from streamer_check where name='connected');
set local role service_role;
insert into streamer_check select 'context',public.broadcast_operation_context(
  (select (value#>>'{}')::uuid from streamer_check where name='session'),
  (select (value->>'token')::uuid from streamer_check where name='reservation'));
do $check$ begin
  if (select count(*) from streamer_check)<>7 or not exists(
    select 1 from streamer_check where name='context'
      and value->>'refresh_token'='synthetic-refresh-not-a-credential'
      and value->'session'->>'state'='preparing') then
    raise exception 'Account preflight did not complete';
  end if;
end $check$;
select 'PASS: approved account, channel consent storage, phone reservation and provider context; rolled back' as result;
rollback;
