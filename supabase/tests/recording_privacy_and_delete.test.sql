-- Recordings private on YouTube while hidden, deleted on request, taken down
-- by admins (20261027120000_recording_privacy_and_delete.sql). Fixtures roll back.
begin;
set local search_path=public,extensions;
select no_plan();
insert into public.app_flags(key,enabled) values('chat_enabled',true),('registrations_open',true)
  on conflict(key) do update set enabled=true;
insert into auth.users(id,email) values
  ('c3000000-0000-4000-8000-000000000001','rec-owner@example.invalid'),
  ('c3000000-0000-4000-8000-000000000002','rec-other@example.invalid'),
  ('c3000000-0000-4000-8000-000000000003','rec-admin@example.invalid'),
  ('c3000000-0000-4000-8000-000000000004','rec-org-owner@example.invalid'),
  ('c3000000-0000-4000-8000-000000000005','rec-co-owner@example.invalid');
insert into public.profiles(id,email,display_name_en,is_streamer,is_verified,personal_broadcast_approved) values
  ('c3000000-0000-4000-8000-000000000001','rec-owner@example.invalid','Owner',true,true,true),
  ('c3000000-0000-4000-8000-000000000002','rec-other@example.invalid','Other',true,true,true),
  ('c3000000-0000-4000-8000-000000000003','rec-admin@example.invalid','Admin',false,false,false),
  ('c3000000-0000-4000-8000-000000000004','rec-org-owner@example.invalid','Org owner',false,false,false),
  ('c3000000-0000-4000-8000-000000000005','rec-co-owner@example.invalid','Co-owner',false,false,false);
insert into public.user_roles(profile_id,role) values('c3000000-0000-4000-8000-000000000003','admin');
insert into auth.sessions(id,user_id) values
  ('c3000000-0000-4000-8000-000000000011','c3000000-0000-4000-8000-000000000001'),
  ('c3000000-0000-4000-8000-000000000012','c3000000-0000-4000-8000-000000000002'),
  ('c3000000-0000-4000-8000-000000000013','c3000000-0000-4000-8000-000000000003'),
  ('c3000000-0000-4000-8000-000000000014','c3000000-0000-4000-8000-000000000004'),
  ('c3000000-0000-4000-8000-000000000015','c3000000-0000-4000-8000-000000000005');
insert into public.channel_connections(id,owner_profile_id,youtube_channel_id,channel_title)
 values('c3000000-0000-4000-8000-000000000021','c3000000-0000-4000-8000-000000000001','UCrrrrrrrrrrrrrrrrrrrrrr','Owner');
insert into public.organizations(id,name_en,name_ar,owner_profile_id)
 values('c3000000-0000-4000-8000-000000000030','Rec org','Rec org','c3000000-0000-4000-8000-000000000004');
insert into public.org_memberships(organization_id,profile_id,role) values
  ('c3000000-0000-4000-8000-000000000030','c3000000-0000-4000-8000-000000000005','co_owner'),
  ('c3000000-0000-4000-8000-000000000030','c3000000-0000-4000-8000-000000000001','broadcaster');
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
create function pg_temp.as_user(p_n int) returns void language sql as $$
  select set_config('request.jwt.claims',format('{"sub":"c3000000-0000-4000-8000-00000000000%s","role":"authenticated","session_id":"c3000000-0000-4000-8000-00000000001%s"}',p_n,p_n),true);
$$;
create function pg_temp.sid(p_key text) returns uuid language sql as $$ select v from ids where k=p_key $$;
-- A personal live by the owner on its phone, as broadcast-control records it.
create function pg_temp.live(p_key text, p_watch text, p_hide boolean default false) returns void language plpgsql as $$
declare v_id uuid; v_token uuid;
begin
  set local role authenticated;
  perform pg_temp.as_user(1);
  insert into ids select p_key, public.broadcast_create_personal('Rec '||p_key,'liveVideo');
  v_id:=pg_temp.sid(p_key);
  perform public.broadcast_reserve_confirmed(v_id,'DEV-R','phone_direct','prepare','c3000000-0000-4000-8000-000000000021',1);
  if p_hide then perform public.broadcast_set_hide_replay(v_id,true); end if;
  reset role;
  select operation_token into v_token from private.broadcast_provider where session_id=v_id;
  perform public.broadcast_provider_step(v_id,v_token,'stream_create',
    jsonb_build_object('id','feed-'||v_id,'url','rtmps://a.rtmps.youtube.com/live2','key','fake-ingest'));
  perform public.broadcast_provider_step(v_id,v_token,'broadcast_create',jsonb_build_object('id',p_watch));
  perform public.broadcast_provider_step(v_id,v_token,'bind','{}');
  perform public.broadcast_provider_step(v_id,v_token,'observe','{"status":"live"}');
  perform public.broadcast_provider_step(v_id,v_token,'finish');
