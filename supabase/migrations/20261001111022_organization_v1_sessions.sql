-- Canonical sessions and durable provider reservations reuse broadcast_sessions.
begin;
alter table public.broadcast_sessions drop constraint broadcast_sessions_state_check,
  drop constraint broadcast_sessions_terminal_shape;
alter table public.broadcast_sessions alter column stream_id drop not null,
  alter column started_at drop not null,alter column started_at drop default,
  alter column state set default 'draft';
alter table public.broadcast_sessions add constraint broadcast_sessions_state_check check(state in
  ('draft','awaiting_acceptance','scheduled','preparing','live','ending','processing_replay','completed','cancelled','failed','ended'));
alter table public.broadcast_sessions add column schedule_id uuid references public.upcoming_schedules(id) on delete set null,
  add column channel_connection_id uuid references public.channel_connections(id) on delete set null,
  add column content_owner_profile_id uuid references public.profiles(id) on delete set null,
  add column scheduled_start_at timestamptz,
  add column occurrence_at timestamptz,
  add column expected_end_at timestamptz,
  add column accepted_at timestamptz,
  add column venue_id uuid,
  add column title_en text not null default '',add column title_ar text not null default '',
  add column description text not null default '',
  add column replay_status text not null default 'not_started' check(replay_status in ('not_started','processing','available','missing')),
  add column provider_observed_at timestamptz,
  add column termination_pending boolean not null default false,
  add constraint broadcast_session_window check(expected_end_at>scheduled_start_at),
  add constraint broadcast_title_length check(char_length(title_en)<=120 and char_length(title_ar)<=120 and char_length(description)<=2000);
drop index public.broadcast_sessions_one_live_per_owner;
create unique index broadcast_sessions_one_active_presenter on public.broadcast_sessions(owner_id)
  where state in ('preparing','live','ending');
create unique index broadcast_sessions_occurrence on public.broadcast_sessions(schedule_id,occurrence_at)
  where schedule_id is not null;
create index broadcast_sessions_org_window on public.broadcast_sessions(org_id,scheduled_start_at,expected_end_at)
  where state in ('awaiting_acceptance','scheduled','preparing','live','ending');
create index broadcast_sessions_presenter_window on public.broadcast_sessions(owner_id,scheduled_start_at,expected_end_at)
  where state in ('awaiting_acceptance','scheduled','preparing','live','ending');
comment on table public.broadcast_sessions is 'Canonical presenter, destination, occurrence, provider-confirmed state and replay identity. API writes only through authorized RPCs.';

create table private.broadcast_provider (
  session_id uuid primary key references public.broadcast_sessions(id) on delete cascade,
  channel_revision bigint not null,
  operation text check(operation in ('prepare','start','end','observe')),
  operation_token uuid,actor_id uuid,auth_session_id uuid,
  claimed_until timestamptz,
  step text,
  needs_reconciliation boolean not null default false,
  provider_stream_id text,provider_broadcast_id text,
  ingest_secret_id uuid references vault.secrets(id),ingest_url text,
  bound boolean not null default false,feed_retired boolean not null default false,broadcast_deleted boolean not null default false,
  last_error text,checked_at timestamptz
);

create function private.broadcast_permission(p_actor uuid,p_org uuid,p_type text,p_require_flag boolean default true)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles p where p.id=p_actor and p.is_verified and not public.is_banned(p.id)
   and case when p_org is null then p.personal_broadcast_approved else p.organization_broadcast_approved end)
 and (p_org is null or (exists(select 1 from public.organizations where id=p_org and is_verified)
   and (not p_require_flag or public.org_v1_enabled(p_org))
   and exists(select 1 from public.org_memberships m where m.organization_id=p_org and m.profile_id=p_actor and m.status='active'
     and m.permissions->>case when p_type='liveAudio' then 'can_go_audio_only' else 'can_go_live_video' end='true')));
$$;
create function private.broadcast_primary(p_actor uuid,p_device text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.device_sessions where user_id=p_actor and device_id=p_device
   and is_primary_broadcaster and last_active_at>now()-interval '90 seconds');
$$;
create function private.broadcast_capacity(p_id uuid,p_actor uuid,p_org uuid,p_start timestamptz,p_end timestamptz) returns void
language plpgsql security definer set search_path='' as $$
begin
 -- ponytail: serialize pilot reservations; use per-presenter/org locks if contention is measured.
 perform pg_advisory_xact_lock(20261001,3);
 if exists(select 1 from public.broadcast_sessions b where b.id is distinct from p_id and b.owner_id=p_actor
   and b.state in ('awaiting_acceptance','scheduled','preparing','live','ending')
   and tstzrange(b.scheduled_start_at,b.expected_end_at,'[)') && tstzrange(p_start,p_end,'[)')) then
   raise exception 'Presenter assignments overlap' using errcode='23P01'; end if;
 if p_org is not null and exists(
   select 1 from (select p_start at_time union select scheduled_start_at from public.broadcast_sessions
     where org_id=p_org and id is distinct from p_id and scheduled_start_at>=p_start and scheduled_start_at<p_end) points
   where (select count(*) from public.broadcast_sessions b where b.org_id=p_org and b.id is distinct from p_id
     and b.state in ('awaiting_acceptance','scheduled','preparing','live','ending')
     and b.scheduled_start_at<=points.at_time and b.expected_end_at>points.at_time)>=3) then
   raise exception 'Organization has three reserved shows' using errcode='23P01'; end if;
