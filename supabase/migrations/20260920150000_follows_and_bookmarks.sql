-- P2 / 05 D-07: follows and bookmarks persist for signed-in accounts.
-- Until now both lived only in AppProvider's memory (and the bookmark set even
-- shipped with two sample ids pre-selected), so a follow vanished on restart
-- and meant nothing on another device.
--
-- Target ids are text, not uuid references: a followed channel is a profile OR
-- an organization, and a bookmark points at a VOD id that comes from YouTube,
-- not from our schema. A uuid FK would model only half of each case, so the
-- column stays text and the client resolves it -- the same choice the existing
-- text `active_stream_id` / `stream_id` columns already make.
--
-- Own-row RLS: a row is readable and writable only by the account it belongs
-- to. Nobody, not even an admin tier, reads another account's follow list
-- through these tables; aggregate follower counts stay on profiles, which is
-- where the app already reads them.
begin;

create table public.follows (
  follower_profile_id uuid not null references public.profiles (id) on delete cascade,
  target_id text not null check (char_length(target_id) between 1 and 128),
  created_at timestamptz not null default now(),
  primary key (follower_profile_id, target_id)
);

create index follows_target_idx on public.follows (target_id);

comment on table public.follows is
  'Channels (profile or organization ids, as text) a signed-in account follows. Own-row only: see follows_select_own. Guests keep follows locally on the device and nothing reaches this table.';

alter table public.follows enable row level security;

create policy follows_select_own on public.follows
  for select to authenticated
  using (follower_profile_id = (select auth.uid()));

create policy follows_insert_own on public.follows
  for insert to authenticated
  with check (follower_profile_id = (select auth.uid()));

create policy follows_delete_own on public.follows
  for delete to authenticated
  using (follower_profile_id = (select auth.uid()));

-- No update policy: a follow is created or removed, never edited.

create policy follows_insert_not_banned on public.follows
  as restrictive for insert to authenticated
  with check (not public.is_current_user_banned());

create policy follows_delete_not_banned on public.follows
  as restrictive for delete to authenticated
  using (not public.is_current_user_banned());

create table public.bookmarks (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  vod_id text not null check (char_length(vod_id) between 1 and 128),
  streamer_id text not null default '' check (char_length(streamer_id) <= 128),
  created_at timestamptz not null default now(),
  primary key (profile_id, vod_id)
);

comment on table public.bookmarks is
  'Recordings a signed-in account saved. vod_id is the id the catalog uses (a YouTube video id for YouTube-sourced VODs), streamer_id the channel it belongs to, both text for the same reason as follows.target_id. Own-row only.';

alter table public.bookmarks enable row level security;

create policy bookmarks_select_own on public.bookmarks
  for select to authenticated
  using (profile_id = (select auth.uid()));

create policy bookmarks_insert_own on public.bookmarks
  for insert to authenticated
  with check (profile_id = (select auth.uid()));

create policy bookmarks_delete_own on public.bookmarks
  for delete to authenticated
  using (profile_id = (select auth.uid()));

create policy bookmarks_insert_not_banned on public.bookmarks
  as restrictive for insert to authenticated
  with check (not public.is_current_user_banned());

create policy bookmarks_delete_not_banned on public.bookmarks
  as restrictive for delete to authenticated
  using (not public.is_current_user_banned());

commit;
