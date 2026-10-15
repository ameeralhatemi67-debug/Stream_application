-- Bring tables and functions added after the 2026-09-21/23 privilege
-- hardening back in line with the catalog contract in
-- supabase/tests/rls_catalog.test.sql (R2, R3, R5, R6b, R10, R11).
--
-- The reminder (20260930010000) and review-history (20260929010000) tables
-- were created after 20260921110000 revoked the API roles' blanket grants, so
-- whatever default privileges the migrating role carries were applied to
-- them. Where that role grants everything (a local stack migrated as
-- supabase_admin), anon could SELECT and even TRUNCATE them; TRUNCATE skips
-- RLS. Each migration's own explicit GRANT is the intended surface, so this
-- revokes everything beyond it. It is a no-op where the defaults were
-- already narrow.
begin;

-- Tables: anon never reads or writes these; authenticated keeps exactly the
-- explicit grants from the creating migrations.
revoke all on public.upcoming_schedules, public.channel_schedule_reminders,
  public.card_schedule_reminders, public.schedule_reminder_preferences,
  public.schedule_push_devices, public.schedule_reminder_deliveries,
  public.application_review_events
  from anon;
revoke truncate, trigger, references on public.upcoming_schedules,
  public.channel_schedule_reminders, public.card_schedule_reminders,
  public.schedule_reminder_preferences, public.schedule_push_devices
  from authenticated;
-- Delivery rows are service-role only (deny-all RLS, no client grants).
revoke all on public.schedule_reminder_deliveries from authenticated;
-- Review events are written only by security-definer triggers.
revoke insert, update, delete, truncate, trigger, references
  on public.application_review_events from authenticated;

-- Functions granted to authenticated only; default privileges must not hand
-- them to guests as well.
revoke execute on function public.can_subscribe_upcoming(uuid) from anon;
revoke execute on function public.register_schedule_push_device(text,text,text) from anon;

-- Membership requests are written only through the organization v1 RPCs
-- since 20261001095030 revoked direct INSERT/UPDATE. These policies have been
-- unreachable since then.
drop policy affiliation_requests_insert_party on public.affiliation_requests;
drop policy affiliation_requests_insert_not_banned on public.affiliation_requests;
drop policy affiliation_requests_update_party on public.affiliation_requests;
drop policy affiliation_requests_update_not_banned on public.affiliation_requests;

-- Per-command policies (20260921100000 convention). Same predicates as the
-- FOR ALL policies they replace: USING for select/update/delete, WITH CHECK
-- for insert/update.
drop policy channel_reminders_own on public.channel_schedule_reminders;
create policy channel_reminders_select_own on public.channel_schedule_reminders
  for select to authenticated using (viewer_profile_id = (select auth.uid()));
create policy channel_reminders_insert_own on public.channel_schedule_reminders
  for insert to authenticated
  with check (viewer_profile_id = (select auth.uid())
    and public.can_publish_upcoming(streamer_profile_id) and not public.is_current_user_banned());
create policy channel_reminders_update_own on public.channel_schedule_reminders
  for update to authenticated using (viewer_profile_id = (select auth.uid()))
  with check (viewer_profile_id = (select auth.uid())
    and public.can_publish_upcoming(streamer_profile_id) and not public.is_current_user_banned());
create policy channel_reminders_delete_own on public.channel_schedule_reminders
  for delete to authenticated using (viewer_profile_id = (select auth.uid()));

drop policy card_reminders_own on public.card_schedule_reminders;
create policy card_reminders_select_own on public.card_schedule_reminders
  for select to authenticated using (viewer_profile_id = (select auth.uid()));
create policy card_reminders_insert_own on public.card_schedule_reminders
  for insert to authenticated
  with check (viewer_profile_id = (select auth.uid()) and not public.is_current_user_banned()
    and public.can_subscribe_upcoming(schedule_id));
create policy card_reminders_update_own on public.card_schedule_reminders
  for update to authenticated using (viewer_profile_id = (select auth.uid()))
  with check (viewer_profile_id = (select auth.uid()) and not public.is_current_user_banned()
    and public.can_subscribe_upcoming(schedule_id));
create policy card_reminders_delete_own on public.card_schedule_reminders
  for delete to authenticated using (viewer_profile_id = (select auth.uid()));

drop policy reminder_preferences_own on public.schedule_reminder_preferences;
create policy reminder_preferences_select_own on public.schedule_reminder_preferences
  for select to authenticated using (viewer_profile_id = (select auth.uid()));
create policy reminder_preferences_insert_own on public.schedule_reminder_preferences
  for insert to authenticated
  with check (viewer_profile_id = (select auth.uid()) and not public.is_current_user_banned());
create policy reminder_preferences_update_own on public.schedule_reminder_preferences
  for update to authenticated using (viewer_profile_id = (select auth.uid()))
  with check (viewer_profile_id = (select auth.uid()) and not public.is_current_user_banned());
create policy reminder_preferences_delete_own on public.schedule_reminder_preferences
  for delete to authenticated using (viewer_profile_id = (select auth.uid()));

drop policy push_devices_own on public.schedule_push_devices;
create policy push_devices_select_own on public.schedule_push_devices
  for select to authenticated using (viewer_profile_id = (select auth.uid()));
create policy push_devices_insert_own on public.schedule_push_devices
  for insert to authenticated
  with check (viewer_profile_id = (select auth.uid()) and not public.is_current_user_banned());
create policy push_devices_update_own on public.schedule_push_devices
  for update to authenticated using (viewer_profile_id = (select auth.uid()))
  with check (viewer_profile_id = (select auth.uid()) and not public.is_current_user_banned());
create policy push_devices_delete_own on public.schedule_push_devices
  for delete to authenticated using (viewer_profile_id = (select auth.uid()));

-- notification_push_preferences grants select/insert/update only (20261001160000).
drop policy push_preferences_own on public.notification_push_preferences;
create policy push_preferences_select_own on public.notification_push_preferences
  for select to authenticated using (viewer_profile_id = (select auth.uid()));
create policy push_preferences_insert_own on public.notification_push_preferences
  for insert to authenticated
  with check (viewer_profile_id = (select auth.uid()) and not public.is_current_user_banned());
create policy push_preferences_update_own on public.notification_push_preferences
  for update to authenticated using (viewer_profile_id = (select auth.uid()))
  with check (viewer_profile_id = (select auth.uid()) and not public.is_current_user_banned());

commit;