end; $$;

alter table public.upcoming_schedules add column organization_id uuid references public.organizations(id) on delete cascade,
  add column created_by uuid references public.profiles(id) on delete set null,
  add column venue_id uuid,add column broadcast_type text not null default 'liveVideo' check(broadcast_type in ('liveVideo','liveAudio')),
  add column duration_minutes integer not null default 60 check(duration_minutes between 15 and 720),
  add column cancelled_at timestamptz;
create index upcoming_schedules_org on public.upcoming_schedules(organization_id) where organization_id is not null;
create or replace function public.guard_upcoming_schedule() returns trigger
language plpgsql security definer set search_path='' as $$
declare t text;
begin
 if new.organization_id is null then
   if not public.can_publish_upcoming(new.streamer_profile_id) then raise exception 'Approved personal broadcaster required'; end if;
 else
   if coalesce(current_setting('app.org_schedule_write',true),'')<>'1' then
     raise exception 'Use organization schedule RPC' using errcode='42501'; end if;
   if tg_op='UPDATE' and new.cancelled_at is not null then return new; end if;
   if not private.broadcast_permission(new.streamer_profile_id,new.organization_id,new.broadcast_type,false) then
     raise exception 'Approved organization presenter and grant required' using errcode='42501'; end if;
 end if;
 if tg_op='UPDATE' and (new.organization_id is distinct from old.organization_id or
   (new.organization_id is null and new.streamer_profile_id<>old.streamer_profile_id)) then raise exception 'Cannot transfer a schedule'; end if;
 if new.kind='once' and (new.one_time_start_at<=now() or new.local_time<>(new.one_time_start_at at time zone 'Asia/Riyadh')::time) then
   raise exception 'Future Saudi start required'; end if;
 foreach t in array new.tags loop
   if char_length(t)>32 or not exists(select 1 from public.tags where name=t and status in ('approved','pending')) then
     raise exception 'Tag must be submitted for moderation'; end if;
 end loop;
 return new;
end; $$;
-- Existing client DML remains personal-only, including delete (which has no row trigger).
drop policy upcoming_insert_owner on public.upcoming_schedules;
drop policy upcoming_update_owner on public.upcoming_schedules;
drop policy upcoming_delete_owner on public.upcoming_schedules;
create policy upcoming_insert_owner on public.upcoming_schedules for insert to authenticated
 with check(organization_id is null and streamer_profile_id=auth.uid() and public.can_publish_upcoming(streamer_profile_id));
create policy upcoming_update_owner on public.upcoming_schedules for update to authenticated
 using(organization_id is null and streamer_profile_id=auth.uid() and not public.is_current_user_banned())
 with check(organization_id is null and streamer_profile_id=auth.uid() and public.can_publish_upcoming(streamer_profile_id));
create policy upcoming_delete_owner on public.upcoming_schedules for delete to authenticated
 using(organization_id is null and streamer_profile_id=auth.uid() and not public.is_current_user_banned());
create policy upcoming_org_staff on public.upcoming_schedules for select to authenticated
 using(organization_id is not null and public.org_v1_can(organization_id,'schedule'));

create function private.broadcast_materialize(p_schedule uuid) returns void
language plpgsql security definer set search_path='' as $$
declare s public.upcoming_schedules; occurrence timestamptz; last_start timestamptz:=now();
begin
 select * into s from public.upcoming_schedules where id=p_schedule for update;
 if not found or s.organization_id is null or s.cancelled_at is not null then return; end if;
 if not private.broadcast_permission(s.streamer_profile_id,s.organization_id,s.broadcast_type,false) then return; end if;
 loop
   occurrence:=case when s.kind='once' then s.one_time_start_at else public.next_riyadh_occurrence(s.weekdays,s.local_time,last_start) end;
   exit when occurrence is null or occurrence<=now() or (s.kind='weekly' and occurrence>=now()+interval '28 days');
   if not exists(select 1 from public.broadcast_sessions where schedule_id=s.id and occurrence_at=occurrence) then
     perform private.broadcast_capacity(null,s.streamer_profile_id,s.organization_id,occurrence,occurrence+make_interval(mins=>s.duration_minutes));
     insert into public.broadcast_sessions(owner_id,org_id,schedule_id,broadcast_type,state,scheduled_start_at,occurrence_at,expected_end_at,
       venue_id,title_en,title_ar,description) values(s.streamer_profile_id,s.organization_id,s.id,s.broadcast_type,'awaiting_acceptance',
       occurrence,occurrence,occurrence+make_interval(mins=>s.duration_minutes),s.venue_id,s.title_en,s.title_ar,concat_ws(E'\n',s.description_en,s.description_ar));
   end if;
   exit when s.kind='once';
   last_start:=occurrence;
 end loop;
