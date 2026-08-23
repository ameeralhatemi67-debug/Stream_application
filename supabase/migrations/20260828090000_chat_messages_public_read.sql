-- Allow all viewers (including unauthenticated guests) to read live chat messages
-- and resolve public chat sender info (name, avatar, badges). Sending messages remains
-- strictly authenticated-only (sender_id = auth.uid()).

drop policy if exists chat_messages_select_authenticated on public.chat_messages;
drop policy if exists chat_messages_select_public on public.chat_messages;

create policy chat_messages_select_public
  on public.chat_messages for select
  to authenticated, anon
  using (true);

-- Grant execute on chat_sender_info to anon as well so guest viewers see sender display names & badges
grant execute on function public.chat_sender_info(uuid[]) to authenticated, anon;
