-- Local-only pgTAP acceptance for 05 D-07 (follows / bookmarks own-row RLS).
-- UNVERIFIED-STATIC until executed on local Supabase.
begin;
select plan(13);

insert into auth.users (id, email) values
 ('70000000-0000-4000-8000-000000000001', 'viewer.a@example.invalid'),
 ('70000000-0000-4000-8000-000000000002', 'viewer.b@example.invalid'),
 ('70000000-0000-4000-8000-000000000003', 'banned.c@example.invalid');
insert into public.profiles (id, email, display_name_en) values
 ('70000000-0000-4000-8000-000000000001', 'viewer.a@example.invalid', 'A'),
 ('70000000-0000-4000-8000-000000000002', 'viewer.b@example.invalid', 'B'),
 ('70000000-0000-4000-8000-000000000003', 'banned.c@example.invalid', 'C');

select has_table('public', 'follows', 'follows table exists');
select has_table('public', 'bookmarks', 'bookmarks table exists');

-- A follows a channel and saves a recording.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"70000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($$insert into public.follows (follower_profile_id, target_id)
 values ('70000000-0000-4000-8000-000000000001', 'channel-one')$$, 'A can follow a channel');
select lives_ok($$insert into public.bookmarks (profile_id, vod_id, streamer_id)
 values ('70000000-0000-4000-8000-000000000001', 'dQw4w9WgXcQ', 'channel-one')$$, 'A can save a recording');
select is((select count(*)::int from public.follows), 1, 'A sees its own follow');
select is((select count(*)::int from public.bookmarks), 1, 'A sees its own bookmark');

-- A cannot file rows under somebody else's account.
select throws_ok($$insert into public.follows (follower_profile_id, target_id)
 values ('70000000-0000-4000-8000-000000000002', 'channel-two')$$,
 '42501', null, 'A cannot follow on behalf of B');
reset role;

-- B sees none of A's rows and cannot delete them.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"70000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is((select count(*)::int from public.follows), 0, 'B cannot read A''s follows');
select is((select count(*)::int from public.bookmarks), 0, 'B cannot read A''s bookmarks');
delete from public.follows where target_id = 'channel-one';
reset role;
select is((select count(*)::int from public.follows where target_id = 'channel-one'), 1,
 'B''s delete removed nothing');

-- Anonymous readers get nothing at all.
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is((select count(*)::int from public.follows), 0, 'anon reads no follows');
reset role;

-- A banned account cannot add follows or bookmarks.
insert into public.banned_users (profile_id, email, reason)
 values ('70000000-0000-4000-8000-000000000003', 'banned.c@example.invalid', 'Test ban');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"70000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select throws_ok($$insert into public.follows (follower_profile_id, target_id)
 values ('70000000-0000-4000-8000-000000000003', 'channel-one')$$,
 '42501', null, 'A banned account cannot follow');
select throws_ok($$insert into public.bookmarks (profile_id, vod_id)
 values ('70000000-0000-4000-8000-000000000003', 'abc')$$,
 '42501', null, 'A banned account cannot bookmark');
reset role;

select * from finish();
rollback;
