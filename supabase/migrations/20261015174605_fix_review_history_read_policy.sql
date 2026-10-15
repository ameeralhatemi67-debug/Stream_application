-- Admins could never read the application review history. The select policy
-- from 20260929010000 calls public.is_banned(uuid), whose execute grant was
-- revoked from authenticated in 20260920110000, so every client read of
-- application_review_events failed with "permission denied for function
-- is_banned". Use the caller-scoped helper that authenticated may execute;
-- it checks the same banned_users row for auth.uid().
begin;

drop policy application_review_events_admin_select on public.application_review_events;
create policy application_review_events_admin_select
  on public.application_review_events for select to authenticated
  using (public.is_admin_tier() and not public.is_current_user_banned());

commit;
