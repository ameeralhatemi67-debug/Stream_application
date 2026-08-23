-- ===========================================================================
-- Broadcaster Applications RLS: DELETE Policies for Admin and Applicant Self
-- ===========================================================================

-- 1. Admin-tier accounts can DELETE broadcaster applications
create policy broadcaster_applications_delete_admin
  on public.broadcaster_applications for delete
  using (public.is_admin_tier());

-- 2. Applicants can DELETE/cancel their own pending applications
create policy broadcaster_applications_delete_self
  on public.broadcaster_applications for delete
  using (applicant_profile_id = auth.uid() and status = 'pending');
