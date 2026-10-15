-- Connection-loss grace window (20261015191428_broadcast_connection_grace.sql).
-- A lost YouTube feed marks the broadcast interrupted ("we'll be right back");
-- a feed that returns within 2 minutes keeps it live; otherwise the scheduled
-- reconcile claim ends it. Fixtures roll back.
begin;
set local search_path=public,extensions;
select no_plan();
insert into public.app_flags(key,enabled) values('chat_enabled',true),('registrations_open',true)
  on conflict(key) do update set enabled=true;
insert into auth.users(id,email) values('b1000000-0000-4000-8000-000000000001','grace@example.invalid');
insert into public.profiles(id,email,display_name_en,is_streamer,is_verified,personal_broadcast_approved)
 values('b1000000-0000-4000-8000-000000000001','grace@example.invalid','Grace',true,true,true);
insert into auth.sessions(id,user_id) values('b1000000-0000-4000-8000-000000000011','b1000000-0000-4000-8000-000000000001');
insert into public.channel_connections(id,owner_profile_id,youtube_channel_id,channel_title)
 values('b1000000-0000-4000-8000-000000000021','b1000000-0000-4000-8000-000000000001','UCgggggggggggggggggggggg','Grace');
create temporary table ids(k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.confirm_live(p_id uuid, p_watch text) returns void language plpgsql as $$
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
-- Stand-in for one scheduled reconcile claim of this session.
create function pg_temp.claim(p_id uuid) returns uuid language plpgsql as $$
declare v_token uuid:=gen_random_uuid();
begin
  update private.broadcast_provider set operation='observe',operation_token=v_token,
    claimed_until=now()+interval '2 minutes' where session_id=p_id;
  return v_token;
end $$;
create function pg_temp.start(p_key text, p_sender text, p_watch text) returns void language plpgsql as $$
begin
  set local role authenticated;
  perform set_config('request.jwt.claims','{"sub":"b1000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"b1000000-0000-4000-8000-000000000011"}',true);
  insert into ids select p_key, public.broadcast_create_personal('Grace '||p_key,'liveVideo');
  perform public.broadcast_reserve_confirmed((select v from ids where k=p_key),'DEV-G',p_sender,'prepare',
    'b1000000-0000-4000-8000-000000000021',1);
  reset role;
  perform pg_temp.confirm_live((select v from ids where k=p_key),p_watch);
end $$;
create function pg_temp.complete(p_key text) returns void language sql as $$
  update public.broadcast_sessions set state='completed',termination_pending=false,ended_at=now()
   where id=(select v from ids where k=p_key);
$$;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b1000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"b1000000-0000-4000-8000-000000000011"}',true);
select ok(public.claim_broadcaster_device('DEV-G','Phone G','android'),'presenter claims its phone');
reset role;
select lives_ok($$select pg_temp.start('s1','phone_direct','GGGGGGGGGG1')$$,'phone broadcast goes live');
select is((select state from public.broadcast_sessions where id=(select v from ids where k='s1')),'live','session is live');

-- Guards: scheduled reconciliation only.
select ok(not has_function_privilege('anon','public.broadcast_observe_feed(uuid,uuid,boolean)','execute'),'guests cannot report feed state');
select ok(not has_function_privilege('authenticated','public.broadcast_observe_feed(uuid,uuid,boolean)','execute'),'signed-in users cannot report feed state');
select ok(has_function_privilege('service_role','public.broadcast_observe_feed(uuid,uuid,boolean)','execute'),'the reconcile worker can report feed state');
select throws_ok($$select public.broadcast_observe_feed((select v from ids where k='s1'),gen_random_uuid(),false)$$,
  '42501',null,'an unreserved token is refused');

-- 1. Feed lost (dead phone): viewers see the interruption, nothing ends yet.
create temporary table tok(v uuid);
insert into tok select pg_temp.claim((select v from ids where k='s1'));
select lives_ok($$select public.broadcast_observe_feed((select v from ids where k='s1'),(select v from tok),false)$$,'lost feed recorded');
select is((select ingest_state from public.broadcast_sessions where id=(select v from ids where k='s1')),'interrupted','session shows interrupted');
select ok((select interrupted_since is not null from public.broadcast_sessions where id=(select v from ids where k='s1')),'outage start recorded');
update public.broadcast_sessions set interrupted_since=now()-interval '60 seconds' where id=(select v from ids where k='s1');
update private.broadcast_provider set feed_lost_since=now()-interval '60 seconds' where session_id=(select v from ids where k='s1');
select lives_ok($$select public.broadcast_observe_feed((select v from ids where k='s1'),(select v from tok),false)$$,'still lost');
select ok((select interrupted_since<now()-interval '50 seconds' from public.broadcast_sessions where id=(select v from ids where k='s1')),
  'a repeated loss does not restart the grace window');
