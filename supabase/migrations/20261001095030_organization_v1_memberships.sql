-- Organization V1. Memberships authorize; speaker cards never grant authority.
begin;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

alter table public.profiles
  add column personal_broadcast_approved boolean not null default false,
  add column organization_broadcast_approved boolean not null default false;
alter table public.broadcaster_applications add column broadcast_scope text not null default 'personal'
  check (broadcast_scope in ('personal','organization_only'));
update public.profiles p set
  personal_broadcast_approved = p.is_streamer and p.is_verified and not exists (
    select 1 from public.broadcaster_applications a where a.applicant_profile_id=p.id
      and a.status='approved' and a.account_type='organizationVenue'),
  organization_broadcast_approved = p.is_streamer and p.is_verified;

create function public.org_v1_guard_approval() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if current_user in ('anon','authenticated') and not public.is_admin_tier() then
    if tg_op='INSERT' then
      new.personal_broadcast_approved:=false; new.organization_broadcast_approved:=false;
    else
      new.personal_broadcast_approved:=old.personal_broadcast_approved;
      new.organization_broadcast_approved:=old.organization_broadcast_approved;
    end if;
  elsif (tg_op='INSERT' and new.is_streamer and new.is_verified)
     or (tg_op='UPDATE' and new.is_verified is distinct from old.is_verified) then
    new.organization_broadcast_approved:=new.is_streamer and new.is_verified;
    new.personal_broadcast_approved:=new.organization_broadcast_approved and not exists (
      select 1 from public.broadcaster_applications a where a.applicant_profile_id=new.id
        and a.status='approved' and (a.broadcast_scope='organization_only' or a.account_type='organizationVenue'));
  end if;
  return new;
end; $$;
create trigger org_v1_guard_approval before insert or update on public.profiles
  for each row execute function public.org_v1_guard_approval();

create function public.org_v1_guard_scope() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if current_user in ('anon','authenticated') and not public.is_admin_tier()
    and old.status<>'pending' then new.broadcast_scope:=old.broadcast_scope; end if;
  return new;
end; $$;
create trigger org_v1_guard_scope before update on public.broadcaster_applications
  for each row execute function public.org_v1_guard_scope();
create function public.org_v1_apply_approval() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.status='approved' and new.account_type='individualScholar' then
    update public.profiles set is_streamer=true,is_verified=true,
      personal_broadcast_approved=personal_broadcast_approved or new.broadcast_scope='personal',
      organization_broadcast_approved=true where id=new.applicant_profile_id;
  end if;
  return new;
end; $$;
create trigger org_v1_apply_approval after insert or update of status on public.broadcaster_applications
  for each row execute function public.org_v1_apply_approval();

alter table public.app_flags drop constraint app_flags_key_check;
alter table public.app_flags add constraint app_flags_key_check
  check(key in ('chat_enabled','registrations_open','organizations_v1_enabled'));
insert into public.app_flags(key,enabled) values('organizations_v1_enabled',false);
create table private.organization_v1_pilots (
  organization_id uuid primary key references public.organizations(id) on delete cascade
);
create table public.org_memberships (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check(role in ('owner','co_owner','manager','moderator','broadcaster')),
  status text not null default 'active' check(status in ('active','suspended','revoked','review_required')),
  permissions jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  primary key(organization_id,profile_id)
);
create index org_memberships_profile_idx on public.org_memberships(profile_id);
alter table public.org_memberships enable row level security;
revoke all on public.org_memberships from public,anon,authenticated;
grant select on public.org_memberships to authenticated;

create function public.org_v1_role(p_org_id uuid) returns text
language sql stable security definer set search_path='' as $$
  select case when o.owner_profile_id=auth.uid() then 'owner' else m.role end
  from public.organizations o left join public.org_memberships m
    on m.organization_id=o.id and m.profile_id=auth.uid() and m.status='active'
  where o.id=p_org_id and auth.uid() is not null and not public.is_banned(auth.uid());
