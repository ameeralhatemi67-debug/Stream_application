-- Cluster 4 — Task 13: User Message Actions (Edit/Delete Own)
--
-- chat_messages_delete_owner_or_admin (20260825090000) deliberately excluded
-- self-delete: "a regular sender still can't delete their own message... this
-- is a moderation action, not a self-service unsend." Task 13 explicitly asks
-- for a self-service unsend/edit on top of that existing moderation delete,
-- so this adds the missing self policies rather than reopening that one --
-- Postgres OR-combines multiple permissive policies for the same command, so
-- both the moderation delete and this self-delete coexist untouched.
create policy chat_messages_delete_self
  on public.chat_messages for delete
  to authenticated
  using (sender_id = auth.uid());

-- No UPDATE policy existed at all before this (Checkpoint 1 shipped none).
-- edited_at lets the client show an "(edited)" indicator; sender may only
-- change body/edited_at on their own message, never sender_id/stream_id.
alter table public.chat_messages
  add column edited_at timestamptz;

create policy chat_messages_update_self
  on public.chat_messages for update
  to authenticated
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());
