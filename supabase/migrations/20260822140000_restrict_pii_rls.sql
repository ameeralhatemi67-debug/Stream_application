-- v0.5 Backend Foundation — Checkpoint 3, Phase 3: PII field access via RLS
--
-- Closes VULN-AUTH-03 (doc/Audit/01_Security_Data_Protection_Audit.md):
-- confirms phone numbers and restricts venue coordinates to the row owner +
-- admin tiers only.
--
-- broadcaster_applications.phone: already correctly restricted since
-- Checkpoint 1 -- broadcaster_applications_select_own/select_admin are the
-- only SELECT policies on that table, no public/org-member policy exists.
-- Nothing to change; this migration is the "confirm" half of that bullet.
--
-- profiles.latitude/longitude: the base table is correctly owner+admin-only
-- (profiles_select_own/select_admin), but the streamer_public_profiles view
-- (Checkpoint 1) re-exposed latitude/longitude to anon + authenticated for
-- every is_streamer=true row -- exactly the "precise self-disclosed venue
-- coordinates" concern doc/Audit/01 VULN-COMP-02 flagged (individual
-- broadcasters' venues can be closer to a home address than an
-- institution's). Nothing in the app queries this view yet (the map/feed
-- still reads the in-memory mock _streamers list), so this is a zero
-- functional-impact schema fix now, not a live regression. Whichever future
-- checkpoint migrates the public map/discovery read path to Supabase will
-- need its own answer for "how is a streamer's location shown publicly
-- without exposing exact GPS" (fuzzing/rounding, a radius query, etc.) --
-- flagged here rather than solved, since nothing consumes it yet.
--
-- CREATE OR REPLACE VIEW can't drop columns, so this drops and recreates.
drop view if exists public.streamer_public_profiles;

create view public.streamer_public_profiles
  with (security_invoker = false) as
  select
    id, display_name_en, display_name_ar, avatar_url, banner_url,
    bio_en, bio_ar, title_en, title_ar, category_id, tags,
    city_en, city_ar, venue_name_en, venue_name_ar,
    youtube_handle, youtube_video_id, follower_count, is_verified,
    is_currently_live, broadcast_type, active_stream_id, active_viewer_count
  from public.profiles
  where is_streamer = true;

grant select on public.streamer_public_profiles to anon, authenticated;
