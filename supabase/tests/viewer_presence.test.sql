-- Local-only pgTAP acceptance for P3 / 05 D-08 (viewer presence).
-- UNVERIFIED-STATIC until executed on local Supabase.
begin;
select plan(14);

insert into auth.users (id, email) values
 ('80000000-0000-4000-8000-000000000001', 'broadcaster@example.invalid'),
 ('80000000-0000-4000-8000-000000000002', 'viewer@example.invalid');
insert into public.profiles (id, email, display_name_en, is_streamer, is_verified) values
 ('80000000-0000-4000-8000-000000000001', 'broadcaster@example.invalid', 'Caster', true, true),
 ('80000000-0000-4000-8000-000000000002', 'viewer@example.invalid', 'Viewer', false, false);

-- The presence table is deny-all: RLS on, no policy, nothing granted.
select ok((select relrowsecurity from pg_class where oid = 'public.stream_viewers'::regclass),
 'stream_viewers has RLS enabled');
select is((select count(*)::int from pg_policies
 where schemaname = 'public' and tablename = 'stream_viewers'), 0,
 'stream_viewers has no policy at all (deny-all by design)');

-- Nothing is countable before anyone is broadcasting.
select is((select viewer_count from public.get_viewer_counts(array['80000000-0000-4000-8000-000000000041'])), 0,
 'A stream nobody watches counts 0');
select ok(not public.viewer_heartbeat('80000000-0000-4000-8000-000000000041', 'guest-key-0001'),
 'A heartbeat for a stream nobody is broadcasting is refused');

-- The broadcaster goes live from a primary device.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"80000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select ok(public.claim_broadcaster_device('CAST-1', 'Phone', 'android'), 'Broadcaster claims its device');
reset role;
-- LIVE is a provider-confirmed broadcast session (20261001111022) and presence
-- is keyed by that session's id (20261001114055); clients cannot assert it.
insert into public.broadcast_sessions (id, owner_id, device_id, stream_id, broadcast_type, sender_mode, state, started_at, accepted_at)
values ('80000000-0000-4000-8000-000000000041', '80000000-0000-4000-8000-000000000001', 'CAST-1', 'abcdefghijk',
 'liveVideo', 'phone_direct', 'live', now(), now());
select ok((select is_currently_live from public.profiles where id = '80000000-0000-4000-8000-000000000001'), 'Broadcaster goes live');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"80000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
-- Watching your own stream does not add to your own audience.
select ok(not public.viewer_heartbeat('80000000-0000-4000-8000-000000000041', 'anything-at-all'),
 'The broadcaster is not counted in their own audience');
reset role;

-- A guest and a signed-in viewer each count once.
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select ok(public.viewer_heartbeat('80000000-0000-4000-8000-000000000041', 'guest-install-uuid-1'), 'A guest heartbeat is accepted');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"80000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select ok(public.viewer_heartbeat('80000000-0000-4000-8000-000000000041', 'some-other-key-entirely'),
 'A signed-in viewer heartbeat is accepted');
-- The same person on a second device sends a different key; the server keys
-- them by user id, so they stay one viewer.
select ok(public.viewer_heartbeat('80000000-0000-4000-8000-000000000041', 'second-device-key-xyz'),
 'The same account heartbeating from a second device is accepted');
reset role;
select is((select viewer_count from public.get_viewer_counts(array['80000000-0000-4000-8000-000000000041'])), 2,
 'Guest + signed-in viewer (two devices) count as 2, not 3');

-- Presence expires after the 45-second window.
update public.stream_viewers set last_seen = now() - interval '2 minutes';
select is((select viewer_count from public.get_viewer_counts(array['80000000-0000-4000-8000-000000000041'])), 0,
 'Presence older than the 45s window stops counting');

-- 06 A12: direct table access is denied to clients even though the RPCs work.
-- 20260921110000 revoked every table privilege on stream_viewers from anon and
-- authenticated, so the denial now arrives as 42501 before RLS is consulted
-- rather than as an empty result set. That is the stronger of the two
-- outcomes, so these assert the throw instead of a zero count.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"80000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select throws_ok($$select count(*) from public.stream_viewers$$, '42501', null,
 'A12 a signed-in client cannot select presence rows directly');
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$select count(*) from public.stream_viewers$$, '42501', null,
 'A12 anon cannot select presence rows directly');
reset role;

select * from finish();
rollback;
