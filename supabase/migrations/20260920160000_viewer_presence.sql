-- P3 / 05 D-08: a viewer count that counts actual viewers.
-- Until now every number next to a live stream came from a fixture or a
-- stand-in literal. Presence is recorded here, never by the client writing
-- rows: the table has RLS on and NO policy at all, so PostgREST cannot read
-- or write it under any role. The only doors are the two SECURITY DEFINER
-- functions below.
--
-- Counting rules (D-08): heartbeat every 20 s, a viewer counts while its last
-- heartbeat is under 45 s old, viewer_key is the user id when signed in and a
-- per-install UUID otherwise -- so one person on two devices counts once when
-- signed in, and a guest counts once per install.
begin;

create table public.stream_viewers (
  stream_id text not null check (char_length(stream_id) between 1 and 128),
  viewer_key text not null check (char_length(viewer_key) between 8 and 128),
  last_seen timestamptz not null default now(),
  primary key (stream_id, viewer_key)
);

create index stream_viewers_last_seen_idx on public.stream_viewers (last_seen);

comment on table public.stream_viewers is
  'Live-viewer presence. RLS is enabled with NO policy on purpose (deny-all): no client role may select, insert, update or delete a row. Presence is written only by viewer_heartbeat() and read only by get_viewer_counts(), both SECURITY DEFINER. A row is (stream_id, viewer_key) where viewer_key is the signed-in user id or a per-install UUID; rows older than 10 minutes are swept opportunistically by viewer_heartbeat().';

alter table public.stream_viewers enable row level security;

-- Records one viewer's presence on a stream that is actually live.
--
-- Refuses: a stream nobody is broadcasting (checked against the live flags
-- that only set_live_state can write, P1.2, and only while the broadcaster's
-- primary device heartbeat is fresh, P1c), a malformed viewer key, and the
-- broadcaster's own account -- a broadcaster watching their own stream must
-- not inflate their audience.
-- Ignores a repeat call less than 10 s after the last one for the same
-- (stream, viewer): the client heartbeats every 20 s, so anything faster is a
-- retry storm or an attempt to look busier than the room is.
create function public.viewer_heartbeat(p_stream_id text, p_viewer_key text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_last timestamptz;
begin
  if p_stream_id is null or p_viewer_key is null then return false; end if;
  if char_length(p_stream_id) not between 1 and 128 then return false; end if;
  if char_length(p_viewer_key) not between 8 and 128 then return false; end if;

  -- The stream must be live, and its broadcaster still beating.
  if not exists (
    select 1 from public.profiles p
    join public.device_sessions d
      on d.user_id = p.id and d.is_primary_broadcaster
     and d.last_active_at > now() - interval '90 seconds'
    where p.is_currently_live and p.active_stream_id = p_stream_id
  ) and not exists (
    select 1 from public.organizations o
    join public.profiles p on p.active_stream_id = o.active_stream_id
    join public.device_sessions d
      on d.user_id = p.id and d.is_primary_broadcaster
     and d.last_active_at > now() - interval '90 seconds'
    where o.is_currently_live and o.active_stream_id = p_stream_id
  ) then
    return false;
  end if;

  -- The broadcaster does not count as a member of their own audience.
  if v_uid is not null and exists (
    select 1 from public.profiles p
    where p.id = v_uid and p.active_stream_id = p_stream_id and p.is_currently_live
  ) then
    return false;
  end if;

  -- A signed-in viewer is keyed by user id, whatever the client sent, so the
  -- same person on two devices is one viewer and nobody can pad the count by
  -- inventing keys while signed in.
  if v_uid is not null then
    p_viewer_key := v_uid::text;
  end if;

  select last_seen into v_last from public.stream_viewers
   where stream_id = p_stream_id and viewer_key = p_viewer_key;
  if v_last is not null and v_last > now() - interval '10 seconds' then
    return true;
  end if;

  insert into public.stream_viewers (stream_id, viewer_key, last_seen)
  values (p_stream_id, p_viewer_key, now())
  on conflict (stream_id, viewer_key) do update set last_seen = now();

  -- Opportunistic sweep: presence older than 10 minutes can never count
  -- towards the 45-second window again.
  delete from public.stream_viewers where last_seen < now() - interval '10 minutes';

  return true;
end;
$$;

revoke execute on function public.viewer_heartbeat(text, text) from public;
-- Guests watch too, so anon needs this one (D-21 names the two viewer-count
-- functions as the deliberate exceptions to the anon-denied rule).
grant execute on function public.viewer_heartbeat(text, text) to anon, authenticated;

-- Live viewer counts for a batch of streams. Returns one row per requested id
-- so the caller can tell "zero viewers" from "not asked"; a stream with no
-- presence rows returns 0.
create function public.get_viewer_counts(p_stream_ids text[])
returns table (stream_id text, viewer_count integer)
language sql
stable
security definer
set search_path = ''
as $$
  select ids.stream_id,
         (select count(*)::integer from public.stream_viewers v
           where v.stream_id = ids.stream_id
             and v.last_seen > now() - interval '45 seconds') as viewer_count
    from unnest(coalesce(p_stream_ids, '{}'::text[])) as ids(stream_id);
$$;

revoke execute on function public.get_viewer_counts(text[]) from public;
grant execute on function public.get_viewer_counts(text[]) to anon, authenticated;

commit;
