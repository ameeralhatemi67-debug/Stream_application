-- Fresh local SQL: publish only the approving applicant's explicit venue.
begin;
select no_plan();
insert into auth.users(id,email) values
 ('39000000-0000-4000-8000-000000000011','org-location@example.invalid'),
 ('39000000-0000-4000-8000-000000000012','other-location@example.invalid');
insert into public.profiles(id) values
 ('39000000-0000-4000-8000-000000000011'), ('39000000-0000-4000-8000-000000000012');
insert into public.broadcaster_applications(id, applicant_profile_id, account_type,
 applicant_name_en, applicant_name_ar, email, phone, category_id, status,
 city_id, venue_name_en, venue_name_ar, latitude, longitude) values
 ('59000000-0000-4000-8000-000000000011','39000000-0000-4000-8000-000000000011',
 'organizationVenue','Org','Org','org-location@example.invalid','','education','approved',
 'dammam','Exact venue','Exact venue',26.4301234,50.1004321);
insert into public.organizations(id,owner_profile_id,name_en,name_ar,approved_application_id) values
 ('69000000-0000-4000-8000-000000000011','39000000-0000-4000-8000-000000000011','Org','Org','59000000-0000-4000-8000-000000000011'),
 ('69000000-0000-4000-8000-000000000012','39000000-0000-4000-8000-000000000012','Legacy','Legacy',null);
insert into public.org_venues(organization_id,name_en,name_ar,city_en,city_ar,latitude,longitude,is_main_headquarters)
values ('69000000-0000-4000-8000-000000000012','Private branch','Private branch','Dhahran','Dhahran',26.310789,50.140123,true);
set local role anon;
select ok((select city_id='dammam' and latitude=26.4301234 and longitude=50.1004321 and venue_name_en='Exact venue'
 from public.organization_public_profiles where id='69000000-0000-4000-8000-000000000011'), 'approved public point reloads exactly');
select ok((select latitude is null and longitude is null and city_id is null
 from public.organization_public_profiles where id='69000000-0000-4000-8000-000000000012'), 'unknown organization never borrows private headquarters');
reset role;
-- Owner may update its organization, but cannot publish another owner's application.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"39000000-0000-4000-8000-000000000012","role":"authenticated"}',true);
update public.organizations set approved_application_id='59000000-0000-4000-8000-000000000011' where id='69000000-0000-4000-8000-000000000012';
reset role;
set local role anon;
select ok((select latitude is null from public.organization_public_profiles where id='69000000-0000-4000-8000-000000000012'), 'foreign application reference exposes no location');
reset role;
update public.broadcaster_applications set status='pending' where id='59000000-0000-4000-8000-000000000011';
select ok((select latitude is null from public.organization_public_profiles where id='69000000-0000-4000-8000-000000000011'), 'pending application exposes no location');
update public.broadcaster_applications set status='approved',account_type='individualScholar' where id='59000000-0000-4000-8000-000000000011';
select ok((select latitude is null from public.organization_public_profiles where id='69000000-0000-4000-8000-000000000011'), 'individual application cannot stand in for organization venue');
update public.broadcaster_applications set account_type='organizationVenue',latitude=0,longitude=0 where id='59000000-0000-4000-8000-000000000011';
select ok((select latitude=0 and longitude=0 from public.organization_public_profiles where id='69000000-0000-4000-8000-000000000011'), 'unpinned organization stays unpinned');
select ok((select latitude=26.310789 and longitude=50.140123 from public.org_venues where organization_id='69000000-0000-4000-8000-000000000012'), 'legitimate private venue coordinates unchanged');
select * from finish();
rollback;
