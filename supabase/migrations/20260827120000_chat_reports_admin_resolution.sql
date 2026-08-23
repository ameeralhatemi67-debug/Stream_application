-- v0.8 Admin Upgrade — Checkpoint 4 Phase 1: Chat Moderation Dashboard
--
-- chat_reports (20260824090000) deliberately shipped with no UPDATE/DELETE
-- policy: "report triage/resolution tooling is a future admin-console
-- feature, not this checkpoint's job." This is that feature. Resolving a
-- report -- whether by dismissing it outright, or after acting on it via
-- chat_messages delete / chat_muted_users mute -- removes it from the admin
-- queue by deleting the row, the same "delete = resolved/undone" pattern
-- chat_muted_users already uses for unmute (20260825090000).
--
-- No new table or column: chat_messages' delete policy (admin OR
-- owns_stream) and chat_muted_users' insert policy (admin OR owns_stream)
-- already cover the "delete message" / "mute sender" actions for an
-- admin-tier account platform-wide -- only chat_reports itself was missing
-- write access.
create policy chat_reports_delete_admin
  on public.chat_reports for delete
  to authenticated
  using (public.is_admin_tier());