end; $$;
create function public.broadcast_save_schedule(p_org_id uuid,p_schedule_id uuid,p_presenter uuid,p_kind text,
 p_local_time time,p_weekdays smallint[],p_once timestamptz,p_title_en text,p_title_ar text,p_type text,
 p_duration integer default 60,p_venue uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); result uuid;
begin
 if not public.org_v1_can(p_org_id,'schedule') then raise exception 'Organization scheduling denied' using errcode='42501'; end if;
 if p_venue is not null and not exists(select 1 from public.org_venues where id=p_venue and organization_id=p_org_id) then
   raise exception 'Organization venue required' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(20261001,3);
 perform set_config('app.org_schedule_write','1',true);
 if p_schedule_id is null then
   insert into public.upcoming_schedules(streamer_profile_id,organization_id,created_by,kind,local_time,weekdays,one_time_start_at,
     title_en,title_ar,broadcast_type,duration_minutes,venue_id)
   values(p_presenter,p_org_id,actor,p_kind,p_local_time,p_weekdays,p_once,p_title_en,p_title_ar,p_type,p_duration,p_venue) returning id into result;
 else
   if not exists(select 1 from public.upcoming_schedules where id=p_schedule_id and organization_id=p_org_id and cancelled_at is null) then
     raise exception 'Schedule unavailable' using errcode='42501'; end if;
   if exists(select 1 from public.broadcast_sessions where schedule_id=p_schedule_id and state in ('preparing','live','ending')) then
     raise exception 'End active occurrence before editing its series' using errcode='55000'; end if;
   update public.broadcast_sessions set state='cancelled',end_reason='replaced',ended_at=now(),accepted_at=null,revision=revision+1
     where schedule_id=p_schedule_id and state in ('draft','awaiting_acceptance','scheduled');
   -- Retain old occurrence identity. New series revisions get a new template ID.
   update public.upcoming_schedules set cancelled_at=now() where id=p_schedule_id;
   insert into public.upcoming_schedules(streamer_profile_id,organization_id,created_by,kind,local_time,weekdays,one_time_start_at,
     title_en,title_ar,broadcast_type,duration_minutes,venue_id)
   values(p_presenter,p_org_id,actor,p_kind,p_local_time,p_weekdays,p_once,p_title_en,p_title_ar,p_type,p_duration,p_venue) returning id into result;
 end if;
 perform private.broadcast_materialize(result);
 perform set_config('app.org_schedule_write','',true);
 perform private.org_v1_audit(p_org_id,'updatePermissions',jsonb_build_object('schedule',result,'operation','schedule'));
 return result;
end; $$;
create function public.broadcast_edit_occurrence(p_id uuid,p_presenter uuid,p_start timestamptz,p_end timestamptz,
 p_type text,p_venue uuid default null) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); s public.broadcast_sessions;
begin
 perform pg_advisory_xact_lock(20261001,3);
 select * into s from public.broadcast_sessions where id=p_id for update;
 if not found or s.org_id is null or not public.org_v1_can(s.org_id,'schedule') then raise exception 'Schedule denied' using errcode='42501'; end if;
 if s.state not in ('draft','awaiting_acceptance','scheduled') or p_start<=now() or p_end<=p_start or p_end>p_start+interval '12 hours'
   or p_type not in ('liveVideo','liveAudio') then raise exception 'Editable future occurrence required' using errcode='55000'; end if;
 if not private.broadcast_permission(p_presenter,s.org_id,p_type,false) or (p_venue is not null and not exists(
   select 1 from public.org_venues where id=p_venue and organization_id=s.org_id)) then raise exception 'Presenter or venue denied' using errcode='42501'; end if;
 perform private.broadcast_capacity(s.id,p_presenter,s.org_id,p_start,p_end);
 update public.broadcast_sessions set owner_id=p_presenter,scheduled_start_at=p_start,expected_end_at=p_end,broadcast_type=p_type,
   venue_id=p_venue,accepted_at=null,state='awaiting_acceptance',revision=revision+1 where id=s.id;
 perform private.org_v1_audit(s.org_id,'updatePermissions',jsonb_build_object('session',s.id,'operation','edit'));
end; $$;
create function public.broadcast_accept_assignment(p_id uuid,p_accept boolean,p_revision bigint) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); s public.broadcast_sessions;
begin
 select * into s from public.broadcast_sessions where id=p_id for update;
 if p_accept is null or not found or s.owner_id<>actor or s.org_id is null or s.revision<>p_revision
   or s.state<>'awaiting_acceptance' or s.expected_end_at<=now()
   or not private.broadcast_permission(actor,s.org_id,s.broadcast_type,false) then raise exception 'Assignment unavailable' using errcode='42501'; end if;
 update public.broadcast_sessions set state=case when p_accept then 'scheduled' else 'draft' end,
   accepted_at=case when p_accept then now() end,revision=revision+1 where id=s.id;
 perform private.org_v1_audit(s.org_id,'updatePermissions',jsonb_build_object('session',s.id,'accepted',p_accept));
