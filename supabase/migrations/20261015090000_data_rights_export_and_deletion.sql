-- Data rights for the Play launch (brief/launch/03 section 3).
--
-- 1. export_my_data(): one server-side read of every user-linked table, so the
--    in-app export is complete. Other people's identities (who granted a role,
--    who muted, banned or reviewed the user, who the user reported) and secrets
--    (push tokens, OAuth credentials, invite token hashes) are left out.
-- 2. prepare_account_deletion(): tells the client whether self-deletion is
--    blocked and which Storage files it must remove first. Direct SQL deletes
--    from storage.objects are refused by Supabase, so files go through the
--    Storage API before the account row disappears.
-- 3. delete_own_account(): re-checks the blockers, refuses while owned files
--    remain, and redacts the name/email copies that do not cascade (audit log
--    actor columns, application review history, speaker links, invitations by
--    email) before deleting the auth user.
--
-- Retention defaults are erase-or-redact. Counsel may allow keeping more
-- (store/counsel_questions.md question 7); loosen this only on that advice.
begin;

-- Lets the owner of a legacy flat-path upload (owner_id set, no uid prefix)
-- see and delete it, so account deletion never strands an old avatar at a
-- public URL. Uploads still follow can_write_streamer_asset() paths.
create policy streamer_assets_select_own_upload on storage.objects
  for select to authenticated
  using (bucket_id = 'streamer-assets'
    and not public.is_current_user_banned()
    and owner_id = (select auth.uid())::text);
create policy streamer_assets_delete_own_upload on storage.objects
  for delete to authenticated
  using (bucket_id = 'streamer-assets'
    and owner_id = (select auth.uid())::text);

create or replace function private.account_storage_paths(p_profile uuid)
returns setof text
language sql stable security definer set search_path = '' as $$
  select o.name from storage.objects o
  where o.bucket_id = 'streamer-assets'
    and (o.owner_id = p_profile::text
      or split_part(o.name, '/', 1) = p_profile::text
      or (split_part(o.name, '/', 1) = 'org'
        and split_part(o.name, '/', 2) in (
          select id::text from public.organizations where owner_profile_id = p_profile)))
  order by o.name;
$$;

create or replace function private.account_deletion_blocker(p_profile uuid)
returns text
language sql stable security definer set search_path = '' as $$
  select case
    -- A ban must not be shed by deleting and signing up again; support
    -- handles these through the web deletion request.
    when public.is_banned(p_profile) then 'account_restricted'
    -- Same condition broadcast_guard_delete() enforces on the delete itself.
    when exists (select 1 from public.broadcast_sessions s
        left join private.broadcast_provider r on r.session_id = s.id
        where (s.owner_id = p_profile or s.content_owner_profile_id = p_profile
          or s.org_id in (select id from public.organizations where owner_profile_id = p_profile))
          and (s.state in ('preparing', 'live', 'ending')
            or (r.provider_stream_id is not null and not r.feed_retired)))
      then 'broadcast_active'
    -- Deleting the owner deletes the organization; other members keep theirs.
    when exists (select 1 from public.organizations o
        join public.org_memberships m on m.organization_id = o.id
        where o.owner_profile_id = p_profile and m.profile_id <> p_profile
          and m.status = 'active')
      then 'organization_has_members'
  end;
$$;

revoke all on function private.account_storage_paths(uuid) from public, anon, authenticated;
revoke all on function private.account_deletion_blocker(uuid) from public, anon, authenticated;

create or replace function public.prepare_account_deletion()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v uuid := auth.uid();
begin
  if v is null then raise exception 'Not signed in' using errcode = '42501'; end if;
  return jsonb_build_object(
    'blocker', private.account_deletion_blocker(v),
    'storage_paths', coalesce((select jsonb_agg(p) from private.account_storage_paths(v) p), '[]'::jsonb));
end;
$$;
revoke all on function public.prepare_account_deletion() from public, anon;
grant execute on function public.prepare_account_deletion() to authenticated;

create or replace function public.delete_own_account()
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v uuid := auth.uid();
  v_email text;
  v_blocker text;
