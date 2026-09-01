-- Cluster 4 — Tasks 13 & 15: Muted Chatters Audit Log
--
-- One row per mute action (both the admin Chat Moderation dashboard's
-- "Mute User" and the in-stream 3+ report threshold's "Quick Mute"),
-- distinct from chat_muted_users (which only ever holds the *current*
-- mute state, one row per stream+profile, overwritten/deleted on unmute).
-- This table is append-only history, so "how many streams has this person
-- been muted in" and "what did they say right before" survive an unmute.
create table public.chat_mute_audit_log (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  stream_id text not null,
  muted_by uuid references public.profiles (id) on delete set null,
  reason text not null default 'Manual moderator action',
  last_messages text[] not null default '{}',
  created_at timestamptz not null default now()
);

create index chat_mute_audit_log_profile_idx on public.chat_mute_audit_log (profile_id);

comment on table public.chat_mute_audit_log is
  'Append-only history of every chat mute action, for the admin "Muted Chatters Audit Log" section -- distinct from chat_muted_users, which only tracks current mute state.';

alter table public.chat_mute_audit_log enable row level security;

-- Admin tiers see everything; a moderator can see their own logged actions.
create policy chat_mute_audit_log_select
  on public.chat_mute_audit_log for select
  to authenticated
  using (public.is_admin_tier() or muted_by = auth.uid());

-- Any signed-in moderator/admin/streamer can log a mute they personally
-- performed -- the mute itself is already gated by chat_muted_users' own
-- RLS, this is just the accompanying audit trail entry.
create policy chat_mute_audit_log_insert_self
  on public.chat_mute_audit_log for insert
  to authenticated
  with check (muted_by = auth.uid());
