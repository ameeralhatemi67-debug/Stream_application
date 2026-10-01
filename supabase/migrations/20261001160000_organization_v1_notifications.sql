-- Organization V1: durable recipient events, invitation/transfer journeys and
-- client availability. Events are written only by server triggers/RPCs; the
-- client reads its own rows and marks them read. Push delivery reuses the
-- existing Firebase device registrations through a separate service job.
begin;

-- Availability. Organization applications open independently of the global
-- feature flag so a pilot organization can be onboarded while V1 stays off.
alter table public.app_flags drop constraint app_flags_key_check;
alter table public.app_flags add constraint app_flags_key_check check(key in
  ('chat_enabled','registrations_open','organizations_v1_enabled','organization_applications_open'));
insert into public.app_flags(key,enabled) values('organization_applications_open',false) on conflict(key) do nothing;

create function public.org_v1_guard_org_application() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 -- New organization applications only while the switch is open. Revisions of
 -- an approved organization and resubmissions of an existing row continue.
 if new.account_type='organizationVenue' and new.revision_of is null
   and not exists(select 1 from public.broadcaster_applications where id=new.id)
   and not coalesce((select enabled from public.app_flags where key='organization_applications_open'),false)
   and not public.is_admin_tier() then
   raise exception 'Organization applications are not open' using errcode='42501';
 end if;
 return new;
end; $$;
create trigger org_v1_guard_org_application before insert on public.broadcaster_applications
  for each row execute function public.org_v1_guard_org_application();
revoke all on function public.org_v1_guard_org_application() from public,anon,authenticated;

-- Durable per-recipient events. One row per recipient and subject revision.
create table public.org_v1_events (
  id uuid primary key default gen_random_uuid(),
  recipient_profile_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check(kind in ('invitation','invitation_answered','join_request','join_request_answered',
    'assignment','assignment_changed','assignment_cancelled','assignment_answered','assignment_reminder',
    'membership_changed','show_live','show_ending','transfer_proposed','transfer_cancelled','transfer_completed')),
  organization_id uuid references public.organizations(id) on delete cascade,
  session_id uuid references public.broadcast_sessions(id) on delete cascade,
  invitation_id uuid references public.affiliation_requests(id) on delete cascade,
  payload jsonb not null default '{}',
  dedupe_key text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  unique(recipient_profile_id,dedupe_key)
);
create index org_v1_events_recipient_idx on public.org_v1_events(recipient_profile_id,created_at desc);
alter table public.org_v1_events enable row level security;
revoke all on public.org_v1_events from public,anon,authenticated;
grant select on public.org_v1_events to authenticated;
create policy org_v1_events_own on public.org_v1_events for select to authenticated
  using(recipient_profile_id=(select auth.uid()));
comment on table public.org_v1_events is 'Organization V1 recipient events. Server-written only; recipients read their own rows and mark them read through org_v1_mark_events_read.';

