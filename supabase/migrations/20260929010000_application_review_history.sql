-- Review history and queue removal are independent of public broadcaster data.
begin;

alter table public.broadcaster_applications
  add column queue_archived_at timestamptz;

drop index public.application_one_pending_revision;
create unique index application_one_pending_revision
  on public.broadcaster_applications(revision_of)
  where revision_of is not null and status = 'pending' and queue_archived_at is null;
drop policy broadcaster_applications_delete_admin on public.broadcaster_applications;

create table public.application_review_events (
  id uuid primary key default gen_random_uuid(),
  event_order bigint generated always as identity unique,
  application_id uuid not null,
  applicant_name_en text not null,
  applicant_name_ar text not null,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  actor_name text not null,
  action text not null check (action in ('approved', 'rejected', 'removed')),
  previous_status text,
  next_status text,
  reason text,
  application_snapshot jsonb not null,
  base_snapshot jsonb,
  created_at timestamptz not null default now()
);
create index application_review_events_recent
  on public.application_review_events(event_order desc);
create index application_review_events_application
  on public.application_review_events(application_id, event_order desc);
alter table public.application_review_events enable row level security;
grant select on public.application_review_events to authenticated;
create policy application_review_events_admin_select
  on public.application_review_events for select to authenticated
  using (public.is_admin_tier() and not public.is_banned(auth.uid()));

create function public.record_application_review_event() returns trigger
language plpgsql security definer set search_path = '' as $$
declare prior_base jsonb; reviewer_name text;
begin
  select coalesce(nullif(trim(p.display_name_en),''),
      nullif(trim(p.email),''),'Admin') into reviewer_name
    from public.profiles p where p.id=auth.uid();
  reviewer_name := coalesce(reviewer_name,'System');
  if new.queue_archived_at is distinct from old.queue_archived_at and
     (not public.is_admin_tier() or public.is_banned(auth.uid())) then
    raise exception 'Only an administrator may change queue visibility' using errcode='42501';
  end if;
  if new.status is distinct from old.status and new.status in ('approved','rejected')
     and public.is_banned(auth.uid()) then
    raise exception 'Review denied' using errcode='42501';
  end if;
  -- A removed pending edit must not occupy the one-pending-revision slot or
  -- be reused by the next save_broadcaster_profile call.
  if new.queue_archived_at is not null and old.queue_archived_at is null and
     old.status='pending' then new.status := 'suspended'; end if;
  if new.status is distinct from old.status and new.status in ('approved','rejected') then
    if new.revision_of is not null then
      select to_jsonb(b) into prior_base from public.broadcaster_applications b
        where b.id = new.revision_of;
    end if;
    insert into public.application_review_events(
      application_id,applicant_name_en,applicant_name_ar,actor_profile_id,actor_name,
      action,previous_status,next_status,reason,application_snapshot,base_snapshot)
    values(new.id,new.applicant_name_en,new.applicant_name_ar,auth.uid(),reviewer_name,
      case when new.status='approved' then 'approved' else 'rejected' end,
      old.status,new.status,new.admin_review_notes,to_jsonb(old),prior_base);
  end if;
  if new.queue_archived_at is distinct from old.queue_archived_at and
     new.queue_archived_at is not null then
    insert into public.application_review_events(
      application_id,applicant_name_en,applicant_name_ar,actor_profile_id,actor_name,
      action,previous_status,next_status,application_snapshot)
    values(new.id,new.applicant_name_en,new.applicant_name_ar,auth.uid(),reviewer_name,
      'removed',old.status,new.status,to_jsonb(old));
  end if;
  return new;
end;
$$;
revoke all on function public.record_application_review_event() from public,anon,authenticated;
create trigger record_application_review_event
  before update of status, queue_archived_at on public.broadcaster_applications
  for each row execute function public.record_application_review_event();

-- The public identity is granted in the same transaction as initial approval.
-- The client may refresh cards afterward, but cannot report a half-approved row.
create function public.apply_initial_application_approval() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.revision_of is not null or new.status <> 'approved' or
     old.status = 'approved' then return new; end if;
  if new.account_type='individualScholar' then
    update public.profiles set is_streamer=true,is_verified=true
      where id=new.applicant_profile_id;
    if not found then raise exception 'Applicant profile unavailable'; end if;
    perform public.publish_profile_edit(new.id);
  else
    if exists(select 1 from public.organizations
              where approved_application_id=new.id) then
      update public.organizations set is_verified=true
        where approved_application_id=new.id;
    else
      insert into public.organizations(owner_profile_id,approved_application_id,
          name_en,name_ar,is_verified)
        values(new.applicant_profile_id,new.id,new.applicant_name_en,
          new.applicant_name_ar,true);
    end if;
    perform public.publish_profile_edit(new.id);
  end if;
  return new;
end;
$$;
revoke all on function public.apply_initial_application_approval() from public,anon,authenticated;
create trigger apply_initial_application_approval
  after update of status on public.broadcaster_applications
  for each row execute function public.apply_initial_application_approval();

