-- Local-only pgTAP. UNVERIFIED-STATIC until run against local Supabase.
begin;
select plan(7);

-- NOTE ON THE TWO DELETE ASSERTIONS. The storage schema installs a
-- `protect_objects_delete` trigger that raises on ANY direct
-- `delete from storage.objects` ("Use the Storage API instead"), before
-- row-level security is consulted -- so a direct DELETE can never reach, and
-- therefore never test, the RLS policy. It cannot be disabled from here
-- either: storage.objects is owned by supabase_storage_admin and `postgres`
-- is not a member of that role. Real deletes go through the Storage API, which
-- applies streamer_assets_delete_owner on the caller's behalf. So the two
-- deletion cases below assert the predicate that policy is built from,
-- `can_write_streamer_asset(name)`, for a foreign and an owned namespace.

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
select ok(not public.can_write_streamer_asset('10000000-0000-4000-8000-000000000002/banner.png'),
 'A4 deleting another user''s object is not authorized');
select ok(not public.can_write_streamer_asset('org/not-a-uuid/banner.png'), 'Malformed org prefix denies without cast error');
select ok(not public.can_write_streamer_asset('applications/legacy.png'), 'Legacy flat objects are read-only to ordinary callers');
select ok(public.can_write_streamer_asset('10000000-0000-4000-8000-000000000001/banner.png'),
 'Deleting an object in the caller''s own namespace is authorized');
reset role;
select * from finish();
rollback;