end; $$;
create function public.broadcast_create_personal(p_title text,p_type text,p_start timestamptz default now()) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); result uuid;
begin
 if p_type not in ('liveVideo','liveAudio') or nullif(btrim(p_title),'') is null
   or not private.broadcast_permission(actor,null,p_type) then raise exception 'Personal broadcasting denied' using errcode='42501'; end if;
 perform private.broadcast_capacity(null,actor,null,p_start,p_start+interval '1 hour');
 insert into public.broadcast_sessions(owner_id,broadcast_type,state,title_en,scheduled_start_at,expected_end_at,accepted_at)
   values(actor,p_type,'scheduled',p_title,p_start,p_start+interval '1 hour',now()) returning id into result;
 return result;
end; $$;

create function public.broadcast_reserve(p_id uuid,p_device text,p_sender text,p_operation text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); s public.broadcast_sessions; c public.channel_connections; resource private.broadcast_provider; token uuid:=gen_random_uuid();
begin
 perform pg_advisory_xact_lock(20261001,3);
 select * into s from public.broadcast_sessions where id=p_id for update;
 if not found or p_operation not in ('prepare','start','end','observe') then raise exception 'Session unavailable' using errcode='42501'; end if;
 if p_operation='end' then
   if not (s.owner_id=actor or (s.org_id is not null and public.org_v1_can(s.org_id,'end')) or public.is_admin_tier()) then
     raise exception 'Session termination denied' using errcode='42501'; end if;
 else
   if s.owner_id<>actor or not private.broadcast_permission(actor,s.org_id,s.broadcast_type)
     or not private.broadcast_primary(actor,p_device) then raise exception 'Assigned primary presenter required' using errcode='42501'; end if;
 end if;
 if p_sender not in ('phone_direct','obs_laptop') then raise exception 'V1 sender required' using errcode='22023'; end if;
 if p_operation='end' and s.channel_connection_id is null and s.state in ('draft','awaiting_acceptance','scheduled','cancelled') then
   update public.broadcast_sessions set state='cancelled',ended_at=now(),end_reason='owner_end',revision=revision+1 where id=s.id and state<>'cancelled';
   return jsonb_build_object('done',true);
 end if;
 if p_operation in ('prepare','start') then
   if s.accepted_at is null or s.state not in ('scheduled','preparing','live') then raise exception 'Accepted session required' using errcode='55000'; end if;
   if s.scheduled_start_at>now()+interval '30 minutes' or s.expected_end_at<=now() then raise exception 'Outside session preflight window' using errcode='55000'; end if;
   if exists(select 1 from public.broadcast_sessions where owner_id=s.owner_id and id<>s.id and state in ('preparing','live','ending'))
     or (s.org_id is not null and (select count(*) from public.broadcast_sessions where org_id=s.org_id and id<>s.id and state in ('preparing','live','ending'))>=3) then
     raise exception 'Active session limit reached' using errcode='55000'; end if;
 end if;
 if s.channel_connection_id is null then
   select * into c from public.channel_connections where status='connected' and organization_id is not distinct from s.org_id
     and (s.org_id is not null or owner_profile_id=s.owner_id) for update;
   if not found or not private.channel_owner(c.owner_profile_id,c.organization_id) then raise exception 'Verified connected channel required' using errcode='42501'; end if;
   update public.broadcast_sessions set channel_connection_id=c.id,content_owner_profile_id=c.owner_profile_id,
     device_id=p_device,sender_mode=p_sender,revision=revision+1 where id=s.id;
   insert into private.broadcast_provider(session_id,channel_revision) values(s.id,c.revision);
 else
   select * into c from public.channel_connections where id=s.channel_connection_id for update;
 end if;
 select * into resource from private.broadcast_provider where session_id=s.id for update;
 if resource.claimed_until>now() then raise exception 'Operation in progress; refresh this session' using errcode='55000'; end if;
 if p_operation in ('prepare','start') and (c.status<>'connected' or c.revision<>resource.channel_revision
   or (s.device_id is not null and s.device_id<>p_device) or (s.sender_mode<>'unspecified' and s.sender_mode<>p_sender)) then
   raise exception 'Destination or device changed; end this session' using errcode='42501'; end if;
 if p_operation='prepare' and s.state='scheduled' then
   update public.broadcast_sessions set state='preparing',revision=revision+1 where id=s.id;
 elsif p_operation='end' and s.state in ('draft','awaiting_acceptance','scheduled') and resource.provider_broadcast_id is null and resource.provider_stream_id is null then
   update public.broadcast_sessions set state='cancelled',ended_at=now(),end_reason='owner_end',revision=revision+1 where id=s.id;
 elsif p_operation='end' and s.state in ('preparing','live','ending') then
   update public.broadcast_sessions set state='ending',termination_pending=true,end_reason=coalesce(end_reason,'owner_end'),revision=revision+1 where id=s.id;
 end if;
 update private.broadcast_provider set operation=p_operation,operation_token=token,actor_id=actor,
   auth_session_id=(auth.jwt()->>'session_id')::uuid,claimed_until=now()+interval '2 minutes' where session_id=s.id;
 if p_operation='end' then perform private.org_v1_audit(s.org_id,'updatePermissions',jsonb_build_object('session',s.id,'operation','end')); end if;
 return jsonb_build_object('token',token);
