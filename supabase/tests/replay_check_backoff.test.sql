-- Replay checks back off and end (20261020075541_replay_check_backoff.sql).
-- Time passing is simulated by moving a session's timestamps into the past.
-- Fixtures roll back.
begin;
set local search_path=public,extensions;
select no_plan();
insert into public.app_flags(key,enabled) values('chat_enabled',true),('registrations_open',true)
  on conflict(key) do update set enabled=true;
insert into auth.users(id,email) values('c3000000-0000-4000-8000-000000000001','replay@example.invalid');
insert into public.profiles(id,email,display_name_en,is_streamer,is_verified,personal_broadcast_approved) values
  ('c3000000-0000-4000-8000-000000000001','replay@example.invalid','Replay',true,true,true);
insert into auth.sessions(id,user_id) values('c3000000-0000-4000-8000-000000000011','c3000000-0000-4000-8000-000000000001');
insert into public.channel_connections(id,owner_profile_id,youtube_channel_id,channel_title)
 values('c3000000-0000-4000-8000-000000000021','c3000000-0000-4000-8000-000000000001','UCrrrrrrrrrrrrrrrrrrrrrr','Replay');
-- Realtime keeps one partition per day; a local copy may lack today's.
do $$ begin
  if to_regclass('realtime.messages') is not null and not exists(select 1 from pg_inherits i join pg_class c on c.oid=i.inhrelid
    where i.inhparent='realtime.messages'::regclass and c.relname='messages_'||to_char(now(),'YYYY_MM_DD')) then
    execute format('create table realtime.%I partition of realtime.messages for values from (%L) to (%L)',
      'messages_'||to_char(now(),'YYYY_MM_DD'),date_trunc('day',now()::timestamp),date_trunc('day',now()::timestamp)+interval '1 day');
  end if;
