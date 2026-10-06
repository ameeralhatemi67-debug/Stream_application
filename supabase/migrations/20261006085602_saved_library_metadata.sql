begin;

-- Keep the existing private library and ownership/banned-account policies.
-- vod_id remains its reference key for backward compatibility.
alter table public.bookmarks
  add column item_kind text not null default 'recording'
    check (item_kind in ('recording', 'upcoming')),
  add column metadata jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metadata) = 'object' and octet_length(metadata::text) <= 65536);

-- Archive and playlist saves of one YouTube video now share one identity.
-- Preserve the earliest save when the old representations overlap.
insert into public.bookmarks (profile_id, vod_id, streamer_id, created_at)
select distinct on (profile_id, regexp_replace(vod_id, '^vod_(yt|pl)_', ''))
  profile_id, regexp_replace(vod_id, '^vod_(yt|pl)_', ''), streamer_id, created_at
from public.bookmarks
where vod_id ~ '^vod_(yt|pl)_[A-Za-z0-9_-]{11}$'
order by profile_id, regexp_replace(vod_id, '^vod_(yt|pl)_', ''), created_at
on conflict (profile_id, vod_id) do nothing;

delete from public.bookmarks where vod_id ~ '^vod_(yt|pl)_[A-Za-z0-9_-]{11}$';

comment on column public.bookmarks.metadata is
  'Public recording or announcement snapshot for the private library; never authorization or live-state evidence.';
comment on column public.bookmarks.item_kind is
  'recording uses a canonical YouTube video ID; upcoming uses upcoming:<schedule UUID>. Saving does not enable reminders.';

-- Saves are insert-or-ignore and removal is delete. No UPDATE policy needed.
commit;