end; $$;

create function public.broadcast_operation_context(p_id uuid,p_token uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.broadcast_sessions; r private.broadcast_provider; c public.channel_connections; refresh text; ingest text;
begin
 select * into s from public.broadcast_sessions where id=p_id;
 select * into r from private.broadcast_provider where session_id=p_id;
 select * into c from public.channel_connections where id=s.channel_connection_id;
 if r.operation_token is null or r.operation_token is distinct from p_token or r.claimed_until is null or r.claimed_until<=now() then raise exception 'Reservation expired' using errcode='42501'; end if;
 if r.operation in ('prepare','start') and (s.state not in ('preparing','live') or s.accepted_at is null
   or not private.channel_actor(r.actor_id,r.auth_session_id) or not private.broadcast_permission(s.owner_id,s.org_id,s.broadcast_type)
   or not private.broadcast_primary(s.owner_id,s.device_id) or c.status<>'connected' or c.revision<>r.channel_revision
   or not private.channel_owner(c.owner_profile_id,c.organization_id)) then raise exception 'Publishing permission changed' using errcode='42501'; end if;
 select v.decrypted_secret into refresh from private.channel_credentials cc join vault.decrypted_secrets v on v.id=cc.secret_id where cc.connection_id=c.id;
 select decrypted_secret into ingest from vault.decrypted_secrets where id=r.ingest_secret_id;
 if refresh is null then raise exception 'Owner reconnection required' using errcode='55000'; end if;
 return jsonb_build_object('session',to_jsonb(s),'resource',to_jsonb(r)-'ingest_secret_id','channel_id',c.youtube_channel_id,
   'refresh_token',refresh,'ingest_key',ingest);
end; $$;
create function public.broadcast_provider_step(p_id uuid,p_token uuid,p_step text,p_result jsonb default null,
 p_error text default null,p_ambiguous boolean default false) returns void
language plpgsql security definer set search_path='' as $$
declare r private.broadcast_provider; s public.broadcast_sessions; secret uuid;
begin
 select * into r from private.broadcast_provider where session_id=p_id for update;
 if not found or r.operation_token is distinct from p_token then raise exception 'Reservation changed' using errcode='40001'; end if;
 select * into s from public.broadcast_sessions where id=p_id for update;
 if p_step not in ('stream_create','broadcast_create','bind','transition_live','transition_complete','feed_delete','observe','reconcile','finish') then
   raise exception 'Provider step invalid' using errcode='22023'; end if;
 if p_error is not null then
   update private.broadcast_provider set last_error=left(p_error,100),needs_reconciliation=p_ambiguous,
     claimed_until=null,checked_at=now() where session_id=p_id;
   return;
 end if;
 if p_result is null and p_step not in ('finish','observe','reconcile') then
   if r.needs_reconciliation then raise exception 'Reconcile ambiguous write first' using errcode='55000'; end if;
   -- Every write is recorded before contacting YouTube. A crash is ambiguous.
   update private.broadcast_provider set step=p_step,needs_reconciliation=true where session_id=p_id;
   return;
 end if;
 if p_step='stream_create' then
   if p_result->>'id' is null or nullif(p_result->>'key','') is null or p_result->>'url' !~ '^rtmps://([a-z0-9-]+\.)*rtmp\.youtube\.com(:443)?/' then
     raise exception 'Invalid secure feed result' using errcode='22023'; end if;
   if r.ingest_secret_id is null then secret:=vault.create_secret(p_result->>'key','youtube_ingest_'||p_id::text);
   else secret:=r.ingest_secret_id; perform vault.update_secret(secret,p_result->>'key'); end if;
   update private.broadcast_provider set provider_stream_id=p_result->>'id',ingest_url=p_result->>'url',ingest_secret_id=secret where session_id=p_id;
 elsif p_step='broadcast_create' then
   if p_result->>'id' !~ '^[A-Za-z0-9_-]{11}$' then raise exception 'Invalid provider broadcast' using errcode='22023'; end if;
   update private.broadcast_provider set provider_broadcast_id=p_result->>'id' where session_id=p_id;
   update public.broadcast_sessions set stream_id=p_result->>'id',revision=revision+1 where id=p_id;
 elsif p_step='bind' then
   update private.broadcast_provider set bound=true where session_id=p_id;
 elsif p_step='feed_delete' then
   update private.broadcast_provider set feed_retired=true,ingest_secret_id=null where session_id=p_id;
   delete from vault.secrets where id=r.ingest_secret_id;
 elsif p_step in ('observe','transition_live','transition_complete') then
   if p_result->>'deleted'='true' then update private.broadcast_provider set broadcast_deleted=true where session_id=p_id; end if;
   update public.broadcast_sessions set provider_observed_at=now() where id=p_id;
   if p_result->>'status'='live' and s.state='preparing' then
     if private.broadcast_permission(s.owner_id,s.org_id,s.broadcast_type) and private.broadcast_primary(s.owner_id,s.device_id)
       and (select status='connected' and revision=r.channel_revision from public.channel_connections where id=s.channel_connection_id) then
       update public.broadcast_sessions set state='live',started_at=now(),revision=revision+1 where id=p_id;
     else update public.broadcast_sessions set state='ending',termination_pending=true,end_reason='approval_revoked',revision=revision+1 where id=p_id; end if;
   elsif p_result->>'status' in ('complete','revoked') and s.state in ('preparing','live','ending') then
     update public.broadcast_sessions set state='processing_replay',replay_status='processing',termination_pending=false,
       ended_at=now(),end_reason=coalesce(end_reason,'ended'),revision=revision+1 where id=p_id;
   end if;
   if p_result->>'replay' in ('available','missing') and s.state='processing_replay' then
     update public.broadcast_sessions set state='completed',replay_status=p_result->>'replay',revision=revision+1 where id=p_id;
   end if;
 elsif p_step='finish' then
   update private.broadcast_provider set claimed_until=null,last_error=null,checked_at=now() where session_id=p_id;
   return;
 end if;
 update private.broadcast_provider set step=p_step,needs_reconciliation=false,last_error=null,checked_at=now() where session_id=p_id;
end; $$;

-- Compatibility summaries may be derived from a session; never create one from a profile flag.
create or replace function public.sync_broadcast_session() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if coalesce(current_setting('app.session_summary',true),'')='1' then return new; end if;
 if new.is_currently_live and (tg_op='INSERT' or not old.is_currently_live or new.active_stream_id is distinct from old.active_stream_id)
   and not exists(select 1 from public.broadcast_sessions where owner_id=new.id and state='live' and stream_id=new.active_stream_id) then
   raise exception 'Provider-confirmed session required' using errcode='42501'; end if;
 if tg_op='UPDATE' and old.is_currently_live and not new.is_currently_live then
   update public.broadcast_sessions set state='ending',termination_pending=true,
     end_reason=coalesce(nullif(current_setting('app.broadcast_end_reason',true),''),'ended'),revision=revision+1
     where owner_id=new.id and state in ('preparing','live');
 end if;
 return new;
end; $$;
create function public.broadcast_sync_summary() returns trigger
language plpgsql security definer set search_path='' as $$
declare live_session public.broadcast_sessions; org_count integer;
begin
 perform set_config('app.session_summary','1',true);
 select * into live_session from public.broadcast_sessions where owner_id=new.owner_id and state='live';
 update public.profiles set is_currently_live=live_session.id is not null,active_stream_id=live_session.stream_id,
   broadcast_type=case when live_session.id is null then 'offline' else live_session.broadcast_type end where id=new.owner_id;
 if new.org_id is not null then
   select count(*) into org_count from public.broadcast_sessions where org_id=new.org_id and state='live';
   update public.organizations set is_currently_live=org_count>0,
     active_stream_id=case when org_count=1 then (select stream_id from public.broadcast_sessions where org_id=new.org_id and state='live') end,
     broadcast_type=case when org_count=1 then (select broadcast_type from public.broadcast_sessions where org_id=new.org_id and state='live') else 'offline' end
     where id=new.org_id;
 end if;
 perform set_config('app.session_summary','',true);
 return new;
end; $$;
create trigger broadcast_sync_summary after insert or update of state on public.broadcast_sessions
 for each row execute function public.broadcast_sync_summary();
create function public.broadcast_guard_org_summary() returns trigger
language plpgsql security definer set search_path='' as $$
declare total integer;
begin
 if coalesce(current_setting('app.session_summary',true),'')='1' then return new; end if;
 select count(*) into total from public.broadcast_sessions where org_id=new.id and state='live';
 new.is_currently_live:=total>0;
 new.active_stream_id:=case when total=1 then (select stream_id from public.broadcast_sessions where org_id=new.id and state='live') end;
 new.broadcast_type:=case when total=1 then (select broadcast_type from public.broadcast_sessions where org_id=new.id and state='live') else 'offline' end;
 return new;
end; $$;
create trigger broadcast_guard_org_summary before insert or update of is_currently_live,active_stream_id,broadcast_type on public.organizations
 for each row execute function public.broadcast_guard_org_summary();
create function private.broadcast_secret_cleanup() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 delete from vault.secrets where id=old.ingest_secret_id;
 return old;
end; $$;
create trigger broadcast_secret_cleanup after delete on private.broadcast_provider
 for each row execute function private.broadcast_secret_cleanup();
create function public.broadcast_guard_delete() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.broadcast_sessions s left join private.broadcast_provider r on r.session_id=s.id
   where (case when tg_table_name='organizations' then s.org_id=old.id else
     s.owner_id=old.id or s.content_owner_profile_id=old.id end)
   and (s.state in ('preparing','live','ending') or (r.provider_stream_id is not null and not r.feed_retired))) then
   raise exception 'Complete provider termination and feed retirement before deleting this account or organization' using errcode='55000'; end if;
 return old;
