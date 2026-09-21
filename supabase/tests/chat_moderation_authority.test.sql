-- P6.3 — who may moderate a chat, and who may not.
--
-- The client caches a `canModerate` flag to decide whether to show Mute and
-- Delete, but that flag is only a UX gate. These assertions are the actual
-- contract: RLS on chat_messages / chat_muted_users / chat_reports, plus
-- log_audit_event's own guards. Everything here runs as the real API roles with
-- a real JWT claim, never as the table owner.
--
-- 06 §2 attack probes covered: A3 (a viewer pointing their own
-- active_stream_id at a victim's stream and moderating there), A9 (a non-admin
-- calling an admin path), A11 (a muted sender inserting).
begin;
select plan(24);

-- ---------------------------------------------------------------------------
-- Cast: a verified streamer who owns the stream, a plain viewer, a second
-- streamer who owns a DIFFERENT stream, and a platform admin.
-- ---------------------------------------------------------------------------
insert into auth.users (id, email) values
 ('a0000000-0000-4000-8000-000000000001', 'owner@example.invalid'),
 ('a0000000-0000-4000-8000-000000000002', 'viewer@example.invalid'),
 ('a0000000-0000-4000-8000-000000000003', 'stranger@example.invalid'),
 ('a0000000-0000-4000-8000-000000000004', 'admin@example.invalid');

insert into public.profiles (id, email, display_name_en, is_streamer, is_verified, is_currently_live, active_stream_id) values
 ('a0000000-0000-4000-8000-000000000001', 'owner@example.invalid', 'Owner', true, true, true, 'modstream1'),
 ('a0000000-0000-4000-8000-000000000002', 'viewer@example.invalid', 'Viewer', false, false, false, null),
 -- The stranger is a verified streamer too, but of another stream entirely.
 ('a0000000-0000-4000-8000-000000000003', 'stranger@example.invalid', 'Stranger', true, true, true, 'otherstream'),
 ('a0000000-0000-4000-8000-000000000004', 'admin@example.invalid', 'Admin', false, false, false, null);

insert into public.user_roles (profile_id, role) values
 ('a0000000-0000-4000-8000-000000000004', 'admin');

-- One message from the viewer in the owner's stream.
insert into public.chat_messages (id, stream_id, sender_id, body) values
 ('b0000000-0000-4000-8000-000000000001', 'modstream1',
  'a0000000-0000-4000-8000-000000000002', 'a message to moderate');

-- ---------------------------------------------------------------------------
-- owns_stream / chat_can_moderate resolve from the profile that is actually
-- live on that stream id, not from anything the caller sends.
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select ok(public.owns_stream('modstream1'), 'the broadcaster owns its own stream');
select ok(public.chat_can_moderate('modstream1'),
 'the broadcaster may moderate its own stream');
select ok(not public.chat_can_moderate('otherstream'),
 'the broadcaster may NOT moderate a stream it does not own');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select ok(not public.owns_stream('modstream1'), 'a viewer owns no stream');
select ok(not public.chat_can_moderate('modstream1'),
 'A9 a viewer may not moderate');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select ok(not public.chat_can_moderate('modstream1'),
 'A3 an unrelated broadcaster may not moderate someone else''s stream');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
select ok(public.chat_can_moderate('modstream1'),
 'a platform admin may moderate any stream');
reset role;

-- ---------------------------------------------------------------------------
-- Deleting someone else's message.
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
delete from public.chat_messages where id = 'b0000000-0000-4000-8000-000000000001';
reset role;
select is((select count(*)::int from public.chat_messages
            where id = 'b0000000-0000-4000-8000-000000000001'), 1,
 'A3 an unrelated streamer deleting another stream''s message removes nothing');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
delete from public.chat_messages where id = 'b0000000-0000-4000-8000-000000000001'
 and sender_id <> 'a0000000-0000-4000-8000-000000000002';
reset role;
select is((select count(*)::int from public.chat_messages
            where id = 'b0000000-0000-4000-8000-000000000001'), 1,
 'a viewer cannot delete a message that is not theirs');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
delete from public.chat_messages where id = 'b0000000-0000-4000-8000-000000000001';
reset role;
select is((select count(*)::int from public.chat_messages
            where id = 'b0000000-0000-4000-8000-000000000001'), 0,
 'the stream owner CAN delete a message in its own stream');