end $$;
create function pg_temp.complete(p_key text) returns void language plpgsql as $$
declare v_id uuid:=pg_temp.sid(p_key); v_token uuid:=gen_random_uuid();
begin
  update private.broadcast_provider set operation='end',operation_token=v_token,claimed_until=now()+interval '2 minutes' where session_id=v_id;
  update public.broadcast_sessions set state='ending',termination_pending=true,end_reason='owner_end' where id=v_id and state='live';
  perform public.broadcast_provider_step(v_id,v_token,'transition_complete','{"status":"complete"}');
  perform public.broadcast_provider_step(v_id,v_token,'finish');
end $$;
-- What the reconcile job would do next for this session: claim it and return the token.
create function pg_temp.claim(p_key text) returns uuid language plpgsql as $$
begin
  update private.broadcast_provider set checked_at=null,claimed_until=null where session_id=pg_temp.sid(p_key);
  perform public.broadcast_reconcile_claim();
  return (select operation_token from private.broadcast_provider where session_id=pg_temp.sid(p_key)
    and claimed_until>now());
end $$;
create function pg_temp.pending(p_key text) returns boolean language sql as $$
  select private.recording_work_pending(s,r) from public.broadcast_sessions s join private.broadcast_provider r on r.session_id=s.id
  where s.id=pg_temp.sid(p_key);
$$;
create function pg_temp.hidden(p_channel uuid, p_watch text) returns boolean language sql as $$
  select exists(select 1 from public.hidden_channel_content where streamer_id=p_channel and kind='video' and item_id=p_watch);
$$;

set local role authenticated;
select pg_temp.as_user(1);
select ok(public.claim_broadcaster_device('DEV-R','Phone R','android'),'owner claims its phone');
reset role;

-- Grants.
select ok(not has_function_privilege('anon','public.recording_delete(text)','execute'),'guests cannot delete recordings');
select ok(not has_function_privilege('anon','public.admin_recording_takedown(text,boolean,text)','execute'),'guests cannot take recordings down');
select ok(not has_function_privilege('anon','public.recording_controls(uuid)','execute'),'guests cannot read recording controls');
select ok(has_function_privilege('authenticated','public.recording_delete(text)','execute'),'signed-in owners can delete');
select ok(not has_function_privilege('authenticated','private.recording_work_pending(public.broadcast_sessions,private.broadcast_provider)','execute'),
  'the private helpers stay private');
select ok(not has_function_privilege('authenticated','private.recording_deleter(uuid)','execute'),'the deleter check stays private');
set local role authenticated;
select pg_temp.as_user(1);
select throws_ok($$select public.log_audit_event(null,'recordingDeleted','fake','fake','{}')$$,'42501',null,'clients cannot forge recording audits');
select throws_ok($$select public.log_audit_event(null,'recordingTakenDown','fake','fake','{}')$$,'42501',null,'nor takedown audits');
reset role;

-- 1. Hidden when the live ends: private on YouTube.
select lives_ok($$select pg_temp.live('r1','RRRRRRRRRR1',true)$$,'a live with the switch on');
select ok(not pg_temp.pending('r1'),'nothing for YouTube while live');
select lives_ok($$select pg_temp.complete('r1')$$,'the live ends');
select ok(pg_temp.hidden('c3000000-0000-4000-8000-000000000001','RRRRRRRRRR1'),'hidden in the app');
select ok(pg_temp.pending('r1'),'YouTube privacy pending');
select isnt(pg_temp.claim('r1'),null,'the reconcile job claims the privacy work');
select throws_ok($$select public.broadcast_provider_step(pg_temp.sid('r1'),
  (select operation_token from private.broadcast_provider where session_id=pg_temp.sid('r1')),'recording_privacy','{"privacy":"hidden"}')$$,
  '22023',null,'only public or private is recorded');
select lives_ok($$select public.broadcast_provider_step(pg_temp.sid('r1'),
  (select operation_token from private.broadcast_provider where session_id=pg_temp.sid('r1')),'recording_privacy','{"privacy":"private"}')$$,
  'broadcast-control records the private recording');
