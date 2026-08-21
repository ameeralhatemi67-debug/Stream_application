-- v0.5 Backend Foundation — Checkpoint 1, Phase 2: Schema Design
--
-- Straight port of the existing client-side Dart models (lib/features/admin/models,
-- lib/features/organization/models, lib/features/profile/models) into real Postgres
-- tables, per doc/Roadmap/v0.5_Backend_Foundation.md. Every FK/column below traces back
-- to a field that already exists in one of those Dart classes — this is not a redesign.
--
-- Naming convention: snake_case columns, `_en`/`_ar` suffixes preserved exactly as the
-- Dart models use them (the app's bilingual UI reads both unconditionally).

create extension if not exists "pgcrypto"; -- gen_random_uuid()

-- ---------------------------------------------------------------------------
-- Shared trigger: keep `updated_at` current on every UPDATE.
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- profiles — mirrors auth.users (1:1), extended with the display + broadcaster
-- fields every individual account (viewer or streamer) can carry. Mirrors
-- lib/features/profile/models/user_account_model.dart (UserProfileModel) and the
-- non-organization fields of lib/features/profile/models/streamer_models.dart
-- (StreamerModel). Organization-only fields (venues, roster) live in their own
-- tables below instead of here.
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  display_name_en text,
  display_name_ar text,
  avatar_url text,
  banner_url text,
  bio_en text,
  bio_ar text,
  title_en text,
  title_ar text,
  organization_en text,
  organization_ar text,

  -- Broadcaster fields (null/false for plain viewers; populated once a
  -- broadcaster_applications row for this profile is approved).
  is_streamer boolean not null default false,
  is_verified boolean not null default false,
  category_id text,
  tags text[] not null default '{}',
  city_en text,
  city_ar text,
  venue_name_en text,
  venue_name_ar text,
  latitude double precision,
  longitude double precision,
  youtube_handle text,
  youtube_video_id text,
  follower_count integer not null default 0,
  total_lecture_hours integer not null default 0,
  upcoming_schedule_en text[] not null default '{}',
  upcoming_schedule_ar text[] not null default '{}',

  -- Ephemeral live-broadcast state (StreamerModel.isCurrentlyLive / broadcastType /
  -- activeStreamId / activeViewerCount).
  is_currently_live boolean not null default false,
  broadcast_type text not null default 'offline'
    check (broadcast_type in ('offline', 'liveVideo', 'liveAudio')),
  active_stream_id text,
  active_viewer_count integer not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create index profiles_email_idx on public.profiles (email);
create index profiles_is_streamer_idx on public.profiles (is_streamer) where is_streamer;

comment on table public.profiles is
  'Mirrors auth.users; adds display name/avatar/role plus broadcaster fields for streamer accounts. Port of UserProfileModel + non-org StreamerModel fields.';

-- ---------------------------------------------------------------------------
-- organizations — the public entity for an org-type broadcaster (StreamerModel
-- rows with isOrganization = true), separate from `profiles` because orgs have
-- their own venues/roster that individual streamers don't.
-- ---------------------------------------------------------------------------
create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  owner_profile_id uuid not null references public.profiles (id) on delete restrict,

  name_en text not null,
  name_ar text not null,
  avatar_url text,
  banner_url text,
  bio_en text,
  bio_ar text,
  category_id text,
  tags text[] not null default '{}',
  official_website_url text,
  youtube_handle text,
  youtube_video_id text,
  featured_channel_handles text[] not null default '{}',
  is_verified boolean not null default false,
  follower_count integer not null default 0,
  upcoming_schedule_en text[] not null default '{}',
  upcoming_schedule_ar text[] not null default '{}',

  is_currently_live boolean not null default false,
  broadcast_type text not null default 'offline'
    check (broadcast_type in ('offline', 'liveVideo', 'liveAudio')),
  active_stream_id text,
  active_viewer_count integer not null default 0,
  active_live_venue_id uuid, -- FK added below, after org_venues exists
  active_live_speaker_ids uuid[] not null default '{}',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_organizations_updated_at
  before update on public.organizations
  for each row execute function public.set_updated_at();

create index organizations_owner_idx on public.organizations (owner_profile_id);

comment on table public.organizations is
  'Org-type broadcaster entity. Port of the isOrganization=true branch of StreamerModel.';

-- ---------------------------------------------------------------------------
-- org_venues — port of OrgVenueBranchModel (lib/features/organization/models/org_venue_branch_model.dart).
-- ---------------------------------------------------------------------------
create table public.org_venues (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,

  name_en text not null,
  name_ar text not null,
  city_en text not null,
  city_ar text not null,
  latitude double precision not null,
  longitude double precision not null,
  seating_capacity integer not null default 100,
  is_main_headquarters boolean not null default false,
  room_number_or_hall text,
  available_facilities text[] not null default '{}',
  address_en text,
  address_ar text,

  created_at timestamptz not null default now()
);

create index org_venues_org_idx on public.org_venues (organization_id);

alter table public.organizations
  add constraint organizations_active_live_venue_fkey
  foreign key (active_live_venue_id) references public.org_venues (id) on delete set null;

comment on table public.org_venues is
  'Physical campus/venue branches of an organization. Port of OrgVenueBranchModel.';

-- ---------------------------------------------------------------------------
-- org_speakers — port of OrgSpeakerModel (lib/features/organization/models/org_speaker_model.dart).
-- `permissions` stored as jsonb, matching OrgBroadcasterPermissions.toJson()/fromJson() 1:1.
-- ---------------------------------------------------------------------------
create table public.org_speakers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  linked_profile_id uuid references public.profiles (id) on delete set null,

  name_en text not null,
  name_ar text not null,
  role_or_title_en text not null,
  role_or_title_ar text not null,
  avatar_url text,
  bio_en text not null default '',
  bio_ar text not null default '',
  is_permanent_staff boolean not null default true,
  linked_email text,
  youtube_handle text,
  permissions jsonb not null default '{
    "can_go_live_video": true,
    "can_go_audio_only": true,
    "can_change_location": false,
    "can_edit_description": true,
    "can_edit_stream_time": false,
    "can_add_external_links": true
  }'::jsonb,

  created_at timestamptz not null default now()
);

