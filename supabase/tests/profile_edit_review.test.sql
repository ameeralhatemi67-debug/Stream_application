begin;
select no_plan();
insert into auth.users(id,email) values
 ('69000000-0000-4000-8000-000000000001','editor@example.invalid'),
 ('69000000-0000-4000-8000-000000000002','stranger@example.invalid');
insert into public.profiles(id,is_streamer,is_verified,email,youtube_handle,latitude,longitude) values
 ('69000000-0000-4000-8000-000000000001',true,true,'editor@example.invalid','original',26,50),
 ('69000000-0000-4000-8000-000000000002',false,false,'stranger@example.invalid',null,null,null);
insert into public.broadcaster_applications(id,applicant_profile_id,account_type,applicant_name_en,applicant_name_ar,email,phone,category_id,tags,city_id,latitude,longitude,youtube_channel_url,youtube_handle,status)
 values('79000000-0000-4000-8000-000000000001','69000000-0000-4000-8000-000000000001','individualScholar','Original','Original','editor@example.invalid','123','science','{}','khobar',26,50,'https://www.youtube.com/@original','original','approved');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"69000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is(public.save_broadcaster_profile('79000000-0000-4000-8000-000000000001',
 '{"applicant_name_en":"Edited","bio_en":"New biography","academic_title_en":"Professor","institution_en":"College","tags":["#Physics"],"status":"approved","applicant_profile_id":"69000000-0000-4000-8000-000000000002"}') ->> 'status','approved','safe fields save without review; forged lifecycle/owner ignored');
select ok((select display_name_en='Edited' and bio_en='New biography' and title_en='Professor' and organization_en='College' and tags=array['#Physics'] and is_verified from public.profiles where id=auth.uid()),'safe edits publish while preserving verification');
select is((select count(*)::int from public.broadcaster_applications where status='pending'),0,'no unnecessary review');
-- Every sensitive field independently creates a pending request; reverting
-- removes only that pending revision. No approved application is overwritten.
do $$ declare field text; value jsonb; changes jsonb;
begin
 for field,value in select * from jsonb_each('{"email":"new@example.invalid","phone":"456","city_id":"dammam","latitude":26.4,"longitude":50.2,"venue_name_en":"New hall","venue_name_ar":"New hall","youtube_channel_url":"https://www.youtube.com/@new","youtube_handle":"new"}'::jsonb) loop
   changes := public.save_broadcaster_profile('79000000-0000-4000-8000-000000000001',jsonb_build_object(field,value));
   if changes->>'status' <> 'pending' then raise exception 'Sensitive field bypass: %',field; end if;
   perform public.save_broadcaster_profile('79000000-0000-4000-8000-000000000001','{}');
 end loop;
end $$;
select pass('all nine sensitive location/contact/channel columns require review');
select is(public.save_broadcaster_profile('79000000-0000-4000-8000-000000000001','{"phone":"456","youtube_channel_url":"https://www.youtube.com/@new","youtube_handle":"new"}')->>'status','pending','mixed sensitive change pending');
select is((select youtube_handle from public.profiles where id=auth.uid()),'original','pending channel never published');
update public.profiles set youtube_handle='bypass',latitude=5,email='bypass@example.invalid' where id=auth.uid();
select ok((select youtube_handle='original' and latitude=26 and email='editor@example.invalid' from public.profiles where id=auth.uid()),'direct table updates cannot bypass review');
select set_config('request.jwt.claims','{"sub":"69000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.save_broadcaster_profile('79000000-0000-4000-8000-000000000001','{}')$$,'42501',null,'stranger denied');
reset role;
update public.broadcaster_applications set status='rejected' where revision_of='79000000-0000-4000-8000-000000000001';
select ok((select is_verified and is_streamer and youtube_handle='original' from public.profiles where id='69000000-0000-4000-8000-000000000001'),'rejection preserves original verified channel');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"69000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select public.save_broadcaster_profile('79000000-0000-4000-8000-000000000001','{"email":"new@example.invalid","phone":"789","latitude":26.4,"youtube_channel_url":"https://www.youtube.com/@new","youtube_handle":"new"}');
select public.save_broadcaster_profile('79000000-0000-4000-8000-000000000001','{"email":"new@example.invalid","phone":"789","latitude":26.4,"youtube_channel_url":"https://www.youtube.com/@new","youtube_handle":"new"}');
select is((select count(*)::int from public.broadcaster_applications where revision_of is not null and status='pending'),1,'repeat save keeps one pending revision');
update public.broadcaster_applications set status='approved' where revision_of is not null and status='pending';
select is((select count(*)::int from public.broadcaster_applications where revision_of is not null and status='pending'),1,'owner cannot self-approve');
reset role;
update public.broadcaster_applications set status='approved',reviewed_at=now() where revision_of is not null and status='pending';
select ok((select is_verified and youtube_handle='new' and latitude=26.4 and email='new@example.invalid' from public.profiles where id='69000000-0000-4000-8000-000000000001'),'approval atomically publishes sensitive changes');
select is((select phone from public.broadcaster_applications where id='79000000-0000-4000-8000-000000000001'),'789','approved base stores reviewed phone');
-- Organization revisions update the existing organization, never create a duplicate.
insert into public.broadcaster_applications(id,applicant_profile_id,account_type,applicant_name_en,applicant_name_ar,email,phone,category_id,city_id,latitude,longitude,youtube_channel_url,youtube_handle,status)
 values('79000000-0000-4000-8000-000000000002','69000000-0000-4000-8000-000000000001','organizationVenue','Org','Org','org@example.invalid','123','science','khobar',26,50,'https://www.youtube.com/@org','org','approved');
insert into public.organizations(id,owner_profile_id,name_en,name_ar,is_verified,approved_application_id,youtube_handle)
 values('89000000-0000-4000-8000-000000000001','69000000-0000-4000-8000-000000000001','Org','Org',true,'79000000-0000-4000-8000-000000000002','org');
set local role authenticated;
select public.save_broadcaster_profile('79000000-0000-4000-8000-000000000002','{"applicant_name_en":"Updated org","latitude":26.45}');
select ok((select name_en='Updated org' and youtube_handle='org' from public.organizations where id='89000000-0000-4000-8000-000000000001'),'organization safe changes publish immediately');
reset role;
update public.broadcaster_applications set status='approved' where revision_of='79000000-0000-4000-8000-000000000002' and status='pending';
select is((select latitude from public.organization_public_profiles where id='89000000-0000-4000-8000-000000000001'),26.45::double precision,'organization approved public location updates');
select is((select count(*)::int from public.organizations where owner_profile_id='69000000-0000-4000-8000-000000000001'),1,'organization identity remains stable');
select * from finish();
rollback;