select is((select replay_privacy from private.broadcast_provider where session_id=pg_temp.sid('r1')),'private','private on YouTube');
select ok(not pg_temp.pending('r1'),'nothing left to do');

-- 2. Shown again from the channel page: public again.
set local role authenticated;
select pg_temp.as_user(1);
delete from public.hidden_channel_content where streamer_id='c3000000-0000-4000-8000-000000000001' and item_id='RRRRRRRRRR1';
reset role;
select ok(not (select hide_replay from public.broadcast_sessions where id=pg_temp.sid('r1')),'showing it clears the hide choice');
select ok(pg_temp.pending('r1'),'public again is pending');
select isnt(pg_temp.claim('r1'),null,'claimed again');
select lives_ok($$select public.broadcast_provider_step(pg_temp.sid('r1'),
  (select operation_token from private.broadcast_provider where session_id=pg_temp.sid('r1')),'recording_privacy','{"privacy":"public"}')$$,
  'recorded public');
select ok(not pg_temp.pending('r1'),'done');
-- Hidden again later from the channel page.
set local role authenticated;
select pg_temp.as_user(1);
insert into public.hidden_channel_content(streamer_id,kind,item_id) values('c3000000-0000-4000-8000-000000000001','video','RRRRRRRRRR1');
reset role;
select ok((select hide_replay from public.broadcast_sessions where id=pg_temp.sid('r1')),'hiding from the channel page sets the choice');
select ok(pg_temp.pending('r1'),'private again is pending');
-- A playlist with the same id is not a recording.
set local role authenticated;
select pg_temp.as_user(1);
insert into public.hidden_channel_content(streamer_id,kind,item_id) values('c3000000-0000-4000-8000-000000000001','playlist','RRRRRRRRRR9');
reset role;

-- 3. What the channel page is told.
set local role authenticated;
select pg_temp.as_user(1);
select is((select private_wanted from public.recording_controls('c3000000-0000-4000-8000-000000000001') where video_id='RRRRRRRRRR1'),true,
  'owner: wanted private');
select is((select youtube_privacy from public.recording_controls('c3000000-0000-4000-8000-000000000001') where video_id='RRRRRRRRRR1'),'public',
  'owner: still public on YouTube until written');
select is((select can_delete from public.recording_controls('c3000000-0000-4000-8000-000000000001') where video_id='RRRRRRRRRR1'),true,
  'owner may delete');
select pg_temp.as_user(2);
select is((select count(*)::int from public.recording_controls('c3000000-0000-4000-8000-000000000001')),0,'another account sees nothing');
select pg_temp.as_user(3);
select is((select can_delete from public.recording_controls('c3000000-0000-4000-8000-000000000001') where video_id='RRRRRRRRRR1'),false,
  'an admin sees it but may not delete');
reset role;

-- 4. Deleting.
select lives_ok($$select pg_temp.live('r2','RRRRRRRRRR2')$$,'a second live');
set local role authenticated;
select pg_temp.as_user(1);
select throws_ok($$select public.recording_delete('RRRRRRRRRR2')$$,'55000',null,'not while live');
select throws_ok($$select public.recording_delete('NOSUCHVIDEO')$$,'22023',null,'unknown recording');
reset role;
select lives_ok($$select pg_temp.complete('r2')$$,'second live ends');
set local role authenticated;
select pg_temp.as_user(2);
select throws_ok($$select public.recording_delete('RRRRRRRRRR2')$$,'42501',null,'another account cannot delete it');
select pg_temp.as_user(3);
select throws_ok($$select public.recording_delete('RRRRRRRRRR2')$$,'42501',null,'an admin cannot delete it');
select pg_temp.as_user(1);
select lives_ok($$select public.recording_delete('RRRRRRRRRR2')$$,'the owner asks to delete it');
select lives_ok($$select public.recording_delete('RRRRRRRRRR2')$$,'asking twice is harmless');
reset role;
select ok(pg_temp.hidden('c3000000-0000-4000-8000-000000000001','RRRRRRRRRR2'),'gone from the app at once');
select is((select count(*)::int from public.audit_logs where action='recordingDeleted' and metadata->>'video_id'='RRRRRRRRRR2'),1,
  'one audit entry');
select ok(pg_temp.pending('r2'),'deletion pending');
select isnt(pg_temp.claim('r2'),null,'claimed for deletion');
select lives_ok($$select public.broadcast_provider_step(pg_temp.sid('r2'),
  (select operation_token from private.broadcast_provider where session_id=pg_temp.sid('r2')),'recording_delete','{}')$$,
  'broadcast-control records the deletion');
