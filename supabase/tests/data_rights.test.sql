-- export_my_data / prepare_account_deletion / delete_own_account
-- (20261015090000_data_rights_export_and_deletion.sql). Fixtures roll back.
begin;
set local search_path=public,extensions;
select no_plan();
insert into public.app_flags(key,enabled) values('chat_enabled',true),('registrations_open',true)
  on conflict(key) do update set enabled=true;
insert into auth.users(id,email) values
 ('a1000000-0000-4000-8000-000000000001','user@rights.invalid'),
 ('a1000000-0000-4000-8000-000000000002','owner@rights.invalid'),
 ('a1000000-0000-4000-8000-000000000003','member@rights.invalid'),
 ('a1000000-0000-4000-8000-000000000004','banned@rights.invalid'),
 ('a1000000-0000-4000-8000-000000000005','admin@rights.invalid');
insert into public.profiles(id,email,display_name_en,is_streamer,is_verified) values
 ('a1000000-0000-4000-8000-000000000001','user@rights.invalid','Rights User',false,false),
 ('a1000000-0000-4000-8000-000000000002','owner@rights.invalid','Owner',true,true),
 ('a1000000-0000-4000-8000-000000000003','member@rights.invalid','Member',false,false),
 ('a1000000-0000-4000-8000-000000000004','banned@rights.invalid','Banned',false,false),
 ('a1000000-0000-4000-8000-000000000005','admin@rights.invalid','Admin',false,false);

-- The user: an application, chat, follows, bookmarks, reminders, a push
-- device, a solo organization, an uploaded file and audit entries.
insert into public.broadcaster_applications(id,applicant_profile_id,account_type,
    applicant_name_en,applicant_name_ar,email,phone,category_id,city_id,
    latitude,longitude,youtube_channel_url,youtube_handle,status,reviewed_by) values
 ('a2000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001',
  'individualScholar','Rights User','مستخدم','user@rights.invalid','555','science','khobar',
  26,50,'https://www.youtube.com/@rights','rights','pending',null);
insert into public.application_review_events(application_id,applicant_name_en,applicant_name_ar,
    actor_profile_id,actor_name,action,application_snapshot)
 select 'a2000000-0000-4000-8000-000000000001','Rights User','مستخدم',
   'a1000000-0000-4000-8000-000000000005','Admin','rejected','{"email":"user@rights.invalid"}'
 where not exists(select 1 from public.application_review_events
   where application_id='a2000000-0000-4000-8000-000000000001');
insert into public.follows(follower_profile_id,target_id) values
 ('a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002');
insert into public.bookmarks(profile_id,vod_id) values('a1000000-0000-4000-8000-000000000001','abcdefghijk');
insert into public.chat_user_blocks(blocker_id,blocked_id) values
 ('a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000003');
insert into public.schedule_push_devices(token,viewer_profile_id,platform) values
 ('secret-push-token','a1000000-0000-4000-8000-000000000001','android');
insert into public.organizations(id,owner_profile_id,name_en,name_ar) values
 ('a3000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','Solo','منفرد'),
 ('a3000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002','Shared','مشتركة');
insert into public.org_memberships(organization_id,profile_id,role,status) values
 ('a3000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000003','manager','active');
insert into public.affiliation_requests(organization_id,direction,target_email,status) values
 ('a3000000-0000-4000-8000-000000000002','orgToStreamer','USER@rights.invalid','pending');
insert into public.audit_logs(actor_profile_id,actor_email,actor_name,action,description_en,description_ar) values
 ('a1000000-0000-4000-8000-000000000001','user@rights.invalid','Rights User','accountSessionsRevoked','d','d');
insert into storage.buckets(id,name,public) values('streamer-assets','streamer-assets',true)
  on conflict(id) do nothing;
insert into storage.objects(bucket_id,name,owner_id) values
 ('streamer-assets','a1000000-0000-4000-8000-000000000001/avatars/a.png','a1000000-0000-4000-8000-000000000001'),
 ('streamer-assets','legacy-flat-a.png','a1000000-0000-4000-8000-000000000001'),
 ('streamer-assets','org/a3000000-0000-4000-8000-000000000001/logo.png','a1000000-0000-4000-8000-000000000001'),
 ('streamer-assets','a1000000-0000-4000-8000-000000000002/avatars/o.png','a1000000-0000-4000-8000-000000000002');
insert into public.banned_users(profile_id,email,reason) values
 ('a1000000-0000-4000-8000-000000000004','banned@rights.invalid','test');

