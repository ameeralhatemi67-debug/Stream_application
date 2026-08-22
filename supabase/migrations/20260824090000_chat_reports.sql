-- v0.6 Live Chat & Realtime Engagement — Checkpoint 3, Phase 1: Report & Block
--
-- "Block user" (per-user, client-side hide of future messages) has no server
-- component at all -- it's not a platform-wide action, so it lives entirely
-- in the blocking viewer's own SharedPreferences (see LiveChatController).
--
-- "Report message" does need a server row: it has to reach admin tiers, who
-- can't see it any other way. One row per (message, reporter) -- the unique
-- constraint below both stops a reporter spamming the same message and
-- doubles as an idempotent "already reported" signal for the client.
create table public.chat_reports (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.chat_messages (id) on delete cascade,
  stream_id text not null,
  reported_sender_id uuid not null references public.profiles (id) on delete cascade,
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  reason text not null check (char_length(reason) between 1 and 200),
  created_at timestamptz not null default now(),

  unique (message_id, reporter_id)
);

create index chat_reports_stream_created_idx
  on public.chat_reports (stream_id, created_at desc);

comment on table public.chat_reports is
  'Chat message reports, visible only to admin tiers. One row per (message, reporter).';

-- ---------------------------------------------------------------------------
-- RLS: reporters can only insert as themselves, about a message that isn't
-- their own; only admin tiers can read. No update/delete policy -- report
-- triage/resolution tooling is a future admin-console feature, not this
-- checkpoint's job.
-- ---------------------------------------------------------------------------
alter table public.chat_reports enable row level security;

create policy chat_reports_insert_self
  on public.chat_reports for insert
  to authenticated
  with check (
    reporter_id = auth.uid()
    and reported_sender_id <> auth.uid()
  );

create policy chat_reports_select_admin
  on public.chat_reports for select
  to authenticated
  using (public.is_admin_tier());
