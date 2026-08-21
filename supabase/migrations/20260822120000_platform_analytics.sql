-- v0.5 Backend Foundation — Checkpoint 3, Phase 1 support
--
-- Checkpoint 1's schema covered profiles/applications/organizations/terms/audit_logs
-- but not the aggregate ViewerAnalyticsModel AdminDatabaseService also persists.
-- Singleton table: `id boolean primary key default true` + `check (id)` means at
-- most one row can ever exist (same style as terms_and_conditions' partial unique
-- index for "only one active version" -- a constraint-enforced invariant instead
-- of trusting application code).
create table public.platform_analytics (
  id boolean primary key default true,
  total_guest_sessions integer not null default 0,
  total_registered_google_users integer not null default 0,
  total_lecture_bookmarks integer not null default 0,
  total_auditorium_rsvps integer not null default 0,
  total_broadcast_hours double precision not null default 0,
  active_viewers_live integer not null default 0,
  last_refreshed timestamptz not null default now(),

  constraint platform_analytics_singleton check (id)
);

comment on table public.platform_analytics is
  'Aggregated platform telemetry (single row). Port of ViewerAnalyticsModel.';

-- Admin-tier only -- internal telemetry, not public-facing content (unlike
-- terms_and_conditions, which is deliberately public-read).
alter table public.platform_analytics enable row level security;

create policy platform_analytics_select_admin
  on public.platform_analytics for select
  using (public.is_admin_tier());

create policy platform_analytics_write_admin
  on public.platform_analytics for all
  using (public.is_admin_tier())
  with check (public.is_admin_tier());