$$;
create function public.org_v1_can(p_org_id uuid,p_action text) returns boolean
language sql stable security definer set search_path='' as $$
  select coalesce(case p_action
    when 'leadership' then public.org_v1_role(p_org_id)='owner'
    when 'channel' then public.org_v1_role(p_org_id)='owner'
    when 'members' then public.org_v1_role(p_org_id) in ('owner','co_owner','manager')
    when 'schedule' then public.org_v1_role(p_org_id) in ('owner','co_owner','manager')
    when 'end' then public.org_v1_role(p_org_id) in ('owner','co_owner','manager')
    when 'profile' then public.org_v1_role(p_org_id) in ('owner','co_owner')
    when 'moderate' then public.org_v1_role(p_org_id) in ('owner','co_owner','moderator')
    when 'audit' then public.org_v1_role(p_org_id) in ('owner','co_owner','manager','moderator')
    else false end,false);
$$;
create policy org_memberships_read on public.org_memberships for select to authenticated using (
  profile_id=auth.uid() or public.org_v1_can(organization_id,'members') or public.is_admin_tier());
create function private.org_v1_actor() returns uuid
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or public.is_banned(auth.uid()) or not exists (
    select 1 from auth.sessions s where s.user_id=auth.uid() and s.id::text=auth.jwt()->>'session_id'
      and (s.not_after is null or s.not_after>now())) then
    raise exception 'Active account session required' using errcode='42501';
  end if;
  return auth.uid();
end; $$;
create function private.org_v1_permissions(p_value jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare item record;
begin
  if p_value is null or jsonb_typeof(p_value)<>'object' then
    raise exception 'Permissions must be an object' using errcode='22023';
  end if;
  for item in select * from jsonb_each(p_value) loop
    if item.key not in ('can_go_live_video','can_go_audio_only','can_change_location',
      'can_edit_description','can_edit_stream_time','can_add_external_links')
      or jsonb_typeof(item.value)<>'boolean' then
      raise exception 'Unknown or invalid permission' using errcode='22023';
    end if;
  end loop;
  return p_value;
end; $$;
create function private.org_v1_audit(p_org uuid,p_action text,p_metadata jsonb,p_actor uuid default auth.uid()) returns void
language plpgsql security definer set search_path='' as $$
begin
  if p_actor is null or public.is_banned(p_actor) then raise exception 'Audit actor required' using errcode='42501'; end if;
  -- Only authorized RPCs call this private helper. Incoming requests and declined
  -- invitations intentionally have no membership yet, so the public logger's
  -- membership check cannot represent their server-authorized audit event.
  insert into public.audit_logs(organization_id,actor_profile_id,actor_email,actor_name,
    action,description_en,description_ar,metadata)
    select p_org,p.id,coalesce(p.email,'unknown'),coalesce(p.display_name_en,'Unknown'),
      p_action,'Organization authority change','تغيير صلاحيات المؤسسة',p_metadata
    from public.profiles p where p.id=p_actor;
end; $$;

-- Owners are derived from the existing ownership field. Conflicting roster /
-- accepted-request permissions are quarantined instead of merged into a grant.
insert into public.org_memberships(organization_id,profile_id,role,permissions)
  select id,owner_profile_id,'owner','{"can_go_live_video":true,"can_go_audio_only":true}'::jsonb
  from public.organizations;
insert into public.org_memberships(organization_id,profile_id,role,status,permissions)
select a.organization_id,a.streamer_profile_id,'broadcaster',
  case when count(*)=1 and count(s.id)=1 and bool_and(s.permissions=a.permissions)
    then 'active' else 'review_required' end,
  case when count(*)=1 and count(s.id)=1 and bool_and(s.permissions=a.permissions)
    then (array_agg(a.permissions))[1] else '{}'::jsonb end
from public.affiliation_requests a left join public.org_speakers s
  on s.organization_id=a.organization_id and s.linked_profile_id=a.streamer_profile_id
where a.status='accepted' group by a.organization_id,a.streamer_profile_id
on conflict do nothing;
insert into public.org_memberships(organization_id,profile_id,role)
  select organization_id,profile_id,'co_owner' from public.user_roles where role='org_co_owner'
  on conflict(organization_id,profile_id) do update set role='co_owner'
  where public.org_memberships.role<>'owner';

create function public.org_v1_sync_owner() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_op='UPDATE' and old.owner_profile_id<>new.owner_profile_id then
    update public.org_memberships set role='co_owner',updated_at=now()
      where organization_id=new.id and profile_id=old.owner_profile_id;
  end if;
  insert into public.org_memberships(organization_id,profile_id,role)
    values(new.id,new.owner_profile_id,'owner') on conflict(organization_id,profile_id)
    do update set role='owner',status='active',updated_at=now();
  return new;
end; $$;
create trigger org_v1_sync_owner after insert or update of owner_profile_id on public.organizations
  for each row execute function public.org_v1_sync_owner();
create function public.org_v1_sync_roles() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  delete from public.user_roles where organization_id=new.organization_id
    and profile_id=new.profile_id and role='org_co_owner';
  if new.role='co_owner' and new.status='active' then
    insert into public.user_roles(profile_id,organization_id,role,granted_by)
      values(new.profile_id,new.organization_id,'org_co_owner',auth.uid()) on conflict do nothing;
  end if;
  return new;
end; $$;
create trigger org_v1_sync_roles after insert or update on public.org_memberships
  for each row execute function public.org_v1_sync_roles();

create function public.org_v1_set_member(p_org_id uuid,p_profile_id uuid,p_role text,
  p_status text,p_permissions jsonb default '{}') returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); old_role text;
