-- Local-only pgTAP acceptance for P1c: the missing is_banned() helper, the
-- server-side live-flag expiry, and the privilege guards on
-- bootstrap_admin_role()/log_audit_event().
-- UNVERIFIED-STATIC until executed on local Supabase.
begin;
select plan(18);

-- Users: A broadcasts, B is banned, C is an impostor claiming an admin email.
insert into auth.users (id, email) values
 ('60000000-0000-4000-8000-000000000001', 'live.a@example.invalid'),
 ('60000000-0000-4000-8000-000000000002', 'banned.b@example.invalid'),
 ('60000000-0000-4000-8000-000000000003', 'impostor.c@example.invalid');
insert into public.profiles (id, email, display_name_en, is_streamer, is_verified) values
 ('60000000-0000-4000-8000-000000000001', 'live.a@example.invalid', 'A', true, true),
 ('60000000-0000-4000-8000-000000000002', 'banned.b@example.invalid', 'B', true, true);

-- 1. The helper every broadcast RPC calls must exist with that exact signature.
select has_function('public', 'is_banned', array['uuid'],
 'is_banned(uuid) exists -- guarded_broadcast_sessions depends on it');
select ok(not public.is_banned('60000000-0000-4000-8000-000000000002'),
 'Not banned before a ban row exists');
insert into public.banned_users (profile_id, email, reason)
 values ('60000000-0000-4000-8000-000000000002', 'banned.b@example.invalid', 'Test ban');
select ok(public.is_banned('60000000-0000-4000-8000-000000000002'), 'Active ban reads as banned');
update public.banned_users set expires_at = now() - interval '1 hour'
 where profile_id = '60000000-0000-4000-8000-000000000002';
select ok(not public.is_banned('60000000-0000-4000-8000-000000000002'), 'Expired ban does not count');
select ok(not public.is_banned(null), 'A null profile id is not banned');

-- 2. is_banned is not exposed to clients (no per-uuid ban probe).
select ok(not has_function_privilege('authenticated', 'public.is_banned(uuid)', 'execute'),
 'authenticated cannot execute is_banned(uuid) directly');
select ok(not has_function_privilege('anon', 'public.is_banned(uuid)', 'execute'),
 'anon cannot execute is_banned(uuid) directly');

-- 3. Live-flag expiry: A goes live from a primary device, then that device
-- goes silent. The sweep clears the flag; a device still beating survives it.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"60000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select ok(public.claim_broadcaster_device('DEV-A', 'Phone A', 'android'), 'A claims its primary device');
select lives_ok($$select public.set_live_state(true,'liveVideo','abcdefghijk','DEV-A')$$, 'A goes live');
reset role;
select is(public.sweep_stale_live_flags(), 0, 'A fresh heartbeat is not swept');
update public.device_sessions set last_active_at = now() - interval '5 minutes'
 where user_id = '60000000-0000-4000-8000-000000000001';
select is(public.sweep_stale_live_flags(), 1, 'A silent primary device is swept');
select ok((select not is_currently_live and active_stream_id is null
 from public.profiles where id = '60000000-0000-4000-8000-000000000001'),
 'Swept broadcaster is no longer live');
select is(public.sweep_stale_live_flags(), 0, 'Sweeping again clears nothing (idempotent)');

-- 4. Ending a broadcast must work even when the heartbeat has lapsed: a
-- broadcaster whose phone slept can still switch itself off. Starting one
-- must not.
update public.device_sessions set last_active_at = now()
 where user_id = '60000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"60000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($$select public.set_live_state(true,'liveVideo','abcdefghijk','DEV-A')$$, 'A goes live again');
reset role;
update public.device_sessions set last_active_at = now() - interval '5 minutes'
 where user_id = '60000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"60000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($$select public.set_live_state(false,'offline',null,'DEV-A')$$,
 'A stale primary device can still END its own broadcast');
select throws_ok($$select public.set_live_state(true,'liveVideo','abcdefghijk','DEV-A')$$,
 '42501', 'Primary device required', 'A stale primary device cannot START a broadcast');
reset role;

-- 5. A banned account cannot append to the audit log.
update public.banned_users set expires_at = null
 where profile_id = '60000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"60000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select throws_ok($$select public.log_audit_event(null,'test.action','en','ar')$$,
 '42501', 'Not permitted', 'Banned account cannot write an audit event');
reset role;

-- 6. bootstrap_admin_role only trusts the address Supabase Auth verified for
-- that user id, not whatever the profiles row claims.
insert into public.profiles (id, email, display_name_en)
 values ('60000000-0000-4000-8000-000000000003', 'polkgvd2@gmail.com', 'Impostor');
select is((select count(*)::int from public.user_roles
 where profile_id = '60000000-0000-4000-8000-000000000003' and role = 'master_admin'), 0,
 'A profile row claiming an admin email does not grant master_admin');

select * from finish();
rollback;
