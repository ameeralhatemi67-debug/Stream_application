-- P1.4: applicants cannot supply review decisions or change counterparties.
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
  if tg_op = 'INSERT' then
    new.status := 'pending';
    new.reviewed_by := null;
    new.reviewed_at := null;
    new.admin_review_notes := null;
    new.submitted_at := now();
  else
    new.id := old.id;
    new.applicant_profile_id := old.applicant_profile_id;
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
create trigger guard_broadcaster_application_review
before insert or update on public.broadcaster_applications
for each row execute function public.guard_application_review();

create or replace function public.guard_affiliation_transition()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  owner_call boolean;
begin
  if current_user not in ('authenticated', 'anon') or public.is_admin_tier() then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    -- Evaluate authority on the original organization, never caller-supplied IDs.
    new.id := old.id;
    new.organization_id := old.organization_id;
    new.streamer_profile_id := old.streamer_profile_id;
    new.direction := old.direction;
    new.created_at := old.created_at;
  end if;
  owner_call := public.owns_organization(new.organization_id);
  if tg_op = 'INSERT' then
    new.status := 'pending';
    new.resolved_at := null;
    new.created_at := now();
    if not owner_call then
      -- Membership and its permissions must be granted by the organization.
      new.permissions := '{"can_go_live_video":false,"can_go_audio_only":false,"can_change_location":false,"can_edit_description":false,"can_edit_stream_time":false,"can_add_external_links":false}'::jsonb;
    end if;
  elsif not owner_call then
    new.permissions := old.permissions;
    new.proposed_role_en := old.proposed_role_en;
    new.proposed_role_ar := old.proposed_role_ar;
    if not (
      old.streamer_profile_id = (select auth.uid()) and old.status = 'pending'
      and (new.status in ('declined', 'revoked')
        -- Accepting an owner's invitation uses the owner's unchanged grant.
        or (old.direction = 'orgToStreamer' and new.status = 'accepted'))
    ) then
      new.status := old.status;
    end if;
    new.resolved_at := case when new.status is distinct from old.status then now() else old.resolved_at end;
  else
    new.resolved_at := case when new.status is distinct from old.status then now() else old.resolved_at end;
  end if;
  return new;
end;
$$;
revoke execute on function public.guard_affiliation_transition() from public, anon, authenticated;
create trigger guard_affiliation_request_transition
before insert or update on public.affiliation_requests
for each row execute function public.guard_affiliation_transition();
commit;