begin
  perform 1 from public.organizations where id=p_org_id for update;
  if not found or not public.org_v1_can(p_org_id,'members') then
    raise exception 'Membership management not permitted' using errcode='42501';
  end if;
  select role into old_role from public.org_memberships where organization_id=p_org_id and profile_id=p_profile_id;
  if not found then raise exception 'Accept an invitation first' using errcode='42501'; end if;
  if p_role is null or p_role not in ('owner','co_owner','manager','moderator','broadcaster')
    or p_status is null or p_status not in ('active','suspended','revoked') then
    raise exception 'Invalid membership' using errcode='22023';
  end if;
  if old_role='owner' and (p_role<>'owner' or p_status<>'active') then
    raise exception 'Use ownership transfer' using errcode='42501';
  end if;
  if (p_role<>'broadcaster' or old_role<>'broadcaster') and not public.org_v1_can(p_org_id,'leadership') then
    raise exception 'Only owner appoints leadership' using errcode='42501';
  end if;
  if p_role='owner' and old_role<>'owner' then raise exception 'Use ownership transfer' using errcode='42501'; end if;
  update public.org_memberships set role=p_role,status=p_status,
    permissions=private.org_v1_permissions(p_permissions),updated_at=now()
    where organization_id=p_org_id and profile_id=p_profile_id;
  perform private.org_v1_audit(p_org_id,'updatePermissions',jsonb_build_object('profile_id',p_profile_id,'role',p_role,'status',p_status));
end; $$;

alter table public.affiliation_requests alter column streamer_profile_id drop not null;
alter table public.affiliation_requests add column target_email text,
  add column invited_by_profile_id uuid references public.profiles(id) on delete set null,
  add column invited_role text not null default 'broadcaster'
    check(invited_role in ('co_owner','manager','moderator','broadcaster')),
  add column expires_at timestamptz;
create table private.organization_invite_tokens (
  invitation_id uuid primary key references public.affiliation_requests(id) on delete cascade,
  token_hash text not null unique,
  consumed_at timestamptz
);
revoke insert,update,delete on public.affiliation_requests from authenticated;

create function public.org_v1_invite(p_org_id uuid,p_email text,p_role text default 'broadcaster',
  p_permissions jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); invite uuid:=gen_random_uuid();
  token text:=gen_random_uuid()::text||gen_random_uuid()::text; target uuid; invite_email text:=lower(btrim(p_email));
