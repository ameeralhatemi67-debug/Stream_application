-- chat_session_send compared broadcast_sessions.id with broadcast_sessions.stream_id
-- (the unqualified column resolved inside the subquery to the session's own YouTube
-- video id), so no chat message could ever be inserted. Compare with the new row.
drop policy if exists chat_session_send on public.chat_messages;
create policy chat_session_send on public.chat_messages as restrictive for insert to authenticated
 with check(exists(select 1 from public.broadcast_sessions s
   where s.id::text=chat_messages.stream_id and s.state='live')
   and public.broadcast_chat_read(chat_messages.stream_id));