begin
  if v is null then raise exception 'Not signed in' using errcode = '42501'; end if;
  -- Same lock as admin account actions, so the two never race on one account.
  perform pg_advisory_xact_lock(20260920, 12);
  v_blocker := private.account_deletion_blocker(v);
  if v_blocker is not null then
    raise exception '%', v_blocker using errcode = '55000';
  end if;
  if exists (select 1 from private.account_storage_paths(v)) then
    raise exception 'storage_cleanup_required' using errcode = '55000';
  end if;

  select email into v_email from auth.users where id = v;

  -- Copies of the name and email that survive the cascade.
  update public.audit_logs
     set actor_email = 'deleted', actor_name = 'Deleted account'
   where actor_profile_id = v;
  update public.application_review_events
     set actor_name = 'Deleted account'
   where actor_profile_id = v;
  update public.application_review_events
     set applicant_name_en = 'Deleted account', applicant_name_ar = 'حساب محذوف',
         application_snapshot = '{}'::jsonb, base_snapshot = null
   where application_id in (
     select id from public.broadcaster_applications where applicant_profile_id = v);
  update public.org_speakers set linked_email = null where linked_profile_id = v;
  if v_email is not null then
    delete from public.affiliation_requests where lower(target_email) = lower(v_email);
  end if;

  delete from auth.users where id = v;
end;
$$;
revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;
comment on function public.delete_own_account() is
  'Self-service deletion. Call prepare_account_deletion() first and remove the listed Storage files through the Storage API. Refuses while banned, while a broadcast is active, while an owned organization has other active members, or while owned files remain.';

create or replace function public.export_my_data()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v uuid := auth.uid();
  v_email text;
