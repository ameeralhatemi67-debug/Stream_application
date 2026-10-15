-- Guests (anon) keep only the read surface the migrations grant on purpose.
--
-- The hosted project predates the "do not auto-expose new tables" default, so
-- anon still held SELECT/INSERT/UPDATE/DELETE on almost every public table and
-- on both public profile views (seen 2026-10-15). RLS has no anon policy for
-- any of those writes and both views are not updatable, so nothing could use
-- them, but a single permissive policy added later would have exposed a table
-- to signed-out callers. Revoke everything, re-grant the deliberate reads
-- (20260921110000, 20260923120000, 20260925100000, 20261001111022), and stop
-- new tables from inheriting anon privileges. Explicit grants in future
-- migrations still apply. A no-op where the database was already narrow.
begin;

revoke all on all tables in schema public from anon;

grant select on public.academic_categories, public.tags, public.terms_and_conditions,
  public.chat_messages, public.chat_stream_settings, public.streamer_custom_placeholders,
  public.app_flags, public.broadcast_sessions,
  public.streamer_public_profiles, public.organization_public_profiles
  to anon;

alter default privileges in schema public revoke all on tables from anon;

commit;
