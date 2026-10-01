-- Shared personal / organization owner OAuth. No credential in client records.
begin;
create extension if not exists supabase_vault with schema vault;
revoke all on all tables in schema vault from public,anon,authenticated,service_role;
revoke all on all functions in schema vault from public,anon,authenticated,service_role;
create table public.channel_connections (
  id uuid primary key default gen_random_uuid(),
  owner_profile_id uuid not null references public.profiles(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete cascade,
  youtube_channel_id text not null check(youtube_channel_id ~ '^UC[A-Za-z0-9_-]{22}$'),
  channel_title text not null,
  status text not null default 'connected' check(status in ('connected','disconnected','reconnect_required')),
  revision bigint not null default 1,
  connected_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index channel_one_personal on public.channel_connections(owner_profile_id) where organization_id is null;
create unique index channel_one_active_destination on public.channel_connections(youtube_channel_id)
  where status<>'disconnected';
create unique index channel_one_organization on public.channel_connections(organization_id) where organization_id is not null;
alter table public.channel_connections enable row level security;
revoke all on public.channel_connections from public,anon,authenticated;
grant select on public.channel_connections to authenticated;
create policy channel_identity_read on public.channel_connections for select to authenticated using (
  owner_profile_id=auth.uid() or (organization_id is not null and public.is_org_member(organization_id)) or public.is_admin_tier());
create table private.channel_credentials (
  connection_id uuid primary key references public.channel_connections(id) on delete cascade,
  secret_id uuid not null references vault.secrets(id)
);
create function private.channel_secret_cleanup() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  delete from vault.secrets where id=old.secret_id;
  return old;
end; $$;
create trigger channel_secret_cleanup after delete on private.channel_credentials
  for each row execute function private.channel_secret_cleanup();
create table private.channel_oauth_requests (
  id uuid primary key default gen_random_uuid(),
  state_hash text not null unique,
  actor_id uuid not null references public.profiles(id) on delete cascade,
  auth_session_id uuid not null,
  organization_id uuid references public.organizations(id) on delete cascade,
  verifier text not null,
  expires_at timestamptz not null default now()+interval '10 minutes',
  used_at timestamptz,
  completed_at timestamptz
);
create function private.channel_owner(p_actor uuid,p_org uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select not public.is_banned(p_actor) and case when p_org is null then exists (
    select 1 from public.profiles where id=p_actor and is_verified and personal_broadcast_approved)
  else exists(select 1 from public.organizations where id=p_org and owner_profile_id=p_actor and is_verified) end;
$$;
create function private.channel_actor(p_actor uuid,p_session uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select not public.is_banned(p_actor) and exists(select 1 from auth.sessions
    where id=p_session and user_id=p_actor and (not_after is null or not_after>now()));
$$;
create function public.channel_oauth_begin(p_org_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); state text:=gen_random_uuid()::text||gen_random_uuid()::text;
  verifier text:=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-',''); intent uuid;
begin
  if not private.channel_owner(actor,p_org_id) then raise exception 'Channel owner approval required' using errcode='42501'; end if;
  -- One current consent attempt per destination. Older callbacks cannot win.
  perform pg_advisory_xact_lock(hashtextextended(coalesce(p_org_id,actor)::text,20261001));
  if exists(select 1 from public.broadcast_sessions b where b.state in ('preparing','live','ending')
    and ((p_org_id is null and b.org_id is null and b.owner_id=actor) or b.org_id=p_org_id)) then
    raise exception 'End active sessions before changing channels' using errcode='55000'; end if;
  update private.channel_oauth_requests set used_at=coalesce(used_at,now()),completed_at=now()
    where organization_id is not distinct from p_org_id
    and (p_org_id is not null or actor_id=actor) and completed_at is null;
  insert into private.channel_oauth_requests(state_hash,actor_id,auth_session_id,organization_id,verifier)
    values(encode(sha256(convert_to(state,'UTF8')),'hex'),actor,(auth.jwt()->>'session_id')::uuid,p_org_id,verifier)
    returning id into intent;
  return jsonb_build_object('id',intent,'state',state,'challenge',
    rtrim(translate(encode(sha256(convert_to(verifier,'UTF8')),'base64'),'+/','-_'),'='));
end; $$;
create function public.channel_oauth_consume(p_state text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare request private.channel_oauth_requests;
begin
  select * into request from private.channel_oauth_requests
    where state_hash=encode(sha256(convert_to(p_state,'UTF8')),'hex') for update;
  if not found or request.used_at is not null or request.expires_at<=now()
    or not private.channel_owner(request.actor_id,request.organization_id)
    or not private.channel_actor(request.actor_id,request.auth_session_id) then
    raise exception 'OAuth state expired or unavailable' using errcode='42501';
  end if;
  update private.channel_oauth_requests set used_at=now() where id=request.id;
  return jsonb_build_object('id',request.id,'actor_id',request.actor_id,
    'organization_id',request.organization_id,'verifier',request.verifier);
end; $$;
create function public.channel_oauth_commit(p_request_id uuid,p_channel_id text,p_title text,p_refresh_token text) returns uuid
language plpgsql security definer set search_path='' as $$
declare request private.channel_oauth_requests; connection uuid; secret uuid;
begin
  select * into request from private.channel_oauth_requests where id=p_request_id for update;
  if not found or request.used_at is null or request.completed_at is not null or request.expires_at<=now()
    or not private.channel_owner(request.actor_id,request.organization_id)
    or not private.channel_actor(request.actor_id,request.auth_session_id) then
    raise exception 'Consent no longer authorized' using errcode='42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(coalesce(request.organization_id,request.actor_id)::text,20261001));
  if exists(select 1 from public.broadcast_sessions where state in ('preparing','live','ending')
    and ((request.organization_id is null and org_id is null and owner_id=request.actor_id)
      or org_id=request.organization_id)) then
    raise exception 'End active sessions before changing channels' using errcode='55000'; end if;
  if exists(select 1 from private.channel_oauth_requests newer where newer.id<>request.id
    and newer.organization_id is not distinct from request.organization_id
    and (request.organization_id is not null or newer.actor_id=request.actor_id)
    and newer.used_at is null and newer.expires_at>now()) then
    raise exception 'Newer consent attempt exists' using errcode='40001';
  end if;
  if p_channel_id is null or p_channel_id !~ '^UC[A-Za-z0-9_-]{22}$'
    or nullif(btrim(p_refresh_token),'') is null or char_length(p_refresh_token)>8192
    or p_title is null or char_length(p_title)>200 then raise exception 'Invalid provider result' using errcode='22023'; end if;
  select id into connection from public.channel_connections where organization_id is not distinct from request.organization_id
    and (request.organization_id is not null or owner_profile_id=request.actor_id) for update;
  if found then
    select secret_id into secret from private.channel_credentials where connection_id=connection;
    update public.channel_connections set owner_profile_id=request.actor_id,youtube_channel_id=p_channel_id,
      channel_title=p_title,status='connected',revision=revision+1,updated_at=now() where id=connection;
  else
    insert into public.channel_connections(owner_profile_id,organization_id,youtube_channel_id,channel_title)
      values(request.actor_id,request.organization_id,p_channel_id,p_title) returning id into connection;
  end if;
  if secret is null then
    secret:=vault.create_secret(p_refresh_token,'youtube_connection_'||connection::text);
    insert into private.channel_credentials values(connection,secret);
  else perform vault.update_secret(secret,p_refresh_token); end if;
  update private.channel_oauth_requests set completed_at=now() where id=request.id;
  perform private.org_v1_audit(request.organization_id,'updatePermissions',jsonb_build_object('channel_connection',connection,'channel_id',p_channel_id,'operation','connect'),request.actor_id);
  return connection;
end; $$;
create function public.channel_server_credential(p_connection_id uuid,p_actor uuid,p_session uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare connection public.channel_connections; token text;
begin
  select * into connection from public.channel_connections where id=p_connection_id;
  if not found or connection.status<>'connected' or not private.channel_actor(p_actor,p_session)
    or not private.channel_owner(connection.owner_profile_id,connection.organization_id)
    or (connection.organization_id is null and connection.owner_profile_id<>p_actor)
    or (connection.organization_id is not null and not exists(select 1 from public.org_memberships
      where organization_id=connection.organization_id and profile_id=p_actor and status='active')) then
    raise exception 'Channel access denied' using errcode='42501';
  end if;
  select v.decrypted_secret into token from private.channel_credentials c join vault.decrypted_secrets v
    on v.id=c.secret_id where c.connection_id=connection.id;
  if token is null then raise exception 'Reconnect channel' using errcode='55000'; end if;
  return jsonb_build_object('refresh_token',token,'channel_id',connection.youtube_channel_id,'revision',connection.revision);
end; $$;
create function public.channel_disconnect(p_connection_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); connection public.channel_connections;
begin
  select * into connection from public.channel_connections where id=p_connection_id for update;
  if not found or not private.channel_owner(actor,connection.organization_id)
    or (connection.organization_id is null and connection.owner_profile_id<>actor) then
    raise exception 'Channel owner required' using errcode='42501'; end if;
  if exists(select 1 from public.broadcast_sessions where state in ('preparing','live','ending')
    and ((connection.organization_id is null and org_id is null and owner_id=actor) or org_id=connection.organization_id)) then
    raise exception 'End active sessions before disconnecting' using errcode='55000'; end if;
  update public.channel_connections set status='disconnected',revision=revision+1,updated_at=now() where id=connection.id;
  delete from private.channel_credentials where connection_id=connection.id;
  perform private.org_v1_audit(connection.organization_id,'updatePermissions',jsonb_build_object('channel_connection',connection.id,'operation','disconnect'));
end; $$;
create function public.channel_owner_changed() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.owner_profile_id<>old.owner_profile_id then
    update public.channel_connections set status='reconnect_required',revision=revision+1,updated_at=now()
      where organization_id=new.id;
    update private.channel_oauth_requests set used_at=coalesce(used_at,now()),completed_at=now()
      where organization_id=new.id and completed_at is null;
  end if;
  return new;
end; $$;
create trigger channel_owner_changed after update of owner_profile_id on public.organizations
  for each row execute function public.channel_owner_changed();

-- STREAM-D8: old starts cannot accept a forged watch URL or bypass server consent.
-- Existing end, ingest and recovery paths remain callable for already-live sessions.
revoke execute on function public.start_broadcast_session(text,text,text,uuid,text) from public,anon,authenticated;
revoke execute on function public.set_live_state(boolean,text,text,text,uuid) from public,anon,authenticated;
do $$ declare f record;
begin
  for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='public' and p.proname like 'channel_%') or (n.nspname='private' and p.proname like 'channel_%') loop
    execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
  end loop;
end; $$;
grant execute on function public.channel_oauth_begin(uuid),public.channel_disconnect(uuid) to authenticated;
grant execute on function public.channel_oauth_consume(text),public.channel_oauth_commit(uuid,text,text,text),
  public.channel_server_credential(uuid,uuid,uuid) to service_role;
revoke all on all tables in schema private from public,anon,authenticated,service_role;
commit;
