-- P1.10(b) completion, 05 D-21: policy quality, part 2 of 2.
--
-- This finishes the two items `supabase/tests/policy_matrix.md` recorded as
-- reviewed-but-open after 20260920140000:
--
--   1. The seven remaining `for all` policies become explicit per-command
--      policies. `for all` on a table whose SELECT is meant to be wider than
--      its writes is one careless edit away from widening the write path, and
--      it makes the access matrix unreadable.
--   2. The 32 policies created before 20260920 that omit a role clause are
--      addressed to PUBLIC, so PostgreSQL evaluates them for `anon` too. They
--      deny anon today only because every predicate resolves through
--      `auth.uid()`, which is null for an anonymous request -- a single
--      `or <something>` away from a hole. D-21 asks for the explicit role.
--
-- Predicates are reproduced from the live `pg_policies` catalog (read from a
-- local stack with the whole chain applied), not retyped from the original
-- migrations, so the authority of each policy is unchanged. The only
-- deliberate rewrites are `auth.uid()` -> `(select auth.uid())`, which lets
-- the planner evaluate the uid once per statement instead of once per row
-- (D-21), and an explicit `with check` on the UPDATE policies that previously
-- relied on PostgreSQL reusing `using` for the new row.
--
-- `terms_and_conditions` keeps anon SELECT: the legal text has to be readable
-- before sign-in. Every other recreated policy becomes `to authenticated`;
-- anonymous reads of profile and organization data go through the two public
-- views (`streamer_public_profiles`, `organization_public_profiles`), never
-- through these tables.
begin;

-- ---------------------------------------------------------------------------
-- 1. profiles
-- ---------------------------------------------------------------------------
drop policy profiles_select_own on public.profiles;
drop policy profiles_select_admin on public.profiles;
drop policy profiles_insert_self on public.profiles;
drop policy profiles_update_own on public.profiles;
drop policy profiles_update_admin on public.profiles;

create policy profiles_select_own on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy profiles_select_admin on public.profiles
  for select to authenticated using (public.is_admin_tier());
