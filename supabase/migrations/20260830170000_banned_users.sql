-- Cluster 4 — Task 16: Platform-Wide Account Ban
--
-- A row existing = banned, matching the "delete = undo" pattern
-- chat_muted_users/chat_reports already use for unmute/resolve -- unbanning
-- is just deleting the row. expires_at null = permanent; a future timestamp
-- = temporary ban that self-expires without any admin follow-up action.
create table public.banned_users (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles (id) on delete cascade,
  email text not null,
  reason text not null check (char_length(reason) between 1 and 500),
  banned_by uuid references public.profiles (id) on delete set null,
  banned_at timestamptz not null default now(),
  expires_at timestamptz
);

create index banned_users_profile_idx on public.banned_users (profile_id);

comment on table public.banned_users is
  'Platform-wide account bans. Row presence = banned; expires_at null = permanent, else self-expiring. Port of the admin "Banned Accounts" manager.';

alter table public.banned_users enable row level security;

-- A banned user can read their own row (AccountBannedScreen shows the
-- reason); admin tier can read/write everything.
create policy banned_users_select_own_or_admin
  on public.banned_users for select
  to authenticated
  using (profile_id = auth.uid() or public.is_admin_tier());

create policy banned_users_write_admin
  on public.banned_users for all
  to authenticated
  using (public.is_admin_tier())
  with check (public.is_admin_tier() and banned_by = auth.uid());

-- SECURITY DEFINER so the router-guard check works even though a banned
-- user's own profiles row may otherwise be restricted -- same "one round
-- trip, policy is the real enforcement" convenience pattern as
-- chat_can_moderate(). Ignores an already-expired temporary ban.
create or replace function public.is_current_user_banned()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.banned_users
    where profile_id = auth.uid()
      and (expires_at is null or expires_at > now())
  );
$$;

grant execute on function public.is_current_user_banned() to authenticated;

alter publication supabase_realtime add table public.banned_users;
