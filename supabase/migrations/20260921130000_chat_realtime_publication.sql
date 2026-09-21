-- P6.2 / P6.3 — put the two moderation tables the UI has to react to on the
-- realtime publication.
--
-- `chat_stream_settings` (P6.2). The composer has to show "chat is off" and a
-- slow-mode countdown the moment the broadcaster changes them, not on the next
-- screen open. Its SELECT policy is already `to anon, authenticated` with
-- `using (true)` -- everyone who can read a public chat can see that the chat
-- is off -- so publishing it exposes nothing that a guest could not already
-- read, and Realtime applies RLS per subscriber regardless.
--
-- `chat_reports` (P6.3). The admin moderation queue polled for this. Its
-- SELECT policy is admin-tier only, so only admin subscribers receive a row;
-- a reporter cannot even read their own report back, which is deliberate
-- (20260824090000) and unchanged here. `brief/03` P6.1 asked to either publish
-- this table or prove polling was adequate -- publishing it is the answer.
--
-- NOT PUBLISHED, deliberately: `chat_muted_users`. Its SELECT policy is the
-- stream owner, moderators and admins, so a muted viewer would never receive
-- their own mute event anyway, and the obvious "fix" -- letting a user select
-- their own mute row -- would hand them `muted_by`, i.e. tell a muted account
-- exactly which moderator muted it. That is a harassment vector, and it is not
-- needed: `chat_is_muted(stream_id, profile_id)` is already SECURITY DEFINER
-- and granted to `authenticated`, so the client can ask "am I muted?" without
-- reading the table. LiveChatController re-resolves it on start, whenever a
-- send is refused, and whenever one of the viewer's own messages is deleted by
-- someone else.
begin;

alter publication supabase_realtime add table public.chat_stream_settings;
alter publication supabase_realtime add table public.chat_reports;

commit;
