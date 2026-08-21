-- v0.5 Backend Foundation — Checkpoint 1, Phase 3: Row-Level Security
--
-- Closes VULN-RBAC-01/02/03 and VULN-AUTH-03 from doc/Audit/01_Security_Data_Protection_Audit.md
-- at the data layer: every table below denies all access by default the moment RLS is
-- enabled, and only the policies written here open anything back up. This is what makes
-- the client-side checks in AppProvider/GoRouter (Checkpoint 2 of this version) into a real
-- security boundary instead of a UI convenience anyone could bypass by reading the compiled app.

-- ---------------------------------------------------------------------------
-- Helper functions (SECURITY DEFINER so policies can consult user_roles /
-- organizations / affiliation_requests without needing their own RLS to allow
-- the *calling* row's read — these functions run as their owner, not the
-- caller, precisely so they can see what they need to answer "yes/no").
-- ---------------------------------------------------------------------------

create or replace function public.is_admin_tier()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_roles
    where profile_id = auth.uid()
      and role in ('master_admin', 'admin')
  );
$$;

create or replace function public.owns_organization(org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.organizations
    where id = org_id and owner_profile_id = auth.uid()
  )
  or exists (
    select 1 from public.user_roles
    where profile_id = auth.uid()
      and organization_id = org_id
      and role in ('org_owner', 'org_co_owner')
  );
$$;