begin
  perform 1 from public.organizations where id=p_org_id for update;
  if not found or not public.org_v1_can(p_org_id,'members') then raise exception 'Invite not permitted' using errcode='42501'; end if;
  if p_role is null or p_role not in ('co_owner','manager','moderator','broadcaster')
    or (p_role<>'broadcaster' and not public.org_v1_can(p_org_id,'leadership')) then
    raise exception 'Role not permitted' using errcode='42501';
  end if;
  if invite_email is null or char_length(invite_email)>254 or invite_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Valid email required' using errcode='22023';
  end if;
  select id into target from auth.users where lower(auth.users.email)=invite_email and email_confirmed_at is not null;
  if exists(select 1 from public.org_memberships m where m.organization_id=p_org_id and m.profile_id=target
      and (m.status='active' or (m.role<>'broadcaster' and not public.org_v1_can(p_org_id,'leadership')))) then
    raise exception 'Use membership management for existing members' using errcode='42501';
  end if;
  if exists(select 1 from public.affiliation_requests a where a.organization_id=p_org_id
      and a.target_email=invite_email and a.status='pending' and a.expires_at>now()) then
    raise exception 'Pending invitation already exists' using errcode='23505';
  end if;
  insert into public.affiliation_requests(id,organization_id,streamer_profile_id,direction,
    target_email,invited_by_profile_id,invited_role,permissions,expires_at) values(invite,p_org_id,target,'orgToStreamer',
    invite_email,actor,p_role,private.org_v1_permissions(p_permissions),now()+interval '7 days');
  insert into private.organization_invite_tokens(invitation_id,token_hash)
    values(invite,encode(sha256(convert_to(token,'UTF8')),'hex'));
  perform private.org_v1_audit(p_org_id,'submitAffiliationRequest',jsonb_build_object('invitation_id',invite,'role',p_role));
  return jsonb_build_object('id',invite,'token',token,'expires_at',now()+interval '7 days');
end; $$;