select is(public.sweep_stale_live_flags(),0,'inside the 2-minute window the broadcast stays live');

-- 2. Feed returns within the window: the broadcast continues.
select lives_ok($$select public.broadcast_observe_feed((select v from ids where k='s1'),(select v from tok),true)$$,'feed back');
select is((select ingest_state from public.broadcast_sessions where id=(select v from ids where k='s1')),'sending','interruption cleared');
select ok((select interrupted_since is null from public.broadcast_sessions where id=(select v from ids where k='s1')),'outage start cleared');
select is((select state from public.broadcast_sessions where id=(select v from ids where k='s1')),'live','still live');

-- 3. The phone's newer report wins over a lagging YouTube status.
select lives_ok($$select public.broadcast_observe_feed((select v from ids where k='s1'),(select v from tok),false)$$,'lost again');
update private.broadcast_provider set feed_lost_since=now()-interval '20 seconds' where session_id=(select v from ids where k='s1');
set local role authenticated;
select lives_ok($$select public.report_broadcast_ingest((select v from ids where k='s1'),'DEV-G','sending')$$,'phone reports it is sending again');
reset role;
select lives_ok($$select public.broadcast_observe_feed((select v from ids where k='s1'),(select v from tok),false)$$,'YouTube still lagging');
select is((select ingest_state from public.broadcast_sessions where id=(select v from ids where k='s1')),'sending','lagging YouTube does not override the phone');
set local role authenticated;
select lives_ok($$select public.report_broadcast_ingest((select v from ids where k='s1'),'DEV-G','interrupted')$$,'phone reports a new drop');
reset role;
select lives_ok($$select public.broadcast_observe_feed((select v from ids where k='s1'),(select v from tok),true)$$,'YouTube sees data');
select is((select ingest_state from public.broadcast_sessions where id=(select v from ids where k='s1')),'interrupted','a newer phone report is kept');
select ok((select feed_lost_since is null from private.broadcast_provider where session_id=(select v from ids where k='s1')),'provider loss cleared');

-- 4. Not back within 2 minutes: the scheduled claim ends it and completes it on YouTube.
update public.broadcast_sessions set interrupted_since=now()-interval '121 seconds' where id=(select v from ids where k='s1');
update private.broadcast_provider set claimed_until=null,checked_at=null where session_id=(select v from ids where k='s1');
create temporary table claims(v jsonb);
insert into claims select public.broadcast_reconcile_claim();
select is((select state from public.broadcast_sessions where id=(select v from ids where k='s1')),'ending','grace expired: broadcast ends');
select is((select end_reason from public.broadcast_sessions where id=(select v from ids where k='s1')),'ingest_lost','recorded as connection lost');
select ok(exists(select 1 from claims where v->>'id'=(select v from ids where k='s1')::text),'claimed in the same pass');
select is((select operation from private.broadcast_provider where session_id=(select v from ids where k='s1')),'end','claimed to complete the YouTube broadcast');
select ok((select not is_currently_live from public.profiles where id='b1000000-0000-4000-8000-000000000001'),'profile no longer listed live');
select pg_temp.complete('s1');

-- 5. Backstop: YouTube has had no feed for 10 minutes although the phone says sending.
select lives_ok($$select pg_temp.start('s2','phone_direct','GGGGGGGGGG2')$$,'second phone broadcast live');
update private.broadcast_provider set feed_lost_since=now()-interval '11 minutes' where session_id=(select v from ids where k='s2');
update public.broadcast_sessions set ingest_state='sending',interrupted_since=null where id=(select v from ids where k='s2');
select is(public.sweep_stale_live_flags(),1,'a feed missing at YouTube for 10 minutes ends the broadcast');
select pg_temp.complete('s2');

-- 6. OBS / laptop senders are covered too (they never report themselves).
select lives_ok($$select pg_temp.start('s3','obs_laptop','GGGGGGGGGG3')$$,'OBS broadcast live');
insert into tok select pg_temp.claim((select v from ids where k='s3'));
select lives_ok($$select public.broadcast_observe_feed((select v from ids where k='s3'),(select v from tok offset 1),false)$$,'OBS feed lost');
select is((select ingest_state from public.broadcast_sessions where id=(select v from ids where k='s3')),'interrupted','OBS viewers see the interruption');
update public.broadcast_sessions set interrupted_since=now()-interval '121 seconds' where id=(select v from ids where k='s3');
select is(public.sweep_stale_live_flags(),1,'an OBS feed gone for 2 minutes ends the broadcast');

select * from finish();
rollback;
