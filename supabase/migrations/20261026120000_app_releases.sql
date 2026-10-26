-- App releases for the update checker (ADR-017, owner plan 2026-10-26).
--
-- The Android app downloaded from the website has no store to update it. On
-- start and on return to the foreground every install reads the newest
-- published release of its own channel and compares its version code:
-- * below min_supported_code: a full-screen "update required" page;
-- * below version_code: a prompt it can dismiss, plus an Update row in
--   Settings.
-- 'apk' is the downloaded APK; its link is a file on the website or in the
-- app-releases bucket, or, once the app is on Google Play, the Play listing.
-- 'play' is the Google Play build, which may only point at its Play listing
-- (Play forbids updating an app any other way).
-- Guests read published rows; master admins write. To withdraw a release,
-- clear published_at.

create table public.app_releases (
  id uuid primary key default gen_random_uuid(),
  channel text not null check (channel in ('apk', 'play')),
  version_code integer not null check (version_code > 0),
  version_name text not null check (version_name ~ '^[0-9]+(\.[0-9]+){1,3}$'),
  min_supported_code integer not null default 0
    check (min_supported_code >= 0 and min_supported_code <= version_code),
  download_url text not null check (download_url ~ '^https://[^[:space:]]+$'),
  sha256 text check (sha256 ~ '^[0-9a-f]{64}$'),
  size_bytes bigint check (size_bytes > 0),
  notes_en text not null default '' check (char_length(notes_en) <= 1000),
  notes_ar text not null default '' check (char_length(notes_ar) <= 1000),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  unique (channel, version_code),
  constraint app_releases_play_listing_only check (channel <> 'play'
    or download_url like 'https://play.google.com/store/apps/details?id=sa.hadayah.streamer_app%'),
  -- The download page shows the size and checksum of a published APK. The
  -- last APK release may instead send people to the Play listing.
  constraint app_releases_apk_published_complete check (channel <> 'apk'
    or published_at is null
    or download_url like 'https://play.google.com/store/apps/details?id=sa.hadayah.streamer_app%'
    or (sha256 is not null and size_bytes is not null))
);
comment on table public.app_releases is
  'Releases of the phone app per channel (apk, play). Installs compare their version code with the newest published row: below min_supported_code they must update, below version_code they are offered the update. Written by master admins only.';

alter table public.app_releases enable row level security;
revoke all on public.app_releases from public, anon, authenticated;
grant select on public.app_releases to anon, authenticated;
grant insert, update, delete on public.app_releases to authenticated;

create policy app_releases_select_anon on public.app_releases
  for select to anon using (published_at is not null and published_at <= now());
create policy app_releases_select_authenticated on public.app_releases
  for select to authenticated using (
    (published_at is not null and published_at <= now()) or public.is_master_admin());
create policy app_releases_insert_master on public.app_releases
  for insert to authenticated with check (public.is_master_admin());
create policy app_releases_update_master on public.app_releases
  for update to authenticated using (public.is_master_admin())
  with check (public.is_master_admin());
create policy app_releases_delete_master on public.app_releases
  for delete to authenticated using (public.is_master_admin());

-- The APK files themselves. Public, so the download page and the app can link
-- to them directly; uploaded from the Supabase dashboard (the project-wide
-- upload limit must be at least this bucket's). A browser may label an .apk
-- upload either way, so both types are accepted; nothing else is.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'app-releases',
  'app-releases',
  true,
  209715200, -- 200 MB
  array['application/vnd.android.package-archive', 'application/octet-stream']
)
on conflict (id) do update set
  public = true,
  file_size_limit = 209715200,
  allowed_mime_types = array['application/vnd.android.package-archive', 'application/octet-stream'];