create function public.org_v1_answer_invite(p_invitation_id uuid,p_accept boolean,p_token text default null) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); invite public.affiliation_requests; email text;
begin
  select * into invite from public.affiliation_requests where id=p_invitation_id for update;
  if not found or invite.direction<>'orgToStreamer' or p_accept is null then
    raise exception 'Invitation unavailable' using errcode='42501';
  end if;
  select lower(u.email) into email from auth.users u where u.id=actor and u.email_confirmed_at is not null;
  if email is null or email<>invite.target_email or (invite.streamer_profile_id is not null and invite.streamer_profile_id<>actor) then
    raise exception 'Invitation belongs to another account' using errcode='42501';
  end if;
  if invite.status<>'pending' or invite.expires_at is null or invite.expires_at<=now() then
    raise exception 'Invitation expired or already resolved' using errcode='55000';
  end if;
  if public.is_banned(invite.invited_by_profile_id) or not exists (
    select 1 from public.organizations o left join public.org_memberships m
      on m.organization_id=o.id and m.profile_id=invite.invited_by_profile_id and m.status='active'
    where o.id=invite.organization_id and (o.owner_profile_id=invite.invited_by_profile_id
      or (invite.invited_role='broadcaster' and m.role in ('co_owner','manager')))) then
    raise exception 'Inviter authority revoked' using errcode='42501';
  end if;
  if invite.streamer_profile_id is null and (p_token is null or not exists (
    select 1 from private.organization_invite_tokens t where t.invitation_id=invite.id
      and t.consumed_at is null and t.token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex'))) then
    raise exception 'Invalid invitation token' using errcode='42501';
  end if;
  update private.organization_invite_tokens set consumed_at=now() where invitation_id=invite.id;
  update public.affiliation_requests set streamer_profile_id=actor,
    status=case when p_accept then 'accepted' else 'declined' end,resolved_at=now() where id=invite.id;
  if p_accept then
    insert into public.org_memberships(organization_id,profile_id,role,permissions)
      values(invite.organization_id,actor,invite.invited_role,private.org_v1_permissions(invite.permissions))
      on conflict(organization_id,profile_id) do update set role=excluded.role,status='active',
        permissions=excluded.permissions,updated_at=now()
      where public.org_memberships.role<>'owner';
  end if;
  perform private.org_v1_audit(invite.organization_id,case when p_accept then 'acceptAffiliationRequest'
    else 'declineAffiliationRequest' end,jsonb_build_object('invitation_id',invite.id));
end; $$;
create function public.org_v1_revoke_invite(p_invitation_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); invite public.affiliation_requests;
begin
  select * into invite from public.affiliation_requests where id=p_invitation_id for update;
  if not found or not public.org_v1_can(invite.organization_id,'members') then
    raise exception 'Invite management not permitted' using errcode='42501';
  end if;
  if invite.status='pending' then
    update public.affiliation_requests set status='revoked',resolved_at=now() where id=invite.id;
    update private.organization_invite_tokens set consumed_at=now() where invitation_id=invite.id;
    perform private.org_v1_audit(invite.organization_id,'declineAffiliationRequest',jsonb_build_object('invitation_id',invite.id,'revoked',true));
  end if;
end; $$;

create function public.org_v1_memberships(p_org_id uuid default null) returns setof jsonb
language sql stable security definer set search_path='' as $$
  select to_jsonb(m)||jsonb_build_object('name_en',p.display_name_en,'name_ar',p.display_name_ar,
    'organization_name_en',o.name_en,'organization_name_ar',o.name_ar)
  from public.org_memberships m join public.organizations o on o.id=m.organization_id
    join public.profiles p on p.id=m.profile_id
  where auth.uid() is not null and not public.is_banned(auth.uid())
    and case when p_org_id is null then m.profile_id=auth.uid()
      else m.organization_id=p_org_id and (m.profile_id=auth.uid()
        or public.org_v1_can(p_org_id,'members') or public.is_admin_tier()) end;
$$;
create function public.org_v1_request_join(p_org_id uuid,p_note text default '',
  p_role_en text default null,p_role_ar text default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); request_id uuid;
begin
  if not exists(select 1 from public.organizations where id=p_org_id and is_verified)
    or char_length(coalesce(p_note,''))>2000 then raise exception 'Invalid request' using errcode='22023'; end if;
  if exists(select 1 from public.affiliation_requests where organization_id=p_org_id
    and streamer_profile_id=actor and status='pending') then raise exception 'Request already pending' using errcode='23505'; end if;
  insert into public.affiliation_requests(organization_id,streamer_profile_id,direction,note,
    proposed_role_en,proposed_role_ar,permissions)
    values(p_org_id,actor,'streamerToOrg',coalesce(p_note,''),p_role_en,p_role_ar,'{}') returning id into request_id;
  perform private.org_v1_audit(p_org_id,'submitAffiliationRequest',jsonb_build_object('request_id',request_id));
  return request_id;
end; $$;
create function public.org_v1_resolve_request(p_request_id uuid,p_accept boolean,p_permissions jsonb default '{}') returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); request public.affiliation_requests;
begin
  select * into request from public.affiliation_requests where id=p_request_id for update;
  if not found or request.direction<>'streamerToOrg' or request.status<>'pending'
    or p_accept is null or not public.org_v1_can(request.organization_id,'members') then
    raise exception 'Request management not permitted' using errcode='42501';
  end if;
  update public.affiliation_requests set status=case when p_accept then 'accepted' else 'declined' end,
    permissions=private.org_v1_permissions(p_permissions),resolved_at=now() where id=request.id;
  if p_accept then
    insert into public.org_memberships(organization_id,profile_id,role,permissions)
      values(request.organization_id,request.streamer_profile_id,'broadcaster',private.org_v1_permissions(p_permissions))
      on conflict(organization_id,profile_id) do update set status='active',permissions=excluded.permissions,updated_at=now()
      where public.org_memberships.role='broadcaster';
  end if;
  perform private.org_v1_audit(request.organization_id,case when p_accept then 'acceptAffiliationRequest'
    else 'declineAffiliationRequest' end,jsonb_build_object('request_id',request.id));
end; $$;

create table private.organization_owner_transfers (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  from_profile_id uuid not null references public.profiles(id) on delete cascade,
  to_profile_id uuid not null references public.profiles(id) on delete cascade,
  expires_at timestamptz not null
);
create function public.org_v1_transfer_owner(p_org_id uuid,p_to_profile_id uuid default null) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); transfer private.organization_owner_transfers;
begin
  perform 1 from public.organizations where id=p_org_id for update;
  if p_to_profile_id is not null then
    if not public.org_v1_can(p_org_id,'leadership') or actor=p_to_profile_id
      or not exists(select 1 from public.org_memberships where organization_id=p_org_id
        and profile_id=p_to_profile_id and status='active') or public.is_banned(p_to_profile_id) then
      raise exception 'Transfer not permitted' using errcode='42501';
    end if;
    insert into private.organization_owner_transfers values(p_org_id,actor,p_to_profile_id,now()+interval '7 days')
      on conflict(organization_id) do update set from_profile_id=actor,to_profile_id=p_to_profile_id,expires_at=excluded.expires_at;
  else
    select * into transfer from private.organization_owner_transfers where organization_id=p_org_id for update;
    if not found or transfer.to_profile_id<>actor or transfer.expires_at<=now()
      or public.is_banned(transfer.from_profile_id) or not exists(select 1 from public.organizations
        where id=p_org_id and owner_profile_id=transfer.from_profile_id)
      or not exists(select 1 from public.org_memberships where organization_id=p_org_id and profile_id=actor and status='active') then
      raise exception 'Transfer unavailable' using errcode='42501';
    end if;
    if exists(select 1 from public.broadcast_sessions where org_id=p_org_id and state in ('preparing','live','ending')) then
      raise exception 'End active sessions before transfer' using errcode='55000';
    end if;
    update public.organizations set owner_profile_id=actor where id=p_org_id;
    delete from private.organization_owner_transfers where organization_id=p_org_id;
  end if;
  perform private.org_v1_audit(p_org_id,'assignOwnerRole',jsonb_build_object('proposed',p_to_profile_id is not null,'target',coalesce(p_to_profile_id,actor)));