end $$;
create temporary table ids(k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims','{"sub":"c3000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"c3000000-0000-4000-8000-000000000011"}',true);
$$;
create function pg_temp.id(p_key text) returns uuid language sql as $$ select v from ids where k=p_key $$;
-- A personal phone session that goes live on YouTube.
create function pg_temp.go_live(p_key text, p_watch text) returns void language plpgsql as $$
declare v_id uuid; v_token uuid;
begin
  set local role authenticated;
  perform pg_temp.as_owner();
  insert into ids select p_key, public.broadcast_create_personal('Replay '||p_key,'liveVideo');
  v_id:=pg_temp.id(p_key);
  perform public.broadcast_reserve_confirmed(v_id,'DEV-R','phone_direct','prepare','c3000000-0000-4000-8000-000000000021',1);
  reset role;
  select operation_token into v_token from private.broadcast_provider where session_id=v_id;
  perform public.broadcast_provider_step(v_id,v_token,'stream_create',
    jsonb_build_object('id','feed-'||v_id,'url','rtmps://a.rtmps.youtube.com/live2','key','fake-ingest'));
  perform public.broadcast_provider_step(v_id,v_token,'broadcast_create',jsonb_build_object('id',p_watch));
  perform public.broadcast_provider_step(v_id,v_token,'bind','{}');
  perform public.broadcast_provider_step(v_id,v_token,'observe','{"status":"live"}');
  perform public.broadcast_provider_step(v_id,v_token,'finish');
end $$;
-- The presenter ends it: YouTube completes the broadcast, the feed is retired
-- and the first replay check finds it still 'uploaded'.
create function pg_temp.complete(p_key text) returns void language plpgsql as $$
declare v_id uuid:=pg_temp.id(p_key); v_token uuid:=gen_random_uuid();
begin
  update private.broadcast_provider set operation='end',operation_token=v_token,claimed_until=now()+interval '2 minutes' where session_id=v_id;
  update public.broadcast_sessions set state='ending',termination_pending=true,end_reason='owner_end' where id=v_id and state='live';
  perform public.broadcast_provider_step(v_id,v_token,'transition_complete','{"status":"complete"}');
  perform public.broadcast_provider_step(v_id,v_token,'feed_delete','{}');
  perform public.broadcast_provider_step(v_id,v_token,'finish');
end $$;
-- Only this session can be due: every other fixture was just checked.
create function pg_temp.due(p_key text, p_ended interval, p_checked interval) returns boolean language plpgsql as $$
declare v_id uuid:=pg_temp.id(p_key);
begin
  update private.broadcast_provider set claimed_until=null,checked_at=now() where session_id in (select v from ids);
  update public.broadcast_sessions set ended_at=now()-p_ended where id=v_id and p_ended is not null;
  update private.broadcast_provider set checked_at=now()-p_checked where session_id=v_id;
  return exists(select 1 from public.broadcast_reconcile_claim() c where (c->>'id')::uuid=v_id);
end $$;
-- p_minutes reconcile runs, one a minute, for one session (others held).
-- Each claim is answered the way broadcast-control answers a replay YouTube
-- still reports 'uploaded': nothing settles, the check finishes.
create function pg_temp.simulate(p_key text, p_minutes int) returns int language plpgsql as $$
declare v_id uuid:=pg_temp.id(p_key); n int:=0; v_token text;
begin
  update private.broadcast_provider set claimed_until=now()+interval '1 year' where session_id in (select v from ids) and session_id<>v_id;
  for i in 1..p_minutes loop
    update public.broadcast_sessions set scheduled_start_at=scheduled_start_at-interval '1 minute',
      expected_end_at=expected_end_at-interval '1 minute',started_at=started_at-interval '1 minute',
      ended_at=ended_at-interval '1 minute' where id=v_id;
    update private.broadcast_provider set checked_at=checked_at-interval '1 minute',
      claimed_until=claimed_until-interval '1 minute' where session_id=v_id;
    select c->>'token' into v_token from public.broadcast_reconcile_claim() c where (c->>'id')::uuid=v_id;
    if v_token is not null then
      n:=n+1;
      perform public.broadcast_provider_step(v_id,v_token::uuid,'finish');
    end if;
  end loop;
  return n;
end $$;

set local role authenticated;
select pg_temp.as_owner();
select ok(public.claim_broadcaster_device('DEV-R','Phone R','android'),'presenter claims its phone');
reset role;

select lives_ok($$select pg_temp.go_live('r1','RRRRRRRRRR1')$$,'first live');
select lives_ok($$select pg_temp.complete('r1')$$,'first live ends');
select is((select state from public.broadcast_sessions where id=pg_temp.id('r1')),'processing_replay','waiting for the replay');
select lives_ok($$select pg_temp.go_live('r2','RRRRRRRRRR2')$$,'second live');
select lives_ok($$select pg_temp.complete('r2')$$,'second live ends');
select lives_ok($$select pg_temp.go_live('r3','RRRRRRRRRR3')$$,'third live, still on air');

-- 1. Live work keeps its 30-second cadence.
select ok(pg_temp.due('r3',null,interval '31 seconds'),'a live broadcast is still checked after 30 s');
select ok(not pg_temp.due('r3',null,interval '10 seconds'),'but not sooner');
select lives_ok($$select pg_temp.complete('r3')$$,'third live ends');

-- 2. Replay checks back off with the time since the live ended.
select ok(not pg_temp.due('r1',interval '2 minutes',interval '31 seconds'),'just ended: not re-checked after 30 s any more');
select ok(not pg_temp.due('r1',interval '10 minutes',interval '4 minutes'),'first hour: not within 5 minutes');
select ok(pg_temp.due('r1',interval '10 minutes',interval '6 minutes'),'first hour: every 5 minutes');
select ok(not pg_temp.due('r1',interval '3 hours',interval '10 minutes'),'first day: not within 15 minutes');
select ok(pg_temp.due('r1',interval '3 hours',interval '16 minutes'),'first day: every 15 minutes');
select ok(not pg_temp.due('r1',interval '30 hours',interval '45 minutes'),'after a day: not within the hour');
select ok(pg_temp.due('r1',interval '30 hours',interval '61 minutes'),'after a day: hourly');
select ok(pg_temp.due('r1',interval '30 hours',null),'a session never checked is claimed at once');

-- 3. A failed check (YouTube or Google error) waits like any other.
select ok(pg_temp.due('r1',interval '10 minutes',interval '6 minutes'),'claimed');
select lives_ok($$select public.broadcast_provider_step(pg_temp.id('r1'),
  (select operation_token from private.broadcast_provider where session_id=pg_temp.id('r1')),'observe',null,'quotaExceeded',false)$$,
  'the check fails');
select ok(not exists(select 1 from public.broadcast_reconcile_claim() c where (c->>'id')::uuid=pg_temp.id('r1')),
  'a failed check is not retried at the next minute');

-- 4. broadcast-control's give-up (or a processed replay) settles the session.
select ok(pg_temp.due('r2',interval '49 hours',interval '2 hours'),'an old replay is claimed');
select lives_ok($$select public.broadcast_provider_step(pg_temp.id('r2'),
  (select operation_token from private.broadcast_provider where session_id=pg_temp.id('r2')),'observe','{"replay":"missing"}')$$,
  'broadcast-control gives up on it');
select is((select state||'/'||replay_status from public.broadcast_sessions where id=pg_temp.id('r2')),'completed/missing',
  'settled without a replay');
select ok(not pg_temp.due('r2',interval '49 hours',interval '2 hours'),'and never checked again');
select ok(pg_temp.due('r3',interval '13 hours',interval '20 minutes'),'a replay YouTube has processed is claimed');
select lives_ok($$select public.broadcast_provider_step(pg_temp.id('r3'),
  (select operation_token from private.broadcast_provider where session_id=pg_temp.id('r3')),'observe','{"replay":"available"}')$$,
  'broadcast-control finds it processed');
select is((select state||'/'||replay_status from public.broadcast_sessions where id=pg_temp.id('r3')),'completed/available',
  'settled with the replay');

-- 5. A feed left on YouTube after the session completed: retried, then let go.
update private.broadcast_provider set feed_retired=false where session_id=pg_temp.id('r2');
select ok(pg_temp.due('r2',interval '2 days',interval '61 minutes'),'an unretired feed is retried hourly');
select ok(not pg_temp.due('r2',interval '2 days',interval '20 minutes'),'not sooner');
select ok(not pg_temp.due('r2',interval '8 days',interval '61 minutes'),'and no more after 7 days');

-- 6. A replay YouTube never confirms (the hosted case): bounded checks, then settled.
update public.broadcast_sessions set ended_at=now() where id=pg_temp.id('r1');
update private.broadcast_provider set claimed_until=null,checked_at=now(),last_error=null where session_id=pg_temp.id('r1');
create temporary table runs(day int primary key, checks int);
insert into runs select 1,pg_temp.simulate('r1',1440);
select cmp_ok((select checks from runs where day=1),'<=',100,
  'first day: at most 100 YouTube checks for a stuck replay (was 1,440 at one a minute)');
select cmp_ok((select checks from runs where day=1),'>=',80,'and still checked through the day');
select is((select state from public.broadcast_sessions where id=pg_temp.id('r1')),'processing_replay','still waiting after a day');
insert into runs select 2,pg_temp.simulate('r1',1440);
select cmp_ok((select checks from runs where day=2),'<=',25,'second day: hourly');
insert into runs select 3,pg_temp.simulate('r1',1442);
select cmp_ok((select checks from runs where day=3),'<=',25,'third day: hourly');
select is((select state||'/'||replay_status from public.broadcast_sessions where id=pg_temp.id('r1')),'completed/missing',
  'unconfirmed 72 h after the end: settled without YouTube');
insert into runs select 4,pg_temp.simulate('r1',600);
select is((select checks from runs where day=4),0,'no YouTube check after that');

-- 7. The 72-hour settlement leaves a check in progress alone.
update public.broadcast_sessions set state='processing_replay',replay_status='processing',ended_at=now()-interval '80 hours'
 where id=pg_temp.id('r3');
update private.broadcast_provider set claimed_until=now()+interval '1 minute' where session_id=pg_temp.id('r3');
select lives_ok($$select public.broadcast_reconcile_claim()$$,'claim runs');
select is((select state from public.broadcast_sessions where id=pg_temp.id('r3')),'processing_replay',
  'a session broadcast-control is checking right now is not settled under it');

select * from finish();
rollback;
