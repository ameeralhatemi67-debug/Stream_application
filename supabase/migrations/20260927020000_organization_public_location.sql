-- Application availability and map membership are different scopes.
alter table public.broadcaster_applications
  drop constraint broadcaster_applications_city_id_check,
  add constraint broadcaster_applications_city_id_check
    check (city_id in ('khobar', 'dhahran', 'dammam', 'ahsa', 'jubail', 'riyadh', 'other'));
comment on column public.broadcaster_applications.city_id is
  'Explicit application city choice; NULL means unknown. Only three cities appear on the discovery map.';

-- Preserve the approved public point without copying or publishing private
-- org_venues. Legacy organizations remain unknown until explicitly linked.
alter table public.organizations add column approved_application_id uuid
  references public.broadcaster_applications(id) on delete set null;

create or replace view public.organization_public_profiles
  with (security_invoker = false) as
  select
    o.id, o.name_en, o.name_ar, o.avatar_url, o.banner_url, o.bio_en, o.bio_ar,
    o.category_id, o.tags, o.official_website_url, o.youtube_handle, o.youtube_video_id,
    o.is_verified, o.follower_count, o.is_currently_live, o.broadcast_type,
    o.active_stream_id, o.active_viewer_count, o.active_live_venue_id,
    o.is_temporarily_hidden_from_map,
    s.id as live_session_id,
    coalesce(s.hidden_from_discovery, false) as is_hidden_from_discovery,
    s.ingest_state as live_ingest_state,
    a.city_id, a.venue_name_en, a.venue_name_ar, a.latitude, a.longitude
  from public.organizations o
  -- The organization's own live session only, at most one row per org.
  left join lateral (
    select b.id, b.hidden_from_discovery, b.ingest_state
    from public.broadcast_sessions b
    where b.org_id = o.id and b.state = 'live' and b.stream_id = o.active_stream_id
    order by b.started_at desc
    limit 1
   ) s on true
  -- Application review publishes this venue point, not the member-only branch
  -- directory. A foreign, pending or individual application cannot expose data.
  left join public.broadcaster_applications a
    on a.id = o.approved_application_id
    and a.applicant_profile_id = o.owner_profile_id
    and a.account_type = 'organizationVenue' and a.status = 'approved';