create index org_speakers_org_idx on public.org_speakers (organization_id);
create index org_speakers_linked_profile_idx on public.org_speakers (linked_profile_id);

comment on table public.org_speakers is
  'Instructor/speaker roster within an organization. Port of OrgSpeakerModel; permissions column mirrors OrgBroadcasterPermissions JSON shape exactly.';

-- ---------------------------------------------------------------------------
-- affiliation_requests — port of OrgAffiliationRequestModel
-- (lib/features/organization/models/org_affiliation_request_model.dart). An
-- accepted row IS the membership record — no separate org_members table.
-- ---------------------------------------------------------------------------
create table public.affiliation_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  streamer_profile_id uuid not null references public.profiles (id) on delete cascade,

  direction text not null check (direction in ('streamerToOrg', 'orgToStreamer')),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'revoked')),
  proposed_role_en text,
  proposed_role_ar text,
  note text not null default '',
  permissions jsonb not null default '{
    "can_go_live_video": true,
    "can_go_audio_only": true,
    "can_change_location": false,
    "can_edit_description": true,
    "can_edit_stream_time": false,
    "can_add_external_links": true
  }'::jsonb,

  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index affiliation_requests_org_idx on public.affiliation_requests (organization_id);
create index affiliation_requests_streamer_idx on public.affiliation_requests (streamer_profile_id);
create index affiliation_requests_status_idx on public.affiliation_requests (status);

comment on table public.affiliation_requests is
  'Streamer <-> Organization join/invite requests. Port of OrgAffiliationRequestModel. An accepted row is the active membership record.';

-- ---------------------------------------------------------------------------
-- broadcaster_applications — port of BroadcasterApplicationModel
-- (lib/features/admin/models/broadcaster_application_model.dart).
-- ---------------------------------------------------------------------------
create table public.broadcaster_applications (
  id uuid primary key default gen_random_uuid(),
  applicant_profile_id uuid not null references public.profiles (id) on delete cascade,

  account_type text not null check (account_type in ('individualScholar', 'organizationVenue')),
  applicant_name_en text not null,
  applicant_name_ar text not null,
  email text not null,
  phone text not null,

  academic_title_en text,
  academic_title_ar text,
  institution_en text,
  institution_ar text,
  category_id text not null,
  tags text[] not null default '{}',

  organization_type text,
  venue_name_en text not null default '',
  venue_name_ar text not null default '',
  latitude double precision,
  longitude double precision,
  seating_capacity integer not null default 0,
  official_website_url text,

  youtube_channel_url text not null default '',
  youtube_handle text not null default '',
  bio_en text not null default '',
  bio_ar text not null default '',
  avatar_url text,
  banner_url text,

  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'suspended')),
  admin_review_notes text,
  reviewed_by uuid references public.profiles (id) on delete set null,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create index broadcaster_applications_applicant_idx on public.broadcaster_applications (applicant_profile_id);
create index broadcaster_applications_status_idx on public.broadcaster_applications (status);

