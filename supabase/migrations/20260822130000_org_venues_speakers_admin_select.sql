-- v0.5 Backend Foundation — Checkpoint 3, Phase 2 fix
--
-- Checkpoint 1's RLS gave org_venues/org_speakers an admin bypass for writes
-- (org_venues_write_owner_or_admin / org_speakers_write_owner_or_admin) but
-- not for reads -- only org_venues_select_member / org_speakers_select_member
-- exist, both gated on public.is_org_member(), which an admin managing an
-- org they don't own and aren't affiliated with fails. organizations itself
-- got both organizations_select_member AND organizations_select_admin; these
-- two tables were missed. Surfaced now because Phase 2's OrgManagementView
-- read path (ensureOrgDataLoaded/getOrganizationVenues/getOrganizationSpeakers)
-- is admin-facing and would otherwise silently see empty lists.
create policy org_venues_select_admin
  on public.org_venues for select
  using (public.is_admin_tier());

create policy org_speakers_select_admin
  on public.org_speakers for select
  using (public.is_admin_tier());
