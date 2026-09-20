-- Local-only pgTAP acceptance for P1.1. Never run against a linked project.
-- UNVERIFIED-STATIC until executed using the local Supabase test runner.
begin;
select plan(9);

insert into auth.users (id, email) values
 ('10000000-0000-4000-8000-000000000001', 'viewer@example.invalid'),
 ('10000000-0000-4000-8000-000000000002', 'admin@example.invalid');
insert into public.profiles (id) values ('10000000-0000-4000-8000-000000000002');
insert into public.user_roles (profile_id, role)
values ('10000000-0000-4000-8000-000000000002', 'admin');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
insert into public.profiles (id, is_streamer, is_verified, is_currently_live, active_stream_id, follower_count)
values ('10000000-0000-4000-8000-000000000001', true, true, true, 'victim12345A', 999);
select ok((select not is_streamer and not is_verified and not is_currently_live and active_stream_id is null and follower_count = 0
 from public.profiles where id = auth.uid()), 'A2 forged profile INSERT is neutralized');
update public.profiles set is_streamer = true, is_verified = true, follower_count = 999,
 is_currently_live = true, active_stream_id = 'victim12345A', active_viewer_count = 999,
 broadcast_type = 'liveVideo', bio_en = 'Updated bio', youtube_handle = '@lecture'
where id = auth.uid();
select ok((select not is_streamer and not is_verified and follower_count = 0
 from public.profiles where id = auth.uid()), 'A1 self-elevation UPDATE is neutralized');
select ok((select not is_currently_live and active_stream_id is null and active_viewer_count = 0 and broadcast_type = 'offline'
 from public.profiles where id = auth.uid()), 'A3 cannot claim a victim stream');
select is((select bio_en from public.profiles where id = auth.uid()), 'Updated bio', 'P1 bio remains editable');
select is((select youtube_handle from public.profiles where id = auth.uid()), '@lecture', 'P1 handle remains editable');

select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
update public.profiles set is_streamer = true, is_verified = true
where id = '10000000-0000-4000-8000-000000000001';
select ok((select is_streamer and is_verified from public.profiles
 where id = '10000000-0000-4000-8000-000000000001'), 'P2 admin approval still writes privileges');
insert into public.organizations (id, owner_profile_id, name_en, name_ar)
values ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Lecture', 'Lecture');

select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
update public.organizations set is_verified = true, is_currently_live = true,
 active_stream_id = 'victim12345A', follower_count = 999, bio_en = 'Org bio',
 owner_profile_id = '10000000-0000-4000-8000-000000000002'
where id = '20000000-0000-4000-8000-000000000001';
select ok((select not is_verified and not is_currently_live and active_stream_id is null and follower_count = 0
 from public.organizations where id = '20000000-0000-4000-8000-000000000001'), 'Org owner cannot forge approval/live/counts');
select is((select owner_profile_id::text from public.organizations where id = '20000000-0000-4000-8000-000000000001'),
 '10000000-0000-4000-8000-000000000001', 'Ownership cannot be reassigned through profile editing');
select is((select bio_en from public.organizations where id = '20000000-0000-4000-8000-000000000001'), 'Org bio', 'Org bio remains editable');
reset role;
select * from finish();
rollback;
