-- P6: atomic, authorized account erasure and Auth refresh-session revocation.
begin;

alter table public.audit_logs drop constraint audit_logs_action_check;
alter table public.audit_logs add constraint audit_logs_action_check check (action = any(array[
 'createOrganization','updateOrganizationProfile','addVenueBranch','updateVenueBranch','removeVenueBranch',
 'addSpeakerToRoster','updateSpeakerDetails','removeSpeakerFromRoster','grantBroadcastPermission',
 'revokeBroadcastPermission','updatePermissions','assignOwnerRole','revokeOwnerRole','startLiveBroadcast',
 'endLiveBroadcast','applyBroadcaster','submitAffiliationRequest','acceptAffiliationRequest','declineAffiliationRequest',
 'chatReportDismissed','chatMessageDeleted','chatSenderMuted','chatSenderBanned',
 'accountBanned','accountUnbanned','accountStreamerRevoked','accountVerificationRevoked',
 'accountDeleted','accountSessionsRevoked','streamForceEnded','streamRemovedFromFeed'
]));

-- Clients cannot forge these new server-only audit events through the public logger.
alter function public.log_audit_event(uuid,text,text,text,jsonb) rename to log_audit_event_internal;
revoke all on function public.log_audit_event_internal(uuid,text,text,text,jsonb) from public,anon,authenticated;
create function public.log_audit_event(p_organization_id uuid,p_action text,
 p_description_en text,p_description_ar text,p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
begin
 if p_action in ('accountDeleted','accountSessionsRevoked','streamForceEnded','streamRemovedFromFeed') then
   raise exception 'Server-only audit action' using errcode='42501';
 end if;
 return public.log_audit_event_internal(p_organization_id,p_action,p_description_en,p_description_ar,p_metadata);
end;
$$;
revoke all on function public.log_audit_event(uuid,text,text,text,jsonb) from public,anon;
grant execute on function public.log_audit_event(uuid,text,text,text,jsonb) to authenticated;

create table public.removed_live_streams (
 stream_id text primary key,
 removed_at timestamptz not null default now()
);
alter table public.removed_live_streams enable row level security;
revoke all on public.removed_live_streams from public,anon,authenticated;
create function public.guard_removed_live_stream() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.is_currently_live and exists(select 1 from public.removed_live_streams where stream_id=new.active_stream_id) then
   raise exception 'Stream removed by moderation' using errcode='42501';
 end if;
 return new;
end;
$$;
revoke all on function public.guard_removed_live_stream() from public,anon,authenticated;
create trigger guard_removed_stream before insert or update on public.profiles
 for each row execute function public.guard_removed_live_stream();
create trigger guard_removed_stream before insert or update on public.organizations
 for each row execute function public.guard_removed_live_stream();

create function public.admin_auth_account_action(p_profile_id uuid,p_action text,p_reason text)
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
 -- Existing self-erasure cascades delete owned organizations. Administrative
 -- deletion must require an explicit ownership transfer instead of erasing them.
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
 update public.organizations set is_currently_live=false,broadcast_type='offline',active_stream_id=null,active_viewer_count=0
   where active_stream_id=v_stream;
 update public.profiles set is_currently_live=false,broadcast_type='offline',active_stream_id=null,active_viewer_count=0 where id=p_profile_id;
 update public.device_sessions set is_primary_broadcaster=false where user_id=p_profile_id;
 -- Remove legacy refresh tokens too, including tokens with no session_id.
 if p_action in ('delete_account','revoke_sessions') then
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
 'Admin-only atomic account deletion/session revocation with protected targets and audit. Issued JWTs remain valid until expiry outside paths that check auth.sessions. Org/storage owners must be resolved before deletion.';
commit;
