-- P1c follow-ups to 20260920120000_guarded_broadcast_sessions.sql.
-- 1. A live flag had no expiry: if the broadcaster's phone died, the profile
--    (and its organization) stayed "live" forever, and set_live_state
--    required a heartbeat younger than 90 s even to switch live OFF -- so the
--    one path that could clear the flag was shut exactly when it was needed.
-- 2. bootstrap_admin_role() granted master_admin from the email string in the
--    inserted profiles row, without checking that Supabase Auth had actually
--    verified that address for that user id.
-- 3. log_audit_event() accepted writes from banned accounts.
-- No existing migration is edited; these replace the functions by name.
begin;

-- 1a. Ending a broadcast only needs the caller's own primary device row, not a
-- fresh heartbeat. Starting one still needs a heartbeat under 90 s, so a
-- silent device cannot start a stream.
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
    if p_org_id is not null and exists(select 1 from public.organizations o where o.id=p_org_id and o.is_currently_live
      and not exists(select 1 from public.profiles p where p.id=v_uid and p.active_stream_id=o.active_stream_id)) then
      raise exception 'Organization already broadcasting' using errcode='42501';
    end if;
  else
    -- Stopping: the caller must still own this device row and be its primary
    -- broadcaster, but a lapsed heartbeat must not trap the flag as live.
    if not exists(select 1 from public.device_sessions where user_id=v_uid and device_id=p_device_id
      and is_primary_broadcaster) then
      raise exception 'Primary device required' using errcode='42501';
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

-- 1b. Server-side expiry. A profile counts as live only while the primary
-- device that started the broadcast is still sending heartbeats; this clears
-- the flags of everyone whose primary device has been silent for more than
-- 90 seconds (a dead phone, a killed app, a lost network), and of the
-- organizations mirroring those streams.
-- Idempotent and self-limiting: it only ever switches flags OFF, using the
-- same heartbeat window the RPCs use, so any caller can run it safely.
create or replace function public.sweep_stale_live_flags()
returns integer language plpgsql security definer set search_path = '' as $$
declare v_stale uuid[]; v_streams text[];
begin
  -- try-lock: concurrent sweeps are pointless, so a caller that loses the
  -- race reports 0 instead of queueing behind the winner.
  if not pg_try_advisory_xact_lock(20260920, 13) then return 0; end if;
  select coalesce(array_agg(p.id), '{}'::uuid[]),
         coalesce(array_agg(p.active_stream_id) filter (where p.active_stream_id is not null), '{}'::text[])
    into v_stale, v_streams
    from public.profiles p
    where p.is_currently_live
      and not exists (
        select 1 from public.device_sessions d
        where d.user_id = p.id and d.is_primary_broadcaster
          and d.last_active_at > now() - interval '90 seconds');
  if array_length(v_stale, 1) is null then return 0; end if;
  update public.organizations set is_currently_live=false, broadcast_type='offline',
    active_stream_id=null, active_viewer_count=0
    where active_stream_id = any(v_streams);
  update public.profiles set is_currently_live=false, broadcast_type='offline',
    active_stream_id=null, active_viewer_count=0
    where id = any(v_stale);
  return array_length(v_stale, 1);
end;
$$;

comment on function public.sweep_stale_live_flags() is
  'Clears is_currently_live for broadcasters whose primary device heartbeat is older than 90 s, and the organizations mirroring those streams. Only ever turns flags off. Clients may call it opportunistically before reading the feed; a scheduled job (pg_cron) is the durable answer -- see brief/OWNER_ACTIONS.md.';

revoke execute on function public.sweep_stale_live_flags() from public, anon;
grant execute on function public.sweep_stale_live_flags() to authenticated;

-- 2. Only bootstrap master_admin when Supabase Auth has verified that address
-- for this exact user id. Previously any account that could insert its own
-- profiles row with one of these emails became master_admin, whatever address
-- it had actually signed up with. Which addresses are bootstrapped at all is
-- the owner's decision (05 owner-only actions); this closes the spoof path.
create or replace function public.bootstrap_admin_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_auth_email text;
begin
  select lower(u.email) into v_auth_email from auth.users u where u.id = new.id;
  if v_auth_email is not null
     and v_auth_email = lower(new.email)
     and v_auth_email in (
       'polkgvd2@gmail.com',
       'ameeralhatemi67@gmail.com',
       'amir.alhatemi@gmail.com'
     ) then
    insert into public.user_roles (profile_id, role)
    values (new.id, 'master_admin')
    on conflict (profile_id, role, organization_id) do nothing;
  end if;
  return new;
end;
$$;

-- 3. Banned accounts cannot append to the audit log. Every other RPC that
-- writes already refuses them; this one did not.
create or replace function public.log_audit_event(
  p_organization_id uuid,
  p_action text,
  p_description_en text,
  p_description_ar text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_email text;
  v_actor_name text;
  v_id uuid;
begin
  if auth.uid() is null or public.is_banned(auth.uid()) then
    raise exception 'Not permitted' using errcode = '42501';
  end if;

  select email, coalesce(display_name_en, email, 'Unknown')
    into v_actor_email, v_actor_name
    from public.profiles where id = auth.uid();

  insert into public.audit_logs (
    organization_id, actor_profile_id, actor_email, actor_name,
    action, description_en, description_ar, metadata
  ) values (
    p_organization_id, auth.uid(), coalesce(v_actor_email, 'unknown'), coalesce(v_actor_name, 'Unknown'),
    p_action, p_description_en, p_description_ar, p_metadata
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke execute on function public.log_audit_event(uuid, text, text, text, jsonb) from public, anon;
grant execute on function public.log_audit_event(uuid, text, text, text, jsonb) to authenticated;

commit;