end; $$;
create trigger broadcast_guard_delete before delete on public.profiles for each row execute function public.broadcast_guard_delete();
create trigger broadcast_guard_delete before delete on public.organizations for each row execute function public.broadcast_guard_delete();
create function public.broadcast_revoke_member() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 update public.broadcast_sessions s set state=case when s.state in ('preparing','live','ending') then 'ending' else 'cancelled' end,
   accepted_at=null,termination_pending=s.state in ('preparing','live','ending'),end_reason='approval_revoked',
   ended_at=case when s.state not in ('preparing','live','ending') then now() end,revision=revision+1
 where s.owner_id=new.profile_id and s.org_id=new.organization_id and s.state in ('draft','awaiting_acceptance','scheduled','preparing','live','ending')
   and (new.status<>'active' or new.permissions->>case when s.broadcast_type='liveAudio' then 'can_go_audio_only' else 'can_go_live_video' end is distinct from 'true');
 perform set_config('app.org_schedule_write','1',true);
 update public.upcoming_schedules set cancelled_at=now() where organization_id=new.organization_id and streamer_profile_id=new.profile_id
   and cancelled_at is null and (new.status<>'active' or new.permissions->>case when broadcast_type='liveAudio' then 'can_go_audio_only' else 'can_go_live_video' end is distinct from 'true');
 perform set_config('app.org_schedule_write','',true);
 return new;
