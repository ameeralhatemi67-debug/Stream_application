begin;
set local search_path=public,extensions;
select plan(36);
insert into public.app_flags(key,enabled) values('registrations_open',true) on conflict(key) do update set enabled=true;
insert into auth.users(id,email,email_confirmed_at)
 select ('97000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'session-'||n||'@org.invalid',now() from generate_series(1,6)n;
insert into auth.sessions(id,user_id)
 select ('98000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,('97000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid from generate_series(1,6)n;
insert into public.profiles(id,is_streamer,is_verified)
 select ('97000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,true,true from generate_series(1,6)n;
insert into public.organizations(id,owner_profile_id,name_en,name_ar,is_verified)
 values('99000000-0000-4000-8000-000000000001','97000000-0000-4000-8000-000000000001','Session org','مؤسسة البرامج',true);
insert into public.org_memberships(organization_id,profile_id,role,status,permissions)
 select '99000000-0000-4000-8000-000000000001',('97000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
   'broadcaster','active','{"can_go_live_video":true}'::jsonb from generate_series(2,6)n;
insert into private.organization_v1_pilots(organization_id) values('99000000-0000-4000-8000-000000000001');
insert into public.channel_connections(id,owner_profile_id,organization_id,youtube_channel_id,channel_title)
 values('99900000-0000-4000-8000-000000000001','97000000-0000-4000-8000-000000000001','99000000-0000-4000-8000-000000000001','UCaaaaaaaaaaaaaaaaaaaaaa','Pilot');
insert into private.channel_credentials values('99900000-0000-4000-8000-000000000001',vault.create_secret('fake-refresh'));
insert into public.device_sessions(user_id,device_id,device_name,platform,is_primary_broadcaster,last_active_at)
 select ('97000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'device-'||n,'Test','web',true,now() from generate_series(2,6)n;
create temporary table fixtures(name text primary key,id uuid,value jsonb);
grant all on fixtures to authenticated,service_role;
grant select on fixtures to anon;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"97000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"98000000-0000-4000-8000-000000000001"}',true);
insert into fixtures(name,id) select 'weekly',public.broadcast_save_schedule('99000000-0000-4000-8000-000000000001',null,
 '97000000-0000-4000-8000-000000000002','weekly',((now()+interval '10 minutes') at time zone 'Asia/Riyadh')::time,
 array[extract(isodow from (now()+interval '10 minutes') at time zone 'Asia/Riyadh')::smallint],null,'Weekly','أسبوعي','liveVideo');
select is((select count(*)::integer from public.broadcast_sessions where schedule_id=(select id from fixtures where name='weekly')),4,'Four weeks are materialized in Riyadh time');
select ok((select bool_and(state='awaiting_acceptance' and accepted_at is null) from public.broadcast_sessions where schedule_id=(select id from fixtures where name='weekly')),'Each occurrence requires acceptance');
insert into fixtures(name,id) select 'session',id from public.broadcast_sessions where schedule_id=(select id from fixtures where name='weekly') order by scheduled_start_at limit 1;
select throws_ok($$select public.broadcast_save_schedule('99000000-0000-4000-8000-000000000001',null,'97000000-0000-4000-8000-000000000002','once',((now()+interval '15 minutes') at time zone 'Asia/Riyadh')::time,'{}',now()+interval '15 minutes','Overlap','','liveVideo')$$,'23P01',null,'Presenter cannot have overlapping assignments');
insert into fixtures(name,id) select 'second',public.broadcast_save_schedule('99000000-0000-4000-8000-000000000001',null,
 '97000000-0000-4000-8000-000000000003','once',((now()+interval '10 minutes') at time zone 'Asia/Riyadh')::time,'{}',now()+interval '10 minutes','Second','','liveVideo');
insert into fixtures(name,id) select 'third',public.broadcast_save_schedule('99000000-0000-4000-8000-000000000001',null,
 '97000000-0000-4000-8000-000000000004','once',((now()+interval '10 minutes') at time zone 'Asia/Riyadh')::time,'{}',now()+interval '10 minutes','Third','','liveVideo');
select throws_ok($$select public.broadcast_save_schedule('99000000-0000-4000-8000-000000000001',null,'97000000-0000-4000-8000-000000000005','once',((now()+interval '10 minutes') at time zone 'Asia/Riyadh')::time,'{}',now()+interval '10 minutes','Fourth','','liveVideo')$$,'23P01',null,'Fourth simultaneous organization reservation denied');
select throws_ok($$select public.broadcast_accept_assignment((select id from fixtures where name='session'),true,1)$$,'42501',null,'Leadership cannot accept for the presenter');
set local role anon;
select is((select count(*)::integer from public.broadcast_sessions where schedule_id=(select id from fixtures where name='weekly')),0,'Unaccepted assignments are not public');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"97000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"98000000-0000-4000-8000-000000000002"}',true);
select throws_ok($$select public.broadcast_reserve_confirmed((select id from fixtures where name='session'),'device-2','obs_laptop','prepare','99900000-0000-4000-8000-000000000001',1)$$,'55000',null,'Unaccepted session cannot prepare');
select lives_ok($$select public.broadcast_accept_assignment((select id from fixtures where name='session'),true,1)$$,'Presenter accepts the exact revision');
select throws_ok($$select public.broadcast_accept_assignment((select id from fixtures where name='session'),true,1)$$,'42501',null,'Stale acceptance denied');
set local role anon;
select is((select count(*)::integer from public.broadcast_sessions where owner_id='97000000-0000-4000-8000-000000000002'),1,'Only accepted occurrence becomes public');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"97000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"98000000-0000-4000-8000-000000000001"}',true);
select lives_ok($$select public.broadcast_edit_occurrence((select id from fixtures where name='session'),'97000000-0000-4000-8000-000000000002',now()+interval '11 minutes',now()+interval '71 minutes','liveVideo')$$,'Leadership reschedules the occurrence');
select ok((select accepted_at is null and state='awaiting_acceptance' from public.broadcast_sessions where id=(select id from fixtures where name='session')),'Material edit resets acceptance');
reset role;
select private.broadcast_materialize((select id from fixtures where name='weekly'));
select is((select count(*)::integer from public.broadcast_sessions where schedule_id=(select id from fixtures where name='weekly')),4,'Replenishment preserves rescheduled occurrence identity');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"97000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"98000000-0000-4000-8000-000000000002"}',true);
select public.broadcast_accept_assignment((select id from fixtures where name='session'),true,3);
select throws_ok($$select public.broadcast_reserve_confirmed((select id from fixtures where name='session'),'wrong-device','obs_laptop','prepare','99900000-0000-4000-8000-000000000001',1)$$,'42501',null,'Wrong device cannot reserve');
update fixtures set value=public.broadcast_reserve_confirmed(id,'device-2','obs_laptop','prepare','99900000-0000-4000-8000-000000000001',1) where name='session';
select ok((select state='preparing' and channel_connection_id='99900000-0000-4000-8000-000000000001' from public.broadcast_sessions where id=(select id from fixtures where name='session')),'Preparation freezes the verified destination');
select ok((select not is_currently_live from public.profiles where id=auth.uid()),'Preparing does not falsely show LIVE');
select throws_ok($$select public.broadcast_reserve_confirmed((select id from fixtures where name='session'),'device-2','obs_laptop','prepare','99900000-0000-4000-8000-000000000001',1)$$,'55000',null,'Concurrent preparation has a single reservation');
select throws_ok($$select public.broadcast_provider_step((select id from fixtures where name='session'),(select (value->>'token')::uuid from fixtures where name='session'),'observe','{"status":"live"}')$$,'42501',null,'Client cannot forge provider confirmation');
set local role service_role;
select public.broadcast_provider_step((select id from fixtures where name='session'),(select (value->>'token')::uuid from fixtures where name='session'),'stream_create');
select public.broadcast_provider_step((select id from fixtures where name='session'),(select (value->>'token')::uuid from fixtures where name='session'),'stream_create',null,'timeout',true);
reset role;
select ok((select needs_reconciliation from private.broadcast_provider where session_id=(select id from fixtures where name='session')),'Ambiguous creation remains fenced for reconciliation');
set local role authenticated;
update fixtures set value=public.broadcast_reserve_confirmed(id,'device-2','obs_laptop','prepare','99900000-0000-4000-8000-000000000001',1) where name='session';
set local role service_role;
select throws_ok($$select public.broadcast_provider_step((select id from fixtures where name='session'),(select (value->>'token')::uuid from fixtures where name='session'),'stream_create')$$,'55000',null,'Ambiguous resource creation cannot retry blindly');
select public.broadcast_provider_step((select id from fixtures where name='session'),(select (value->>'token')::uuid from fixtures where name='session'),'stream_create','{"id":"provider-feed","url":"rtmps://a.rtmps.youtube.com/live2","key":"fake-ingest"}');
select public.broadcast_provider_step((select id from fixtures where name='session'),(select (value->>'token')::uuid from fixtures where name='session'),'broadcast_create','{"id":"abcdefghijk"}');
select public.broadcast_provider_step((select id from fixtures where name='session'),(select (value->>'token')::uuid from fixtures where name='session'),'bind','{}');
select public.broadcast_provider_step((select id from fixtures where name='session'),(select (value->>'token')::uuid from fixtures where name='session'),'observe','{"status":"liveStarting"}');
reset role;
select ok((select state='preparing' from public.broadcast_sessions where id=(select id from fixtures where name='session')),'YouTube liveStarting is not LIVE');
set local role service_role;
select public.broadcast_provider_step((select id from fixtures where name='session'),(select (value->>'token')::uuid from fixtures where name='session'),'observe','{"status":"live"}');
reset role;
select ok((select state='live' from public.broadcast_sessions where id=(select id from fixtures where name='session')),'Provider confirmed transition becomes LIVE');
select ok((select is_currently_live and active_stream_id='abcdefghijk' from public.profiles where id='97000000-0000-4000-8000-000000000002'),'Profile live status is a session summary');
select throws_ok($$delete from public.profiles where id='97000000-0000-4000-8000-000000000002'$$,'55000',null,'Deleting an active presenter cannot orphan provider media');
update public.organizations set is_currently_live=false,active_stream_id='forgedvideo' where id='99000000-0000-4000-8000-000000000001';
select ok((select is_currently_live and active_stream_id='abcdefghijk' from public.organizations where id='99000000-0000-4000-8000-000000000001'),'Legacy organization writes cannot overwrite the session summary');
update public.device_sessions set last_active_at=now()-interval '1 hour' where user_id='97000000-0000-4000-8000-000000000002';
select is(public.sweep_stale_live_flags(),0,'Healthy OBS is not ended by a closed management tab');
update public.org_memberships set status='revoked' where organization_id='99000000-0000-4000-8000-000000000001' and profile_id='97000000-0000-4000-8000-000000000002';
select ok((select state='ending' and termination_pending from public.broadcast_sessions where id=(select id from fixtures where name='session')),'Revocation immediately requests provider termination');
select is((select count(*)::integer from public.broadcast_sessions where owner_id='97000000-0000-4000-8000-000000000002' and state='cancelled'),3,'Revocation cancels that presenter future occurrences');
select is((select count(*)::integer from public.broadcast_sessions where owner_id in('97000000-0000-4000-8000-000000000003','97000000-0000-4000-8000-000000000004') and state='awaiting_acceptance'),2,'Other presenters remain independent');
set local role service_role;
select public.broadcast_provider_step((select id from fixtures where name='session'),(select (value->>'token')::uuid from fixtures where name='session'),'observe','{"status":"complete"}');
reset role;
select ok((select state='processing_replay' and replay_status='processing' and not termination_pending from public.broadcast_sessions where id=(select id from fixtures where name='session')),'Completion and replay processing are distinct');
set local role service_role;
select public.broadcast_provider_step((select id from fixtures where name='session'),(select (value->>'token')::uuid from fixtures where name='session'),'observe','{"replay":"missing"}');
reset role;
select ok((select state='completed' and replay_status='missing' from public.broadcast_sessions where id=(select id from fixtures where name='session')),'Missing archive reports a truthful terminal replay status');
select throws_ok($$delete from public.profiles where id='97000000-0000-4000-8000-000000000002'$$,'55000',null,'Deletion waits until the bound feed is retired');
set local role service_role;
select public.broadcast_provider_step((select id from fixtures where name='session'),(select (value->>'token')::uuid from fixtures where name='session'),'feed_delete','{}');
reset role;
select ok(not exists(select 1 from vault.secrets where name='youtube_ingest_'||(select id::text from fixtures where name='session')),'Feed retirement removes the ingest secret');
set local role authenticated;
select lives_ok($$update public.profiles set is_currently_live=true,active_stream_id='forgedvideo' where id=auth.uid()$$,'Legacy client profile write is harmless');
select ok((select not is_currently_live from public.profiles where id=auth.uid()),'Client profile flags cannot mint a live session');
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select throws_ok($$update public.profiles set is_currently_live=true,active_stream_id='forgedvideo' where id='97000000-0000-4000-8000-000000000002'$$,'42501',null,'Privileged profile writers also require a confirmed session');
select * from finish();
rollback;
