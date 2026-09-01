-- Multi-Device Session Governance (issue_log.md)
--
-- One row per (user, device). is_primary_broadcaster marks which single
-- device currently holds broadcaster rights for that account -- checked on
-- every sign-in so a second device can be prompted with
-- DeviceSessionConflictDialog instead of silently colliding with an
-- already-live broadcast on the first device.
create table public.device_sessions (
  user_id uuid not null references public.profiles (id) on delete cascade,
  device_id text not null,
  device_name text not null default '',
  platform text not null default '',
  is_primary_broadcaster boolean not null default false,
  last_active_at timestamptz not null default now(),
  primary key (user_id, device_id)
);

create index device_sessions_user_idx on public.device_sessions (user_id);

comment on table public.device_sessions is
  'One row per signed-in device per account. is_primary_broadcaster=true marks the device currently holding broadcaster rights, so a second device signing into the same account can detect the conflict.';

alter table public.device_sessions enable row level security;

-- A user only ever needs to see/manage their own device rows.
create policy device_sessions_select_own
  on public.device_sessions for select
  to authenticated
  using (user_id = auth.uid());

create policy device_sessions_write_own
  on public.device_sessions for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

alter publication supabase_realtime add table public.device_sessions;