-- Reversing approval of an edit restores only reviewed fields. Safe edits
-- already published by the applicant are retained.
create function public.reverse_approved_application(p_event_id uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare e public.application_review_events; a public.broadcaster_applications;
  base public.broadcaster_applications; old_base public.broadcaster_applications;
  org_id uuid; org_stream text; other_approved_id uuid;
begin
  if auth.uid() is null or not public.is_admin_tier() or public.is_banned(auth.uid()) then
    raise exception 'Not permitted' using errcode='42501';
  end if;
  if length(trim(coalesce(p_reason,''))) not between 1 and 500 then
    raise exception 'A reversal reason is required' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(20260920,12);
  select * into e from public.application_review_events where id=p_event_id and action='approved';
  if not found then raise exception 'Approval event unavailable' using errcode='P0002'; end if;
  select * into a from public.broadcaster_applications where id=e.application_id for update;
  if not found or a.status <> 'approved' or exists (
    select 1 from public.application_review_events later
    where later.application_id=e.application_id and later.action in ('approved','rejected')
      and later.event_order > e.event_order
  ) then raise exception 'Approval is no longer current' using errcode='40001'; end if;
  if a.revision_of is null and (a.applicant_profile_id=auth.uid() or exists(
    select 1 from public.user_roles r where r.profile_id=a.applicant_profile_id
      and (r.role='master_admin' or (r.role='admin' and not public.is_master_admin()))
  )) then raise exception 'Protected administrator' using errcode='42501'; end if;
  if a.revision_of is not null then
    if e.base_snapshot is null then raise exception 'Previous approved data unavailable'; end if;
    old_base := jsonb_populate_record(null::public.broadcaster_applications,e.base_snapshot);
    select * into base from public.broadcaster_applications where id=a.revision_of for update;
    if not found or base.status <> 'approved' then raise exception 'Approved base unavailable'; end if;
    if (base.email,base.phone,base.city_id,base.latitude,base.longitude,
        base.venue_name_en,base.venue_name_ar,base.youtube_channel_url,base.youtube_handle)
       is distinct from
       (a.email,a.phone,a.city_id,a.latitude,a.longitude,
        a.venue_name_en,a.venue_name_ar,a.youtube_channel_url,a.youtube_handle) then
      raise exception 'Approved data changed since this review' using errcode='40001';
    end if;
    update public.broadcaster_applications set
      email=old_base.email,phone=old_base.phone,city_id=old_base.city_id,
      latitude=old_base.latitude,longitude=old_base.longitude,
      venue_name_en=old_base.venue_name_en,venue_name_ar=old_base.venue_name_ar,
      youtube_channel_url=old_base.youtube_channel_url,youtube_handle=old_base.youtube_handle
      where id=base.id;
    update public.broadcaster_applications set status='rejected',
      admin_review_notes=trim(p_reason),reviewed_by=auth.uid(),reviewed_at=now(),
      queue_archived_at=null where id=a.id;
    if old_base.youtube_handle is distinct from a.youtube_handle or
       old_base.youtube_channel_url is distinct from a.youtube_channel_url then
      perform set_config('app.broadcast_end_reason','approval_reversed',true);
      if a.account_type='individualScholar' then
        update public.profiles set is_currently_live=false,broadcast_type='offline',
          active_stream_id=null,active_viewer_count=0
          where id=a.applicant_profile_id and is_currently_live;
      else
        update public.organizations set is_currently_live=false,broadcast_type='offline',
          active_stream_id=null,active_viewer_count=0
          where approved_application_id=base.id and is_currently_live;
        update public.profiles set is_currently_live=false,broadcast_type='offline',
          active_stream_id=null,active_viewer_count=0
          where id=a.applicant_profile_id and is_currently_live;
      end if;
      update public.device_sessions set is_primary_broadcaster=false
        where user_id=a.applicant_profile_id;
      perform public.reset_broadcast_context();
    end if;
    perform public.publish_profile_edit(base.id);
  else
    perform set_config('app.broadcast_end_reason','approval_reversed',true);
    if a.account_type='individualScholar' then
      select id into other_approved_id from public.broadcaster_applications
        where applicant_profile_id=a.applicant_profile_id and id<>a.id
          and revision_of is null and account_type='individualScholar'
          and status='approved' order by reviewed_at desc nulls last limit 1;
      update public.profiles set is_streamer=other_approved_id is not null,
        is_verified=other_approved_id is not null,
        is_currently_live=false,broadcast_type='offline',active_stream_id=null,
        active_viewer_count=0 where id=a.applicant_profile_id;
    else
      select id,active_stream_id into org_id,org_stream
        from public.organizations where approved_application_id=a.id;
      if org_id is not null then
        update public.organizations set is_verified=false,is_currently_live=false,
          broadcast_type='offline',active_stream_id=null,active_viewer_count=0
          where id=org_id;
        update public.profiles set is_currently_live=false,broadcast_type='offline',
          active_stream_id=null,active_viewer_count=0
          where id=a.applicant_profile_id and is_currently_live
            and active_stream_id=org_stream;
      end if;
    end if;
    if a.account_type='individualScholar' or org_stream is not null then
      update public.device_sessions set is_primary_broadcaster=false
        where user_id=a.applicant_profile_id;
    end if;
    update public.broadcaster_applications set status='rejected',
      admin_review_notes=trim(p_reason),reviewed_by=auth.uid(),reviewed_at=now(),
      queue_archived_at=null where id=a.id;
    if other_approved_id is not null then
      perform public.publish_profile_edit(other_approved_id);
    end if;
    perform public.reset_broadcast_context();
  end if;
  return (select to_jsonb(b) from public.broadcaster_applications b where b.id=a.id);
end;
$$;
revoke all on function public.reverse_approved_application(uuid,text) from public,anon;
grant execute on function public.reverse_approved_application(uuid,text) to authenticated;
commit;