end; $$;
create trigger broadcast_revoke_member after update of status,permissions on public.org_memberships
 for each row execute function public.broadcast_revoke_member();
create function public.broadcast_revoke_approval() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 update public.broadcast_sessions s set state=case when s.state in ('preparing','live','ending') then 'ending' else 'cancelled' end,
   termination_pending=s.state in ('preparing','live','ending'),end_reason='approval_revoked',accepted_at=null,revision=revision+1
 where s.owner_id=new.id and s.state in ('draft','awaiting_acceptance','scheduled','preparing','live','ending')
   and (not new.is_verified or (s.org_id is null and not new.personal_broadcast_approved) or (s.org_id is not null and not new.organization_broadcast_approved));
 return new;
end; $$;
create trigger broadcast_revoke_approval after update of is_verified,personal_broadcast_approved,organization_broadcast_approved on public.profiles
 for each row execute function public.broadcast_revoke_approval();
create function public.broadcast_revoke_organization() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if not new.is_verified then
   update public.broadcast_sessions set state=case when state in ('preparing','live','ending') then 'ending' else 'cancelled' end,
     termination_pending=state in ('preparing','live','ending'),end_reason='organization_revoked',accepted_at=null,revision=revision+1
     where org_id=new.id and state in ('draft','awaiting_acceptance','scheduled','preparing','live','ending');
 end if;
 return new;
end; $$;
create trigger broadcast_revoke_organization after update of is_verified on public.organizations
 for each row execute function public.broadcast_revoke_organization();

create or replace function public.sweep_stale_live_flags() returns integer
language plpgsql security definer set search_path='' as $$
declare affected integer;
begin
 update public.broadcast_sessions s set state='ending',termination_pending=true,end_reason='ingest_lost',revision=revision+1
 where s.state='live' and s.sender_mode='phone_direct' and s.ingest_state='interrupted' and s.interrupted_since<now()-interval '120 seconds';
 get diagnostics affected=row_count;
 -- OBS is observed through YouTube; a closed management tab is not an encoder failure.
 return affected;
end; $$;
create or replace function public.end_broadcast_session(p_session_id uuid,p_device_id text) returns void
language plpgsql security definer set search_path='' as $$
declare s public.broadcast_sessions;
begin
 perform private.org_v1_actor();
 select * into s from public.broadcast_sessions where id=p_session_id for update;
 if not found or s.owner_id<>auth.uid() or s.device_id<>p_device_id then raise exception 'Session device denied' using errcode='42501'; end if;
 update public.broadcast_sessions set state='ending',termination_pending=true,end_reason='owner_end',revision=revision+1
   where id=p_session_id and state in ('preparing','live');
