-- P1.2/P1.7. Existing live flags were client-writable and cannot be trusted.
-- Applying this migration ends existing sessions; clients must claim again.
begin;
update public.profiles set is_currently_live = false, broadcast_type = 'offline', active_stream_id = null, active_viewer_count = 0;
update public.organizations set is_currently_live = false, broadcast_type = 'offline', active_stream_id = null, active_viewer_count = 0;
update public.device_sessions set is_primary_broadcaster = false;
create unique index profiles_one_live_stream on public.profiles(active_stream_id)
  where is_currently_live and active_stream_id is not null;
create unique index device_sessions_one_primary on public.device_sessions(user_id)
  where is_primary_broadcaster;
drop policy device_sessions_write_own on public.device_sessions;
-- Device writes are RPC-only, including timestamps and primary status.

create function public.can_broadcast(p_org_id uuid, p_type text)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and not public.is_banned(auth.uid())
    and p_type in ('liveVideo', 'liveAudio') and case when p_org_id is null then
      exists(select 1 from public.profiles where id = auth.uid() and is_streamer and is_verified)
    else exists(select 1 from public.organizations o where o.id = p_org_id and o.is_verified
      and (o.owner_profile_id = auth.uid() or exists(select 1 from public.org_speakers s
        where s.organization_id = o.id and s.linked_profile_id = auth.uid()
        and s.permissions ->> case when p_type = 'liveVideo' then 'can_go_live_video' else 'can_go_audio_only' end = 'true')))
    end;
$$;
revoke execute on function public.can_broadcast(uuid,text) from public, anon;
grant execute on function public.can_broadcast(uuid,text) to authenticated;

create function public.claim_broadcaster_device(p_device_id text, p_name text, p_platform text, p_force boolean default false)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_previous text;
begin
  if v_uid is null or public.is_banned(v_uid) then raise exception 'Broadcast not permitted' using errcode = '42501'; end if;
  if p_device_id is null or length(p_device_id) not between 1 and 128 then raise exception 'Invalid device'; end if;
  if not (public.can_broadcast(null,'liveVideo') or exists(select 1 from public.organizations o
    where public.can_broadcast(o.id,'liveVideo') or public.can_broadcast(o.id,'liveAudio'))) then
    raise exception 'Broadcast not permitted' using errcode = '42501';
  end if;
  -- Shared lock orders live/claim/release operations across users and organizations.
  perform pg_advisory_xact_lock(20260920, 12);
  if not coalesce(p_force,false) and exists(select 1 from public.device_sessions
    where user_id = v_uid and device_id <> p_device_id and is_primary_broadcaster
    and last_active_at > now() - interval '90 seconds') then return false; end if;
  if exists(select 1 from public.device_sessions where user_id = v_uid
    and device_id <> p_device_id and is_primary_broadcaster) then
    select active_stream_id into v_previous from public.profiles where id = v_uid;
    update public.organizations set is_currently_live=false, broadcast_type='offline', active_stream_id=null, active_viewer_count=0
      where active_stream_id = v_previous;
    update public.profiles set is_currently_live=false, broadcast_type='offline', active_stream_id=null, active_viewer_count=0 where id=v_uid;
  end if;
  update public.device_sessions set is_primary_broadcaster=false where user_id=v_uid and device_id<>p_device_id;
  insert into public.device_sessions(user_id,device_id,device_name,platform,is_primary_broadcaster,last_active_at)
    values(v_uid,p_device_id,left(coalesce(p_name,''),128),left(coalesce(p_platform,''),32),true,now())
    on conflict(user_id,device_id) do update set device_name=excluded.device_name,
      platform=excluded.platform,is_primary_broadcaster=true,last_active_at=now();
  return true;
end;
$$;
revoke execute on function public.claim_broadcaster_device(text,text,text,boolean) from public, anon;
grant execute on function public.claim_broadcaster_device(text,text,text,boolean) to authenticated;

create function public.device_heartbeat(p_device_id text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_primary boolean;
begin
  if auth.uid() is null or public.is_banned(auth.uid()) then return false; end if;
  update public.device_sessions set last_active_at=now() where user_id=auth.uid() and device_id=p_device_id
    returning is_primary_broadcaster into v_primary;
  return coalesce(v_primary,false);
end;
$$;
revoke execute on function public.device_heartbeat(text) from public, anon;
grant execute on function public.device_heartbeat(text) to authenticated;

create function public.set_live_state(p_live boolean, p_type text, p_stream_id text, p_device_id text, p_org_id uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_previous text;
begin
  if v_uid is null or public.is_banned(v_uid) then raise exception 'Broadcast not permitted' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(20260920, 12);
  if not exists(select 1 from public.device_sessions where user_id=v_uid and device_id=p_device_id
    and is_primary_broadcaster and last_active_at > now() - interval '90 seconds') then
    raise exception 'Primary device required' using errcode='42501';
  end if;
  if p_live is null then raise exception 'Live state required'; end if;
  if p_live then
    if not public.can_broadcast(p_org_id,p_type) then raise exception 'Broadcast not permitted' using errcode='42501'; end if;
    if p_stream_id is null or p_stream_id !~ '^[A-Za-z0-9_-]{11}$' then raise exception 'Invalid YouTube video ID'; end if;
    if p_org_id is not null and exists(select 1 from public.organizations o where o.id=p_org_id and o.is_currently_live
      and not exists(select 1 from public.profiles p where p.id=v_uid and p.active_stream_id=o.active_stream_id)) then
      raise exception 'Organization already broadcasting' using errcode='42501';
    end if;
  end if;
  select active_stream_id into v_previous from public.profiles where id=v_uid;
  update public.organizations set is_currently_live=false,broadcast_type='offline',active_stream_id=null,active_viewer_count=0 where active_stream_id=v_previous;
  update public.profiles set is_currently_live=p_live, broadcast_type=case when p_live then p_type else 'offline' end,
    active_stream_id=case when p_live then p_stream_id else null end, active_viewer_count=0 where id=v_uid;
  if p_live and p_org_id is not null then
    update public.organizations set is_currently_live=true,broadcast_type=p_type,active_stream_id=p_stream_id,active_viewer_count=0 where id=p_org_id;
  end if;
end;
$$;
revoke execute on function public.set_live_state(boolean,text,text,text,uuid) from public, anon;
grant execute on function public.set_live_state(boolean,text,text,text,uuid) to authenticated;

create function public.release_broadcaster_device(p_device_id text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_previous text;
begin
  perform pg_advisory_xact_lock(20260920, 12);
  if exists(select 1 from public.device_sessions where user_id=auth.uid() and device_id=p_device_id and is_primary_broadcaster) then
    select active_stream_id into v_previous from public.profiles where id=auth.uid();
    update public.organizations set is_currently_live=false,broadcast_type='offline',active_stream_id=null,active_viewer_count=0 where active_stream_id=v_previous;
    update public.profiles set is_currently_live=false,broadcast_type='offline',active_stream_id=null,active_viewer_count=0 where id=auth.uid();
  end if;
  delete from public.device_sessions where user_id=auth.uid() and device_id=p_device_id;
end;
$$;
revoke execute on function public.release_broadcaster_device(text) from public, anon;
grant execute on function public.release_broadcaster_device(text) to authenticated;
commit;