set local role anon;
select throws_ok($$select public.export_my_data()$$,'42501',null,'anon cannot export');
select throws_ok($$select public.prepare_account_deletion()$$,'42501',null,'anon cannot prepare deletion');
select throws_ok($$select public.delete_own_account()$$,'42501',null,'anon cannot delete');
reset role;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
create temporary table export_result as select public.export_my_data() as value;
select is((select value->'account'->>'email' from export_result),'user@rights.invalid','export includes the account');
select is((select value->'profile'->>'display_name_en' from export_result),'Rights User','export includes the profile');
select is((select jsonb_array_length(value->'broadcaster_applications') from export_result),1,'export includes applications');
select ok(not (select value->'broadcaster_applications'->0 ? 'reviewed_by' from export_result),'export omits the reviewer');
select ok((select jsonb_array_length(value->'application_history') from export_result) >= 1,'export includes application history');
select ok(not (select (value->'application_history')::text like '%a1000000-0000-4000-8000-000000000005%' from export_result),'history omits the reviewer identity');
select is((select jsonb_array_length(value->'follows') from export_result),1,'export includes follows');
select is((select jsonb_array_length(value->'bookmarks') from export_result),1,'export includes bookmarks');
select is((select jsonb_array_length(value->'chat_blocks') from export_result),1,'export includes blocks');
select is((select jsonb_array_length(value->'push_devices') from export_result),1,'export lists push devices');
select ok(not (select value::text like '%secret-push-token%' from export_result),'export never contains push tokens');
select is((select jsonb_array_length(value->'organizations_owned') from export_result),1,'export includes owned organizations');
select is((select jsonb_array_length(value->'organization_invitations') from export_result),1,'export includes invitations sent to the email');
select is((select jsonb_array_length(value->'actions_recorded') from export_result),1,'export includes recorded actions');
select is((select jsonb_array_length(value->'uploaded_files') from export_result),3,'export lists own, legacy and solo-org files');
select ok((select value ? 'reminders' and value ? 'youtube_channel_connections' and value ? 'organization_events' from export_result),'export has every section');

select is((select public.prepare_account_deletion()->>'blocker'),null,'solo owner is not blocked');
select is((select jsonb_array_length(public.prepare_account_deletion()->'storage_paths')),3,'deletion lists files to remove');
select is((select count(*)::int from storage.objects where name='legacy-flat-a.png'),1,'owner can see a legacy upload');
select throws_ok($$select public.delete_own_account()$$,'55000','storage_cleanup_required','files must be removed first');

-- Stand-in for the Storage API removal the client performs.
reset role;
select set_config('storage.allow_delete_query','true',true);
delete from storage.objects where owner_id='a1000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.delete_own_account()$$,'user deletes own account');
reset role;
select is((select count(*)::int from auth.users where id='a1000000-0000-4000-8000-000000000001'),0,'auth user removed');
select is((select count(*)::int from public.profiles where id='a1000000-0000-4000-8000-000000000001'),0,'profile removed');
select is((select count(*)::int from public.organizations where id='a3000000-0000-4000-8000-000000000001'),0,'solo organization removed');
select is((select count(*)::int from public.schedule_push_devices where token='secret-push-token'),0,'push token removed');
select is((select count(*)::int from public.follows where follower_profile_id='a1000000-0000-4000-8000-000000000001'),0,'follows removed');
select is((select count(*)::int from public.audit_logs where actor_email='user@rights.invalid' or actor_name='Rights User'),0,'audit log keeps no name or email');
select is((select count(*)::int from public.application_review_events
  where application_id='a2000000-0000-4000-8000-000000000001'
    and (applicant_name_en<>'Deleted account' or application_snapshot<>'{}'::jsonb)),0,'review history redacted');
select is((select count(*)::int from public.affiliation_requests where lower(target_email)='user@rights.invalid'),0,'invitations to the email removed');
select is((select count(*)::int from storage.objects where owner_id='a1000000-0000-4000-8000-000000000002'),1,'other users files untouched');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((select public.prepare_account_deletion()->>'blocker'),'organization_has_members','owner with members is blocked');
select throws_ok($$select public.delete_own_account()$$,'55000','organization_has_members','owner with members cannot delete');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select is((select public.prepare_account_deletion()->>'blocker'),'account_restricted','banned user is blocked');
select throws_ok($$select public.delete_own_account()$$,'55000','account_restricted','banned user cannot self-delete');
select is((select public.export_my_data()->'bans_received'->0->>'reason'),'test','banned user can still export');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select is((select count(*)::int from storage.objects where name like 'a1000000-0000-4000-8000-000000000002/%'),0,'others cannot list another users files');
reset role;

select * from finish();
rollback;
