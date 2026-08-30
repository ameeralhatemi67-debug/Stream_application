-- Cluster 4 — Task 14: Mute duration options (10 min / 1 hour / Permanent)
--
-- chat_muted_users (20260825090000) was permanent-only (delete row = unmute).
-- The moderation queue's "Mute in Stream" action now needs a duration picker;
-- expires_at null keeps the existing permanent behavior, a future timestamp
-- makes chat_is_muted() stop blocking sends on its own once it passes,
-- without any admin follow-up (the row can be swept later, but even if it
-- lingers it's inert past expiry).
alter table public.chat_muted_users
  add column expires_at timestamptz;

create or replace function public.chat_is_muted(p_stream_id text, p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.chat_muted_users
    where stream_id = p_stream_id and muted_profile_id = p_profile_id
      and (expires_at is null or expires_at > now())
  );
$$;
