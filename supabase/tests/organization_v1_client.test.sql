begin;
set local search_path=public,extensions;
select plan(25);
insert into public.app_flags(key,enabled) values('registrations_open',true),('chat_enabled',true) on conflict(key) do update set enabled=true;
insert into auth.users(id,email,email_confirmed_at)
 select ('91000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'client-'||n||'@org.invalid',now() from generate_series(1,6)n;
insert into auth.sessions(id,user_id)
 select ('92000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,('91000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid from generate_series(1,6)n;
insert into public.profiles(id,is_streamer,is_verified)
 select ('91000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,true,true from generate_series(1,6)n;
insert into public.organizations(id,owner_profile_id,name_en,name_ar,is_verified)
 values('93000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','Org','مؤسسة',true);
insert into public.org_memberships(organization_id,profile_id,role,status,permissions)
 select '93000000-0000-4000-8000-000000000001',('91000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 case n when 3 then 'manager' when 4 then 'moderator' else 'broadcaster' end,'active','{"can_go_live_video":true}'::jsonb from generate_series(2,5)n;
insert into public.device_sessions(user_id,device_id,device_name,platform,is_primary_broadcaster,last_active_at)
 values('91000000-0000-4000-8000-000000000002','phone','Phone','android',true,now());
insert into public.broadcast_sessions(id,owner_id,org_id,state,broadcast_type,stream_id,device_id,sender_mode,accepted_at,scheduled_start_at,expected_end_at,hidden_from_discovery)
 values('94000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000002','93000000-0000-4000-8000-000000000001','live','liveVideo','aaaaaaaaaaa','phone','phone_direct',now(),now(),now()+interval '1 hour',true),
 ('94000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000005','93000000-0000-4000-8000-000000000001','live','liveVideo','bbbbbbbbbbb','obs','obs_laptop',now(),now(),now()+interval '1 hour',false),
 ('94000000-0000-4000-8000-000000000003','91000000-0000-4000-8000-000000000006',null,'live','liveVideo','ccccccccccc','obs','obs_laptop',now(),now(),now()+interval '1 hour',false);
insert into public.chat_messages(id,stream_id,sender_id,body) values
 ('95000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000006','first room'),
 ('95000000-0000-4000-8000-000000000002','94000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000006','second room'),
 ('95000000-0000-4000-8000-000000000003','94000000-0000-4000-8000-000000000003','91000000-0000-4000-8000-000000000005','outside org');
insert into public.chat_reports(message_id,stream_id,reported_sender_id,reporter_id,reason)
 select id,stream_id,sender_id,'91000000-0000-4000-8000-000000000001','spam' from public.chat_messages;
set local role anon;
select ok(public.broadcast_room('94000000-0000-4000-8000-000000000001') is not null,'Hidden public session has a direct room');
select ok(not (public.broadcast_room('94000000-0000-4000-8000-000000000001') ? 'device_id'),'Public room excludes device identity');
select ok(not public.broadcast_is_public('94000000-0000-4000-8000-000000000001'),'Hidden room excluded from discovery');
select ok((select is_speaker from public.chat_sender_info(array['91000000-0000-4000-8000-000000000002'::uuid],'94000000-0000-4000-8000-000000000001')),'Guest can resolve the presenter badge in a public hidden room');
select ok(public.viewer_heartbeat('94000000-0000-4000-8000-000000000001','guest-test-1'),'Guest presence uses canonical hidden room');
select is((select viewer_count from public.get_viewer_counts(array['94000000-0000-4000-8000-000000000002'])),0,'Presence does not leak between shows');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000003","role":"authenticated","session_id":"92000000-0000-4000-8000-000000000003"}',true);
select ok(not public.owns_stream('94000000-0000-4000-8000-000000000001'),'Manager scheduling role grants no moderation');
select is((select count(*)::integer from public.chat_reports),0,'Manager cannot read reports');
select throws_ok($$insert into public.stream_moderators(profile_id,scope,stream_id,assigned_by) values(auth.uid(),'stream','94000000-0000-4000-8000-000000000001',auth.uid())$$,'42501',null,'Manager cannot self-appoint chat moderator');
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000004","role":"authenticated","session_id":"92000000-0000-4000-8000-000000000004"}',true);
select ok(public.owns_stream('94000000-0000-4000-8000-000000000001'),'Organization moderator can moderate exact session');
select ok(not public.owns_stream('94000000-0000-4000-8000-000000000003'),'Organization role has no outside moderation');
select ok(not public.is_admin_tier(),'Organization moderator gains no platform privileges');
select is((select count(*)::integer from public.chat_reports),2,'Moderator reads only organization reports');
select lives_ok($$insert into public.chat_muted_users(stream_id,muted_profile_id,muted_by) values('94000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000006',auth.uid())$$,'Moderator can mute in first session');
select is((select count(*)::integer from public.chat_muted_users where stream_id='94000000-0000-4000-8000-000000000002'),0,'Mute is isolated from concurrent show');
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000006","role":"authenticated","session_id":"92000000-0000-4000-8000-000000000006"}',true);
select throws_ok($$insert into public.chat_messages(stream_id,sender_id,body) values('94000000-0000-4000-8000-000000000001',auth.uid(),'muted')$$,'42501',null,'Session mute enforced on writes');
select throws_ok($$insert into public.chat_messages(stream_id,sender_id,body) values('aaaaaaaaaaa',auth.uid(),'wrong room')$$,'42501',null,'Watch ID cannot create parallel chat');
select throws_ok($$select public.broadcast_reserve('94000000-0000-4000-8000-000000000003','obs','obs_laptop','prepare')$$,'42501',null,'Unconfirmed reservation is inaccessible');
select throws_ok($$select public.broadcast_reserve_confirmed('94000000-0000-4000-8000-000000000003','obs','obs_laptop','prepare',null,null)$$,'42501',null,'Explicit destination confirmation required');
select ok((select is_moderator from public.chat_sender_info(array['91000000-0000-4000-8000-000000000004'::uuid],'94000000-0000-4000-8000-000000000001')),'Moderator badge applies to the organization room');
select ok(not (select is_moderator from public.chat_sender_info(array['91000000-0000-4000-8000-000000000004'::uuid],'94000000-0000-4000-8000-000000000003')),'Moderator badge does not cross organizations');
select ok(not (select is_org_owner or is_moderator from public.chat_sender_info(array['91000000-0000-4000-8000-000000000003'::uuid],'94000000-0000-4000-8000-000000000001')),'Manager has no moderation badge');
reset role;
update public.device_sessions set is_primary_broadcaster=false where device_id='phone';
select ok((select state='ending' and termination_pending from public.broadcast_sessions where id='94000000-0000-4000-8000-000000000001'),'Device displacement immediately requests termination');
select is((select state from public.broadcast_sessions where id='94000000-0000-4000-8000-000000000002'),'live','Other show survives device displacement');
set local role anon;
select ok(not public.viewer_heartbeat('94000000-0000-4000-8000-000000000001','guest-test-2'),'Ending show cannot claim new viewers');
select * from finish();
rollback;
