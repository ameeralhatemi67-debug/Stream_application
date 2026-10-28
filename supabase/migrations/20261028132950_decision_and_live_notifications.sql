-- The applicant hears the admin's decision, and a personal live alert names
-- the presenter.
--
-- Until now "approved" and "rejected" notices were added on the reviewing
-- admin's own device, so the applicant was never told. The decision is now a
-- server event for the applicant (the bell, and a push once the event
-- dispatcher runs). Decision pushes are account notices: no switch turns
-- them off.
--
-- A personal live alert had no organization name, so it read "Live now -
-- Your organization". The session payload now carries the presenter's name.
begin;

alter table public.org_v1_events drop constraint org_v1_events_kind_check;
alter table public.org_v1_events add constraint org_v1_events_kind_check check(kind in (
  'invitation','invitation_answered','join_request','join_request_answered',
  'assignment','assignment_changed','assignment_cancelled','assignment_answered','assignment_reminder',
  'membership_changed','show_live','show_ending','transfer_proposed','transfer_cancelled','transfer_completed',
  'application_approved','application_rejected'));

-- Every approve or reject, including a reversed approval (the reversal
-- reason is the note) and the approval of a profile edit.
create function private.application_decision_events() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.status is distinct from old.status and new.status in ('approved','rejected') then
   perform private.org_v1_emit(new.applicant_profile_id,'application_'||new.status,null,null,null,
     new.id::text||':'||extract(epoch from clock_timestamp())::text,
     jsonb_build_object('application_id',new.id,'edit',new.revision_of is not null,
       'organization',new.account_type='organizationVenue',
       'name_en',new.applicant_name_en,'name_ar',new.applicant_name_ar,
       'reason',case when new.status='rejected' then nullif(btrim(coalesce(new.admin_review_notes,'')),'') end));
 end if;
 return new;
end; $$;
create trigger application_decision_events after update of status on public.broadcaster_applications
  for each row execute function private.application_decision_events();
revoke all on function private.application_decision_events() from public,anon,authenticated,service_role;

create or replace function private.org_v1_session_payload(s public.broadcast_sessions) returns jsonb
language sql stable security definer set search_path='' as $$
 select private.org_v1_org_payload(s.org_id)||jsonb_build_object('title_en',s.title_en,'title_ar',s.title_ar,
   'start',s.scheduled_start_at,'state',s.state,'presenter_id',s.owner_id,'revision',s.revision,'end_reason',s.end_reason)
   ||coalesce((select jsonb_build_object('presenter_name_en',p.display_name_en,'presenter_name_ar',p.display_name_ar)
     from public.profiles p where p.id=s.owner_id),'{}'::jsonb);
$$;
revoke all on function private.org_v1_session_payload(public.broadcast_sessions) from public,anon,authenticated,service_role;

-- As in 20261001160000, plus: decision events always push.
create or replace function public.claim_org_v1_event_pushes() returns table(event_id uuid,token text,kind text,
  recipient_profile_id uuid,language_code text,organization_id uuid,session_id uuid,invitation_id uuid,payload jsonb)
language plpgsql security definer set search_path='' as $$
begin
 perform private.org_v1_emit_reminders(null);
 insert into private.org_v1_event_deliveries(event_id,token)
   select e.id,d.token from public.org_v1_events e
   join public.schedule_push_devices d on d.viewer_profile_id=e.recipient_profile_id
   left join public.notification_push_preferences p on p.viewer_profile_id=e.recipient_profile_id
   where e.read_at is null and not public.is_banned(e.recipient_profile_id)
     and e.created_at>now()-case when e.kind='show_live' then interval '30 minutes' else interval '24 hours' end
     and case when e.kind in ('application_approved','application_rejected') then true
       when e.kind='show_live' and not exists(select 1 from private.org_v1_leaders(e.organization_id) l where l=e.recipient_profile_id)
       then coalesce(p.live_enabled,true) else coalesce(p.organization_enabled,true) end
   on conflict do nothing;
 return query update private.org_v1_event_deliveries r set claimed_until=now()+interval '2 minutes',attempts=r.attempts+1
   from public.org_v1_events e, public.schedule_push_devices d
   where r.event_id=e.id and r.token=d.token and (r.event_id,r.token) in (
     select q.event_id,q.token from private.org_v1_event_deliveries q join public.org_v1_events qe on qe.id=q.event_id
     where q.sent_at is null and q.attempts<5 and (q.claimed_until is null or q.claimed_until<now())
       and qe.read_at is null and qe.created_at>now()-interval '24 hours'
     order by qe.created_at limit 200 for update of q skip locked)
   returning r.event_id,r.token,e.kind,e.recipient_profile_id,d.language_code,e.organization_id,e.session_id,e.invitation_id,e.payload;
end; $$;
revoke all on function public.claim_org_v1_event_pushes() from public,anon,authenticated;
grant execute on function public.claim_org_v1_event_pushes() to service_role;

commit;