-- Server-side push preferences, mirrored from the in-app notification switches.
create table public.notification_push_preferences (
  viewer_profile_id uuid primary key references public.profiles(id) on delete cascade,
  live_enabled boolean not null default true,
  organization_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.notification_push_preferences enable row level security;
revoke all on public.notification_push_preferences from public,anon,authenticated;
grant select,insert,update on public.notification_push_preferences to authenticated;
create policy push_preferences_own on public.notification_push_preferences for all to authenticated
  using(viewer_profile_id=(select auth.uid()))
  with check(viewer_profile_id=(select auth.uid()) and not public.is_current_user_banned());

create function private.org_v1_emit(p_recipient uuid,p_kind text,p_org uuid,p_session uuid,p_invitation uuid,
  p_key text,p_payload jsonb default '{}') returns void
language plpgsql security definer set search_path='' as $$
begin
 if p_recipient is null or public.is_banned(p_recipient) then return; end if;
 insert into public.org_v1_events(recipient_profile_id,kind,organization_id,session_id,invitation_id,payload,dedupe_key)
   values(p_recipient,p_kind,p_org,p_session,p_invitation,coalesce(p_payload,'{}'),p_kind||':'||p_key)
   on conflict(recipient_profile_id,dedupe_key) do nothing;
end; $$;

create function private.org_v1_org_payload(p_org uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce((select jsonb_build_object('organization_name_en',o.name_en,'organization_name_ar',o.name_ar)
   from public.organizations o where o.id=p_org),'{}'::jsonb);
$$;
create function private.org_v1_session_payload(s public.broadcast_sessions) returns jsonb
language sql stable security definer set search_path='' as $$
 select private.org_v1_org_payload(s.org_id)||jsonb_build_object('title_en',s.title_en,'title_ar',s.title_ar,
   'start',s.scheduled_start_at,'state',s.state,'presenter_id',s.owner_id,'revision',s.revision,'end_reason',s.end_reason);
$$;
create function private.org_v1_leaders(p_org uuid,p_roles text[] default array['owner','co_owner','manager'])
returns setof uuid language sql stable security definer set search_path='' as $$
 select m.profile_id from public.org_memberships m where m.organization_id=p_org and m.status='active' and m.role=any(p_roles)
 union select owner_profile_id from public.organizations where id=p_org and 'owner'=any(p_roles);
$$;
create function private.org_v1_day() returns text language sql stable set search_path='' as $$
 select to_char(now() at time zone 'Asia/Riyadh','YYYY-MM-DD');
$$;

-- Sessions: assignments, edits, cancellations, answers, confirmed starts and
-- server-initiated termination. Series events collapse to one per day.
create function private.org_v1_session_events() returns trigger
language plpgsql security definer set search_path='' as $$
declare payload jsonb:=private.org_v1_session_payload(new); subject text:=coalesce(new.schedule_id,new.id)::text;
  recipient uuid; creator uuid;
begin
 if new.state='live' and (tg_op='INSERT' or old.state<>'live') then
   if not new.hidden_from_discovery then
     for recipient in select f.follower_profile_id from public.follows f
       where f.target_id=coalesce(new.org_id,new.owner_id)::text and f.follower_profile_id<>new.owner_id loop
       perform private.org_v1_emit(recipient,'show_live',new.org_id,new.id,null,new.id::text,payload);
     end loop;
   end if;
   if new.org_id is not null then
     for recipient in select * from private.org_v1_leaders(new.org_id) loop
       if recipient<>new.owner_id then perform private.org_v1_emit(recipient,'show_live',new.org_id,new.id,null,new.id::text,payload); end if;
     end loop;
   end if;
 end if;
 if new.org_id is null then return new; end if;
 if tg_op='UPDATE' and new.state='ending' and old.state<>'ending'
   and new.end_reason in ('approval_revoked','device_transfer','organization_revoked','ingest_lost') then
   perform private.org_v1_emit(new.owner_id,'show_ending',new.org_id,new.id,null,new.id::text,payload);
 end if;
 if new.state='awaiting_acceptance' and (tg_op='INSERT' or old.state<>'awaiting_acceptance' or old.revision<>new.revision) then
   if tg_op='INSERT' or old.owner_id<>new.owner_id then
     perform private.org_v1_emit(new.owner_id,'assignment',new.org_id,new.id,null,subject||':'||private.org_v1_day(),payload);
   else
     perform private.org_v1_emit(new.owner_id,'assignment_changed',new.org_id,new.id,null,new.id::text||':'||new.revision,payload);
   end if;
 end if;
 if tg_op='UPDATE' and old.owner_id<>new.owner_id and old.state in ('draft','awaiting_acceptance','scheduled') then
   perform private.org_v1_emit(old.owner_id,'assignment_cancelled',new.org_id,new.id,null,new.id::text||':'||new.revision,payload);
 end if;
 if tg_op='UPDATE' and new.state='cancelled' and old.state in ('draft','awaiting_acceptance','scheduled') then
   perform private.org_v1_emit(new.owner_id,'assignment_cancelled',new.org_id,new.id,null,subject||':'||private.org_v1_day(),payload);
 end if;
 if tg_op='UPDATE' and old.state='awaiting_acceptance' and new.state in ('scheduled','draft') then
   select created_by into creator from public.upcoming_schedules where id=new.schedule_id;
   creator:=coalesce(creator,(select owner_profile_id from public.organizations where id=new.org_id));
   if creator is not null and creator<>new.owner_id then
     perform private.org_v1_emit(creator,'assignment_answered',new.org_id,new.id,null,
       subject||':'||new.owner_id||':'||(new.state='scheduled')||':'||private.org_v1_day(),
       payload||jsonb_build_object('accepted',new.state='scheduled'));
   end if;
 end if;
 return new;
end; $$;
create trigger org_v1_session_events after insert or update of state,owner_id,revision on public.broadcast_sessions
  for each row execute function private.org_v1_session_events();

create function private.org_v1_membership_events() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if (old.role,old.status,old.permissions) is not distinct from (new.role,new.status,new.permissions) then return new; end if;
 perform private.org_v1_emit(new.profile_id,'membership_changed',new.organization_id,null,null,
   new.organization_id||':'||extract(epoch from clock_timestamp())::text,
   private.org_v1_org_payload(new.organization_id)||jsonb_build_object('role',new.role,'status',new.status,
     'video',new.permissions->>'can_go_live_video'='true','audio',new.permissions->>'can_go_audio_only'='true'));
 return new;
end; $$;
create trigger org_v1_membership_events after update of role,status,permissions on public.org_memberships
  for each row execute function private.org_v1_membership_events();

create function private.org_v1_invitation_events() returns trigger
language plpgsql security definer set search_path='' as $$
declare payload jsonb:=private.org_v1_org_payload(new.organization_id)||jsonb_build_object('role',new.invited_role,'expires_at',new.expires_at);
  recipient uuid;
begin
 if new.direction='orgToStreamer' then
   if new.status='pending' and new.streamer_profile_id is not null
     and (tg_op='INSERT' or old.streamer_profile_id is null) then
     perform private.org_v1_emit(new.streamer_profile_id,'invitation',new.organization_id,null,new.id,new.id::text,payload);
   end if;
   if tg_op='UPDATE' and old.status='pending' and new.status in ('accepted','declined') then
     perform private.org_v1_emit(new.invited_by_profile_id,'invitation_answered',new.organization_id,null,new.id,new.id::text,
       payload||jsonb_build_object('accepted',new.status='accepted','email',new.target_email));
   end if;
 elsif new.direction='streamerToOrg' then
   if tg_op='INSERT' and new.status='pending' then
     for recipient in select * from private.org_v1_leaders(new.organization_id) loop
       perform private.org_v1_emit(recipient,'join_request',new.organization_id,null,new.id,new.id::text,payload);
     end loop;
   elsif tg_op='UPDATE' and old.status='pending' and new.status in ('accepted','declined') then
     perform private.org_v1_emit(new.streamer_profile_id,'join_request_answered',new.organization_id,null,new.id,new.id::text,
       payload||jsonb_build_object('accepted',new.status='accepted'));
   end if;
 end if;
 return new;
end; $$;
create trigger org_v1_invitation_events after insert or update of status,streamer_profile_id on public.affiliation_requests
  for each row execute function private.org_v1_invitation_events();

create function private.org_v1_transfer_events() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 perform private.org_v1_emit(new.to_profile_id,'transfer_proposed',new.organization_id,null,null,
   new.organization_id||':'||new.to_profile_id||':'||extract(epoch from new.expires_at)::text,
   private.org_v1_org_payload(new.organization_id)||jsonb_build_object('expires_at',new.expires_at));
 return new;
end; $$;
create trigger org_v1_transfer_events after insert or update on private.organization_owner_transfers
  for each row execute function private.org_v1_transfer_events();
create function private.org_v1_owner_events() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient uuid; key text:=new.id||':'||new.owner_profile_id||':'||extract(epoch from clock_timestamp())::text;
begin
 for recipient in select * from private.org_v1_leaders(new.id,array['owner','co_owner']) loop
   perform private.org_v1_emit(recipient,'transfer_completed',new.id,null,null,key,
     private.org_v1_org_payload(new.id)||jsonb_build_object('owner_id',new.owner_profile_id,'previous_owner_id',old.owner_profile_id));
 end loop;
 return new;
end; $$;
create trigger org_v1_owner_events after update of owner_profile_id on public.organizations
  for each row when (old.owner_profile_id is distinct from new.owner_profile_id)
  execute function private.org_v1_owner_events();

-- Presenter reminders for accepted (and still unanswered) assignments.
create function private.org_v1_emit_reminders(p_profile uuid default null) returns void
language plpgsql security definer set search_path='' as $$
declare s public.broadcast_sessions;
begin
 for s in select b.* from public.broadcast_sessions b
   left join public.schedule_reminder_preferences p on p.viewer_profile_id=b.owner_id
   where b.org_id is not null and b.state in ('awaiting_acceptance','scheduled')
     and (p_profile is null or b.owner_id=p_profile)
     and b.scheduled_start_at>now() and b.scheduled_start_at<=now()+make_interval(mins=>coalesce(p.lead_minutes,15)) loop
   perform private.org_v1_emit(s.owner_id,'assignment_reminder',s.org_id,s.id,null,s.id::text||':'||s.revision,
     private.org_v1_session_payload(s));
 end loop;
end; $$;

create function public.org_v1_events(p_limit integer default 50) returns setof public.org_v1_events
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or public.is_banned(auth.uid()) then return; end if;
 perform private.org_v1_emit_reminders(auth.uid());
 return query select * from public.org_v1_events where recipient_profile_id=auth.uid()
   order by created_at desc limit least(greatest(coalesce(p_limit,50),1),100);
end; $$;
create function public.org_v1_mark_events_read(p_ids uuid[] default null) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in required' using errcode='42501'; end if;
 update public.org_v1_events set read_at=now() where recipient_profile_id=auth.uid() and read_at is null
   and (p_ids is null or id=any(p_ids));
end; $$;

-- Invitations. A pending invitation addressed to the caller's verified email
-- binds to that account on read, the same binding the inviter's lookup makes
-- when the account already exists, so it can be answered in-app.
create function public.org_v1_my_invitations() returns setof jsonb
language plpgsql security definer set search_path='' as $$
declare email text;
begin
 if auth.uid() is null or public.is_banned(auth.uid()) then return; end if;
 select lower(u.email) into email from auth.users u where u.id=auth.uid() and u.email_confirmed_at is not null;
 if email is not null then
   update public.affiliation_requests set streamer_profile_id=auth.uid()
     where direction='orgToStreamer' and status='pending' and streamer_profile_id is null
       and target_email=email and expires_at>now();
 end if;
 return query select jsonb_build_object('id',a.id,'organization_id',a.organization_id,'organization_name_en',o.name_en,
   'organization_name_ar',o.name_ar,'role',a.invited_role,'permissions',a.permissions,'expires_at',a.expires_at,
   'invited_by_en',p.display_name_en,'invited_by_ar',p.display_name_ar)
   from public.affiliation_requests a join public.organizations o on o.id=a.organization_id
   left join public.profiles p on p.id=a.invited_by_profile_id
   where a.direction='orgToStreamer' and a.status='pending' and a.expires_at>now() and a.streamer_profile_id=auth.uid()
   order by a.expires_at;
end; $$;
create function public.org_v1_invitations(p_org_id uuid) returns setof jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',a.id,'email',a.target_email,'role',a.invited_role,'permissions',a.permissions,
   'expires_at',a.expires_at,'bound',a.streamer_profile_id is not null)
 from public.affiliation_requests a
 where a.organization_id=p_org_id and a.direction='orgToStreamer' and a.status='pending' and a.expires_at>now()
   and auth.uid() is not null and public.org_v1_can(p_org_id,'members')
 order by a.expires_at;
$$;

-- Transfer: either party may withdraw a pending proposal.
create function public.org_v1_cancel_transfer(p_org_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); transfer private.organization_owner_transfers;
begin
 select * into transfer from private.organization_owner_transfers where organization_id=p_org_id for update;
 if not found or actor not in (transfer.from_profile_id,transfer.to_profile_id) then
   raise exception 'Transfer unavailable' using errcode='42501';
 end if;
 delete from private.organization_owner_transfers where organization_id=p_org_id;
 perform private.org_v1_emit(case when actor=transfer.from_profile_id then transfer.to_profile_id else transfer.from_profile_id end,
   'transfer_cancelled',p_org_id,null,null,p_org_id||':'||extract(epoch from clock_timestamp())::text,
   private.org_v1_org_payload(p_org_id)||jsonb_build_object('by_target',actor=transfer.to_profile_id));
 perform private.org_v1_audit(p_org_id,'assignOwnerRole',jsonb_build_object('cancelled',true));
end; $$;

-- Membership rows carry rollout availability and any pending transfer so the
-- client never shows an action the server would refuse.
create or replace function public.org_v1_memberships(p_org_id uuid default null) returns setof jsonb
language sql stable security definer set search_path='' as $$
  select to_jsonb(m)||jsonb_build_object('name_en',p.display_name_en,'name_ar',p.display_name_ar,
    'organization_name_en',o.name_en,'organization_name_ar',o.name_ar,'v1_enabled',public.org_v1_enabled(o.id),
    'transfer_to_me',t.to_profile_id=auth.uid() and t.expires_at>now() and m.profile_id=auth.uid(),
    'transfer_target_id',case when o.owner_profile_id=auth.uid() and t.expires_at>now() then t.to_profile_id end,
    'transfer_expires_at',case when t.expires_at>now() and auth.uid() in (t.from_profile_id,t.to_profile_id) then t.expires_at end)
  from public.org_memberships m join public.organizations o on o.id=m.organization_id
    join public.profiles p on p.id=m.profile_id
    left join private.organization_owner_transfers t on t.organization_id=o.id
  where auth.uid() is not null and not public.is_banned(auth.uid())
    and case when p_org_id is null then m.profile_id=auth.uid()
      else m.organization_id=p_org_id and (m.profile_id=auth.uid()
        or public.org_v1_can(p_org_id,'members') or public.is_admin_tier()) end;
$$;

-- Master Admin pilot overview.
create function public.org_v1_pilot_status() returns setof jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',o.id,'name_en',o.name_en,'name_ar',o.name_ar,
   'pilot',exists(select 1 from private.organization_v1_pilots p where p.organization_id=o.id))
 from public.organizations o where public.is_master_admin() order by o.name_en;