begin
  if v is null then raise exception 'Not signed in' using errcode = '42501'; end if;
  select email into v_email from auth.users where id = v;

  return jsonb_build_object(
    'format_version', 1,
    'exported_at', now(),
    'account', (select jsonb_build_object(
        'id', u.id, 'email', u.email, 'created_at', u.created_at,
        'last_sign_in_at', u.last_sign_in_at,
        'sign_in_providers', u.raw_app_meta_data -> 'providers')
      from auth.users u where u.id = v),
    'profile', (select to_jsonb(p) from public.profiles p where p.id = v),
    'consent', (select jsonb_build_object('version', p.consent_version,
        'accepted_at', p.consent_accepted_at) from public.profiles p where p.id = v),
    'roles', coalesce((select jsonb_agg(jsonb_build_object('role', r.role,
        'organization_id', r.organization_id, 'granted_at', r.granted_at))
      from public.user_roles r where r.profile_id = v), '[]'::jsonb),
    'permissions', coalesce((select jsonb_agg(jsonb_build_object('permission', p.permission_key,
        'organization_id', p.organization_id, 'granted_at', p.granted_at))
      from public.user_permissions p where p.profile_id = v), '[]'::jsonb),
    'device_sessions', coalesce((select jsonb_agg(to_jsonb(d))
      from public.device_sessions d where d.user_id = v), '[]'::jsonb),
    'broadcaster_applications', coalesce((select jsonb_agg(to_jsonb(a) - 'reviewed_by')
      from public.broadcaster_applications a where a.applicant_profile_id = v), '[]'::jsonb),
    'application_history', coalesce((select jsonb_agg(jsonb_build_object(
        'application_id', e.application_id, 'action', e.action,
        'previous_status', e.previous_status, 'next_status', e.next_status,
        'reason', e.reason, 'created_at', e.created_at) order by e.event_order)
      from public.application_review_events e where e.application_id in (
        select id from public.broadcaster_applications where applicant_profile_id = v)), '[]'::jsonb),
    'custom_placeholders', coalesce((select jsonb_agg(to_jsonb(c) - 'reviewed_by')
      from public.streamer_custom_placeholders c where c.streamer_id = v), '[]'::jsonb),
    'suggested_tags', coalesce((select jsonb_agg(jsonb_build_object('name', t.name,
        'status', t.status, 'created_at', t.created_at))
      from public.tags t where t.created_by = v), '[]'::jsonb),
    'follows', coalesce((select jsonb_agg(to_jsonb(f) - 'follower_profile_id')
      from public.follows f where f.follower_profile_id = v), '[]'::jsonb),
    'bookmarks', coalesce((select jsonb_agg(to_jsonb(b) - 'profile_id')
      from public.bookmarks b where b.profile_id = v), '[]'::jsonb),
    'chat_messages', coalesce((select jsonb_agg(to_jsonb(m) - 'sender_id' order by m.created_at)
      from public.chat_messages m where m.sender_id = v), '[]'::jsonb),
    'chat_reports_filed', coalesce((select jsonb_agg(jsonb_build_object('id', r.id,
        'message_id', r.message_id, 'stream_id', r.stream_id, 'reason', r.reason,
        'created_at', r.created_at))
      from public.chat_reports r where r.reporter_id = v), '[]'::jsonb),
    'chat_blocks', coalesce((select jsonb_agg(jsonb_build_object('blocked_profile_id', b.blocked_id,
        'created_at', b.created_at))
      from public.chat_user_blocks b where b.blocker_id = v), '[]'::jsonb),
    'chat_mutes_received', coalesce((select jsonb_agg(jsonb_build_object('stream_id', m.stream_id,
        'created_at', m.created_at, 'expires_at', m.expires_at))
      from public.chat_muted_users m where m.muted_profile_id = v), '[]'::jsonb),
    'chat_mute_history', coalesce((select jsonb_agg(jsonb_build_object('stream_id', a.stream_id,
        'reason', a.reason, 'messages', a.last_messages, 'created_at', a.created_at))
      from public.chat_mute_audit_log a where a.profile_id = v), '[]'::jsonb),
    'bans_received', coalesce((select jsonb_agg(jsonb_build_object('reason', b.reason,
        'banned_at', b.banned_at, 'expires_at', b.expires_at))
      from public.banned_users b where b.profile_id = v), '[]'::jsonb),
    'moderator_assignments', coalesce((select jsonb_agg(jsonb_build_object('scope', s.scope,
        'stream_id', s.stream_id, 'organization_id', s.organization_id, 'granted_at', s.granted_at))
      from public.stream_moderators s where s.profile_id = v), '[]'::jsonb),
    'broadcast_sessions', coalesce((select jsonb_agg(jsonb_build_object('id', s.id,
        'organization_id', s.org_id, 'stream_id', s.stream_id, 'broadcast_type', s.broadcast_type,
        'state', s.state, 'end_reason', s.end_reason, 'title_en', s.title_en, 'title_ar', s.title_ar,
        'description', s.description, 'scheduled_start_at', s.scheduled_start_at,
        'started_at', s.started_at, 'ended_at', s.ended_at, 'replay_status', s.replay_status,
        'device_id', s.device_id) order by s.started_at)
      from public.broadcast_sessions s
      where s.owner_id = v or s.content_owner_profile_id = v), '[]'::jsonb),
    'upcoming_schedules', coalesce((select jsonb_agg(to_jsonb(u))
      from public.upcoming_schedules u
      where u.streamer_profile_id = v or u.created_by = v), '[]'::jsonb),
    'reminders', jsonb_build_object(
      'channels', coalesce((select jsonb_agg(jsonb_build_object('streamer_profile_id', r.streamer_profile_id,
          'created_at', r.created_at))
        from public.channel_schedule_reminders r where r.viewer_profile_id = v), '[]'::jsonb),
      'schedules', coalesce((select jsonb_agg(jsonb_build_object('schedule_id', r.schedule_id,
          'created_at', r.created_at))
        from public.card_schedule_reminders r where r.viewer_profile_id = v), '[]'::jsonb),
      'lead_minutes', (select p.lead_minutes from public.schedule_reminder_preferences p
        where p.viewer_profile_id = v),
      'deliveries', coalesce((select jsonb_agg(jsonb_build_object('schedule_id', d.schedule_id,
          'occurrence_at', d.occurrence_at, 'lead_minutes', d.lead_minutes, 'sent_at', d.sent_at))
        from public.schedule_reminder_deliveries d where d.viewer_profile_id = v), '[]'::jsonb)),
    'notification_preferences', (select jsonb_build_object('live_enabled', n.live_enabled,
        'organization_enabled', n.organization_enabled, 'updated_at', n.updated_at)
      from public.notification_push_preferences n where n.viewer_profile_id = v),
    -- Push tokens are device credentials: list the devices, not the tokens.
    'push_devices', coalesce((select jsonb_agg(jsonb_build_object('platform', d.platform,
        'language_code', d.language_code, 'updated_at', d.updated_at))
      from public.schedule_push_devices d where d.viewer_profile_id = v), '[]'::jsonb),
    'organizations_owned', coalesce((select jsonb_agg(to_jsonb(o))
      from public.organizations o where o.owner_profile_id = v), '[]'::jsonb),
    'organization_memberships', coalesce((select jsonb_agg(to_jsonb(m) - 'profile_id')
      from public.org_memberships m where m.profile_id = v), '[]'::jsonb),
    'organization_invitations', coalesce((select jsonb_agg(jsonb_build_object('id', a.id,
        'organization_id', a.organization_id, 'direction', a.direction, 'status', a.status,
        'invited_role', a.invited_role, 'proposed_role_en', a.proposed_role_en,
        'proposed_role_ar', a.proposed_role_ar, 'note', a.note, 'created_at', a.created_at,
        'resolved_at', a.resolved_at, 'expires_at', a.expires_at,
        'sent_by_me', a.invited_by_profile_id = v))
      from public.affiliation_requests a
      where a.streamer_profile_id = v or a.invited_by_profile_id = v
        or (v_email is not null and lower(a.target_email) = lower(v_email))), '[]'::jsonb),
    'organization_speaker_links', coalesce((select jsonb_agg(jsonb_build_object(
        'organization_id', s.organization_id, 'name_en', s.name_en, 'name_ar', s.name_ar,
        'role_or_title_en', s.role_or_title_en, 'role_or_title_ar', s.role_or_title_ar,
        'created_at', s.created_at))
      from public.org_speakers s where s.linked_profile_id = v), '[]'::jsonb),
    'organization_ownership_transfers', coalesce((select jsonb_agg(jsonb_build_object(
        'organization_id', t.organization_id, 'direction',
        case when t.from_profile_id = v then 'outgoing' else 'incoming' end,
        'expires_at', t.expires_at))
      from private.organization_owner_transfers t
      where t.from_profile_id = v or t.to_profile_id = v), '[]'::jsonb),
    'organization_events', coalesce((select jsonb_agg(jsonb_build_object('kind', e.kind,
        'organization_id', e.organization_id, 'session_id', e.session_id,
        'payload', e.payload, 'created_at', e.created_at, 'read_at', e.read_at)
        order by e.created_at)
      from public.org_v1_events e where e.recipient_profile_id = v), '[]'::jsonb),
    -- Channel metadata only; OAuth credentials stay in Vault.
    'youtube_channel_connections', coalesce((select jsonb_agg(jsonb_build_object(
        'youtube_channel_id', c.youtube_channel_id, 'channel_title', c.channel_title,
        'organization_id', c.organization_id, 'status', c.status,
        'connected_at', c.connected_at, 'updated_at', c.updated_at))
      from public.channel_connections c where c.owner_profile_id = v), '[]'::jsonb),
    'actions_recorded', coalesce((select jsonb_agg(jsonb_build_object('action', l.action,
        'organization_id', l.organization_id, 'description_en', l.description_en,
        'description_ar', l.description_ar, 'created_at', l.created_at) order by l.created_at)
      from public.audit_logs l where l.actor_profile_id = v), '[]'::jsonb),
    'uploaded_files', coalesce((select jsonb_agg(p) from private.account_storage_paths(v) p), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;
comment on function public.export_my_data() is
  'Returns every user-linked record for the caller as JSON. Excludes other people''s identities and secrets (push tokens, OAuth credentials, invite token hashes).';

commit;
