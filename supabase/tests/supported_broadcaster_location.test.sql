begin;
select no_plan();
insert into auth.users(id,email) values
 ('a9000000-0000-4000-8000-000000000001','map-owner@example.invalid');
insert into public.profiles(id,is_streamer,is_verified,email) values
 ('a9000000-0000-4000-8000-000000000001',true,true,'map-owner@example.invalid');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a9000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok($$insert into public.broadcaster_applications
 (applicant_profile_id,account_type,applicant_name_en,applicant_name_ar,email,phone,category_id,latitude,longitude)
 values(auth.uid(),'individualScholar','Map','Map','map-owner@example.invalid','123','science',27,50.1)$$,
 '22023',null,'an out-of-map application is rejected');
select throws_ok($$insert into public.broadcaster_applications
 (applicant_profile_id,account_type,applicant_name_en,applicant_name_ar,email,phone,category_id)
 values(auth.uid(),'individualScholar','Map','Map','map-owner@example.invalid','123','science')$$,
 '22023',null,'an unpinned application is rejected');
insert into public.broadcaster_applications
 (id,applicant_profile_id,account_type,applicant_name_en,applicant_name_ar,email,phone,category_id,city_id,latitude,longitude,status)
 values('b9000000-0000-4000-8000-000000000001',auth.uid(),'individualScholar','Map','Map','map-owner@example.invalid','123','science','other',26.72,50.35,'pending');
select ok((select latitude=26.72 and longitude=50.35 from public.broadcaster_applications
 where id='b9000000-0000-4000-8000-000000000001'),
 'point inside map but outside three-city core is retained exactly');
select throws_ok($$update public.broadcaster_applications set longitude=50.44
 where id='b9000000-0000-4000-8000-000000000001'$$,
 '22023',null,'pending applicant cannot move outside map');
select ok((select longitude=50.35 from public.broadcaster_applications
 where id='b9000000-0000-4000-8000-000000000001'),
 'rejected move leaves saved point intact');
reset role;
update public.broadcaster_applications set status='approved'
 where id='b9000000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($$select public.save_broadcaster_profile('b9000000-0000-4000-8000-000000000001',
 '{"latitude":26.79}')$$,'22023',null,'approved profile edit cannot request out-of-map point');
select is(public.save_broadcaster_profile('b9000000-0000-4000-8000-000000000001',
 '{"bio_en":"Safe edit"}')->>'status','approved','unrelated descriptive edit still works');
select * from finish();
rollback;
