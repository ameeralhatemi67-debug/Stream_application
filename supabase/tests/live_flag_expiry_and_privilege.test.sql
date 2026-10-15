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

-- 3. Live expiry. LIVE is provider-confirmed (20261001111022): A reserves a
-- personal session from its primary phone and the provider worker confirms it.
-- The sweep now ends a phone sender whose own encoder reported the feed
-- interrupted for more than 120 s (ingest_lost); a fresh feed survives it.
-- (A heartbeat-only expiry no longer exists: OBS is observed through YouTube,
-- see organization_v1_sessions.test.sql.)
update public.profiles set personal_broadcast_approved = true
 where id = '60000000-0000-4000-8000-000000000001';
insert into auth.sessions (id, user_id)
 values ('60000000-0000-4000-8000-000000000011', '60000000-0000-4000-8000-000000000001');
insert into public.channel_connections (id, owner_profile_id, youtube_channel_id, channel_title)
 values ('60000000-0000-4000-8000-000000000021', '60000000-0000-4000-8000-000000000001',
  'UCeeeeeeeeeeeeeeeeeeeeee', 'Expiry');
create temporary table ids(k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.confirm_live(p_id uuid, p_watch text) returns void language plpgsql as $$
declare v_token uuid;
begin
  select operation_token into v_token from private.broadcast_provider where session_id = p_id;
  perform public.broadcast_provider_step(p_id, v_token, 'stream_create',
    jsonb_build_object('id', 'feed-' || p_id, 'url', 'rtmps://a.rtmps.youtube.com/live2', 'key', 'fake-ingest'));
  perform public.broadcast_provider_step(p_id, v_token, 'broadcast_create', jsonb_build_object('id', p_watch));
  perform public.broadcast_provider_step(p_id, v_token, 'bind', '{}');
  perform public.broadcast_provider_step(p_id, v_token, 'observe', '{"status":"live"}');
  perform public.broadcast_provider_step(p_id, v_token, 'finish');
end $$;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"60000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"60000000-0000-4000-8000-000000000011"}', true);
select ok(public.claim_broadcaster_device('DEV-A', 'Phone A', 'android'), 'A claims its primary device');
insert into ids select 's1', public.broadcast_create_personal('First', 'liveVideo');
select public.broadcast_reserve_confirmed((select v from ids where k = 's1'), 'DEV-A', 'phone_direct', 'prepare',
 '60000000-0000-4000-8000-000000000021', 1);
reset role;
select pg_temp.confirm_live((select v from ids where k = 's1'), 'abcdefghijk');
select ok((select is_currently_live from public.profiles where id = '60000000-0000-4000-8000-000000000001'), 'A goes live');
set local role authenticated;
select public.report_broadcast_ingest((select v from ids where k = 's1'), 'DEV-A', 'interrupted');
reset role;
select is(public.sweep_stale_live_flags(), 0, 'A feed interrupted for under 120 s is not swept');
update public.broadcast_sessions set interrupted_since = now() - interval '121 seconds'
 where id = (select v from ids where k = 's1');
select is(public.sweep_stale_live_flags(), 1, 'A phone feed interrupted for over 120 s is swept');
select ok((select not is_currently_live and active_stream_id is null
 from public.profiles where id = '60000000-0000-4000-8000-000000000001')
 and (select end_reason = 'ingest_lost' from public.broadcast_sessions where id = (select v from ids where k = 's1')),
 'Swept broadcaster is no longer live');
select is(public.sweep_stale_live_flags(), 0, 'Sweeping again clears nothing (idempotent)');

-- 4. Ending a broadcast must work even when the heartbeat has lapsed: a
-- broadcaster whose phone slept can still switch itself off. Starting one
-- must not.
-- The provider worker completes termination of the swept broadcast.
update public.broadcast_sessions set state = 'completed', termination_pending = false, ended_at = now()
 where id = (select v from ids where k = 's1');
set local role authenticated;
insert into ids select 's2', public.broadcast_create_personal('Second', 'liveVideo');
select public.broadcast_reserve_confirmed((select v from ids where k = 's2'), 'DEV-A', 'phone_direct', 'prepare',
 '60000000-0000-4000-8000-000000000021', 1);
reset role;
select pg_temp.confirm_live((select v from ids where k = 's2'), 'abcdefghij2');
select ok((select state = 'live' from public.broadcast_sessions where id = (select v from ids where k = 's2')), 'A goes live again');
update public.device_sessions set last_active_at = now() - interval '5 minutes'
 where user_id = '60000000-0000-4000-8000-000000000001';
set local role authenticated;
select lives_ok($$select public.end_broadcast_session((select v from ids where k = 's2'), 'DEV-A')$$,
 'A stale primary device can still END its own broadcast');
insert into ids select 's3', public.broadcast_create_personal('Third', 'liveVideo', now() + interval '2 hours');
reset role;
update public.broadcast_sessions set state = 'completed', termination_pending = false, ended_at = now()
 where id = (select v from ids where k = 's2');
update public.broadcast_sessions set scheduled_start_at = now(), expected_end_at = now() + interval '1 hour'
 where id = (select v from ids where k = 's3');
set local role authenticated;
select throws_ok($$select public.broadcast_reserve_confirmed((select v from ids where k = 's3'), 'DEV-A', 'phone_direct', 'prepare',
 '60000000-0000-4000-8000-000000000021', 1)$$,
 '42501', 'Assigned primary presenter required', 'A stale primary device cannot START a broadcast');
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
