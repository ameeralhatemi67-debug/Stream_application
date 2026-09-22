-- P6.4. Account reads and mutations remain server-authorized. No Auth deletion.
begin;

create policy device_sessions_select_admin on public.device_sessions
  for select to authenticated
  using (public.is_admin_tier() and not public.is_banned(auth.uid()));

create function public.admin_user_directory(p_query text default '', p_offset integer default 0)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_rows jsonb;
begin
  if auth.uid() is null or not public.is_admin_tier() or public.is_banned(auth.uid()) then
    raise exception 'Not permitted' using errcode = '42501';
  end if;
  if p_offset is null or p_offset < 0 or length(coalesce(p_query,'')) > 200 then
    raise exception 'Invalid search' using errcode = '22023';
  end if;
  -- Literal substring matching: %, commas and underscores are not filter syntax.
  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
    select p.id, p.email, p.display_name_en, p.display_name_ar, p.youtube_handle,
      p.is_streamer, p.is_verified, public.is_banned(p.id) as is_banned
    from public.profiles p
    where coalesce(trim(p_query),'') = '' or exists (
      select 1 from unnest(array[p.email,p.display_name_en,p.display_name_ar,p.youtube_handle]) s(value)
      where strpos(lower(coalesce(s.value,'')), lower(trim(p_query))) > 0)
    order by p.created_at desc, p.id limit 26 offset p_offset
  ) r;
  return v_rows;
end;
$$;

create function public.admin_user_detail(p_profile_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_result jsonb;
begin
  if auth.uid() is null or not public.is_admin_tier() or public.is_banned(auth.uid()) then
    raise exception 'Not permitted' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'id',p.id,'email',p.email,'display_name_en',p.display_name_en,
    'display_name_ar',p.display_name_ar,'youtube_handle',p.youtube_handle,
    'is_streamer',p.is_streamer,'is_verified',p.is_verified,
    'is_banned',public.is_banned(p.id),
    'roles', (select coalesce(jsonb_agg(r.role order by r.role),'[]'::jsonb)
      from public.user_roles r where r.profile_id=p.id),
    'organizations', (select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'name_en',o.name_en,'name_ar',o.name_ar)),'[]'::jsonb)
      from public.organizations o where o.owner_profile_id=p.id or exists
        (select 1 from public.org_speakers s where s.organization_id=o.id and s.linked_profile_id=p.id)),
    'devices', (select coalesce(jsonb_agg(to_jsonb(d) order by d.last_active_at desc),'[]'::jsonb)
      from public.device_sessions d where d.user_id=p.id),
    'report_count', (select count(*) from public.chat_reports r where r.reported_sender_id=p.id),
    'ban', (select to_jsonb(b) - 'email' from public.banned_users b where b.profile_id=p.id)
  ) into v_result from public.profiles p where p.id=p_profile_id;
  if v_result is null then raise exception 'Account not found' using errcode = 'P0002'; end if;
  return v_result;
end;
$$;

-- Extend the closed audit vocabulary without changing existing values.
alter table public.audit_logs drop constraint audit_logs_action_check;
alter table public.audit_logs add constraint audit_logs_action_check check (action = any(array[
  'createOrganization','updateOrganizationProfile','addVenueBranch','updateVenueBranch','removeVenueBranch',
  'addSpeakerToRoster','updateSpeakerDetails','removeSpeakerFromRoster','grantBroadcastPermission',
  'revokeBroadcastPermission','updatePermissions','assignOwnerRole','revokeOwnerRole','startLiveBroadcast',
  'endLiveBroadcast','applyBroadcaster','submitAffiliationRequest','acceptAffiliationRequest','declineAffiliationRequest',
  'chatReportDismissed','chatMessageDeleted','chatSenderMuted','chatSenderBanned',
  'accountBanned','accountUnbanned','accountStreamerRevoked','accountVerificationRevoked'
]));

create function public.admin_update_account(p_profile_id uuid, p_action text, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_target public.profiles; v_action text;
begin
  if auth.uid() is null or not public.is_admin_tier() or public.is_banned(auth.uid()) then
    raise exception 'Not permitted' using errcode = '42501';
  end if;
  if p_action is null or p_action not in ('ban','unban','revoke_streamer','revoke_verified')
     or p_reason is null or length(trim(p_reason)) not between 1 and 500 then
    raise exception 'Invalid account action or reason' using errcode = '22023';
  end if;
  -- Same lock as the broadcast RPCs, so revocation cannot race a go-live.
  perform pg_advisory_xact_lock(20260920,12);
  select * into v_target from public.profiles where id=p_profile_id for update;
  if not found then raise exception 'Account not found' using errcode = 'P0002'; end if;
  -- Never lock out the acting administrator or a master administrator.
  if p_profile_id=auth.uid() or exists(select 1 from public.user_roles
      where profile_id=p_profile_id and role='master_admin')
     or (not public.is_master_admin() and exists(select 1 from public.user_roles
      where profile_id=p_profile_id and role='admin')) then
    raise exception 'Protected administrator' using errcode = '42501';
  end if;
  if p_action='ban' then
    insert into public.banned_users(profile_id,email,reason,banned_by)
      values(p_profile_id,coalesce(v_target.email,''),trim(p_reason),auth.uid())
      on conflict(profile_id) do update set reason=excluded.reason,banned_by=excluded.banned_by,
        banned_at=now(),expires_at=null;
    v_action := 'accountBanned';
  elsif p_action='unban' then
    delete from public.banned_users where profile_id=p_profile_id;
    v_action := 'accountUnbanned';
  elsif p_action='revoke_streamer' then
    update public.profiles set is_streamer=false,is_verified=false where id=p_profile_id;
    update public.broadcaster_applications set status='rejected',admin_review_notes=trim(p_reason)
      where applicant_profile_id=p_profile_id and status='approved';
    v_action := 'accountStreamerRevoked';
  else
    update public.profiles set is_verified=false where id=p_profile_id;
    v_action := 'accountVerificationRevoked';
  end if;
  if p_action <> 'unban' then
    update public.organizations set is_currently_live=false,broadcast_type='offline',
      active_stream_id=null,active_viewer_count=0
      where active_stream_id=v_target.active_stream_id;
    update public.profiles set is_currently_live=false,broadcast_type='offline',
      active_stream_id=null,active_viewer_count=0 where id=p_profile_id;
    update public.device_sessions set is_primary_broadcaster=false where user_id=p_profile_id;
  end if;
  -- Atomic with the action: failed audit => failed mutation, never false success.
  perform public.log_audit_event(null,v_action,trim(p_reason),trim(p_reason),
    jsonb_build_object('target_profile_id',p_profile_id,'action',p_action));
end;
$$;

revoke execute on function public.admin_user_directory(text,integer) from public,anon;
revoke execute on function public.admin_user_detail(uuid) from public,anon;
revoke execute on function public.admin_update_account(uuid,text,text) from public,anon;
grant execute on function public.admin_user_directory(text,integer) to authenticated;
grant execute on function public.admin_user_detail(uuid) to authenticated;
grant execute on function public.admin_update_account(uuid,text,text) to authenticated;
commit;