comment on table public.broadcaster_applications is
  'Streamer/organization verification applications. Port of BroadcasterApplicationModel.';

-- ---------------------------------------------------------------------------
-- terms_and_conditions — port of TermsAndConditionsModel
-- (lib/features/admin/models/terms_and_conditions_model.dart). Only one row
-- should have is_active = true at a time; enforced by the partial unique index
-- below rather than application logic.
-- ---------------------------------------------------------------------------
create table public.terms_and_conditions (
  version text primary key,
  last_updated timestamptz not null default now(),
  terms_of_service_en text not null,
  terms_of_service_ar text not null,
  broadcaster_guidelines_en text not null,
  broadcaster_guidelines_ar text not null,
  privacy_policy_en text not null,
  privacy_policy_ar text not null,
  is_active boolean not null default false
);

create unique index terms_and_conditions_single_active_idx
  on public.terms_and_conditions (is_active)
  where is_active;

comment on table public.terms_and_conditions is
  'Versioned Terms of Service / Broadcaster Guidelines / Privacy Policy. Port of TermsAndConditionsModel.';

-- ---------------------------------------------------------------------------
-- audit_logs — port of OrgAuditLogEntry (lib/features/organization/models/org_audit_log_entry.dart),
-- generalized with a nullable organization_id so it can also record
-- platform-level (non-org) admin actions later. System-inserted only — see
-- the RLS migration for why there is no direct INSERT policy.
-- ---------------------------------------------------------------------------
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations (id) on delete cascade,
  actor_profile_id uuid references public.profiles (id) on delete set null,
  actor_email text not null,
  actor_name text not null,
  action text not null check (action in (
    'createOrganization', 'updateOrganizationProfile',
    'addVenueBranch', 'updateVenueBranch', 'removeVenueBranch',
    'addSpeakerToRoster', 'updateSpeakerDetails', 'removeSpeakerFromRoster',
    'grantBroadcastPermission', 'revokeBroadcastPermission', 'updatePermissions',
    'assignOwnerRole', 'revokeOwnerRole',
    'startLiveBroadcast', 'endLiveBroadcast',
    'applyBroadcaster', 'submitAffiliationRequest',
    'acceptAffiliationRequest', 'declineAffiliationRequest'
  )),
  description_en text not null,
  description_ar text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index audit_logs_org_idx on public.audit_logs (organization_id);
create index audit_logs_created_at_idx on public.audit_logs (created_at desc);

comment on table public.audit_logs is
  'Append-only administrative/moderation audit trail. Port of OrgAuditLogEntry, organization_id made nullable for platform-level events.';

-- ---------------------------------------------------------------------------
-- user_roles — admin-tier hierarchy from doc/Roadmap/00_Roadmap_Overview.md:
-- master_admin -> admin -> org_owner / org_co_owner (org-scoped). Empty/unused
-- until v0.8 builds the UI to manage it, but created now so v0.8 doesn't need
-- another migration round on tables v0.5 already touches.
-- ---------------------------------------------------------------------------
create table public.user_roles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  role text not null check (role in ('master_admin', 'admin', 'org_owner', 'org_co_owner')),
  organization_id uuid references public.organizations (id) on delete cascade,
  granted_by uuid references public.profiles (id) on delete set null,
  granted_at timestamptz not null default now(),

  -- org_owner / org_co_owner must be scoped to an org; master_admin / admin are platform-wide.
  constraint user_roles_org_scope_chk check (
    (role in ('org_owner', 'org_co_owner') and organization_id is not null)
    or (role in ('master_admin', 'admin') and organization_id is null)
  ),
  unique (profile_id, role, organization_id)
);

create index user_roles_profile_idx on public.user_roles (profile_id);
create index user_roles_org_idx on public.user_roles (organization_id);

comment on table public.user_roles is
  'Admin-tier role grants (master_admin/admin/org_owner/org_co_owner). Schema-only in v0.5; UI arrives in v0.8.';

-- ---------------------------------------------------------------------------
-- user_permissions — per-user checkbox-style granular capability grants,
-- layered on top of any user_roles tier. Same "schema now, UI in v0.8" status.
-- ---------------------------------------------------------------------------
create table public.user_permissions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  permission_key text not null,
  organization_id uuid references public.organizations (id) on delete cascade,
  granted_by uuid references public.profiles (id) on delete set null,
  granted_at timestamptz not null default now(),

  unique (profile_id, permission_key, organization_id)
);

create index user_permissions_profile_idx on public.user_permissions (profile_id);

comment on table public.user_permissions is
  'Granular checkbox-style capability grants layered on top of user_roles. Schema-only in v0.5; UI arrives in v0.8.';