create or replace function public.is_org_member(org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.owns_organization(org_id)
  or exists (
    select 1 from public.org_speakers
    where organization_id = org_id and linked_profile_id = auth.uid()
  )
  or exists (
    select 1 from public.affiliation_requests
    where organization_id = org_id
      and streamer_profile_id = auth.uid()
      and status = 'accepted'
  );
$$;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;

create policy profiles_select_own
  on public.profiles for select
  using (auth.uid() = id);

create policy profiles_select_admin
  on public.profiles for select
  using (public.is_admin_tier());

create policy profiles_insert_self
  on public.profiles for insert
  with check (auth.uid() = id);

create policy profiles_update_own
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy profiles_update_admin
  on public.profiles for update
  using (public.is_admin_tier());

-- No DELETE policy: account deletion (audit item #5, doc/Audit/03) goes through
-- a dedicated flow in v0.9, not a raw client DELETE.

-- Public browsing (discovery feed / broadcaster profile screen) needs to show
-- streamer display info to anonymous viewers without exposing `email` on the
-- base table. `security_invoker = false` makes this view evaluate with the
-- view owner's privileges, deliberately bypassing the owner-only RLS above for
-- just these columns — the standard Supabase pattern for a "public profile".
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

-- ---------------------------------------------------------------------------
-- organizations
-- ---------------------------------------------------------------------------
alter table public.organizations enable row level security;

create policy organizations_select_member
  on public.organizations for select
  using (public.is_org_member(id));

create policy organizations_select_admin
  on public.organizations for select
  using (public.is_admin_tier());

-- Orgs are created as a side effect of an admin approving an
-- organizationVenue broadcaster_applications row, not self-service signup.
create policy organizations_insert_admin
  on public.organizations for insert
  with check (public.is_admin_tier());

create policy organizations_update_owner_or_admin
  on public.organizations for update
  using (public.owns_organization(id) or public.is_admin_tier());

create view public.organization_public_profiles
  with (security_invoker = false) as
  select
    id, name_en, name_ar, avatar_url, banner_url, bio_en, bio_ar,
    category_id, tags, official_website_url, youtube_handle, youtube_video_id,
    is_verified, follower_count, is_currently_live, broadcast_type,
    active_stream_id, active_viewer_count, active_live_venue_id
  from public.organizations;

grant select on public.organization_public_profiles to anon, authenticated;

-- ---------------------------------------------------------------------------
-- org_venues / org_speakers — member read, owner/co-owner/admin write, per
-- Phase 3's spec. (Unlike organizations/profiles above, no public view is
-- added here yet — if the org profile screen needs to show venues/speakers to
-- anonymous viewers once the UI reads from Supabase, add one then rather than
-- widening this policy speculatively now.)
-- ---------------------------------------------------------------------------
alter table public.org_venues enable row level security;

create policy org_venues_select_member
  on public.org_venues for select
  using (public.is_org_member(organization_id));

create policy org_venues_write_owner_or_admin
  on public.org_venues for all
  using (public.owns_organization(organization_id) or public.is_admin_tier())
  with check (public.owns_organization(organization_id) or public.is_admin_tier());

alter table public.org_speakers enable row level security;

create policy org_speakers_select_member
  on public.org_speakers for select
  using (public.is_org_member(organization_id));

create policy org_speakers_write_owner_or_admin
  on public.org_speakers for all
  using (public.owns_organization(organization_id) or public.is_admin_tier())
  with check (public.owns_organization(organization_id) or public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- affiliation_requests — not explicitly called out in Phase 3's checklist,
-- but it carries the same kind of cross-user data as broadcaster_applications
-- and can't ship without RLS. Readable/writable by its two counterparties
-- (the applying/invited streamer, the target org's owner/co-owner) or admin.
-- ---------------------------------------------------------------------------
alter table public.affiliation_requests enable row level security;

create policy affiliation_requests_select_party
  on public.affiliation_requests for select
  using (
    streamer_profile_id = auth.uid()
    or public.owns_organization(organization_id)
    or public.is_admin_tier()
  );

create policy affiliation_requests_insert_party
  on public.affiliation_requests for insert
  with check (
    (direction = 'streamerToOrg' and streamer_profile_id = auth.uid())
    or (direction = 'orgToStreamer' and public.owns_organization(organization_id))
    or public.is_admin_tier()
  );

create policy affiliation_requests_update_party
  on public.affiliation_requests for update
  using (
    streamer_profile_id = auth.uid()
    or public.owns_organization(organization_id)
    or public.is_admin_tier()
  );

-- ---------------------------------------------------------------------------
-- broadcaster_applications
-- ---------------------------------------------------------------------------
alter table public.broadcaster_applications enable row level security;

create policy broadcaster_applications_select_own
  on public.broadcaster_applications for select
  using (applicant_profile_id = auth.uid());

create policy broadcaster_applications_select_admin
  on public.broadcaster_applications for select
  using (public.is_admin_tier());

create policy broadcaster_applications_insert_self
  on public.broadcaster_applications for insert
  with check (applicant_profile_id = auth.uid());

-- Applicant may keep editing their own application while it's still pending.
-- Note: this is row-level, not column-level — a pending applicant could still
-- technically set admin_review_notes/reviewed_by themselves. Locking that down
-- needs column-level privileges (REVOKE/GRANT per-column) or a BEFORE UPDATE
-- trigger; flagged here as a follow-up rather than solved in this migration.
create policy broadcaster_applications_update_own_pending
  on public.broadcaster_applications for update
  using (applicant_profile_id = auth.uid() and status = 'pending')
  with check (applicant_profile_id = auth.uid() and status = 'pending');

create policy broadcaster_applications_update_admin
  on public.broadcaster_applications for update
  using (public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- terms_and_conditions — public read, admin-tier write only.
-- ---------------------------------------------------------------------------
alter table public.terms_and_conditions enable row level security;

create policy terms_select_public
  on public.terms_and_conditions for select
  using (true);

create policy terms_write_admin
  on public.terms_and_conditions for all
  using (public.is_admin_tier())
  with check (public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- audit_logs — admin-tier read only, system-inserted only. Deliberately no
-- INSERT/UPDATE/DELETE policy for anon/authenticated: with RLS enabled and no
-- matching policy, those commands are denied outright for those roles. Writes
-- happen exclusively through log_audit_event(), which runs as its (privileged)
-- owner and derives the actor's identity from auth.uid() itself rather than
-- trusting whatever the caller passes in.
-- ---------------------------------------------------------------------------
alter table public.audit_logs enable row level security;

create policy audit_logs_select_admin
  on public.audit_logs for select
  using (public.is_admin_tier());

create or replace function public.log_audit_event(
  p_organization_id uuid,
  p_action text,
  p_description_en text,
  p_description_ar text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_email text;
  v_actor_name text;
  v_id uuid;
begin
  select email, coalesce(display_name_en, email, 'Unknown')
    into v_actor_email, v_actor_name
    from public.profiles where id = auth.uid();

  insert into public.audit_logs (
    organization_id, actor_profile_id, actor_email, actor_name,
    action, description_en, description_ar, metadata
  ) values (
    p_organization_id, auth.uid(), coalesce(v_actor_email, 'unknown'), coalesce(v_actor_name, 'Unknown'),
    p_action, p_description_en, p_description_ar, p_metadata
  )
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.log_audit_event(uuid, text, text, text, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- user_roles / user_permissions — schema-only tables (v0.8 builds the admin
-- UI on top of these); RLS still applied now so they're never open by
-- default. Note: the roadmap's master_admin-grants-master_admin/admin vs.
-- admin-grants-org_owner/org_co_owner nuance is deferred to v0.8 — for v0.5,
-- any admin-tier profile can write either table.
-- ---------------------------------------------------------------------------
alter table public.user_roles enable row level security;

create policy user_roles_select_own_or_admin
  on public.user_roles for select
  using (profile_id = auth.uid() or public.is_admin_tier());

create policy user_roles_write_admin
  on public.user_roles for all
  using (public.is_admin_tier())
  with check (public.is_admin_tier());

alter table public.user_permissions enable row level security;

create policy user_permissions_select_own_or_admin
  on public.user_permissions for select
  using (profile_id = auth.uid() or public.is_admin_tier());

create policy user_permissions_write_admin
  on public.user_permissions for all
  using (public.is_admin_tier())
  with check (public.is_admin_tier());
