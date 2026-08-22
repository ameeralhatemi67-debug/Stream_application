-- v0.6 Live Chat & Realtime Engagement — Checkpoint 3, Phase 2: Streamer/Admin
-- Moderation Controls
--
-- The roadmap doc says "RLS + a Supabase Edge Function"; this project has
-- never deployed an Edge Function (no supabase/functions directory, no Deno
-- runtime in the toolchain) and every other server-enforced check so far
-- (is_admin_tier, owns_organization, chat_sender_info, ...) is a plain
-- SECURITY DEFINER SQL function reached through RLS or a direct table
-- policy -- there's no reason mute/delete needs a different mechanism, and
-- the actual requirement ("not just a client-side check") is satisfied
-- exactly as well by RLS alone, with one fewer moving part to deploy.
--
-- "The stream's owner" has no explicit row anywhere -- chat_messages.stream_id
-- is free text (see 20260823090000), not a FK to a streams table (there is
-- none). What DOES exist is profiles.active_stream_id (individual streamer)
-- and organizations.active_stream_id (org broadcaster) -- both already the
-- source of truth the rest of the app uses to know "who is live on stream
-- X". owns_stream() below is the same shape as owns_organization().
create or replace function public.owns_stream(p_stream_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and active_stream_id = p_stream_id
  )
  or exists (
    select 1 from public.organizations o
    where o.active_stream_id = p_stream_id
      and public.owns_organization(o.id)
  );
$$;

-- Convenience bundle for the client: "can I see moderation controls on this
-- stream's chat" -- a single round trip instead of two. Purely a UX check;
-- the RLS policies below are what actually enforce it.
create or replace function public.chat_can_moderate(p_stream_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin_tier() or public.owns_stream(p_stream_id);
$$;

grant execute on function public.owns_stream(text) to authenticated;
grant execute on function public.chat_can_moderate(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Delete: no new table needed -- chat_messages just gets a DELETE policy it
-- didn't have before (Checkpoint 1 deliberately left it off, noting
-- moderation was this checkpoint's job). A regular sender still can't delete
-- their own message (matches the roadmap: this is a moderation action, not a
-- self-service "unsend").
-- ---------------------------------------------------------------------------
create policy chat_messages_delete_owner_or_admin
  on public.chat_messages for delete
  to authenticated
  using (public.is_admin_tier() or public.owns_stream(stream_id));

-- ---------------------------------------------------------------------------
-- Mute: a per-stream allow/deny row, enforced by rewriting the existing
-- insert policy to also reject muted senders -- the mute takes effect
-- immediately for every future send attempt without the client needing to
-- special-case anything.
-- ---------------------------------------------------------------------------
create table public.chat_muted_users (
  id uuid primary key default gen_random_uuid(),
  stream_id text not null,
  muted_profile_id uuid not null references public.profiles (id) on delete cascade,
  muted_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),

  unique (stream_id, muted_profile_id)
);

comment on table public.chat_muted_users is
  'Per-stream chat mutes set by that stream''s owner/admin. Enforced via chat_messages_insert_self, not just checked client-side.';

alter table public.chat_muted_users enable row level security;

create policy chat_muted_users_select_owner_or_admin
  on public.chat_muted_users for select
  to authenticated
  using (public.is_admin_tier() or public.owns_stream(stream_id));

create policy chat_muted_users_insert_owner_or_admin
  on public.chat_muted_users for insert
  to authenticated
  with check (
    (public.is_admin_tier() or public.owns_stream(stream_id))
    and muted_by = auth.uid()
  );

-- Unmute -- a mute with no way back would be a permanent trap, and deleting
-- the row is the natural "undo" of inserting it.
create policy chat_muted_users_delete_owner_or_admin
  on public.chat_muted_users for delete
  to authenticated
  using (public.is_admin_tier() or public.owns_stream(stream_id));

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
  );
$$;

drop policy chat_messages_insert_self on public.chat_messages;

create policy chat_messages_insert_self
  on public.chat_messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and not public.chat_is_muted(stream_id, auth.uid())
  );
