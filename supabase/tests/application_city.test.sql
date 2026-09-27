-- Disposable local fixture: city edits must round-trip without relocating pins
-- or weakening application RLS. No legacy data backfill is performed.
begin;
select plan(6);
insert into auth.users (id, email) values
 ('39000000-0000-4000-8000-000000000001', 'city-owner@example.invalid'),
 ('39000000-0000-4000-8000-000000000002', 'city-stranger@example.invalid');
insert into public.profiles (id) values
 ('39000000-0000-4000-8000-000000000001'),
 ('39000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"39000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
insert into public.broadcaster_applications (id, applicant_profile_id, account_type,
 applicant_name_en, applicant_name_ar, email, phone, category_id, city_id, latitude, longitude)
values ('59000000-0000-4000-8000-000000000001', auth.uid(), 'individualScholar',
 'Fixture', 'Fixture', 'city-owner@example.invalid', '', 'education', 'khobar', 26.304212, 50.146278);
select is((select city_id from public.broadcaster_applications where id='59000000-0000-4000-8000-000000000001'), 'khobar', 'selected city round-trips');
update public.broadcaster_applications set city_id='dhahran' where id='59000000-0000-4000-8000-000000000001';
select is((select city_id from public.broadcaster_applications where id='59000000-0000-4000-8000-000000000001'), 'dhahran', 'pending owner can correct city');
select ok((select latitude=26.304212 and longitude=50.146278 from public.broadcaster_applications where id='59000000-0000-4000-8000-000000000001'), 'city selection preserves exact pin');
select set_config('request.jwt.claims', '{"sub":"39000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
update public.broadcaster_applications set city_id='dammam' where id='59000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claims', '{"sub":"39000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is((select city_id from public.broadcaster_applications where id='59000000-0000-4000-8000-000000000001'), 'dhahran', 'stranger cannot rewrite city');
select throws_ok($$update public.broadcaster_applications set city_id='invented-city' where id='59000000-0000-4000-8000-000000000001'$$, '23514', null, 'unsupported city identifier rejected');
update public.broadcaster_applications set city_id=null where id='59000000-0000-4000-8000-000000000001';
select ok((select city_id is null and latitude=26.304212 and longitude=50.146278 from public.broadcaster_applications where id='59000000-0000-4000-8000-000000000001'), 'unknown legacy city remains unknown without losing its pin');
select * from finish();
rollback;
