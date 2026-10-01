begin;
select no_plan();

insert into auth.users(id,email) values
 ('71000000-0000-4000-8000-000000000001','reviewer@example.invalid'),
 ('71000000-0000-4000-8000-000000000002','applicant@example.invalid'),
 ('71000000-0000-4000-8000-000000000003','newapplicant@example.invalid');
insert into public.profiles(id,display_name_en,email,is_streamer,is_verified,
    youtube_handle,latitude,longitude) values
 ('71000000-0000-4000-8000-000000000001','Review Admin','reviewer@example.invalid',false,false,null,null,null),
 ('71000000-0000-4000-8000-000000000002','Applicant','applicant@example.invalid',true,true,'old',26,50),
 ('71000000-0000-4000-8000-000000000003','New applicant','newapplicant@example.invalid',false,false,'new',26,50);
insert into public.user_roles(profile_id,role) values
 ('71000000-0000-4000-8000-000000000001','admin');
insert into public.broadcaster_applications(id,applicant_profile_id,account_type,
    applicant_name_en,applicant_name_ar,email,phone,category_id,city_id,
    latitude,longitude,youtube_channel_url,youtube_handle,status) values
 ('72000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000002',
  'individualScholar','Applicant','متقدم','applicant@example.invalid','111','science','khobar',
  26,50,'https://www.youtube.com/@old','old','approved');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"71000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is(public.save_broadcaster_profile(
    '72000000-0000-4000-8000-000000000001',
    '{"phone":"222","youtube_channel_url":"https://www.youtube.com/@new","youtube_handle":"new"}')
    ->>'status','pending','sensitive edit creates one pending revision');
select throws_ok($$update public.broadcaster_applications
    set queue_archived_at=now() where revision_of='72000000-0000-4000-8000-000000000001'$$,
    '42501',null,'applicant cannot remove a pending review from the queue');

select set_config('request.jwt.claims',
  '{"sub":"71000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
with deleted as (delete from public.broadcaster_applications
  where id='72000000-0000-4000-8000-000000000001' returning id)
select is((select count(*)::int from deleted),0,
  'admin cannot physically delete an approved application');
update public.broadcaster_applications set status='approved',
  admin_review_notes='Reviewed edit',reviewed_by=auth.uid(),reviewed_at=now()
  where revision_of='72000000-0000-4000-8000-000000000001' and status='pending';
select is((select youtube_handle from public.profiles
  where id='71000000-0000-4000-8000-000000000002'),'new',
  'edit approval publishes its reviewed channel');
select is((select actor_name from public.application_review_events
  where action='approved' order by event_order desc limit 1),'Review Admin',
  'audit stores the acting administrator name');
select public.reverse_approved_application((select id from public.application_review_events
  where action='approved' and application_id in
    (select id from public.broadcaster_applications
     where revision_of='72000000-0000-4000-8000-000000000001')
  order by event_order desc limit 1),'Wrong approval');
select ok((select is_streamer and is_verified and youtube_handle='old'
  from public.profiles where id='71000000-0000-4000-8000-000000000002'),
  'reversing edit approval restores public data and retains broadcaster role');
select is((select phone from public.broadcaster_applications
  where id='72000000-0000-4000-8000-000000000001'),'111',
  'reversing edit approval restores reviewed base fields');
select set_config('request.jwt.claims',
  '{"sub":"71000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select public.save_broadcaster_profile('72000000-0000-4000-8000-000000000001',
  '{"phone":"444"}');
select set_config('request.jwt.claims',
  '{"sub":"71000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
update public.broadcaster_applications set queue_archived_at=now()
  where revision_of='72000000-0000-4000-8000-000000000001' and status='pending';
select set_config('request.jwt.claims',
  '{"sub":"71000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select public.save_broadcaster_profile('72000000-0000-4000-8000-000000000001',
  '{"phone":"555"}');
select is((select count(*)::int from public.broadcaster_applications
  where revision_of='72000000-0000-4000-8000-000000000001'
    and status='pending' and queue_archived_at is null),1,
  'a removed pending edit does not block the next edit');
select set_config('request.jwt.claims',
  '{"sub":"71000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
update public.broadcaster_applications set queue_archived_at=now()
  where id='72000000-0000-4000-8000-000000000001';
select ok((select is_streamer and is_verified from public.profiles
  where id='71000000-0000-4000-8000-000000000002'),
  'removing an approved queue entry preserves account approval');
select is((select count(*)::int from public.application_review_events
  where action='removed' and application_id='72000000-0000-4000-8000-000000000001'),1,
  'queue removal remains visible in the action log');

insert into public.broadcaster_applications(id,applicant_profile_id,account_type,
    applicant_name_en,applicant_name_ar,email,phone,category_id,city_id,
    latitude,longitude,youtube_channel_url,youtube_handle,status) values
 ('72000000-0000-4000-8000-000000000002','71000000-0000-4000-8000-000000000003',
  'individualScholar','New applicant','متقدم جديد','newapplicant@example.invalid','333','science','khobar',
  26,50,'https://www.youtube.com/@new','new','pending');
update public.broadcaster_applications set status='approved',reviewed_by=auth.uid()
  where id='72000000-0000-4000-8000-000000000002';
select ok((select is_streamer and is_verified from public.profiles
  where id='71000000-0000-4000-8000-000000000003'),
  'initial approval grants broadcaster role in the review transaction');
select public.reverse_approved_application((select id from public.application_review_events
  where application_id='72000000-0000-4000-8000-000000000002'
    and action='approved' order by event_order desc limit 1),'Wrong applicant');
select ok((select not is_streamer and not is_verified from public.profiles
  where id='71000000-0000-4000-8000-000000000003'),
  'reversing initial approval removes only that account approval');
select ok((select is_streamer and is_verified from public.profiles
  where id='71000000-0000-4000-8000-000000000002'),
  'another approved broadcaster remains verified');

select * from finish();
rollback;
