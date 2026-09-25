-- P6S wave 3, group 1: broadcast identity records and truthful admin live
-- controls (owner retest 2026-09-25, Test 6).
--
-- Findings this answers, reproduced from the SQL, not from screenshots:
--  * admin_auth_account_action('force_end' | 'remove_from_feed') also cleared
--    is_primary_broadcaster on every device of the account. The broadcasting
--    phone read that as "another device took over", showed "this device lost
--    its primary session" and dropped out of broadcaster mode, so ending one
--    broadcast looked like a demotion of the account.
--  * profiles carried only the current live flag. Nothing recorded which
--    broadcast (watch ID, device) had been live or why it ended, so a device
--    could not tell an admin End from a device transfer or a revocation.
--  * "Remove from Feed" ended the broadcast outright; there was no way to hide
--    a running broadcast from app discovery while current viewers keep
--    watching, and no way to undo it.
--
-- What changes:
--  1. broadcast_sessions: one row per app broadcast (owner, device, watch ID,
--     start/end, end reason, revision). A trigger on profiles keeps it in step
--     with every existing writer of the live flag, so no older function has to
--     be rewritten to stay correct. Writers that know why a broadcast ended
--     say so through a transaction-local setting; the trigger derives the
--     reason for revocations and bans.
--  2. admin force_end / remove_from_feed stop the broadcast without touching
--     device ownership or approval. delete_account / revoke_sessions still
--     release devices (the account's sessions are gone).
--  3. admin_set_stream_discovery hides the *current* live session from app
--     discovery (feed, map, live list) and shows it again. It does not end the
--     broadcast, does not remove anyone from the room, and is not access
--     control: the YouTube watch link and the app's direct room link keep
--     working. Labelled that way in the UI.
--  4. my_broadcast_status(): the caller's own live session and the last ended
--     one with its reason, so a broadcasting device can explain a remote end
--     precisely and never guesses from a demotion.
--  5. start_broadcast_session / report_broadcast_ingest / end_broadcast_session:
--     the sending device works through its session id, so a late reconnect
--     can never revive a session that was ended, and viewers can be told
--     "reconnecting" instead of seeing LIVE flicker off and on.
-- Earlier migrations are not edited; functions are replaced by name.
begin;

-- ---------------------------------------------------------------------------
-- Audit actions for the new discovery control (server-only).
-- ---------------------------------------------------------------------------
do $$
declare v_constraint text;
begin
 select pg_get_constraintdef(oid) into v_constraint from pg_constraint
   where conrelid='public.audit_logs'::regclass and conname='audit_logs_action_check';
 execute 'alter table public.audit_logs drop constraint audit_logs_action_check';
 execute 'alter table public.audit_logs add constraint audit_logs_action_check CHECK (' ||
   substr(v_constraint,8,length(v_constraint)-8) ||
   ' OR action = ANY (ARRAY[''streamHiddenFromDiscovery''::text,''streamShownInDiscovery''::text]))';
end;
$$;

create or replace function public.log_audit_event(p_organization_id uuid,p_action text,
 p_description_en text,p_description_ar text,p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
begin
 if p_action in ('accountDeleted','accountSessionsRevoked','streamForceEnded','streamRemovedFromFeed',
   'appFlagChanged','chatKeywordAdded','chatKeywordUpdated','chatKeywordRemoved',
   'broadcasterHiddenFromMap','broadcasterShownOnMap','organizationVerificationRevoked',
   'streamHiddenFromDiscovery','streamShownInDiscovery') then
   raise exception 'Server-only audit action' using errcode='42501';
 end if;
 return public.log_audit_event_internal(p_organization_id,p_action,p_description_en,p_description_ar,p_metadata);
end;
$$;
revoke all on function public.log_audit_event(uuid,text,text,text,jsonb) from public,anon;
grant execute on function public.log_audit_event(uuid,text,text,text,jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 1. broadcast_sessions
-- ---------------------------------------------------------------------------
create table public.broadcast_sessions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  org_id uuid references public.organizations(id) on delete set null,
  device_id text,
  -- set_live_state validates new watch IDs; the record accepts any existing
  -- value so it can never block a legitimate profile write.
  stream_id text not null check (length(stream_id) between 1 and 128),
  broadcast_type text not null,
  state text not null default 'live' check (state in ('live','ended')),
  end_reason text check (end_reason in ('owner_end','device_transfer','admin_end',
    'admin_remove','approval_revoked','ban','stale_expired','account_action',
    'replaced','ended','ingest_lost','organization_revoked')),
  hidden_from_discovery boolean not null default false,
  -- Which sender the broadcaster declared, and what the sending phone last
  -- reported about its encoder connection. External senders (OBS, another
  -- phone app) are not observed by the app, so their ingest stays 'unknown'.
  sender_mode text not null default 'unspecified'
    check (sender_mode in ('phone_direct','obs_laptop','external_phone','unspecified')),
  ingest_state text not null default 'unknown'
    check (ingest_state in ('sending','interrupted','unknown')),
  ingest_observed_at timestamptz,
  -- When the current interruption began; repeated "interrupted" reports do
  -- not move it, so the 120 s ingest_lost cut-off measures the outage.
  interrupted_since timestamptz,
  revision bigint not null default 1,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  constraint broadcast_sessions_terminal_shape check (
    (state = 'live' and ended_at is null and end_reason is null)
    or (state = 'ended' and ended_at is not null and end_reason is not null))
);
create unique index broadcast_sessions_one_live_per_owner
  on public.broadcast_sessions(owner_id) where state = 'live';
create index broadcast_sessions_stream on public.broadcast_sessions(stream_id);
create index broadcast_sessions_owner_recent on public.broadcast_sessions(owner_id, started_at desc);

alter table public.broadcast_sessions enable row level security;
revoke all on public.broadcast_sessions from public, anon, authenticated;
grant select on public.broadcast_sessions to authenticated;
-- Read-only for API roles. Owners see their own history, admins everything.
-- Writes happen only in the SECURITY DEFINER trigger and RPCs below.
create policy broadcast_sessions_select_own_or_admin on public.broadcast_sessions
  for select to authenticated
  using (owner_id = (select auth.uid()) or public.is_admin_tier());
comment on table public.broadcast_sessions is
  'One row per app broadcast. Kept in step with profiles.is_currently_live/active_stream_id by sync_broadcast_session(). No API writes; hidden_from_discovery is changed only by admin_set_stream_discovery().';

-- The reason a live flag was cleared. Writers that know it set
-- app.broadcast_end_reason (and the device/org) immediately before their
-- profiles update and reset them right after it, so every row of a
-- multi-row update sees the same reason and nothing leaks into a later write
-- in the same transaction. Otherwise the reason is derived.
create function public.sync_broadcast_session() returns trigger
language plpgsql security definer set search_path='' as $$
declare
  v_reason text := nullif(current_setting('app.broadcast_end_reason', true), '');
  v_device text := nullif(current_setting('app.broadcast_device', true), '');
  v_org text := nullif(current_setting('app.broadcast_org', true), '');
  v_was_live boolean := tg_op = 'UPDATE' and old.is_currently_live and old.active_stream_id is not null;
  v_is_live boolean := new.is_currently_live and new.active_stream_id is not null;
begin
  if v_was_live and (not v_is_live or new.active_stream_id is distinct from old.active_stream_id) then
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
  if v_is_live and not (v_was_live and new.active_stream_id = old.active_stream_id) then
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
revoke all on function public.sync_broadcast_session() from public, anon, authenticated;
create trigger sync_broadcast_session
  after insert or update of is_currently_live, active_stream_id on public.profiles
  for each row execute function public.sync_broadcast_session();

-- Profiles already live when this migration runs get an open session.
insert into public.broadcast_sessions(owner_id, org_id, device_id, stream_id, broadcast_type)
select p.id,
       (select o.id from public.organizations o
         where o.is_currently_live and o.active_stream_id = p.active_stream_id limit 1),
       (select d.device_id from public.device_sessions d
         where d.user_id = p.id and d.is_primary_broadcaster limit 1),
       p.active_stream_id,
       coalesce(nullif(p.broadcast_type, 'offline'), 'liveVideo')
from public.profiles p
where p.is_currently_live and length(p.active_stream_id) between 1 and 128;

create function public.reset_broadcast_context() returns void
language sql set search_path='' as $$
  select set_config('app.broadcast_end_reason', '', true),
         set_config('app.broadcast_device', '', true),
         set_config('app.broadcast_org', '', true);
$$;
revoke all on function public.reset_broadcast_context() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Writers that know why the flag changes say so.
-- ---------------------------------------------------------------------------
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
      and not exists(select 1 from public.profiles p where p.id=v_uid and p.active_stream_id=o.active_stream_id)) then
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
revoke execute on function public.set_live_state(boolean,text,text,text,uuid) from public, anon;
grant execute on function public.set_live_state(boolean,text,text,text,uuid) to authenticated;

create or replace function public.claim_broadcaster_device(p_device_id text, p_name text, p_platform text, p_force boolean default false)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_previous text;
begin
  if v_uid is null or public.is_banned(v_uid) then raise exception 'Broadcast not permitted' using errcode = '42501'; end if;
  if p_device_id is null or length(p_device_id) not between 1 and 128 then raise exception 'Invalid device'; end if;
  if not (public.can_broadcast(null,'liveVideo') or exists(select 1 from public.organizations o
    where public.can_broadcast(o.id,'liveVideo') or public.can_broadcast(o.id,'liveAudio'))) then
    raise exception 'Broadcast not permitted' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(20260920, 12);
  if not coalesce(p_force,false) and exists(select 1 from public.device_sessions
    where user_id = v_uid and device_id <> p_device_id and is_primary_broadcaster
    and last_active_at > now() - interval '90 seconds') then return false; end if;
  if exists(select 1 from public.device_sessions where user_id = v_uid
    and device_id <> p_device_id and is_primary_broadcaster) then
    perform set_config('app.broadcast_end_reason', 'device_transfer', true);
    select active_stream_id into v_previous from public.profiles where id = v_uid;
    update public.organizations set is_currently_live=false, broadcast_type='offline', active_stream_id=null, active_viewer_count=0
      where active_stream_id = v_previous;
    update public.profiles set is_currently_live=false, broadcast_type='offline', active_stream_id=null, active_viewer_count=0 where id=v_uid;
    perform public.reset_broadcast_context();
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

create or replace function public.sweep_stale_live_flags()
returns integer language plpgsql security definer set search_path = '' as $$
declare v_stale uuid[]; v_streams text[]; v_ingest_lost integer := 0;
begin
  if not pg_try_advisory_xact_lock(20260920, 13) then return 0; end if;
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
revoke execute on function public.sweep_stale_live_flags() from public, anon;
grant execute on function public.sweep_stale_live_flags() to authenticated;

create or replace function public.release_broadcaster_device(p_device_id text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_previous text;
begin
  perform pg_advisory_xact_lock(20260920, 12);
  if exists(select 1 from public.device_sessions where user_id=auth.uid() and device_id=p_device_id and is_primary_broadcaster) then
    perform set_config('app.broadcast_end_reason', 'owner_end', true);
    select active_stream_id into v_previous from public.profiles where id=auth.uid();
    update public.organizations set is_currently_live=false,broadcast_type='offline',active_stream_id=null,active_viewer_count=0 where active_stream_id=v_previous;
    update public.profiles set is_currently_live=false,broadcast_type='offline',active_stream_id=null,active_viewer_count=0 where id=auth.uid();
    perform public.reset_broadcast_context();
  end if;
  delete from public.device_sessions where user_id=auth.uid() and device_id=p_device_id;
end;
$$;
revoke execute on function public.release_broadcaster_device(text) from public, anon;
grant execute on function public.release_broadcaster_device(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Admin End / End-and-block keep the account's device and approval.
-- ---------------------------------------------------------------------------
create or replace function public.admin_auth_account_action(p_profile_id uuid,p_action text,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare v_stream text; v_action text;
begin
 if auth.uid() is null or not public.is_admin_tier() or public.is_banned(auth.uid())
   or not exists(select 1 from auth.sessions s where s.user_id=auth.uid()
     and s.id::text=auth.jwt()->>'session_id') then
   raise exception 'Not permitted' using errcode='42501';
 end if;
 if p_action is null or p_action not in ('delete_account','revoke_sessions','force_end','remove_from_feed')
   or p_reason is null or length(trim(p_reason)) not between 1 and 500 then
   raise exception 'Invalid account action or reason' using errcode='22023';
 end if;
 perform pg_advisory_xact_lock(20260920,12);
 select active_stream_id into v_stream from public.profiles where id=p_profile_id for update;
 if not found then raise exception 'Account not found' using errcode='P0002'; end if;
 if p_profile_id=auth.uid() or exists(select 1 from public.user_roles
   where profile_id=p_profile_id and role='master_admin')
   or (not public.is_master_admin() and exists(select 1 from public.user_roles
     where profile_id=p_profile_id and role='admin')) then
   raise exception 'Protected administrator' using errcode='42501';
 end if;
 if p_action='delete_account' and exists(select 1 from public.organizations where owner_profile_id=p_profile_id) then
   raise exception 'Transfer organization ownership first' using errcode='23503';
 end if;
 if p_action='delete_account' and exists(select 1 from storage.objects where owner_id=p_profile_id::text) then
   raise exception 'Remove owned storage objects first' using errcode='23503';
 end if;
 if p_action in ('force_end','remove_from_feed') and v_stream is null then
   raise exception 'Account has no live stream' using errcode='22023';
 end if;
 if p_action='remove_from_feed' then
   insert into public.removed_live_streams(stream_id) values(v_stream) on conflict do nothing;
 end if;
 perform set_config('app.broadcast_end_reason', case p_action
   when 'force_end' then 'admin_end'
   when 'remove_from_feed' then 'admin_remove'
   else 'account_action' end, true);
 update public.organizations set is_currently_live=false,broadcast_type='offline',active_stream_id=null,active_viewer_count=0
   where active_stream_id=v_stream;
 update public.profiles set is_currently_live=false,broadcast_type='offline',active_stream_id=null,active_viewer_count=0 where id=p_profile_id;
 perform public.reset_broadcast_context();
 -- Ending a broadcast is not a device or approval change. Only removing the
 -- account's sessions releases its broadcaster device.
 if p_action in ('delete_account','revoke_sessions') then
   update public.device_sessions set is_primary_broadcaster=false where user_id=p_profile_id;
   delete from auth.refresh_tokens where user_id=p_profile_id::text;
   delete from auth.sessions where user_id=p_profile_id;
 end if;
 if p_action='delete_account' then
   delete from auth.users where id=p_profile_id;
   v_action := 'accountDeleted';
 elsif p_action='revoke_sessions' then v_action := 'accountSessionsRevoked';
 elsif p_action='force_end' then v_action := 'streamForceEnded';
 else v_action := 'streamRemovedFromFeed'; end if;
 perform public.log_audit_event_internal(null,v_action,trim(p_reason),trim(p_reason),
   jsonb_build_object('target_profile_id',p_profile_id,'action',p_action,'stream_id',v_stream));
end;
$$;
revoke all on function public.admin_auth_account_action(uuid,text,text) from public,anon;
grant execute on function public.admin_auth_account_action(uuid,text,text) to authenticated;
comment on function public.admin_auth_account_action(uuid,text,text) is
 'Admin-only, audited. force_end ends the current app broadcast; remove_from_feed ends it and blocks that watch ID from being listed again. Neither changes device ownership or broadcaster approval. delete_account/revoke_sessions release devices and Auth sessions. Issued JWTs remain valid until expiry outside paths that check auth.sessions.';


-- Organization verification revocation (20260924110000) ends the broadcast
-- mirrored on the organization; record that reason for the phone.
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
       active_viewer_count=0 where active_stream_id=v_stream;
     perform public.reset_broadcast_context();
   end if;
   v_action := 'organizationVerificationRevoked';
 end if;
 perform public.log_audit_event_internal(null,v_action,trim(p_reason),trim(p_reason),
   jsonb_build_object('target_id',p_target_id,'is_organization',p_is_organization,'action',p_action));
end;
$$;
revoke all on function public.admin_moderate_broadcaster(uuid,boolean,text,text) from public,anon;
grant execute on function public.admin_moderate_broadcaster(uuid,boolean,text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Reversible "hide from app discovery" for the current live session.
-- ---------------------------------------------------------------------------
create function public.admin_set_stream_discovery(p_profile_id uuid, p_hidden boolean, p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare v_session public.broadcast_sessions;
begin
 if auth.uid() is null or not public.is_admin_tier() or public.is_banned(auth.uid())
   or not exists(select 1 from auth.sessions s where s.user_id=auth.uid()
     and s.id::text=auth.jwt()->>'session_id') then
   raise exception 'Not permitted' using errcode='42501';
 end if;
 if p_hidden is null or p_reason is null or length(trim(p_reason)) not between 1 and 500 then
   raise exception 'Invalid discovery action or reason' using errcode='22023';
 end if;
 perform pg_advisory_xact_lock(20260920,12);
 if p_profile_id=auth.uid() or exists(select 1 from public.user_roles
   where profile_id=p_profile_id and role='master_admin')
   or (not public.is_master_admin() and exists(select 1 from public.user_roles
     where profile_id=p_profile_id and role='admin')) then
   raise exception 'Protected administrator' using errcode='42501';
 end if;
 select * into v_session from public.broadcast_sessions
   where owner_id=p_profile_id and state='live' for update;
 if not found then raise exception 'Account has no live stream' using errcode='22023'; end if;
 if v_session.hidden_from_discovery = p_hidden then return; end if;
 update public.broadcast_sessions set hidden_from_discovery=p_hidden, revision=revision+1
   where id=v_session.id;
 perform public.log_audit_event_internal(null,
   case when p_hidden then 'streamHiddenFromDiscovery' else 'streamShownInDiscovery' end,
   trim(p_reason), trim(p_reason),
   jsonb_build_object('target_profile_id',p_profile_id,'session_id',v_session.id,
     'stream_id',v_session.stream_id,'hidden',p_hidden));
end;
$$;
revoke all on function public.admin_set_stream_discovery(uuid,boolean,text) from public,anon;
grant execute on function public.admin_set_stream_discovery(uuid,boolean,text) to authenticated;
comment on function public.admin_set_stream_discovery(uuid,boolean,text) is
 'Admin-only, audited. Hides or shows the target''s current live session in app discovery (feed, map, public live listing). The broadcast keeps running, current viewers stay, and the YouTube watch link and the app room link still work: this is not access control.';

-- Public projections gain the live session identity and its discovery state.
-- Columns are appended so existing readers keep working.
create or replace view public.streamer_public_profiles
  with (security_invoker = false) as
  select
    p.id, p.display_name_en, p.display_name_ar, p.avatar_url, p.banner_url,
    p.bio_en, p.bio_ar, p.title_en, p.title_ar, p.category_id, p.tags,
    p.city_en, p.city_ar, p.venue_name_en, p.venue_name_ar, p.latitude, p.longitude,
    p.youtube_handle, p.youtube_video_id, p.follower_count, p.is_verified,
    p.is_currently_live, p.broadcast_type, p.active_stream_id, p.active_viewer_count,
    p.is_temporarily_hidden_from_map,
    s.id as live_session_id,
    coalesce(s.hidden_from_discovery, false) as is_hidden_from_discovery,
    s.ingest_state as live_ingest_state
  from public.profiles p
  left join public.broadcast_sessions s
    on s.owner_id = p.id and s.state = 'live' and s.stream_id = p.active_stream_id
  where p.is_streamer = true;
grant select on public.streamer_public_profiles to anon, authenticated;

create or replace view public.organization_public_profiles
  with (security_invoker = false) as
  select
    o.id, o.name_en, o.name_ar, o.avatar_url, o.banner_url, o.bio_en, o.bio_ar,
    o.category_id, o.tags, o.official_website_url, o.youtube_handle, o.youtube_video_id,
    o.is_verified, o.follower_count, o.is_currently_live, o.broadcast_type,
    o.active_stream_id, o.active_viewer_count, o.active_live_venue_id,
    o.is_temporarily_hidden_from_map,
    s.id as live_session_id,
    coalesce(s.hidden_from_discovery, false) as is_hidden_from_discovery,
    s.ingest_state as live_ingest_state
  from public.organizations o
  -- The organization's own live session only, at most one row per org.
  left join lateral (
    select b.id, b.hidden_from_discovery, b.ingest_state
    from public.broadcast_sessions b
    where b.org_id = o.id and b.state = 'live' and b.stream_id = o.active_stream_id
    order by b.started_at desc
    limit 1
  ) s on true;
grant select on public.organization_public_profiles to anon, authenticated;

comment on view public.streamer_public_profiles is
  'Public, non-PII projection of streamer profiles for the feed and map, plus the live session id and whether an admin hid it from app discovery. security_invoker = false is deliberate (D-21 exception): anon/authenticated cannot read profiles directly.';
comment on view public.organization_public_profiles is
  'Public, non-PII projection of organizations for the feed and map, plus the live session id and discovery state. security_invoker = false is deliberate (D-21 exception), same contract as streamer_public_profiles.';

-- ---------------------------------------------------------------------------
-- 4. The caller's own broadcast status.
-- ---------------------------------------------------------------------------
create function public.my_broadcast_status()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid := auth.uid(); v_live public.broadcast_sessions; v_last public.broadcast_sessions;
begin
 if v_uid is null then raise exception 'Not signed in' using errcode='42501'; end if;
 select * into v_live from public.broadcast_sessions where owner_id=v_uid and state='live';
 select * into v_last from public.broadcast_sessions where owner_id=v_uid and state='ended'
   order by ended_at desc limit 1;
 return jsonb_build_object(
   'live', v_live.id is not null,
   'session_id', v_live.id,
   'stream_id', v_live.stream_id,
   'device_id', v_live.device_id,
   'revision', v_live.revision,
   'hidden_from_discovery', coalesce(v_live.hidden_from_discovery, false),
   'sender_mode', v_live.sender_mode,
   'ingest_state', v_live.ingest_state,
   'last_ended', case when v_last.id is null then null else jsonb_build_object(
     'session_id', v_last.id, 'stream_id', v_last.stream_id,
     'reason', v_last.end_reason, 'ended_at', v_last.ended_at) end);
end;
$$;
revoke all on function public.my_broadcast_status() from public, anon;
grant execute on function public.my_broadcast_status() to authenticated;
comment on function public.my_broadcast_status() is
 'The caller''s current live session (if any) and the most recent ended one with its end reason. Used by broadcasting devices to explain a remote end; never exposes other accounts.';

-- ---------------------------------------------------------------------------
-- 5. Session-scoped start, ingest reports and end (fencing).
-- A sending phone works through its session id. It no longer withdraws LIVE
-- on every network blip: it reports "interrupted" and then "sending" for
-- THAT session. A session that ended (admin End, transfer, expiry) refuses
-- those reports with SQLSTATE 55000, so an encoder that reconnects after an
-- admin End cannot put the broadcast back. A new broadcast needs an explicit
-- start. end_broadcast_session() ends only the named session.
-- ---------------------------------------------------------------------------
-- Start: the same checks as set_live_state(true), then the session's sender
-- and initial ingest state. Returns the live session id.
create function public.start_broadcast_session(p_type text, p_stream_id text,
  p_device_id text, p_org_id uuid default null, p_sender_mode text default 'unspecified')
returns uuid language plpgsql security definer set search_path='' as $$
declare v_uid uuid := auth.uid(); v_id uuid;
begin
  if p_sender_mode is null or p_sender_mode not in ('phone_direct','obs_laptop','external_phone','unspecified') then
    raise exception 'Invalid sender' using errcode='22023';
  end if;
  perform set_config('app.explicit_start', '1', true);
  perform public.set_live_state(true, p_type, p_stream_id, p_device_id, p_org_id);
  perform set_config('app.explicit_start', '', true);
  update public.broadcast_sessions
     set sender_mode = p_sender_mode,
         ingest_state = case when p_sender_mode = 'phone_direct' then 'sending' else 'unknown' end,
         ingest_observed_at = case when p_sender_mode = 'phone_direct' then now() end,
         revision = revision + 1
   where owner_id = v_uid and state = 'live' and stream_id = p_stream_id
  returning id into v_id;
  if v_id is null then raise exception 'Broadcast session not started' using errcode='55000'; end if;
  return v_id;
end;
$$;
revoke all on function public.start_broadcast_session(text,text,text,uuid,text) from public, anon;
grant execute on function public.start_broadcast_session(text,text,text,uuid,text) to authenticated;

-- Ingest report from the sending phone, fenced to its own live session.
create function public.report_broadcast_ingest(p_session_id uuid, p_device_id text, p_state text)
returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid := auth.uid(); v_session public.broadcast_sessions;
begin
  if v_uid is null or public.is_banned(v_uid) then raise exception 'Broadcast not permitted' using errcode='42501'; end if;
  if p_state is null or p_state not in ('sending','interrupted') then
    raise exception 'Invalid ingest state' using errcode='22023';
  end if;
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
revoke all on function public.report_broadcast_ingest(uuid,text,text) from public, anon;
grant execute on function public.report_broadcast_ingest(uuid,text,text) to authenticated;

-- End exactly this session. Ending an already ended or replaced session is a
-- no-op, so a stale End can never end a newer broadcast.
create function public.end_broadcast_session(p_session_id uuid, p_device_id text)
returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid := auth.uid(); v_session public.broadcast_sessions;
begin
  if v_uid is null then raise exception 'Not signed in' using errcode='42501'; end if;
  select * into v_session from public.broadcast_sessions where id = p_session_id;
  if not found or v_session.owner_id <> v_uid then
    raise exception 'Broadcast session not found' using errcode='42501';
  end if;
  if v_session.state <> 'live' then return; end if;
  perform public.set_live_state(false, v_session.broadcast_type, null, p_device_id, null);
end;
$$;
revoke all on function public.end_broadcast_session(uuid,text) from public, anon;
grant execute on function public.end_broadcast_session(uuid,text) to authenticated;

commit;
