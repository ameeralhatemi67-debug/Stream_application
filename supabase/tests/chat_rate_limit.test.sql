-- Local-only pgTAP acceptance for P6.1 (server-side chat enforcement).
-- UNVERIFIED-STATIC until executed on local Supabase.
begin;
select plan(11);

insert into auth.users (id, email) values
 ('90000000-0000-4000-8000-000000000001', 'caster@example.invalid'),
 ('90000000-0000-4000-8000-000000000002', 'chatter@example.invalid'),
 ('90000000-0000-4000-8000-000000000003', 'stranger@example.invalid');
insert into public.profiles (id, email, display_name_en, is_streamer, is_verified) values
 ('90000000-0000-4000-8000-000000000001', 'caster@example.invalid', 'Caster', true, true),
 ('90000000-0000-4000-8000-000000000002', 'chatter@example.invalid', 'Chatter', false, false),
 ('90000000-0000-4000-8000-000000000003', 'stranger@example.invalid', 'Stranger', false, false);

select has_table('public', 'chat_stream_settings', 'chat_stream_settings exists');

-- The broadcaster goes live so owns_stream()/chat_can_moderate() mean
-- something for this stream id. Chat rooms are keyed by the broadcast session
-- id and LIVE is provider-confirmed (20261001111022/20261001114055), so the
-- live session is the fixture; clients can no longer assert it themselves.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select ok(public.claim_broadcaster_device('CAST-9', 'Phone', 'android'), 'Broadcaster claims a device');
reset role;
insert into public.broadcast_sessions (id, owner_id, device_id, stream_id, broadcast_type, sender_mode, state, started_at, accepted_at)
values ('90000000-0000-4000-8000-000000000041', '90000000-0000-4000-8000-000000000001', 'CAST-9', 'CHATSTREAM1',
 'liveVideo', 'phone_direct', 'live', now(), now());
select ok((select is_currently_live from public.profiles where id = '90000000-0000-4000-8000-000000000001'), 'Broadcaster goes live');

-- A viewer can send one message, but not two in the same instant.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
-- Bodies deliberately avoid the seeded blocklist. 'Hello' cannot be used here:
-- chat_check_banned_keywords matches on bare substrings and the starter list
-- in 20260826090000 contains 'hell', so 'Hello' is rejected as profanity
-- before the rate limiter is ever reached. That substring behaviour is a real
-- defect, recorded as a P6 finding in brief/OWNER_ACTIONS.md -- it is not
-- what this file is testing, so these assertions route around it.
select lives_ok($$insert into public.chat_messages (stream_id, sender_id, body)
 values ('90000000-0000-4000-8000-000000000041', '90000000-0000-4000-8000-000000000002', 'Salaam')$$,
 'A first message is accepted');
select throws_ok($$insert into public.chat_messages (stream_id, sender_id, body)
 values ('90000000-0000-4000-8000-000000000041', '90000000-0000-4000-8000-000000000002', 'Salaam again')$$,
 '42501', 'Sending too fast', 'A second message inside 1.2 s is refused');
reset role;

-- Thirty messages in a minute is the ceiling.
update public.chat_messages set created_at = now() - interval '5 seconds'
 where stream_id = '90000000-0000-4000-8000-000000000041';
insert into public.chat_messages (stream_id, sender_id, body, created_at)
 select '90000000-0000-4000-8000-000000000041', '90000000-0000-4000-8000-000000000002', 'filler ' || g,
        now() - interval '4 seconds'
   from generate_series(1, 29) as g;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select throws_ok($$insert into public.chat_messages (stream_id, sender_id, body)
 values ('90000000-0000-4000-8000-000000000041', '90000000-0000-4000-8000-000000000002', 'thirty-first')$$,
 '42501', 'Too many messages in one minute', 'The 31st message in a minute is refused');
reset role;
delete from public.chat_messages where stream_id = '90000000-0000-4000-8000-000000000041';

-- Only the stream's own moderator tier may write its settings.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select throws_ok($$insert into public.chat_stream_settings (stream_id, chat_enabled, updated_by)
 values ('90000000-0000-4000-8000-000000000041', false, '90000000-0000-4000-8000-000000000003')$$,
 '42501', null, 'A stranger cannot turn a stream''s chat off');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($$insert into public.chat_stream_settings (stream_id, chat_enabled, slow_mode_seconds, updated_by)
 values ('90000000-0000-4000-8000-000000000041', false, 30, '90000000-0000-4000-8000-000000000001')$$,
 'The broadcaster can turn its own chat off');
reset role;

-- Chat off: viewers refused, the broadcaster still gets through.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select throws_ok($$insert into public.chat_messages (stream_id, sender_id, body)
 values ('90000000-0000-4000-8000-000000000041', '90000000-0000-4000-8000-000000000002', 'anyone there?')$$,
 '42501', 'Chat is turned off for this stream', 'A viewer cannot post while chat is off');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($$insert into public.chat_messages (stream_id, sender_id, body)
 values ('90000000-0000-4000-8000-000000000041', '90000000-0000-4000-8000-000000000001', 'Chat is off, back shortly')$$,
 'The broadcaster can still post while chat is off');
reset role;

-- Slow mode applies to viewers, not to the broadcaster.
update public.chat_stream_settings set chat_enabled = true where stream_id = '90000000-0000-4000-8000-000000000041';
delete from public.chat_messages where stream_id = '90000000-0000-4000-8000-000000000041';
insert into public.chat_messages (stream_id, sender_id, body, created_at)
 values ('90000000-0000-4000-8000-000000000041', '90000000-0000-4000-8000-000000000002', 'earlier',
         now() - interval '5 seconds');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select throws_ok($$insert into public.chat_messages (stream_id, sender_id, body)
 values ('90000000-0000-4000-8000-000000000041', '90000000-0000-4000-8000-000000000002', 'too soon for 30s slow mode')$$,
 '42501', 'Sending too fast', 'Slow mode holds a viewer back for its full window');
reset role;

select * from finish();
rollback;