select is((select replay_status from public.broadcast_sessions where id=pg_temp.sid('r2')),'deleted','replay marked deleted');
select is((select state from public.broadcast_sessions where id=pg_temp.sid('r2')),'completed','no replay check left');
select ok((select recording_deleted_at is not null from public.broadcast_sessions where id=pg_temp.sid('r2')),'deletion time kept');
select ok(not pg_temp.pending('r2'),'nothing left to do');
select isnt(pg_temp.claim('r1'),null,'another session claimed');
select throws_ok($$select public.broadcast_provider_step(pg_temp.sid('r1'),
  (select operation_token from private.broadcast_provider where session_id=pg_temp.sid('r1')),'recording_delete','{}')$$,
  '55000',null,'a deletion nobody asked for is refused');
update private.broadcast_provider set claimed_until=null where session_id=pg_temp.sid('r1');

-- 5. Admin takedown.
select lives_ok($$select pg_temp.live('r3','RRRRRRRRRR3')$$,'a third live');
select lives_ok($$select pg_temp.complete('r3')$$,'third live ends');
set local role authenticated;
select pg_temp.as_user(1);
select throws_ok($$select public.admin_recording_takedown('RRRRRRRRRR3',true,'test')$$,'42501',null,'owners are not admins');
select pg_temp.as_user(3);
select throws_ok($$select public.admin_recording_takedown('RRRRRRRRRR3',true,'  ')$$,'22023',null,'a reason is required');
select lives_ok($$select public.admin_recording_takedown('RRRRRRRRRR3',true,'Harmful content')$$,'an admin takes it down');
reset role;
select ok((select replay_taken_down and hide_replay from public.broadcast_sessions where id=pg_temp.sid('r3')),'taken down and hidden');
select ok(pg_temp.hidden('c3000000-0000-4000-8000-000000000001','RRRRRRRRRR3'),'hidden in the app');
select ok(pg_temp.pending('r3'),'private on YouTube pending');
select is((select count(*)::int from public.audit_logs where action='recordingTakenDown' and metadata->>'video_id'='RRRRRRRRRR3'),1,
  'takedown audited');
set local role authenticated;
select pg_temp.as_user(1);
delete from public.hidden_channel_content where streamer_id='c3000000-0000-4000-8000-000000000001' and item_id='RRRRRRRRRR3';
reset role;
select ok(pg_temp.hidden('c3000000-0000-4000-8000-000000000001','RRRRRRRRRR3'),'the owner cannot show a taken-down recording');
select ok((select hide_replay from public.broadcast_sessions where id=pg_temp.sid('r3')),'still wanted private');
set local role authenticated;
select pg_temp.as_user(1);
select is((select taken_down from public.recording_controls('c3000000-0000-4000-8000-000000000001') where video_id='RRRRRRRRRR3'),true,
  'the owner is told it was taken down');
select pg_temp.as_user(3);
select lives_ok($$select public.admin_recording_takedown('RRRRRRRRRR3',false,'Reviewed')$$,'an admin restores it');
reset role;
select ok(not (select replay_taken_down from public.broadcast_sessions where id=pg_temp.sid('r3')),'restored');
select ok(pg_temp.hidden('c3000000-0000-4000-8000-000000000001','RRRRRRRRRR3'),'still hidden until the owner shows it');
select is((select count(*)::int from public.audit_logs where action='recordingRestored' and metadata->>'video_id'='RRRRRRRRRR3'),1,
  'restore audited');
set local role authenticated;
select pg_temp.as_user(1);
delete from public.hidden_channel_content where streamer_id='c3000000-0000-4000-8000-000000000001' and item_id='RRRRRRRRRR3';
reset role;
select ok(not pg_temp.hidden('c3000000-0000-4000-8000-000000000001','RRRRRRRRRR3'),'now the owner can show it');
-- The owner may still delete a taken-down recording.
set local role authenticated;
select pg_temp.as_user(3);
select lives_ok($$select public.admin_recording_takedown('RRRRRRRRRR3',true,'Again')$$,'taken down again');
select pg_temp.as_user(1);
select lives_ok($$select public.recording_delete('RRRRRRRRRR3')$$,'the owner deletes a taken-down recording');
reset role;