create policy profiles_insert_self on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);
create policy profiles_update_own on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);
create policy profiles_update_admin on public.profiles
  for update to authenticated
  using (public.is_admin_tier())
  with check (public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- 2. organizations
-- ---------------------------------------------------------------------------
drop policy organizations_select_member on public.organizations;
drop policy organizations_select_admin on public.organizations;
drop policy organizations_insert_admin on public.organizations;
drop policy organizations_update_owner_or_admin on public.organizations;

create policy organizations_select_member on public.organizations
  for select to authenticated using (public.is_org_member(id));
create policy organizations_select_admin on public.organizations
  for select to authenticated using (public.is_admin_tier());
create policy organizations_insert_admin on public.organizations
  for insert to authenticated with check (public.is_admin_tier());
create policy organizations_update_owner_or_admin on public.organizations
  for update to authenticated
  using (public.owns_organization(id) or public.is_admin_tier())
  with check (public.owns_organization(id) or public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- 3. org_venues — select stays member/admin; the `for all` write policy
--    becomes insert/update/delete for the org owner or an admin.
-- ---------------------------------------------------------------------------
drop policy org_venues_select_member on public.org_venues;
drop policy org_venues_select_admin on public.org_venues;
drop policy org_venues_write_owner_or_admin on public.org_venues;

create policy org_venues_select_member on public.org_venues
  for select to authenticated using (public.is_org_member(organization_id));
create policy org_venues_select_admin on public.org_venues
  for select to authenticated using (public.is_admin_tier());
create policy org_venues_insert_owner_or_admin on public.org_venues
  for insert to authenticated
  with check (public.owns_organization(organization_id) or public.is_admin_tier());
create policy org_venues_update_owner_or_admin on public.org_venues
  for update to authenticated
  using (public.owns_organization(organization_id) or public.is_admin_tier())
  with check (public.owns_organization(organization_id) or public.is_admin_tier());
create policy org_venues_delete_owner_or_admin on public.org_venues
  for delete to authenticated
  using (public.owns_organization(organization_id) or public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- 4. org_speakers — same shape as org_venues.
-- ---------------------------------------------------------------------------
drop policy org_speakers_select_member on public.org_speakers;
drop policy org_speakers_select_admin on public.org_speakers;
drop policy org_speakers_write_owner_or_admin on public.org_speakers;

create policy org_speakers_select_member on public.org_speakers
  for select to authenticated using (public.is_org_member(organization_id));
create policy org_speakers_select_admin on public.org_speakers
  for select to authenticated using (public.is_admin_tier());
create policy org_speakers_insert_owner_or_admin on public.org_speakers
  for insert to authenticated
  with check (public.owns_organization(organization_id) or public.is_admin_tier());
create policy org_speakers_update_owner_or_admin on public.org_speakers
  for update to authenticated
  using (public.owns_organization(organization_id) or public.is_admin_tier())
  with check (public.owns_organization(organization_id) or public.is_admin_tier());
create policy org_speakers_delete_owner_or_admin on public.org_speakers
  for delete to authenticated
  using (public.owns_organization(organization_id) or public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- 5. affiliation_requests — "party" = the requesting streamer, the target
--    org's owner, or an admin. Transition rules live in
--    guard_affiliation_transition (P1.4); this is only the role clause.
--    There is deliberately no DELETE policy: a request is cancelled by moving
--    its status, so the history survives.
-- ---------------------------------------------------------------------------
drop policy affiliation_requests_select_party on public.affiliation_requests;
drop policy affiliation_requests_insert_party on public.affiliation_requests;
drop policy affiliation_requests_update_party on public.affiliation_requests;

create policy affiliation_requests_select_party on public.affiliation_requests
  for select to authenticated
  using (
    streamer_profile_id = (select auth.uid())
    or public.owns_organization(organization_id)
    or public.is_admin_tier()
  );
create policy affiliation_requests_insert_party on public.affiliation_requests
  for insert to authenticated
  with check (
    (direction = 'streamerToOrg' and streamer_profile_id = (select auth.uid()))
    or (direction = 'orgToStreamer' and public.owns_organization(organization_id))
    or public.is_admin_tier()
  );
create policy affiliation_requests_update_party on public.affiliation_requests
  for update to authenticated
  using (
    streamer_profile_id = (select auth.uid())
    or public.owns_organization(organization_id)
    or public.is_admin_tier()
  )
  with check (
    streamer_profile_id = (select auth.uid())
    or public.owns_organization(organization_id)
    or public.is_admin_tier()
  );

-- ---------------------------------------------------------------------------
-- 6. broadcaster_applications — guard_application_review (P1.4) forces
--    status='pending' and nulls the review columns on a client write; this is
--    only the role clause.
-- ---------------------------------------------------------------------------
drop policy broadcaster_applications_select_own on public.broadcaster_applications;
drop policy broadcaster_applications_select_admin on public.broadcaster_applications;
drop policy broadcaster_applications_insert_self on public.broadcaster_applications;
drop policy broadcaster_applications_update_own_pending on public.broadcaster_applications;
drop policy broadcaster_applications_update_admin on public.broadcaster_applications;
drop policy broadcaster_applications_delete_self on public.broadcaster_applications;
drop policy broadcaster_applications_delete_admin on public.broadcaster_applications;

create policy broadcaster_applications_select_own on public.broadcaster_applications
  for select to authenticated
  using (applicant_profile_id = (select auth.uid()));
create policy broadcaster_applications_select_admin on public.broadcaster_applications
  for select to authenticated using (public.is_admin_tier());
create policy broadcaster_applications_insert_self on public.broadcaster_applications
  for insert to authenticated
  with check (applicant_profile_id = (select auth.uid()));
create policy broadcaster_applications_update_own_pending on public.broadcaster_applications
  for update to authenticated
  using (applicant_profile_id = (select auth.uid()) and status = 'pending')
  with check (applicant_profile_id = (select auth.uid()) and status = 'pending');
create policy broadcaster_applications_update_admin on public.broadcaster_applications
  for update to authenticated
  using (public.is_admin_tier())
  with check (public.is_admin_tier());
create policy broadcaster_applications_delete_self on public.broadcaster_applications
  for delete to authenticated
  using (applicant_profile_id = (select auth.uid()) and status = 'pending');
create policy broadcaster_applications_delete_admin on public.broadcaster_applications
  for delete to authenticated using (public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- 7. audit_logs — admin read only. Inserts stay RPC-only through
--    log_audit_event(); no INSERT policy is intentional.
-- ---------------------------------------------------------------------------
drop policy audit_logs_select_admin on public.audit_logs;
create policy audit_logs_select_admin on public.audit_logs
  for select to authenticated using (public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- 8. platform_analytics — internal telemetry, admin-only in all four
--    commands. Split so an accidental widening of the read does not widen the
--    write with it.
-- ---------------------------------------------------------------------------
drop policy platform_analytics_select_admin on public.platform_analytics;
drop policy platform_analytics_write_admin on public.platform_analytics;

create policy platform_analytics_select_admin on public.platform_analytics
  for select to authenticated using (public.is_admin_tier());
create policy platform_analytics_insert_admin on public.platform_analytics
  for insert to authenticated with check (public.is_admin_tier());
create policy platform_analytics_update_admin on public.platform_analytics
  for update to authenticated
  using (public.is_admin_tier()) with check (public.is_admin_tier());
create policy platform_analytics_delete_admin on public.platform_analytics
  for delete to authenticated using (public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- 9. terms_and_conditions — public legal text: anon SELECT is the point, so
--    that policy is the one place a role clause names `anon` explicitly.
--    Writes are admin-only, split per command.
-- ---------------------------------------------------------------------------
drop policy terms_select_public on public.terms_and_conditions;
drop policy terms_write_admin on public.terms_and_conditions;

create policy terms_select_public on public.terms_and_conditions
  for select to anon, authenticated using (true);
create policy terms_insert_admin on public.terms_and_conditions
  for insert to authenticated with check (public.is_admin_tier());
create policy terms_update_admin on public.terms_and_conditions
  for update to authenticated
  using (public.is_admin_tier()) with check (public.is_admin_tier());
create policy terms_delete_admin on public.terms_and_conditions
  for delete to authenticated using (public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- 10. academic_categories — public taxonomy read, admin writes.
-- ---------------------------------------------------------------------------
drop policy academic_categories_write_admin on public.academic_categories;

create policy academic_categories_insert_admin on public.academic_categories
  for insert to authenticated with check (public.is_admin_tier());
create policy academic_categories_update_admin on public.academic_categories
  for update to authenticated
  using (public.is_admin_tier()) with check (public.is_admin_tier());
create policy academic_categories_delete_admin on public.academic_categories
  for delete to authenticated using (public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- 11. chat_banned_keywords — the single `for all` policy was also the only
--     SELECT path, so splitting it has to restate the admin read explicitly
--     or the moderation screen stops loading the list.
-- ---------------------------------------------------------------------------
drop policy chat_banned_keywords_admin_only on public.chat_banned_keywords;

create policy chat_banned_keywords_select_admin on public.chat_banned_keywords
  for select to authenticated using (public.is_admin_tier());
create policy chat_banned_keywords_insert_admin on public.chat_banned_keywords
  for insert to authenticated with check (public.is_admin_tier());
create policy chat_banned_keywords_update_admin on public.chat_banned_keywords
  for update to authenticated
  using (public.is_admin_tier()) with check (public.is_admin_tier());
create policy chat_banned_keywords_delete_admin on public.chat_banned_keywords
  for delete to authenticated using (public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- 12. stream_moderators — the `for all` policy had an asymmetric pair: a
--     looser `using` (the appointer or an admin) and a stricter `with check`
--     (the appointer, and only at a scope they actually control). Splitting
--     keeps that asymmetry exactly: INSERT takes only the strict check,
--     DELETE only the loose using, UPDATE both.
-- ---------------------------------------------------------------------------
drop policy stream_moderators_write_scoped on public.stream_moderators;

create policy stream_moderators_insert_scoped on public.stream_moderators
  for insert to authenticated
  with check (
    assigned_by = (select auth.uid())
    and (
      (scope = 'stream' and public.owns_stream(stream_id))
      or (scope = 'organization' and public.owns_organization(organization_id))
      or (scope = 'global' and public.is_admin_tier())
    )
  );
create policy stream_moderators_update_scoped on public.stream_moderators
  for update to authenticated
  using (assigned_by = (select auth.uid()) or public.is_admin_tier())
  with check (
    assigned_by = (select auth.uid())
    and (
      (scope = 'stream' and public.owns_stream(stream_id))
      or (scope = 'organization' and public.owns_organization(organization_id))
      or (scope = 'global' and public.is_admin_tier())
    )
  );
create policy stream_moderators_delete_scoped on public.stream_moderators
  for delete to authenticated
  using (assigned_by = (select auth.uid()) or public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- 13. user_roles / user_permissions — the write halves were already split per
--     command by 20260920140000; only the inherited SELECT policies still had
--     no role clause.
-- ---------------------------------------------------------------------------
drop policy user_roles_select_own_or_admin on public.user_roles;
create policy user_roles_select_own_or_admin on public.user_roles
  for select to authenticated
  using (profile_id = (select auth.uid()) or public.is_admin_tier());

drop policy user_permissions_select_own_or_admin on public.user_permissions;
create policy user_permissions_select_own_or_admin on public.user_permissions
  for select to authenticated
  using (profile_id = (select auth.uid()) or public.is_admin_tier());

-- ---------------------------------------------------------------------------
-- 14. storage.objects — the public-read policy on the streamer-assets bucket
--     also had no role clause. The bucket is public by design (avatars and
--     banners are served straight to unauthenticated viewers), so this is the
--     second and last deliberate `anon` read; it is now explicit, and named
--     like its sibling write policies from 20260920091000.
-- ---------------------------------------------------------------------------
drop policy "Public Access to Streamer Assets" on storage.objects;
create policy streamer_assets_select_public on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'streamer-assets');

commit;