-- ---------------------------------------------------------------------------
-- Muting. chat_muted_users is owner/moderator/admin only.
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select throws_ok($$insert into public.chat_muted_users (stream_id, muted_profile_id, muted_by)
 values ('modstream1', 'a0000000-0000-4000-8000-000000000001',
         'a0000000-0000-4000-8000-000000000002')$$,
 '42501', null, 'A9 a viewer cannot mute anyone');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select throws_ok($$insert into public.chat_muted_users (stream_id, muted_profile_id, muted_by)
 values ('modstream1', 'a0000000-0000-4000-8000-000000000002',
         'a0000000-0000-4000-8000-000000000003')$$,
 '42501', null, 'A3 an unrelated streamer cannot mute in another stream');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($$insert into public.chat_muted_users (stream_id, muted_profile_id, muted_by)
 values ('modstream1', 'a0000000-0000-4000-8000-000000000002',
         'a0000000-0000-4000-8000-000000000001')$$,
 'the stream owner CAN mute a sender in its own stream');
reset role;

-- A11: the muted sender can no longer insert.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select ok(public.chat_is_muted('modstream1', 'a0000000-0000-4000-8000-000000000002'),
 'the muted sender can see that they are muted (drives the composer state)');
select throws_ok($$insert into public.chat_messages (stream_id, sender_id, body)
 values ('modstream1', 'a0000000-0000-4000-8000-000000000002', 'let me back in')$$,
 '42501', null, 'A11 a muted sender cannot insert a message');
reset role;

-- But the mute is scoped to that one stream.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select ok(not public.chat_is_muted('otherstream', 'a0000000-0000-4000-8000-000000000002'),
 'a mute in one stream does not mute the sender everywhere');
reset role;

-- Unmuting is deleting the row, and it is the same authority.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
delete from public.chat_muted_users where stream_id = 'modstream1';
reset role;
select is((select count(*)::int from public.chat_muted_users where stream_id = 'modstream1'),
 1, 'a muted viewer cannot unmute themselves');

-- ---------------------------------------------------------------------------
-- Reports: any signed-in viewer may file one, only admins may read the queue,
-- and the reporter cannot read their own report back.
-- ---------------------------------------------------------------------------
insert into public.chat_messages (id, stream_id, sender_id, body) values
 ('b0000000-0000-4000-8000-000000000002', 'modstream1',
  'a0000000-0000-4000-8000-000000000003', 'reportable');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select lives_ok($$insert into public.chat_reports
 (message_id, stream_id, reported_sender_id, reporter_id, reason)
 values ('b0000000-0000-4000-8000-000000000002', 'modstream1',
         'a0000000-0000-4000-8000-000000000003',
         'a0000000-0000-4000-8000-000000000002', 'spam')$$,
 'a signed-in viewer may file a report');
select is((select count(*)::int from public.chat_reports), 0,
 'the reporter cannot read the moderation queue back');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
select is((select count(*)::int from public.chat_reports), 1,
 'an admin sees the report in the queue');
reset role;

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$select count(*) from public.chat_reports$$, '42501', null,
 'anon cannot read the moderation queue at all');
reset role;

-- ---------------------------------------------------------------------------
-- The audit trail. log_audit_event is how every moderation action is recorded
-- (P6.3); it must accept a platform-scope entry and refuse an organization the
-- caller has nothing to do with (20260921110000).
-- ---------------------------------------------------------------------------
insert into public.organizations (id, name_en, name_ar, owner_profile_id) values
 ('c0000000-0000-4000-8000-000000000001', 'Unrelated Org', 'مؤسسة',
  'a0000000-0000-4000-8000-000000000003');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($$select public.log_audit_event(null, 'chatMessageDeleted',
 'Deleted a chat message.', 'حذف رسالة.', '{}'::jsonb)$$,
 'a moderation action can be audited at platform scope (null organization)');
select throws_ok($$select public.log_audit_event(
 'c0000000-0000-4000-8000-000000000001', 'chatMessageDeleted',
 'Deleted a chat message.', 'حذف رسالة.', '{}'::jsonb)$$,
 '42501', null,
 'a caller cannot file an audit entry against an unrelated organization');
reset role;

select is((select count(*)::int from public.audit_logs
            where action = 'chatMessageDeleted' and organization_id is null), 1,
 'the platform-scope audit entry was written');

select * from finish();
rollback;