-- 6. An organization's recording: only its owner may delete it.
select lives_ok($$select pg_temp.live('r5','RRRRRRRRRR5')$$,'a presenter live');
select lives_ok($$select pg_temp.complete('r5')$$,'it ends');
update public.broadcast_sessions set org_id='c3000000-0000-4000-8000-000000000030' where id=pg_temp.sid('r5');
set local role authenticated;
select pg_temp.as_user(1);
select throws_ok($$select public.recording_delete('RRRRRRRRRR5')$$,'42501',null,'the presenter cannot delete it');
select pg_temp.as_user(5);
select throws_ok($$select public.recording_delete('RRRRRRRRRR5')$$,'42501',null,'a co-owner cannot delete it');
select is((select can_delete from public.recording_controls('c3000000-0000-4000-8000-000000000030') where video_id='RRRRRRRRRR5'),false,
  'a co-owner sees it without delete');
select pg_temp.as_user(4);
select is((select can_delete from public.recording_controls('c3000000-0000-4000-8000-000000000030') where video_id='RRRRRRRRRR5'),true,
  'the organization owner may delete');
select lives_ok($$select public.recording_delete('RRRRRRRRRR5')$$,'the organization owner deletes it');
reset role;
select ok(pg_temp.hidden('c3000000-0000-4000-8000-000000000030','RRRRRRRRRR5'),'hidden on the organization channel');

-- 7. Retries: a failed privacy write waits 15 minutes, not 30 seconds.
update private.broadcast_provider set claimed_until=null,last_error='owner_reconnection_required',checked_at=now()-interval '1 minute'
 where session_id=pg_temp.sid('r1');
select lives_ok($$select public.broadcast_reconcile_claim()$$,'claim runs');
select ok((select claimed_until is null from private.broadcast_provider where session_id=pg_temp.sid('r1')),'not retried a minute after a failure');
update private.broadcast_provider set checked_at=now()-interval '20 minutes' where session_id=pg_temp.sid('r1');
select lives_ok($$select public.broadcast_reconcile_claim()$$,'claim runs again');
select ok((select claimed_until is not null from private.broadcast_provider where session_id=pg_temp.sid('r1')),'retried after 15 minutes');
set local role authenticated;
select pg_temp.as_user(1);
select is((select youtube_error from public.recording_controls('c3000000-0000-4000-8000-000000000001') where video_id='RRRRRRRRRR1'),true,
  'the owner is told YouTube could not be reached');
reset role;

-- 8. YouTube refuses the change: asked again only every 6 hours.
select isnt(pg_temp.claim('r1'),null,'claimed');
select lives_ok($$select public.broadcast_provider_step(pg_temp.sid('r1'),
  (select operation_token from private.broadcast_provider where session_id=pg_temp.sid('r1')),'recording_privacy','{"refused":"private"}')$$,
  'the refusal is recorded');
select is((select replay_privacy from private.broadcast_provider where session_id=pg_temp.sid('r1')),'public','still public on YouTube');
select ok(not pg_temp.pending('r1'),'not asked again at once');
set local role authenticated;
select pg_temp.as_user(1);
select is((select youtube_error from public.recording_controls('c3000000-0000-4000-8000-000000000001') where video_id='RRRRRRRRRR1'),true,
  'the owner is told YouTube refused');
reset role;
update private.broadcast_provider set replay_privacy_refused_at=now()-interval '7 hours' where session_id=pg_temp.sid('r1');
select ok(pg_temp.pending('r1'),'asked again after 6 hours');
update private.broadcast_provider set replay_privacy_refused_at=now() where session_id=pg_temp.sid('r1');
set local role authenticated;
select pg_temp.as_user(1);
delete from public.hidden_channel_content where streamer_id='c3000000-0000-4000-8000-000000000001' and item_id='RRRRRRRRRR1';
select is((select youtube_error from public.recording_controls('c3000000-0000-4000-8000-000000000001') where video_id='RRRRRRRRRR1'),false,
  'shown again: public is what YouTube has, nothing refused');
reset role;
select ok(not pg_temp.pending('r1'),'nothing to do');
select isnt(pg_temp.claim('r3'),null,'claimed');
select lives_ok($$select public.broadcast_provider_step(pg_temp.sid('r3'),
  (select operation_token from private.broadcast_provider where session_id=pg_temp.sid('r3')),'recording_privacy','{"privacy":"private"}')$$,
  'a later success');
select ok((select replay_privacy_refused is null from private.broadcast_provider where session_id=pg_temp.sid('r3')),'clears any refusal');

select * from finish();
rollback;
