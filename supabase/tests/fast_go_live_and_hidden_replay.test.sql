-- Faster go-live and "hide the video when the live ends"
-- (20261019155816_fast_go_live_and_hidden_replay.sql). Fixtures roll back.
begin;
set local search_path=public,extensions;
select no_plan();
insert into public.app_flags(key,enabled) values('chat_enabled',true),('registrations_open',true)
  on conflict(key) do update set enabled=true;
insert into auth.users(id,email) values
  ('c2000000-0000-4000-8000-000000000001','hide@example.invalid'),
  ('c2000000-0000-4000-8000-000000000002','other@example.invalid');
insert into public.profiles(id,email,display_name_en,is_streamer,is_verified,personal_broadcast_approved) values
  ('c2000000-0000-4000-8000-000000000001','hide@example.invalid','Hide',true,true,true),
  ('c2000000-0000-4000-8000-000000000002','other@example.invalid','Other',true,true,true);
insert into auth.sessions(id,user_id) values
  ('c2000000-0000-4000-8000-000000000011','c2000000-0000-4000-8000-000000000001'),
  ('c2000000-0000-4000-8000-000000000012','c2000000-0000-4000-8000-000000000002');
insert into public.channel_connections(id,owner_profile_id,youtube_channel_id,channel_title)
 values('c2000000-0000-4000-8000-000000000021','c2000000-0000-4000-8000-000000000001','UChhhhhhhhhhhhhhhhhhhhhh','Hide');
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
  select set_config('request.jwt.claims','{"sub":"c2000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"c2000000-0000-4000-8000-000000000011"}',true);
$$;
create function pg_temp.as_other() returns void language sql as $$
  select set_config('request.jwt.claims','{"sub":"c2000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"c2000000-0000-4000-8000-000000000012"}',true);
$$;
-- A personal session prepared on this phone (state 'preparing').
create function pg_temp.prepare(p_key text) returns void language plpgsql as $$
begin
  set local role authenticated;
  perform pg_temp.as_owner();
  insert into ids select p_key, public.broadcast_create_personal('Hide '||p_key,'liveVideo');
  perform public.broadcast_reserve_confirmed((select v from ids where k=p_key),'DEV-H','phone_direct','prepare',
    'c2000000-0000-4000-8000-000000000021',1);
  reset role;
end $$;
create function pg_temp.go_live(p_key text, p_watch text) returns void language plpgsql as $$
declare v_id uuid:=(select v from ids where k=p_key); v_token uuid;
begin
  select operation_token into v_token from private.broadcast_provider where session_id=v_id;
  perform public.broadcast_provider_step(v_id,v_token,'stream_create',
    jsonb_build_object('id','feed-'||v_id,'url','rtmps://a.rtmps.youtube.com/live2','key','fake-ingest'));
  perform public.broadcast_provider_step(v_id,v_token,'broadcast_create',jsonb_build_object('id',p_watch));
  perform public.broadcast_provider_step(v_id,v_token,'bind','{}');
  perform public.broadcast_provider_step(v_id,v_token,'observe','{"status":"live"}');
  perform public.broadcast_provider_step(v_id,v_token,'finish');
end $$;
-- YouTube confirms the end the way broadcast-control records it.
create function pg_temp.complete(p_key text) returns void language plpgsql as $$
declare v_id uuid:=(select v from ids where k=p_key); v_token uuid:=gen_random_uuid();
begin
  update private.broadcast_provider set operation='end',operation_token=v_token,claimed_until=now()+interval '2 minutes' where session_id=v_id;
  update public.broadcast_sessions set state='ending',termination_pending=true,end_reason='owner_end' where id=v_id and state='live';
  perform public.broadcast_provider_step(v_id,v_token,'transition_complete','{"status":"complete"}');
  perform public.broadcast_provider_step(v_id,v_token,'finish');
end $$;
create function pg_temp.hidden(p_watch text) returns boolean language sql as $$
  select exists(select 1 from public.hidden_channel_content where streamer_id='c2000000-0000-4000-8000-000000000001'
    and kind='video' and item_id=p_watch);
$$;

set local role authenticated;
select pg_temp.as_owner();
select ok(public.claim_broadcaster_device('DEV-H','Phone H','android'),'presenter claims its phone');
reset role;

-- Grants.
select ok(not has_function_privilege('anon','public.broadcast_set_hide_replay(uuid,boolean)','execute'),'guests cannot set the hide choice');
select ok(has_function_privilege('authenticated','public.broadcast_set_hide_replay(uuid,boolean)','execute'),'signed-in presenters can');
select ok(not has_function_privilege('anon','public.broadcast_update_personal(uuid,text,text)','execute'),'guests cannot retitle');
select ok(has_function_privilege('authenticated','public.broadcast_update_personal(uuid,text,text)','execute'),'signed-in presenters can retitle');

-- 1. Title and video/audio after a background preparation.
select lives_ok($$select pg_temp.prepare('h1')$$,'personal session prepared');
select is((select state from public.broadcast_sessions where id=(select v from ids where k='h1')),'preparing','preparing');
set local role authenticated;
select pg_temp.as_owner();
select is(public.broadcast_update_personal((select v from ids where k='h1'),'My lesson','liveAudio')->>'title_en','My lesson',
  'presenter retitles the preparation');
reset role;
select is((select broadcast_type from public.broadcast_sessions where id=(select v from ids where k='h1')),'liveAudio','audio choice saved');
set local role authenticated;
select throws_ok($$select public.broadcast_update_personal((select v from ids where k='h1'),'  ','liveVideo')$$,'42501',null,'an empty title is refused');
select pg_temp.as_other();
select throws_ok($$select public.broadcast_update_personal((select v from ids where k='h1'),'Taken','liveVideo')$$,'42501',null,
  'another account cannot retitle it');
