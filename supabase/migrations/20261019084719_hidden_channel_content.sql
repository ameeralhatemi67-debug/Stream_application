-- Channel owners can hide a video or playlist inside the app (not on YouTube).
--
-- The videos and playlists come from the channel's YouTube feed, so the app
-- stores only a list of what the owner chose to hide. Viewers read the list
-- to leave those items out; only the channel owner (a streamer for their own
-- id, or an organization owner/co-owner) can change it.
begin;

create table public.hidden_channel_content (
  streamer_id uuid not null,
  kind text not null check (kind in ('video', 'playlist')),
  item_id text not null check (char_length(item_id) between 1 and 128),
  hidden_by uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (streamer_id, kind, item_id)
);

alter table public.hidden_channel_content enable row level security;

-- Everyone who can see a channel needs the list to leave hidden items out. It
-- holds only YouTube ids that are public on YouTube already.
create policy hidden_channel_content_select_all
  on public.hidden_channel_content for select
  to anon, authenticated
  using (true);

create policy hidden_channel_content_insert_owner
  on public.hidden_channel_content for insert
  to authenticated
  with check (
    hidden_by = auth.uid()
    and (streamer_id = auth.uid() or public.owns_organization(streamer_id))
  );

create policy hidden_channel_content_delete_owner
  on public.hidden_channel_content for delete
  to authenticated
  using (streamer_id = auth.uid() or public.owns_organization(streamer_id));

grant select on public.hidden_channel_content to anon, authenticated;
grant insert, delete on public.hidden_channel_content to authenticated;

commit;
