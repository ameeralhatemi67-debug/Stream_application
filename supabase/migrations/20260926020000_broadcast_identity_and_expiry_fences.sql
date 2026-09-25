-- Independent audit: expiry cannot clear a replacement selected after its snapshot.
-- Organization ownership is the session's org_id, never a coincident watch ID.
-- CREATE OR REPLACE preserves the original restricted function grants.
begin;
create or replace function public.sync_broadcast_session() returns trigger
language plpgsql security definer set search_path='' as $$
declare
  v_reason text := nullif(current_setting('app.broadcast_end_reason', true), '');
  v_device text := nullif(current_setting('app.broadcast_device', true), '');
  v_org text := nullif(current_setting('app.broadcast_org', true), '');
  v_was_live boolean := tg_op = 'UPDATE' and old.is_currently_live and old.active_stream_id is not null;
  v_identity_changed boolean;
  v_is_live boolean := new.is_currently_live and new.active_stream_id is not null;
begin
  -- Watch identity alone is insufficient when the same account switches orgs.
  v_identity_changed := new.active_stream_id is distinct from old.active_stream_id
    or (v_device is not null and exists(select 1 from public.broadcast_sessions b
      where b.owner_id=new.id and b.state='live'
        and (b.org_id is distinct from v_org::uuid or b.device_id is distinct from v_device)));
  if v_was_live and (not v_is_live or v_identity_changed) then
    if v_is_live then
      v_reason := 'replaced';
    elsif v_reason is null then
      v_reason := case
        when public.is_banned(new.id) then 'ban'
        when not (new.is_streamer and new.is_verified) then 'approval_revoked'
        else 'ended' end;
    end if;
    update public.broadcast_sessions
      set state = 'ended', end_reason = v_reason, ended_at = now(), revision = revision + 1
      where owner_id = new.id and state = 'live';
  end if;
  if v_is_live and not (v_was_live and not v_identity_changed) then
    -- A stale session left live by an inconsistent write is closed first so
    -- the one-live-per-owner index never blocks a legitimate start.
    update public.broadcast_sessions
      set state = 'ended', end_reason = 'replaced', ended_at = now(), revision = revision + 1
      where owner_id = new.id and state = 'live';
    insert into public.broadcast_sessions(owner_id, org_id, device_id, stream_id, broadcast_type)
      values (new.id, v_org::uuid, v_device, new.active_stream_id,
              coalesce(nullif(new.broadcast_type, 'offline'), 'liveVideo'));
  end if;
  return new;
end;
$$;

