-- A rejected application is resubmitted in place. The applicant's save puts
-- the same row back in the review queue (pending, review fields cleared), so
-- an approved organization keeps its link to the application. The rejected
-- version stays in application_review_events, which copied the row when it
-- was rejected. Before this, "Reapply" was refused by the update policy.
begin;

create or replace function public.guard_application_review()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_user not in ('authenticated', 'anon') or public.is_admin_tier() then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    new.id := old.id;
    new.applicant_profile_id := old.applicant_profile_id;
  end if;
  if tg_op = 'INSERT' or (old.status = 'rejected' and old.revision_of is null) then
    new.status := 'pending';
    new.reviewed_by := null;
    new.reviewed_at := null;
    new.admin_review_notes := null;
    new.submitted_at := now();
  else
    new.status := old.status;
    new.reviewed_by := old.reviewed_by;
    new.reviewed_at := old.reviewed_at;
    new.admin_review_notes := old.admin_review_notes;
    new.submitted_at := old.submitted_at;
  end if;
  return new;
end;
$$;
revoke execute on function public.guard_application_review() from public, anon, authenticated;

-- Rejected profile edits (revision_of set) and rows an admin removed from the
-- queue stay closed; the applicant starts over from the approved profile or
-- with a new application.
drop policy broadcaster_applications_update_own_pending on public.broadcaster_applications;
create policy broadcaster_applications_update_own_pending on public.broadcaster_applications
  for update to authenticated
  using (applicant_profile_id = (select auth.uid()) and (status = 'pending'
    or (status = 'rejected' and revision_of is null and queue_archived_at is null)))
  with check (applicant_profile_id = (select auth.uid()) and status = 'pending');

commit;
