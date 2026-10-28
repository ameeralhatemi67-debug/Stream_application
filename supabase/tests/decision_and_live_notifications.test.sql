-- The applicant hears the decision; a personal live alert names the
-- presenter (20261028132950).
begin;
set local search_path=public,extensions;
select plan(13);
insert into auth.users(id,email,email_confirmed_at) values
 ('82000000-0000-4000-8000-000000000001','applicant@decision.invalid',now()),
 ('82000000-0000-4000-8000-000000000002','follower@decision.invalid',now()),
 ('82000000-0000-4000-8000-000000000003','presenter@decision.invalid',now());
insert into public.profiles(id,email,display_name_en,display_name_ar,is_streamer,is_verified) values
 ('82000000-0000-4000-8000-000000000001','applicant@decision.invalid','Applicant','مقدم الطلب',false,false),
 ('82000000-0000-4000-8000-000000000002','follower@decision.invalid','Follower','متابع',false,false),
 ('82000000-0000-4000-8000-000000000003','presenter@decision.invalid','Sheikh Presenter','الشيخ المقدم',true,true)
 on conflict (id) do update set display_name_en=excluded.display_name_en,display_name_ar=excluded.display_name_ar,
   is_streamer=excluded.is_streamer,is_verified=excluded.is_verified;
insert into public.broadcaster_applications(id,applicant_profile_id,account_type,applicant_name_en,applicant_name_ar,
  email,phone,category_id,city_id,latitude,longitude,youtube_channel_url,youtube_handle,tags)
values('82000000-0000-4000-8000-0000000000a1','82000000-0000-4000-8000-000000000001','individualScholar',
  'Omar','عمر','applicant@decision.invalid','0500000000','fiqh','khobar',26.28,50.20,
  'https://www.youtube.com/@omar','@omar','{}');

-- Rejection, with the reviewer's note.
update public.broadcaster_applications set status='rejected',admin_review_notes='  Add a clearer photo.  '
 where id='82000000-0000-4000-8000-0000000000a1';
select is((select count(*)::int from public.org_v1_events
   where recipient_profile_id='82000000-0000-4000-8000-000000000001' and kind='application_rejected'),
 1,'the applicant receives the rejection');
select ok((select payload->>'reason'='Add a clearer photo.' and payload->>'edit'='false' and payload->>'name_ar'='عمر'
   from public.org_v1_events where kind='application_rejected'
     and recipient_profile_id='82000000-0000-4000-8000-000000000001'),
 'the rejection carries the trimmed note and the names');

-- Resubmitted and approved.
update public.broadcaster_applications set status='pending' where id='82000000-0000-4000-8000-0000000000a1';
update public.broadcaster_applications set status='approved',admin_review_notes=null
 where id='82000000-0000-4000-8000-0000000000a1';
select ok((select payload->>'reason' is null and payload->>'edit'='false' from public.org_v1_events
   where recipient_profile_id='82000000-0000-4000-8000-000000000001' and kind='application_approved'),
 'the applicant receives the approval, without a note');
select is((select count(*)::int from public.org_v1_events where kind like 'application_%'
   and recipient_profile_id<>'82000000-0000-4000-8000-000000000001'),
 0,'nobody else receives the decision');

-- An edit that is not approved.
insert into public.broadcaster_applications(id,revision_of,applicant_profile_id,account_type,applicant_name_en,applicant_name_ar,
  email,phone,category_id,city_id,latitude,longitude,youtube_channel_url,youtube_handle,tags)
values('82000000-0000-4000-8000-0000000000b1','82000000-0000-4000-8000-0000000000a1','82000000-0000-4000-8000-000000000001',
  'individualScholar','Omar','عمر','new@decision.invalid','0500000000','fiqh','khobar',26.28,50.20,
  'https://www.youtube.com/@omar','@omar','{}');
update public.broadcaster_applications set status='rejected',admin_review_notes='Keep the old email'
 where id='82000000-0000-4000-8000-0000000000b1';
select ok((select payload->>'edit'='true' from public.org_v1_events
   where kind='application_rejected' and payload->>'application_id'='82000000-0000-4000-8000-0000000000b1'),
 'a refused edit is marked as an edit');

-- Other status changes say nothing.
update public.broadcaster_applications set status='suspended' where id='82000000-0000-4000-8000-0000000000b1';
select is((select count(*)::int from public.org_v1_events where kind like 'application_%'),
 3,'only approve and reject write a decision');

-- The recipient reads it through the inbox; others cannot.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"82000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is((select count(*)::int from public.org_v1_events(50) where kind like 'application_%'),
 3,'the applicant sees the three decisions in the inbox');
select set_config('request.jwt.claims','{"sub":"82000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((select count(*)::int from public.org_v1_events(50) where kind like 'application_%'),
 0,'another account sees none of them');
select throws_ok($$insert into public.org_v1_events(recipient_profile_id,kind,payload,dedupe_key)
  values(auth.uid(),'application_approved','{}','forged')$$,'42501',null,'clients cannot forge a decision');
reset role;

-- A personal live names the presenter.
insert into public.follows(follower_profile_id,target_id)
 values('82000000-0000-4000-8000-000000000002','82000000-0000-4000-8000-000000000003');
insert into public.broadcast_sessions(id,owner_id,state,broadcast_type,stream_id,device_id,sender_mode,accepted_at,
  scheduled_start_at,expected_end_at,title_en,title_ar)
values('82000000-0000-4000-8000-0000000000c1','82000000-0000-4000-8000-000000000003','preparing','liveVideo',
  'ddddddddddd','obs','obs_laptop',now(),now(),now()+interval '1 hour','Tafsir','تفسير');
update public.broadcast_sessions set state='live' where id='82000000-0000-4000-8000-0000000000c1';
select ok((select payload->>'presenter_name_en'='Sheikh Presenter' and payload->>'presenter_name_ar'='الشيخ المقدم'
     and payload->>'organization_name_en' is null
   from public.org_v1_events where kind='show_live' and recipient_profile_id='82000000-0000-4000-8000-000000000002'),
 'the follower''s live alert names the presenter');

-- Pushes: decisions ignore the switches; live alerts follow theirs.
insert into public.schedule_push_devices(token,viewer_profile_id,platform,language_code) values
 ('token-applicant-0001','82000000-0000-4000-8000-000000000001','android','ar'),
 ('token-follower-00001','82000000-0000-4000-8000-000000000002','android','en');
insert into public.notification_push_preferences(viewer_profile_id,live_enabled,organization_enabled) values
 ('82000000-0000-4000-8000-000000000001',false,false),
 ('82000000-0000-4000-8000-000000000002',false,true);
set local role service_role;
create temporary table claims as select * from public.claim_org_v1_event_pushes();
reset role;
select is((select count(*)::int from claims where token='token-applicant-0001' and kind like 'application_%'),
 3,'decision pushes go out with both switches off');
select ok((select bool_and(language_code='ar') from claims where token='token-applicant-0001'),
 'the push carries the device language');
select is((select count(*)::int from claims where token='token-follower-00001'),
 0,'a live alert stays silent when live alerts are switched off');

select * from finish();
rollback;
