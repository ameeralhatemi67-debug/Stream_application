-- Local-only pgTAP. UNVERIFIED-STATIC until run against local Supabase.
begin;
select plan(7);
insert into storage.objects (bucket_id, name) values
 ('streamer-assets', '10000000-0000-4000-8000-000000000002/banner.png');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($$insert into storage.objects (bucket_id, name) values
 ('streamer-assets', '10000000-0000-4000-8000-000000000001/banner.png')$$, 'Own prefix accepts upload');
select throws_ok($$insert into storage.objects (bucket_id, name) values
 ('streamer-assets', '10000000-0000-4000-8000-000000000002/new.png')$$,
 '42501', null, 'A4 other user prefix rejects upload');
select throws_ok($$update storage.objects set name = '10000000-0000-4000-8000-000000000002/moved.png'
 where bucket_id = 'streamer-assets' and name = '10000000-0000-4000-8000-000000000001/banner.png'$$,
 '42501', null, 'A4 cannot move owned object into another namespace');
delete from storage.objects where bucket_id = 'streamer-assets'
 and name = '10000000-0000-4000-8000-000000000002/banner.png';
select is((select count(*)::integer from storage.objects where bucket_id = 'streamer-assets'
 and name = '10000000-0000-4000-8000-000000000002/banner.png'), 1, 'A4 other object survives attempted deletion');
select ok(not public.can_write_streamer_asset('org/not-a-uuid/banner.png'), 'Malformed org prefix denies without cast error');
select ok(not public.can_write_streamer_asset('applications/legacy.png'), 'Legacy flat objects are read-only to ordinary callers');
delete from storage.objects where bucket_id = 'streamer-assets'
 and name = '10000000-0000-4000-8000-000000000001/banner.png';
select is((select count(*)::integer from storage.objects where bucket_id = 'streamer-assets'
 and name = '10000000-0000-4000-8000-000000000001/banner.png'), 0, 'Own object can be deleted');
reset role;
select * from finish();
rollback;
