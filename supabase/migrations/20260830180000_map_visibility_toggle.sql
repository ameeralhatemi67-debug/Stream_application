-- Cluster 4 — Task 18: Temporary Removal of Streamer from Map
--
-- No new table/RLS needed: profiles_update_admin and
-- organizations_update_owner_or_admin (20260821203100) already let an
-- admin-tier account update either table, and the public views already
-- filter by the columns listed there. This just adds the flag column to
-- both backing tables and republishes the two public views to include it,
-- so loadVerifiedStreamersFromBackend can read it and the discovery/map
-- queries can exclude it without another round trip.
alter table public.profiles
  add column is_temporarily_hidden_from_map boolean not null default false;

alter table public.organizations
  add column is_temporarily_hidden_from_map boolean not null default false;

create or replace view public.streamer_public_profiles
  with (security_invoker = false) as
  select
    id, display_name_en, display_name_ar, avatar_url, banner_url,
    bio_en, bio_ar, title_en, title_ar, category_id, tags,
    city_en, city_ar, venue_name_en, venue_name_ar, latitude, longitude,
    youtube_handle, youtube_video_id, follower_count, is_verified,
    is_currently_live, broadcast_type, active_stream_id, active_viewer_count,
    is_temporarily_hidden_from_map
  from public.profiles
  where is_streamer = true;

grant select on public.streamer_public_profiles to anon, authenticated;

create or replace view public.organization_public_profiles
  with (security_invoker = false) as
  select
    id, name_en, name_ar, avatar_url, banner_url, bio_en, bio_ar,
    category_id, tags, official_website_url, youtube_handle, youtube_video_id,
    is_verified, follower_count, is_currently_live, broadcast_type,
    active_stream_id, active_viewer_count, active_live_venue_id,
    is_temporarily_hidden_from_map
  from public.organizations;

grant select on public.organization_public_profiles to anon, authenticated;
