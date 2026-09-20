-- P6.1 (server-side chat enforcement). Until now the only thing standing
-- between a signed-in account and an unlimited flood of chat messages was the
-- client: the insert policy checked identity and mute state, nothing else.
-- Slow mode and "chat off" did not exist anywhere.
--
-- Everything here is enforced in the database, on the insert path, so a
-- modified client gains nothing.
begin;

-- Per-stream chat controls. A row is created on demand by whoever owns or
-- moderates the stream; no row means "chat on, no slow mode", so existing
-- streams keep working untouched.
create table public.chat_stream_settings (
  stream_id text primary key check (char_length(stream_id) between 1 and 128),
  chat_enabled boolean not null default true,
  slow_mode_seconds integer not null default 0
    check (slow_mode_seconds between 0 and 300),
  updated_by uuid references public.profiles (id) on delete set null,
  updated_at timestamptz not null default now()
);

comment on table public.chat_stream_settings is
  'Per-stream chat controls (P6.1). Absent row = chat enabled, no slow mode. Readable by everyone who can read the chat itself (guests included, so a guest sees why the composer is closed); writable only by the stream owner, its moderators and admin tiers, which is the same authority chat_can_moderate() already encodes.';

alter table public.chat_stream_settings enable row level security;

-- Guests read chat, so guests must be able to see that chat is off.
create policy chat_stream_settings_select_public on public.chat_stream_settings
  for select to anon, authenticated
  using (true);

create policy chat_stream_settings_insert_moderator on public.chat_stream_settings
  for insert to authenticated
  with check (public.chat_can_moderate(stream_id) and updated_by = (select auth.uid()));

create policy chat_stream_settings_update_moderator on public.chat_stream_settings
  for update to authenticated
  using (public.chat_can_moderate(stream_id))
  with check (public.chat_can_moderate(stream_id) and updated_by = (select auth.uid()));

create policy chat_stream_settings_delete_moderator on public.chat_stream_settings
  for delete to authenticated
  using (public.chat_can_moderate(stream_id));

create policy chat_stream_settings_insert_not_banned on public.chat_stream_settings
  as restrictive for insert to authenticated
  with check (not public.is_current_user_banned());

create policy chat_stream_settings_update_not_banned on public.chat_stream_settings
  as restrictive for update to authenticated
  using (not public.is_current_user_banned());

-- The rate limiter reads a sender's recent messages in one stream; without
-- this index every insert would scan the stream's whole history.
create index chat_messages_sender_recent_idx
  on public.chat_messages (stream_id, sender_id, created_at desc);

-- SECURITY INVOKER on purpose (05 D-21, same reasoning as the column guards):
-- current_user then still tells an ordinary API write apart from a trusted
-- owner-executed RPC, so future server-side moderation tooling is not rate
-- limited by its own janitorial inserts.
create or replace function public.chat_enforce_rate_limit()
returns trigger
language plpgsql
as $$
declare
  v_settings public.chat_stream_settings%rowtype;
  v_last_at timestamptz;
  v_recent integer;
  v_can_moderate boolean;
  v_required_gap interval;
begin
  -- Only ordinary client writes are policed.
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;

  select * into v_settings from public.chat_stream_settings
   where stream_id = new.stream_id;

  v_can_moderate := public.chat_can_moderate(new.stream_id);

  if v_settings.stream_id is not null
     and not v_settings.chat_enabled
     and not v_can_moderate then
    raise exception 'Chat is turned off for this stream'
      using errcode = '42501';
  end if;

  select max(created_at) into v_last_at
    from public.chat_messages
   where stream_id = new.stream_id and sender_id = new.sender_id;

  -- 1.2 s floor for everyone, including moderators: that is a flood guard,
  -- not a moderation policy. Slow mode adds to it and exempts moderators, so
  -- a broadcaster can still answer while the room is slowed down.
  v_required_gap := interval '1200 milliseconds';
  if not v_can_moderate and coalesce(v_settings.slow_mode_seconds, 0) > 0 then
    v_required_gap := greatest(
      v_required_gap,
      make_interval(secs => v_settings.slow_mode_seconds));
  end if;

  if v_last_at is not null and v_last_at > now() - v_required_gap then
    raise exception 'Sending too fast'
      using errcode = '42501';
  end if;

  select count(*) into v_recent
    from public.chat_messages
   where stream_id = new.stream_id
     and sender_id = new.sender_id
     and created_at > now() - interval '1 minute';

  if v_recent >= 30 and not v_can_moderate then
    raise exception 'Too many messages in one minute'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

revoke execute on function public.chat_enforce_rate_limit() from public, anon, authenticated;

create trigger chat_messages_rate_limit
  before insert on public.chat_messages
  for each row execute function public.chat_enforce_rate_limit();

commit;
