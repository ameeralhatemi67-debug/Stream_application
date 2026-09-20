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
-- something for this stream id.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select ok(public.claim_broadcaster_device('CAST-9', 'Phone', 'android'), 'Broadcaster claims a device');
select lives_ok($$select public.set_live_state(true,'liveVideo','chatstream1','CAST-9')$$, 'Broadcaster goes live');
reset role;

-- A viewer can send one message, but not two in the same instant.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select lives_ok($$insert into public.chat_messages (stream_id, sender_id, body)
 values ('chatstream1', '90000000-0000-4000-8000-000000000002', 'Hello')$$,
 'A first message is accepted');
select throws_ok($$insert into public.chat_messages (stream_id, sender_id, body)
 values ('chatstream1', '90000000-0000-4000-8000-000000000002', 'Hello again')$$,
 '42501', 'Sending too fast', 'A second message inside 1.2 s is refused');
reset role;

-- Thirty messages in a minute is the ceiling.
update public.chat_messages set created_at = now() - interval '5 seconds'
 where stream_id = 'chatstream1';
insert into public.chat_messages (stream_id, sender_id, body, created_at)
 select 'chatstream1', '90000000-0000-4000-8000-000000000002', 'filler ' || g,
        now() - interval '4 seconds'
   from generate_series(1, 29) as g;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select throws_ok($$insert into public.chat_messages (stream_id, sender_id, body)
 values ('chatstream1', '90000000-0000-4000-8000-000000000002', 'thirty-first')$$,
 '42501', 'Too many messages in one minute', 'The 31st message in a minute is refused');
reset role;
delete from public.chat_messages where stream_id = 'chatstream1';

-- Only the stream's own moderator tier may write its settings.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select throws_ok($$insert into public.chat_stream_settings (stream_id, chat_enabled, updated_by)
 values ('chatstream1', false, '90000000-0000-4000-8000-000000000003')$$,
 '42501', null, 'A stranger cannot turn a stream''s chat off');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($$insert into public.chat_stream_settings (stream_id, chat_enabled, slow_mode_seconds, updated_by)
 values ('chatstream1', false, 30, '90000000-0000-4000-8000-000000000001')$$,
 'The broadcaster can turn its own chat off');
reset role;

-- Chat off: viewers refused, the broadcaster still gets through.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select throws_ok($$insert into public.chat_messages (stream_id, sender_id, body)
 values ('chatstream1', '90000000-0000-4000-8000-000000000002', 'anyone there?')$$,
 '42501', 'Chat is turned off for this stream', 'A viewer cannot post while chat is off');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($$insert into public.chat_messages (stream_id, sender_id, body)
 values ('chatstream1', '90000000-0000-4000-8000-000000000001', 'Chat is off, back shortly')$$,
 'The broadcaster can still post while chat is off');
reset role;

-- Slow mode applies to viewers, not to the broadcaster.
update public.chat_stream_settings set chat_enabled = true where stream_id = 'chatstream1';
delete from public.chat_messages where stream_id = 'chatstream1';
insert into public.chat_messages (stream_id, sender_id, body, created_at)
 values ('chatstream1', '90000000-0000-4000-8000-000000000002', 'earlier',
         now() - interval '5 seconds');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select throws_ok($$insert into public.chat_messages (stream_id, sender_id, body)
 values ('chatstream1', '90000000-0000-4000-8000-000000000002', 'too soon for 30s slow mode')$$,
 '42501', 'Sending too fast', 'Slow mode holds a viewer back for its full window');
reset role;

select * from finish();
rollback;