end; $$;

create or replace function public.is_org_member(org_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select public.org_v1_role(org_id) is not null;
$$;
create or replace function public.owns_organization(org_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select coalesce(public.org_v1_role(org_id) in ('owner','co_owner'),false);
$$;
create function public.org_v1_enabled(p_org_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.app_flags where key='organizations_v1_enabled' and enabled)
    or exists(select 1 from private.organization_v1_pilots where organization_id=p_org_id);
$$;
create or replace function public.can_broadcast(p_org_id uuid,p_type text) returns boolean
language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and not public.is_banned(auth.uid())
    and p_type in ('liveVideo','liveAudio') and exists (
      select 1 from public.profiles p where p.id=auth.uid() and p.is_verified
        and case when p_org_id is null then p.personal_broadcast_approved
        else p.organization_broadcast_approved and public.org_v1_enabled(p_org_id)
          and exists(select 1 from public.organizations o join public.org_memberships m
            on m.organization_id=o.id and m.profile_id=p.id and m.status='active'
            where o.id=p_org_id and o.is_verified and m.permissions->>
              case when p_type='liveVideo' then 'can_go_live_video' else 'can_go_audio_only' end='true')
        end);
$$;
create or replace function public.can_publish_upcoming(p_profile_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.profiles p where p.id=p_profile_id and p.personal_broadcast_approved
    and p.is_verified and not public.is_banned(p.id));
$$;
create function public.org_v1_set_pilot(p_org_id uuid,p_enabled boolean) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor();
begin
  if not public.is_master_admin() then raise exception 'Master Admin required' using errcode='42501'; end if;
  if p_enabled then insert into private.organization_v1_pilots values(p_org_id) on conflict do nothing;
  else delete from private.organization_v1_pilots where organization_id=p_org_id; end if;
  perform private.org_v1_audit(p_org_id,'updatePermissions',jsonb_build_object('pilot_enabled',p_enabled));
end; $$;

-- No new definer function is executable by PUBLIC. Helpers stay server-only.
do $$ declare f record;
begin
  for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='public' and p.proname like 'org_v1_%') or (n.nspname='private' and p.proname like 'org_v1_%') loop
    execute format('revoke all on function %s from public, anon, authenticated',f.signature);
  end loop;
end; $$;
grant execute on function public.org_v1_role(uuid),public.org_v1_can(uuid,text),public.org_v1_enabled(uuid),
  public.org_v1_set_member(uuid,uuid,text,text,jsonb),public.org_v1_invite(uuid,text,text,jsonb),
  public.org_v1_answer_invite(uuid,boolean,text),public.org_v1_revoke_invite(uuid),
  public.org_v1_transfer_owner(uuid,uuid),public.org_v1_set_pilot(uuid,boolean),public.org_v1_memberships(uuid),
  public.org_v1_request_join(uuid,text,text,text),public.org_v1_resolve_request(uuid,boolean,jsonb) to authenticated;
revoke all on all tables in schema private from public,anon,authenticated;
commit;