select throws_ok($$select public.broadcast_set_hide_replay((select v from ids where k='h1'),true)$$,'42501',null,
  'another account cannot set its hide choice');

-- 2. Hide choice before the live; the video is hidden when the live ends.
select pg_temp.as_owner();
select lives_ok($$select public.broadcast_set_hide_replay((select v from ids where k='h1'),true)$$,'presenter chooses to hide the video');
reset role;
select ok((select hide_replay from public.broadcast_sessions where id=(select v from ids where k='h1')),'choice stored');
select lives_ok($$select pg_temp.go_live('h1','HHHHHHHHHH1')$$,'goes live');
select is((select state from public.broadcast_sessions where id=(select v from ids where k='h1')),'live','live');
select ok(not pg_temp.hidden('HHHHHHHHHH1'),'still visible while live');
select lives_ok($$select pg_temp.complete('h1')$$,'live ends');
select ok(pg_temp.hidden('HHHHHHHHHH1'),'the recording is hidden in the app when the live ends');
select is((select hidden_by from public.hidden_channel_content where item_id='HHHHHHHHHH1'),
  'c2000000-0000-4000-8000-000000000001'::uuid,'hidden on behalf of the presenter');
-- The owner shows it again from the channel page; a later state change keeps that.
delete from public.hidden_channel_content where item_id='HHHHHHHHHH1';
update public.broadcast_sessions set state='completed',replay_status='available' where id=(select v from ids where k='h1');
select ok(not pg_temp.hidden('HHHHHHHHHH1'),'unhiding later sticks');
set local role authenticated;
select pg_temp.as_owner();
select throws_ok($$select public.broadcast_set_hide_replay((select v from ids where k='h1'),false)$$,'55000',null,
  'after the live the channel page owns hide and show');
reset role;

-- 3. Switched on from the live screen's options menu while live; switched off leaves it visible.
select lives_ok($$select pg_temp.prepare('h2')$$,'second session prepared');
select lives_ok($$select pg_temp.go_live('h2','HHHHHHHHHH2')$$,'second live');
set local role authenticated;
select pg_temp.as_owner();
select lives_ok($$select public.broadcast_set_hide_replay((select v from ids where k='h2'),true)$$,'switched on while live');
select lives_ok($$select public.broadcast_set_hide_replay((select v from ids where k='h2'),false)$$,'and off again');
reset role;
select lives_ok($$select pg_temp.complete('h2')$$,'second live ends');
select ok(not pg_temp.hidden('HHHHHHHHHH2'),'switched off: the recording stays visible');

select lives_ok($$select pg_temp.prepare('h3')$$,'third session prepared');
select lives_ok($$select pg_temp.go_live('h3','HHHHHHHHHH3')$$,'third live');
set local role authenticated;
select pg_temp.as_owner();
select lives_ok($$select public.broadcast_set_hide_replay((select v from ids where k='h3'),true)$$,'switched on while live');
select throws_ok($$select public.broadcast_update_personal((select v from ids where k='h3'),'Too late','liveVideo')$$,'42501',null,
  'a live session cannot be retitled here');
reset role;
select lives_ok($$select pg_temp.complete('h3')$$,'third live ends');
select ok(pg_temp.hidden('HHHHHHHHHH3'),'switched on while live: hidden when it ends');

-- 4. Live signal: changing into or out of live never fails because of Realtime.
select ok(to_regprocedure('realtime.send(jsonb,text,text,boolean)') is null
  or exists(select 1 from realtime.messages where event='catalog_changed' and topic='public_streamers_discovery' and not private),
  'going live and ending send the public catalog signal (when Realtime is installed)');
-- realtime.send adds only its own message id to the payload.
select ok(not exists(select 1 from realtime.messages m where m.event='catalog_changed'
  and ((m.payload-'id')<>'{}'::jsonb or exists(select 1 from public.broadcast_sessions s where s.id::text=m.payload->>'id'))),
  'the signal carries no session ids or titles');

-- 5. A preparation whose window has passed can never start: the reconcile claim ends it.
select lives_ok($$select pg_temp.prepare('h4')$$,'abandoned preparation');
update public.broadcast_sessions set scheduled_start_at=now()-interval '2 hours',expected_end_at=now()-interval '1 hour'
 where id=(select v from ids where k='h4');
update private.broadcast_provider set claimed_until=null,checked_at=null where session_id=(select v from ids where k='h4');
create temporary table claims(v jsonb);
insert into claims select public.broadcast_reconcile_claim();
select is((select state from public.broadcast_sessions where id=(select v from ids where k='h4')),'ending','expired preparation ends');
select is((select end_reason from public.broadcast_sessions where id=(select v from ids where k='h4')),'stale_expired','recorded as expired');
select is((select operation from private.broadcast_provider where session_id=(select v from ids where k='h4')),'end',
  'claimed to remove it from YouTube');
select lives_ok($$select pg_temp.complete('h4')$$,'YouTube deletes the never-live broadcast');
select lives_ok($$select pg_temp.prepare('h5')$$,'a fresh preparation');
select lives_ok($$insert into claims select public.broadcast_reconcile_claim()$$,'claim again');
select is((select state from public.broadcast_sessions where id=(select v from ids where k='h5')),'preparing',
  'a preparation inside its window is left alone');

select * from finish();
rollback;
