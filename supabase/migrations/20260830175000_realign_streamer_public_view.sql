-- P1.10 repair: the migration chain could not be applied from scratch.
--
-- `20260822140000_restrict_pii_rls.sql` dropped and recreated
-- `streamer_public_profiles` WITHOUT `latitude`/`longitude` (closing
-- VULN-COMP-02: precise self-disclosed venue coordinates of an individual
-- broadcaster can sit on a home address). `20260830180000_map_visibility_toggle.sql`
-- then re-adds `latitude, longitude` in the MIDDLE of the select list via
-- `create or replace view`, which PostgreSQL refuses:
--
--   ERROR: cannot change name of view column "youtube_handle" to "latitude"
--          (SQLSTATE 42P16)
--
-- `create or replace view` may only APPEND columns, never insert or reorder
-- them. So every `supabase start` / `db reset` aborted at 20260830180000 and
-- no migration after it -- including the whole 20260831* and 20260920* set --
-- had ever been applied to any database. Docker was blamed for the
-- "UNVERIFIED-STATIC" status in earlier sessions; this was the real blocker.
--
-- The repair has to land BEFORE 20260830180000 (a later migration is never
-- reached), and 20260830180000 itself must not be edited. So this migration
-- re-establishes the view with `latitude, longitude` in exactly the position
-- 20260830180000 expects, minus `is_temporarily_hidden_from_map` (that column
-- does not exist on `profiles` until 20260830180000 adds it). 20260830180000's
-- `create or replace view` then only APPENDS that one column, which is legal.
--
-- NOTE ON EXPOSURE, NOT FIXED HERE: restoring `latitude`/`longitude` to an
-- anon-readable view reopens VULN-COMP-02, and 20260830180000 would have done
-- the same had it ever applied. It is required for the map read path
-- (`admin_database_service.dart` reads these columns from this view), and
-- `20260822140000` itself said the public map path "will need its own answer
-- for how a streamer's location is shown publicly without exposing exact GPS
-- (fuzzing/rounding, a radius query)". That answer is a product decision about
-- what the map shows, so it is recorded as an open owner action in
-- `brief/OWNER_ACTIONS.md` and in `supabase/tests/policy_matrix.md` rather
-- than decided here.
begin;

drop view if exists public.streamer_public_profiles;

create view public.streamer_public_profiles
  with (security_invoker = false) as
  select
    id, display_name_en, display_name_ar, avatar_url, banner_url,
    bio_en, bio_ar, title_en, title_ar, category_id, tags,
    city_en, city_ar, venue_name_en, venue_name_ar, latitude, longitude,
    youtube_handle, youtube_video_id, follower_count, is_verified,
    is_currently_live, broadcast_type, active_stream_id, active_viewer_count
  from public.profiles
  where is_streamer = true;

grant select on public.streamer_public_profiles to anon, authenticated;

commit;
