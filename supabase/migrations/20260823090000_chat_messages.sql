-- v0.6 Live Chat & Realtime Engagement — Checkpoint 1, Phase 1: Schema & Channel Design
--
-- stream_id is `text`, not a FK: there is no `streams`/`broadcasts` table yet --
-- a live "stream" is still an ephemeral, client-side concept keyed by the same
-- ad-hoc string ids StreamerModel already uses (e.g. 'stream_live_992'), same
-- as audit_logs.organization_id being nullable rather than assuming a row
-- always exists. sender_name/sender_avatar are deliberately NOT stored here --
-- kept minimal per the roadmap's spec (stream_id, sender_id, body, created_at)
-- and resolved client-side from `profiles`, the same way
-- AdminDatabaseService._resolveDisplayNames already does for
-- broadcaster_applications.reviewed_by. Role badges (Checkpoint 2 Phase 2)
-- read user_roles the same way, rather than denormalizing a role onto every
-- message row.
--
-- Realtime channel naming convention (used by the Flutter client, Checkpoint 1
-- Phase 2): one Supabase Realtime channel per stream, named `chat:<stream_id>`.
-- That same channel is reused for Checkpoint 2's ephemeral broadcast reactions
-- (never persisted here) alongside this table's postgres_changes events.
create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  stream_id text not null,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);

create index chat_messages_stream_created_idx
  on public.chat_messages (stream_id, created_at desc);

comment on table public.chat_messages is
  'Live chat messages, one row per sent message. Realtime channel: chat:<stream_id>.';

-- ---------------------------------------------------------------------------
-- RLS: any authenticated user can read (no separate "stream participants"
-- concept exists to gate on -- being "in" a stream is a client-side
-- navigation state, not a tracked relationship); a sender can only insert as
-- themselves. No UPDATE/DELETE policy at all yet -- moderation (mute/delete,
-- server-enforced) is Checkpoint 3's job, not this one's.
-- ---------------------------------------------------------------------------
alter table public.chat_messages enable row level security;

create policy chat_messages_select_authenticated
  on public.chat_messages for select
  to authenticated
  using (true);

create policy chat_messages_insert_self
  on public.chat_messages for insert
  to authenticated
  with check (sender_id = auth.uid());

-- Required for the client to receive postgres_changes events on INSERT.
alter publication supabase_realtime add table public.chat_messages;
