begin;
set local search_path=public,extensions;
select plan(48);
insert into public.app_flags(key,enabled) values('registrations_open',true),('organization_applications_open',false)
 on conflict(key) do update set enabled=excluded.enabled;
insert into auth.users(id,email,email_confirmed_at)
 select ('a1000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'event-'||n||'@org.invalid',now() from generate_series(1,6)n;
insert into auth.sessions(id,user_id)
 select ('a2000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,('a1000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid from generate_series(1,7)n
 where n<=6;
insert into public.profiles(id,is_streamer,is_verified)
 select ('a1000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,true,true from generate_series(1,6)n;
insert into public.organizations(id,owner_profile_id,name_en,name_ar,is_verified)
 values('a3000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','Event org','مؤسسة الأحداث',true);
insert into public.org_memberships(organization_id,profile_id,role,status,permissions) values
 ('a3000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002','broadcaster','active','{"can_go_live_video":true}'),
 ('a3000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000003','manager','active','{}'),
 ('a3000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000004','moderator','active','{}');
insert into private.organization_v1_pilots(organization_id) values('a3000000-0000-4000-8000-000000000001');
insert into public.follows(follower_profile_id,target_id)
 values('a1000000-0000-4000-8000-000000000005','a3000000-0000-4000-8000-000000000001');
create temporary table fixtures(name text primary key,id uuid,value jsonb);
grant all on fixtures to authenticated,service_role;

-- Availability: new organization applications follow their own switch.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000006","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000006"}',true);
select throws_ok($$insert into public.broadcaster_applications(applicant_profile_id,account_type,applicant_name_en,applicant_name_ar,
 email,phone,category_id,city_id,latitude,longitude) values(auth.uid(),'organizationVenue','New org','مؤسسة',
 'event-6@org.invalid','','education','khobar',26.304212,50.146278)$$,'42501',null,'Closed switch refuses organization applications');
reset role;
update public.app_flags set enabled=true where key='organization_applications_open';
set local role authenticated;
select lives_ok($$insert into public.broadcaster_applications(applicant_profile_id,account_type,applicant_name_en,applicant_name_ar,
 email,phone,category_id,city_id,latitude,longitude) values(auth.uid(),'organizationVenue','New org','مؤسسة',
 'event-6@org.invalid','','education','khobar',26.304212,50.146278)$$,'Open switch accepts organization applications');
select ok(public.org_v1_enabled('a3000000-0000-4000-8000-000000000001'),'Pilot organization is enabled');
select is((select count(*)::integer from public.org_v1_pilot_status()),0,'Pilot overview is Master Admin only');

-- Assignment lifecycle events.
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000003","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000003"}',true);
insert into fixtures(name,id) select 'schedule',public.broadcast_save_schedule('a3000000-0000-4000-8000-000000000001',null,
 'a1000000-0000-4000-8000-000000000002','once',((now()+interval '10 minutes') at time zone 'Asia/Riyadh')::time,'{}',
 now()+interval '10 minutes','Event show','برنامج','liveVideo');
insert into fixtures(name,id) select 'session',id from public.broadcast_sessions where schedule_id=(select id from fixtures where name='schedule');
select is((select count(*)::integer from public.org_v1_events where recipient_profile_id='a1000000-0000-4000-8000-000000000002'),0,'Events of another account are invisible');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000002"}',true);
select is((select count(*)::integer from public.org_v1_events where kind='assignment'),1,'Presenter receives the assignment');
select is((select payload->>'organization_name_en' from public.org_v1_events where kind='assignment'),'Event org','Assignment names its organization');
select throws_ok($$insert into public.org_v1_events(recipient_profile_id,kind,payload,dedupe_key) values(auth.uid(),'assignment','{}','forged')$$,'42501',null,'Clients cannot forge events');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000003","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000003"}',true);
select lives_ok($$select public.broadcast_edit_occurrence((select id from fixtures where name='session'),'a1000000-0000-4000-8000-000000000002',now()+interval '12 minutes',now()+interval '72 minutes','liveVideo')$$,'Leadership edits the occurrence');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000002"}',true);
select is((select count(*)::integer from public.org_v1_events where kind='assignment_changed'),1,'Material edit notifies the presenter once');
select lives_ok($$select public.broadcast_accept_assignment((select id from fixtures where name='session'),true,(select revision from public.broadcast_sessions where id=(select id from fixtures where name='session')))$$,'Presenter accepts');
select is((select count(*)::integer from public.org_v1_events(50) where kind='assignment_reminder'),1,'Reading events emits the due presenter reminder');
select is((select count(*)::integer from public.org_v1_events(50) where kind='assignment_reminder'),1,'Reminder is deduplicated per revision');
select lives_ok($$select public.org_v1_mark_events_read(null)$$,'Presenter marks events read');
select is((select count(*)::integer from public.org_v1_events where read_at is null),0,'All own events are read');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000003","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000003"}',true);
select is((select (payload->>'accepted')::boolean from public.org_v1_events where kind='assignment_answered'),true,'Scheduler learns the answer');
select lives_ok($$select public.broadcast_cancel_schedule((select id from fixtures where name='schedule'))$$,'Scheduler cancels the series');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000002"}',true);
select is((select count(*)::integer from public.org_v1_events where kind='assignment_cancelled'),1,'Presenter learns of the cancellation');

-- Confirmed start: followers and leadership, never the presenter.
reset role;
insert into public.broadcast_sessions(id,owner_id,org_id,state,broadcast_type,stream_id,device_id,sender_mode,accepted_at,scheduled_start_at,expected_end_at,title_en)
 values('a4000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002','a3000000-0000-4000-8000-000000000001','preparing','liveVideo','eeeeeeeeeee','obs','obs_laptop',now(),now(),now()+interval '1 hour','Live show');
update public.broadcast_sessions set state='live' where id='a4000000-0000-4000-8000-000000000001';
select is((select count(*)::integer from public.org_v1_events where kind='show_live' and recipient_profile_id='a1000000-0000-4000-8000-000000000005'),1,'Follower learns the show is live');
select is((select count(*)::integer from public.org_v1_events where kind='show_live' and recipient_profile_id in ('a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000003')),2,'Owner and manager learn the show is live');
select is((select count(*)::integer from public.org_v1_events where kind='show_live' and recipient_profile_id in ('a1000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000004')),0,'Presenter and moderator are not notified');
update public.broadcast_sessions set revision=revision+1 where id='a4000000-0000-4000-8000-000000000001';
select is((select count(*)::integer from public.org_v1_events where kind='show_live'),3,'Confirmed start is announced once');

-- Grant revocation ends the show and tells the presenter.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000001"}',true);
select lives_ok($$select public.org_v1_set_member('a3000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002','broadcaster','active','{"can_go_live_video":false}')$$,'Owner revokes the video grant');
reset role;
select is((select count(*)::integer from public.org_v1_events where recipient_profile_id='a1000000-0000-4000-8000-000000000002' and kind in ('membership_changed','show_ending')),2,'Presenter learns of the grant change and forced end');
select is((select payload->>'video' from public.org_v1_events where recipient_profile_id='a1000000-0000-4000-8000-000000000002' and kind='membership_changed'),'false','Grant change payload is truthful');
update public.broadcast_sessions set state='completed' where id='a4000000-0000-4000-8000-000000000001';

-- Invitations: existing account, later account binding and manager list.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000001"}',true);
insert into fixtures(name,value) select 'invite-existing',public.org_v1_invite('a3000000-0000-4000-8000-000000000001','event-6@org.invalid','broadcaster','{"can_go_audio_only":true}');
insert into fixtures(name,value) select 'invite-late',public.org_v1_invite('a3000000-0000-4000-8000-000000000001','late@org.invalid','moderator','{}');
select is((select count(*)::integer from public.org_v1_invitations('a3000000-0000-4000-8000-000000000001')),2,'Owner lists pending invitations');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000004","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000004"}',true);
select is((select count(*)::integer from public.org_v1_invitations('a3000000-0000-4000-8000-000000000001')),0,'Moderator cannot list invitations');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000006","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000006"}',true);
select is((select count(*)::integer from public.org_v1_events where kind='invitation'),1,'Existing account receives the invitation event');
select is((select count(*)::integer from public.org_v1_my_invitations()),1,'Invitee sees only their invitation');
reset role;
insert into auth.users(id,email,email_confirmed_at) values('a1000000-0000-4000-8000-000000000007','late@org.invalid',now());
insert into auth.sessions(id,user_id) values('a2000000-0000-4000-8000-000000000007','a1000000-0000-4000-8000-000000000007');
insert into public.profiles(id) values('a1000000-0000-4000-8000-000000000007');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000007","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000007"}',true);
select is((select count(*)::integer from public.org_v1_my_invitations()),1,'Verified email binds a later account');
select is((select count(*)::integer from public.org_v1_events where kind='invitation'),1,'Binding creates the in-app invitation');
select lives_ok($$select public.org_v1_answer_invite(((select value from fixtures where name='invite-late')->>'id')::uuid,true)$$,'Bound account accepts in-app');
select is((select role from public.org_memberships where profile_id=auth.uid()),'moderator','Accepted invitation grants its role');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000006","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000006"}',true);
select throws_ok($$select public.org_v1_answer_invite(((select value from fixtures where name='invite-late')->>'id')::uuid,true)$$,'42501',null,'Another account cannot answer a bound invitation');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000001"}',true);
select is((select (payload->>'accepted')::boolean from public.org_v1_events where kind='invitation_answered'),true,'Inviter learns the answer');

-- Two-party transfer with withdrawal.
select lives_ok($$select public.org_v1_transfer_owner('a3000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000003')$$,'Owner proposes a transfer');
select is((select (r->>'transfer_target_id')::uuid from public.org_v1_memberships() r where r->>'organization_id'='a3000000-0000-4000-8000-000000000001'),'a1000000-0000-4000-8000-000000000003'::uuid,'Owner sees the pending target');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000003","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000003"}',true);
select ok((select (r->>'transfer_to_me')::boolean from public.org_v1_memberships() r),'Target sees the incoming transfer');
select is((select count(*)::integer from public.org_v1_events where kind='transfer_proposed'),1,'Target is notified');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000004","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000004"}',true);
select throws_ok($$select public.org_v1_cancel_transfer('a3000000-0000-4000-8000-000000000001')$$,'42501',null,'Third party cannot withdraw a transfer');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000003","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000003"}',true);
select lives_ok($$select public.org_v1_cancel_transfer('a3000000-0000-4000-8000-000000000001')$$,'Target declines the transfer');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000001"}',true);
select is((select count(*)::integer from public.org_v1_events where kind='transfer_cancelled'),1,'Owner learns the transfer was declined');
select public.org_v1_transfer_owner('a3000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000003');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000003","role":"authenticated","session_id":"a2000000-0000-4000-8000-000000000003"}',true);
select lives_ok($$select public.org_v1_transfer_owner('a3000000-0000-4000-8000-000000000001')$$,'Target accepts the renewed transfer');
reset role;
select is((select count(*)::integer from public.org_v1_events where kind='transfer_completed'),2,'Both owners learn the transfer completed');

-- Push claims: service only, preferences respected, each delivery leased once.
insert into public.schedule_push_devices(token,viewer_profile_id,platform,language_code) values
 ('token-presenter-0000000001','a1000000-0000-4000-8000-000000000002','android','ar'),
 ('token-follower-00000000001','a1000000-0000-4000-8000-000000000005','web','en');
insert into public.notification_push_preferences(viewer_profile_id,live_enabled) values('a1000000-0000-4000-8000-000000000005',false);
set local role authenticated;
select throws_ok($$select * from public.claim_org_v1_event_pushes()$$,'42501',null,'Clients cannot claim pushes');
set local role service_role;
insert into fixtures(name,value) select 'claims',coalesce(jsonb_agg(c),'[]') from public.claim_org_v1_event_pushes() c;
select is((select count(*)::integer from jsonb_array_elements((select value from fixtures where name='claims')) c where c->>'token'='token-follower-00000000001'),0,'Disabled live alerts are not pushed');
select ok((select count(*)::integer from jsonb_array_elements((select value from fixtures where name='claims')) c where c->>'token'='token-presenter-0000000001')>0,'Unread presenter events are pushed');
select is((select count(*)::integer from public.claim_org_v1_event_pushes()),0,'A leased delivery is not claimed twice');
select * from finish();
rollback;