create or replace function public.set_live_state(p_live boolean, p_type text, p_stream_id text, p_device_id text, p_org_id uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_previous text;
begin
  if v_uid is null or public.is_banned(v_uid) then raise exception 'Broadcast not permitted' using errcode='42501'; end if;
  if p_live is null then raise exception 'Live state required'; end if;
  perform pg_advisory_xact_lock(20260920, 12);
  if p_live then
    if not exists(select 1 from public.device_sessions where user_id=v_uid and device_id=p_device_id
      and is_primary_broadcaster and last_active_at > now() - interval '90 seconds') then
      raise exception 'Primary device required' using errcode='42501';
    end if;
    if not public.can_broadcast(p_org_id,p_type) then raise exception 'Broadcast not permitted' using errcode='42501'; end if;
    if p_stream_id is null or p_stream_id !~ '^[A-Za-z0-9_-]{11}$' then raise exception 'Invalid YouTube video ID'; end if;
    -- A broadcast an admin ended cannot be put back by a plain live write
    -- (an older app build re-asserting after a reconnect, or a scripted
    -- call). Starting again is an explicit new start through
    -- start_broadcast_session(), which marks its own transaction.
    if coalesce(current_setting('app.explicit_start', true), '') <> '1'
       and not exists(select 1 from public.profiles p where p.id = v_uid
         and p.is_currently_live and p.active_stream_id = p_stream_id)
       and (select b.end_reason from public.broadcast_sessions b
             where b.owner_id = v_uid and b.stream_id = p_stream_id
             order by b.started_at desc limit 1) in ('admin_end','admin_remove') then
      raise exception 'Broadcast ended by an administrator; start a new broadcast'
        using errcode='42501';
    end if;
    if p_org_id is not null and exists(select 1 from public.organizations o where o.id=p_org_id and o.is_currently_live
      and not exists(select 1 from public.broadcast_sessions b where b.owner_id=v_uid and b.org_id=o.id and b.state='live' and b.stream_id=o.active_stream_id)) then
      raise exception 'Organization already broadcasting' using errcode='42501';
    end if;
  else
    if not exists(select 1 from public.device_sessions where user_id=v_uid and device_id=p_device_id
      and is_primary_broadcaster) then
      raise exception 'Primary device required' using errcode='42501';
    end if;
  end if;
  perform set_config('app.broadcast_end_reason', 'owner_end', true);
  perform set_config('app.broadcast_device', coalesce(p_device_id, ''), true);
  perform set_config('app.broadcast_org', coalesce(p_org_id::text, ''), true);
  select active_stream_id into v_previous from public.profiles where id=v_uid;
  update public.organizations set is_currently_live=false,broadcast_type='offline',active_stream_id=null,active_viewer_count=0 where active_stream_id=v_previous;
  update public.profiles set is_currently_live=p_live, broadcast_type=case when p_live then p_type else 'offline' end,
    active_stream_id=case when p_live then p_stream_id else null end, active_viewer_count=0 where id=v_uid;
  perform public.reset_broadcast_context();
  if p_live and p_org_id is not null then
    update public.organizations set is_currently_live=true,broadcast_type=p_type,active_stream_id=p_stream_id,active_viewer_count=0 where id=p_org_id;
  end if;
end;
$$;

create or replace function public.sweep_stale_live_flags()
returns integer language plpgsql security definer set search_path = '' as $$
declare v_stale uuid[]; v_streams text[]; v_ingest_lost integer := 0;
begin
  if not pg_try_advisory_xact_lock(20260920, 13) then return 0; end if;
  -- Serialize selection and clearing with starts, ends and ingest recovery.
  if not pg_try_advisory_xact_lock(20260920, 12) then return 0; end if;
  -- A sending phone that reported "interrupted" and never recovered: its
  -- encoder gives up after about 90 s of retries, so after 120 s the app no
  -- longer lists it as live even if the app itself is still heartbeating.
  select coalesce(array_agg(p.id), '{}'::uuid[]),
         coalesce(array_agg(p.active_stream_id) filter (where p.active_stream_id is not null), '{}'::text[])
    into v_stale, v_streams
    from public.profiles p
    join public.broadcast_sessions b on b.owner_id = p.id and b.state = 'live'
    where p.is_currently_live and b.ingest_state = 'interrupted'
      and b.interrupted_since <= now() - interval '120 seconds';
  if array_length(v_stale, 1) is not null then
    perform set_config('app.broadcast_end_reason', 'ingest_lost', true);
    update public.organizations set is_currently_live=false, broadcast_type='offline',
      active_stream_id=null, active_viewer_count=0
      where active_stream_id = any(v_streams);
    update public.profiles set is_currently_live=false, broadcast_type='offline',
      active_stream_id=null, active_viewer_count=0
      where id = any(v_stale);
    perform public.reset_broadcast_context();
  end if;
  v_ingest_lost := coalesce(array_length(v_stale, 1), 0);
  select coalesce(array_agg(p.id), '{}'::uuid[]),
         coalesce(array_agg(p.active_stream_id) filter (where p.active_stream_id is not null), '{}'::text[])
    into v_stale, v_streams
    from public.profiles p
    where p.is_currently_live
      and not exists (
        select 1 from public.device_sessions d
        where d.user_id = p.id and d.is_primary_broadcaster
          and d.last_active_at > now() - interval '90 seconds');
  if array_length(v_stale, 1) is null then return v_ingest_lost; end if;
  perform set_config('app.broadcast_end_reason', 'stale_expired', true);
  update public.organizations set is_currently_live=false, broadcast_type='offline',
    active_stream_id=null, active_viewer_count=0
    where active_stream_id = any(v_streams);
  update public.profiles set is_currently_live=false, broadcast_type='offline',
    active_stream_id=null, active_viewer_count=0
    where id = any(v_stale);
  perform public.reset_broadcast_context();
  return v_ingest_lost + array_length(v_stale, 1);
end;
$$;

create or replace function public.admin_moderate_broadcaster(p_target_id uuid, p_is_organization boolean,
  p_action text, p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare v_hidden boolean; v_stream text; v_action text;
begin
 if auth.uid() is null or not public.is_admin_tier() or public.is_banned(auth.uid()) then
   raise exception 'Not permitted' using errcode='42501';
 end if;
 if p_action is null or p_action not in ('hide_from_map','show_on_map','revoke_organization')
   or p_is_organization is null
   or (p_action='revoke_organization' and not p_is_organization)
   or p_reason is null or length(trim(p_reason)) not between 1 and 500 then
   raise exception 'Invalid moderation action or reason' using errcode='22023';
 end if;
 perform pg_advisory_xact_lock(20260920,12);
 if p_is_organization then
   select is_temporarily_hidden_from_map, active_stream_id into v_hidden, v_stream
     from public.organizations where id=p_target_id for update;
 else
   select is_temporarily_hidden_from_map, active_stream_id into v_hidden, v_stream
     from public.profiles where id=p_target_id and is_streamer for update;
 end if;
 if not found then raise exception 'Broadcaster not found' using errcode='P0002'; end if;
 if not p_is_organization and (p_target_id=auth.uid() or exists(select 1 from public.user_roles
     where profile_id=p_target_id and role='master_admin')
     or (not public.is_master_admin() and exists(select 1 from public.user_roles
       where profile_id=p_target_id and role='admin'))) then
   raise exception 'Protected administrator' using errcode='42501';
 end if;

 if p_action in ('hide_from_map','show_on_map') then
   if v_hidden = (p_action='hide_from_map') then return; end if;
   if p_is_organization then
     update public.organizations set is_temporarily_hidden_from_map=(p_action='hide_from_map') where id=p_target_id;
   else
     update public.profiles set is_temporarily_hidden_from_map=(p_action='hide_from_map') where id=p_target_id;
   end if;
   v_action := case when p_action='hide_from_map' then 'broadcasterHiddenFromMap' else 'broadcasterShownOnMap' end;
 else
   update public.organizations set is_verified=false,is_currently_live=false,broadcast_type='offline',
     active_stream_id=null,active_viewer_count=0 where id=p_target_id;
   if v_stream is not null then
     perform set_config('app.broadcast_end_reason', 'organization_revoked', true);
     update public.profiles set is_currently_live=false,broadcast_type='offline',active_stream_id=null,
       active_viewer_count=0 where id in (
         select b.owner_id from public.broadcast_sessions b
         where b.org_id=p_target_id and b.state='live' and b.stream_id=v_stream);
     perform public.reset_broadcast_context();
   end if;
   v_action := 'organizationVerificationRevoked';
 end if;
 perform public.log_audit_event_internal(null,v_action,trim(p_reason),trim(p_reason),
   jsonb_build_object('target_id',p_target_id,'is_organization',p_is_organization,'action',p_action));
end;
$$;

create or replace function public.report_broadcast_ingest(p_session_id uuid, p_device_id text, p_state text)
returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid := auth.uid(); v_session public.broadcast_sessions;
begin
  if v_uid is null or public.is_banned(v_uid) then raise exception 'Broadcast not permitted' using errcode='42501'; end if;
  if p_state is null or p_state not in ('sending','interrupted') then
    raise exception 'Invalid ingest state' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(20260920, 12);
  select * into v_session from public.broadcast_sessions where id = p_session_id for update;
  if not found or v_session.owner_id <> v_uid then
    raise exception 'Broadcast session not found' using errcode='42501';
  end if;
  if v_session.state <> 'live' then
    raise exception 'Broadcast session ended' using errcode='55000';
  end if;
  if v_session.device_id is distinct from p_device_id or not exists(
      select 1 from public.device_sessions d where d.user_id = v_uid
        and d.device_id = p_device_id and d.is_primary_broadcaster) then
    raise exception 'Primary device required' using errcode='42501';
  end if;
  if v_session.ingest_state = p_state then
    update public.broadcast_sessions set ingest_observed_at = now() where id = p_session_id;
    return;
  end if;
  update public.broadcast_sessions
     set ingest_state = p_state, ingest_observed_at = now(), revision = revision + 1,
         interrupted_since = case when p_state = 'interrupted' then now() end
   where id = p_session_id;
end;
$$;
commit;
