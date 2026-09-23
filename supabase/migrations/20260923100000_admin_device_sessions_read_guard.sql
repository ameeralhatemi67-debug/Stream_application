-- P6.4: keep ordinary users' own device reads while permitting active admins
-- to inspect other accounts' devices. The earlier admin policy called the
-- server-only is_banned(uuid) helper in caller context and raised 42501.
begin;

drop policy device_sessions_select_own on public.device_sessions;
drop policy device_sessions_select_admin on public.device_sessions;

create policy device_sessions_select_own on public.device_sessions
  for select to authenticated
  using (user_id = auth.uid() and not public.is_current_user_banned());

create policy device_sessions_select_admin on public.device_sessions
  for select to authenticated
  using (public.is_admin_tier() and not public.is_current_user_banned());

commit;