$$;

-- Push claims for the dispatch job (service role only).
create table private.org_v1_event_deliveries (
  event_id uuid not null references public.org_v1_events(id) on delete cascade,
  token text not null references public.schedule_push_devices(token) on delete cascade,
  claimed_until timestamptz,
  sent_at timestamptz,
  attempts integer not null default 0,
  primary key(event_id,token)
);
create function public.claim_org_v1_event_pushes() returns table(event_id uuid,token text,kind text,
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
     and case when e.kind='show_live' and not exists(select 1 from private.org_v1_leaders(e.organization_id) l where l=e.recipient_profile_id)
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
create function public.org_v1_event_push_sent(p_event_id uuid,p_token text) returns void
language sql security definer set search_path='' as $$
 update private.org_v1_event_deliveries set sent_at=now(),claimed_until=null where event_id=p_event_id and token=p_token;
$$;

-- Only the functions created here; earlier phases keep their grants.
do $$ declare f record;
begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where (n.nspname='private' and p.proname in ('org_v1_emit','org_v1_org_payload','org_v1_session_payload','org_v1_leaders',
       'org_v1_day','org_v1_session_events','org_v1_membership_events','org_v1_invitation_events','org_v1_transfer_events',
       'org_v1_owner_events','org_v1_emit_reminders'))
     or (n.nspname='public' and p.proname in ('org_v1_events','org_v1_mark_events_read','org_v1_my_invitations',
       'org_v1_invitations','org_v1_cancel_transfer','org_v1_pilot_status','claim_org_v1_event_pushes','org_v1_event_push_sent')) loop
   execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
 end loop;
end; $$;
grant execute on function public.org_v1_events(integer),public.org_v1_mark_events_read(uuid[]),public.org_v1_my_invitations(),
  public.org_v1_invitations(uuid),public.org_v1_cancel_transfer(uuid),public.org_v1_pilot_status() to authenticated;
grant execute on function public.claim_org_v1_event_pushes(),public.org_v1_event_push_sent(uuid,text) to service_role;
revoke all on all tables in schema private from public,anon,authenticated,service_role;
commit;