end; $$;
create or replace function public.my_broadcast_status() returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('live',coalesce(s.state='live',false),'state',s.state,'session_id',s.id,'stream_id',s.stream_id,
   'device_id',s.device_id,'termination_pending',s.termination_pending,'last_ended',
   (select jsonb_build_object('session_id',b.id,'reason',b.end_reason) from public.broadcast_sessions b where b.owner_id=auth.uid()
     and b.state in ('ending','processing_replay','completed','ended','cancelled','failed') order by b.revision desc,b.ended_at desc nulls last limit 1))
 from (select 1) seed left join lateral(select * from public.broadcast_sessions where owner_id=auth.uid()
   and state in ('preparing','live','ending') order by scheduled_start_at desc limit 1) s on true;
$$;

drop policy broadcast_sessions_select_own_or_admin on public.broadcast_sessions;
create function public.broadcast_is_public(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.broadcast_sessions s where s.id=p_id
   and s.state in ('scheduled','live','processing_replay','completed') and not s.hidden_from_discovery
   and not public.is_banned(s.owner_id) and (s.org_id is null or exists(select 1 from public.organizations where id=s.org_id and is_verified)));
$$;
create policy broadcast_sessions_public_read on public.broadcast_sessions for select to anon using(public.broadcast_is_public(id));
create policy broadcast_sessions_read on public.broadcast_sessions for select to authenticated using(
 public.broadcast_is_public(id) or owner_id=auth.uid() or public.is_admin_tier() or (org_id is not null and public.org_v1_can(org_id,'schedule')));
grant select on public.broadcast_sessions to anon;
create function public.broadcast_list_sessions(p_org uuid default null,p_mine boolean default false) returns setof public.broadcast_sessions
language sql stable set search_path='' as $$
 select * from public.broadcast_sessions where (p_org is null or org_id=p_org) and (not p_mine or owner_id=auth.uid())
   and (expected_end_at>now()-interval '7 days' or state in ('preparing','live','ending','processing_replay','completed')) order by scheduled_start_at;
$$;
create function public.broadcast_reconcile_claim() returns setof jsonb
language plpgsql security definer set search_path='' as $$
declare s public.broadcast_sessions; token uuid; template record;
begin
 -- Revocation and transfer must also terminate provider media when the app is absent.
 update public.broadcast_sessions s set state='ending',termination_pending=true,end_reason='approval_revoked',revision=revision+1
 from public.channel_connections c,private.broadcast_provider r
 where s.channel_connection_id=c.id and r.session_id=s.id and s.state in ('preparing','live')
   and (not private.broadcast_permission(s.owner_id,s.org_id,s.broadcast_type,false)
     or not private.channel_owner(c.owner_profile_id,c.organization_id) or c.status<>'connected' or c.revision<>r.channel_revision
     or not exists(select 1 from public.device_sessions where user_id=s.owner_id and device_id=s.device_id and is_primary_broadcaster));
 for template in select id from public.upcoming_schedules where organization_id is not null and cancelled_at is null loop
   begin perform private.broadcast_materialize(template.id);
   exception when exclusion_violation then null; end;
 end loop;
 for s in select b.* from public.broadcast_sessions b join private.broadcast_provider r on r.session_id=b.id
   where (b.state in ('preparing','live','ending','processing_replay') or (b.state in ('completed','cancelled') and not r.feed_retired))
   and (r.claimed_until is null or r.claimed_until<now()) and (r.checked_at is null or r.checked_at<now()-interval '30 seconds')
   order by r.checked_at nulls first limit 20 for update of r skip locked loop
   token:=gen_random_uuid();
   update private.broadcast_provider set operation=case when s.state='ending' then 'end' else 'observe' end,
     operation_token=token,actor_id=null,auth_session_id=null,claimed_until=now()+interval '2 minutes' where session_id=s.id;
   return next jsonb_build_object('id',s.id,'token',token);
 end loop;
end; $$;

do $$ declare f record;
begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where (n.nspname='public' and p.proname like 'broadcast_%') or (n.nspname='private' and p.proname like 'broadcast_%') loop
   execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
 end loop;
end; $$;
grant execute on function public.broadcast_save_schedule(uuid,uuid,uuid,text,time,smallint[],timestamptz,text,text,text,integer,uuid),
 public.broadcast_edit_occurrence(uuid,uuid,timestamptz,timestamptz,text,uuid),public.broadcast_accept_assignment(uuid,boolean,bigint),
 public.broadcast_create_personal(text,text,timestamptz),public.broadcast_reserve(uuid,text,text,text) to authenticated;
grant execute on function public.broadcast_list_sessions(uuid,boolean),public.broadcast_is_public(uuid) to anon,authenticated;
grant execute on function public.broadcast_operation_context(uuid,uuid),public.broadcast_provider_step(uuid,uuid,text,jsonb,text,boolean),
 public.broadcast_reconcile_claim() to service_role;
revoke all on all tables in schema private from public,anon,authenticated,service_role;
commit;
