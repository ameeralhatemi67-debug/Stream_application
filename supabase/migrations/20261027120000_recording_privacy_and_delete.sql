-- Recordings: private on YouTube while hidden, deleted on request, taken down
-- by admins (owner request 2026-10-27, ADR-018).
--
-- Every live is created public on YouTube with recording on. Hiding a
-- recording in the app (the end-of-live switch, or the channel page) only
-- took it off the app's lists; it stayed public on YouTube.
--
-- 1. For a recording of a live made through the app, hidden means private on
--    YouTube and shown means public again. hide_replay is the owner's wish for
--    the recording, kept in step with hidden_channel_content (either the
--    switch or the channel page can change it). broadcast_provider.replay_privacy
--    records what was last written to YouTube; broadcast-control writes the
--    difference after the live and the reconcile job retries it.
-- 2. recording_delete(): the channel owner (the streamer, or the
--    organization's owner) asks for the recording to be deleted from YouTube.
--    It disappears from the app at once; broadcast-control deletes it.
-- 3. admin_recording_takedown(): an admin makes a recording private and hidden.
--    The owner cannot show it again until an admin restores it; the owner can
--    still delete it. Both directions are audited.
-- 4. recording_controls(): what the channel page needs to offer these actions.
begin;

alter table private.broadcast_provider
  add column if not exists replay_privacy text check (replay_privacy in ('public','private')),
  add column if not exists replay_privacy_refused text check (replay_privacy_refused in ('public','private')),
  add column if not exists replay_privacy_refused_at timestamptz;
comment on column private.broadcast_provider.replay_privacy is
 'Recording privacy last written to YouTube. Null: never changed (public as created).';
comment on column private.broadcast_provider.replay_privacy_refused is
 'Privacy YouTube last refused (400/403). Each attempt costs 50 quota units, so it is retried only every 6 hours.';

alter table public.broadcast_sessions
  add column if not exists replay_taken_down boolean not null default false,
  add column if not exists recording_delete_requested_at timestamptz,
  add column if not exists recording_deleted_at timestamptz;
comment on column public.broadcast_sessions.hide_replay is
 'Owner choice for the recording: hidden in the app and private on YouTube. Set by broadcast_set_hide_replay() before or during the live, and kept in step with hidden_channel_content afterwards.';
comment on column public.broadcast_sessions.replay_taken_down is
 'An admin made the recording private (admin_recording_takedown). The owner cannot show it again until an admin restores it.';

alter table public.broadcast_sessions drop constraint if exists broadcast_sessions_replay_status_check;
alter table public.broadcast_sessions add constraint broadcast_sessions_replay_status_check
  check (replay_status in ('not_started','processing','available','missing','deleted'));

-- The privacy the recording should have on YouTube.
create or replace function private.recording_privacy_wanted(s public.broadcast_sessions)
returns text language sql immutable set search_path='' as $$
 select case when s.hide_replay or s.replay_taken_down then 'private' else 'public' end;
$$;
revoke all on function private.recording_privacy_wanted(public.broadcast_sessions) from public,anon,authenticated;

-- Whether YouTube still has work to do for this recording. A privacy YouTube
-- refused is asked for again 6 hours later.
create or replace function private.recording_work_pending(s public.broadcast_sessions, r private.broadcast_provider)
returns boolean language sql stable set search_path='' as $$
 select s.state in ('processing_replay','completed') and s.started_at is not null and s.stream_id is not null
   and not r.broadcast_deleted and s.recording_deleted_at is null
   and (s.recording_delete_requested_at is not null
     or (coalesce(r.replay_privacy,'public')<>private.recording_privacy_wanted(s)
       and not (r.replay_privacy_refused is not distinct from private.recording_privacy_wanted(s)
         and r.replay_privacy_refused_at>now()-interval '6 hours')));
$$;
revoke all on function private.recording_work_pending(public.broadcast_sessions,private.broadcast_provider) from public,anon,authenticated;

-- The newest recording with this YouTube id from a live made in the app.
create or replace function private.recording_session(p_video text) returns public.broadcast_sessions
language sql stable security definer set search_path='' as $$
 select * from public.broadcast_sessions where stream_id=p_video and started_at is not null
 order by started_at desc limit 1;
$$;
revoke all on function private.recording_session(text) from public,anon,authenticated;

-- Hiding or showing a recording on the channel page changes hide_replay, so
-- the YouTube privacy follows whichever way the owner hid it.
create or replace function private.hidden_content_recording_sync() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_row public.hidden_channel_content; v_hidden boolean:=tg_op='INSERT';
begin
 if tg_op='DELETE' then v_row:=old; else v_row:=new; end if;
 if v_row.kind<>'video' then return null; end if;
 update public.broadcast_sessions set hide_replay=v_hidden
  where stream_id=v_row.item_id and coalesce(org_id,owner_id)=v_row.streamer_id and started_at is not null
    and state in ('live','ending','processing_replay','completed') and hide_replay is distinct from v_hidden;
 return null;
end; $$;
revoke all on function private.hidden_content_recording_sync() from public,anon,authenticated;
drop trigger if exists hidden_content_recording_sync on public.hidden_channel_content;
create trigger hidden_content_recording_sync after insert or delete on public.hidden_channel_content
 for each row execute function private.hidden_content_recording_sync();

-- A taken-down recording stays hidden: the owner's "show" deletes nothing.
create or replace function public.recording_taken_down(p_channel uuid, p_video text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.broadcast_sessions where stream_id=p_video
   and coalesce(org_id,owner_id)=p_channel and replay_taken_down);
$$;
revoke all on function public.recording_taken_down(uuid,text) from public,anon;
grant execute on function public.recording_taken_down(uuid,text) to authenticated;

drop policy if exists hidden_channel_content_delete_owner on public.hidden_channel_content;
create policy hidden_channel_content_delete_owner
  on public.hidden_channel_content for delete
  to authenticated
  using ((streamer_id = auth.uid() or public.owns_organization(streamer_id))
    and not (kind = 'video' and public.recording_taken_down(streamer_id, item_id)));

-- Audit actions for takedowns and deletions; only the server writes them.
do $$
declare v_constraint text;
begin
 select pg_get_constraintdef(oid) into v_constraint from pg_constraint
  where conrelid='public.audit_logs'::regclass and conname='audit_logs_action_check';
 execute 'alter table public.audit_logs drop constraint audit_logs_action_check';
 execute 'alter table public.audit_logs add constraint audit_logs_action_check CHECK (' ||
   substr(v_constraint,8,length(v_constraint)-8) ||
   ' OR action = ANY (ARRAY[''recordingTakenDown''::text,''recordingRestored''::text,''recordingDeleted''::text]))';
end;
$$;

create or replace function public.log_audit_event(p_organization_id uuid,p_action text,
 p_description_en text,p_description_ar text,p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
begin
 if p_action in ('accountDeleted','accountSessionsRevoked','streamForceEnded','streamRemovedFromFeed',
   'appFlagChanged','chatKeywordAdded','chatKeywordUpdated','chatKeywordRemoved',
   'broadcasterHiddenFromMap','broadcasterShownOnMap','organizationVerificationRevoked',
   'streamHiddenFromDiscovery','streamShownInDiscovery',
   'recordingTakenDown','recordingRestored','recordingDeleted') then
   raise exception 'Server-only audit action' using errcode='42501';
 end if;
 return public.log_audit_event_internal(p_organization_id,p_action,p_description_en,p_description_ar,p_metadata);
end;
$$;
revoke all on function public.log_audit_event(uuid,text,text,text,jsonb) from public,anon;
grant execute on function public.log_audit_event(uuid,text,text,text,jsonb) to authenticated;

-- Who may delete a channel's recordings: the streamer on their own channel, or
-- an organization's owner (not a co-owner or a presenter, who can only hide).
create or replace function private.recording_deleter(p_channel uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (p_channel=auth.uid() or coalesce(public.org_v1_role(p_channel)='owner',false));
$$;
revoke all on function private.recording_deleter(uuid) from public,anon,authenticated;

-- The channel owner deletes a recording of a live made in the app.
create or replace function public.recording_delete(p_video text) returns void
language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); s public.broadcast_sessions;
begin
 if v_actor is null or public.is_banned(v_actor) then raise exception 'Not permitted' using errcode='42501'; end if;
 s:=private.recording_session(p_video);
 if s.id is null then raise exception 'Recording unavailable' using errcode='22023'; end if;
 if not private.recording_deleter(coalesce(s.org_id,s.owner_id)) then
   raise exception 'Not permitted' using errcode='42501'; end if;
 if s.state not in ('processing_replay','completed') then raise exception 'Live not over' using errcode='55000'; end if;
 if s.recording_delete_requested_at is not null or s.recording_deleted_at is not null then return; end if;
 update public.broadcast_sessions set recording_delete_requested_at=now(),revision=revision+1 where id=s.id;
 insert into public.hidden_channel_content(streamer_id,kind,item_id,hidden_by)
  values(coalesce(s.org_id,s.owner_id),'video',p_video,v_actor) on conflict do nothing;
 perform public.log_audit_event_internal(s.org_id,'recordingDeleted','Recording deleted from YouTube',
   'حُذف التسجيل من يوتيوب',jsonb_build_object('session_id',s.id,'video_id',p_video,'channel_id',coalesce(s.org_id,s.owner_id)));
end; $$;
revoke all on function public.recording_delete(text) from public,anon;
grant execute on function public.recording_delete(text) to authenticated;

-- An admin takes a recording down (private on YouTube, hidden in the app) or
-- restores it. Restoring keeps it hidden: the owner decides whether to show it.
create or replace function public.admin_recording_takedown(p_video text, p_down boolean, p_reason text) returns void
language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); s public.broadcast_sessions;
begin
 if v_actor is null or not public.is_admin_tier() or public.is_banned(v_actor) then
   raise exception 'Not permitted' using errcode='42501'; end if;
 if p_down is null or p_reason is null or length(trim(p_reason)) not between 1 and 500 then
   raise exception 'Invalid takedown or reason' using errcode='22023'; end if;
 s:=private.recording_session(p_video);
 if s.id is null then raise exception 'Recording unavailable' using errcode='22023'; end if;
 if s.state not in ('processing_replay','completed') then raise exception 'Live not over' using errcode='55000'; end if;
 if s.replay_taken_down=p_down then return; end if;
 update public.broadcast_sessions set replay_taken_down=p_down,revision=revision+1 where id=s.id;
 if p_down then
   insert into public.hidden_channel_content(streamer_id,kind,item_id,hidden_by)
    values(coalesce(s.org_id,s.owner_id),'video',p_video,v_actor) on conflict do nothing;
 end if;
 perform public.log_audit_event_internal(s.org_id,case when p_down then 'recordingTakenDown' else 'recordingRestored' end,
   trim(p_reason),trim(p_reason),jsonb_build_object('session_id',s.id,'video_id',p_video,
   'channel_id',coalesce(s.org_id,s.owner_id),'target_profile_id',s.owner_id));
end; $$;
revoke all on function public.admin_recording_takedown(text,boolean,text) from public,anon;
grant execute on function public.admin_recording_takedown(text,boolean,text) to authenticated;

-- Recordings of lives made in the app on this channel, for its owner or an admin.
create or replace function public.recording_controls(p_channel uuid)
returns table(video_id text, private_wanted boolean, youtube_privacy text, taken_down boolean,
  delete_pending boolean, deleted boolean, youtube_error boolean, can_delete boolean)
language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_owner boolean; v_admin boolean;
begin
 if v_actor is null or p_channel is null or public.is_banned(v_actor) then return; end if;
 v_owner:=p_channel=v_actor or public.owns_organization(p_channel);
 v_admin:=public.is_admin_tier();
 if not (v_owner or v_admin) then return; end if;
 return query
  select distinct on (s.stream_id) s.stream_id,s.hide_replay or s.replay_taken_down,coalesce(r.replay_privacy,'public'),
    s.replay_taken_down,s.recording_delete_requested_at is not null and s.recording_deleted_at is null,
    s.recording_deleted_at is not null,
    (r.last_error is not null and private.recording_work_pending(s,r))
      or (s.recording_deleted_at is null and coalesce(r.replay_privacy,'public')<>private.recording_privacy_wanted(s)
        and r.replay_privacy_refused is not distinct from private.recording_privacy_wanted(s)),
    private.recording_deleter(p_channel)
  from public.broadcast_sessions s join private.broadcast_provider r on r.session_id=s.id
  where coalesce(s.org_id,s.owner_id)=p_channel and s.started_at is not null and s.stream_id is not null
    and s.state in ('live','ending','processing_replay','completed') and not r.broadcast_deleted
  order by s.stream_id,s.started_at desc;
end; $$;
revoke all on function public.recording_controls(uuid) from public,anon;
grant execute on function public.recording_controls(uuid) to authenticated;

-- 20261005054018's step recorder with the two recording steps.
create or replace function public.broadcast_provider_step(p_id uuid,p_token uuid,p_step text,p_result jsonb default null,
 p_error text default null,p_ambiguous boolean default false) returns void
language plpgsql security definer set search_path='' as $$
declare r private.broadcast_provider; s public.broadcast_sessions; secret uuid;
begin
 select * into r from private.broadcast_provider where session_id=p_id for update;
 if not found or r.operation_token is distinct from p_token then raise exception 'Reservation changed' using errcode='40001'; end if;
 select * into s from public.broadcast_sessions where id=p_id for update;
 if p_step not in ('stream_create','broadcast_create','bind','transition_live','transition_complete','feed_delete','observe','reconcile','finish',
   'recording_privacy','recording_delete') then
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
   if p_result->>'id' is null or nullif(p_result->>'key','') is null or p_result->>'url' !~ '^rtmps://([a-z0-9-]+\.)*rtmps?\.youtube\.com(:443)?/' then
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
 elsif p_step='recording_privacy' then
   if coalesce(p_result->>'privacy',p_result->>'refused') is null
     or coalesce(p_result->>'privacy',p_result->>'refused') not in ('public','private') then
     raise exception 'Invalid recording privacy' using errcode='22023'; end if;
   if p_result ? 'privacy' then
     update private.broadcast_provider set replay_privacy=p_result->>'privacy',replay_privacy_refused=null,
       replay_privacy_refused_at=null where session_id=p_id;
   else
     update private.broadcast_provider set replay_privacy_refused=p_result->>'refused',replay_privacy_refused_at=now()
       where session_id=p_id;
   end if;
 elsif p_step='recording_delete' then
   if s.recording_delete_requested_at is null then raise exception 'Deletion not requested' using errcode='55000'; end if;
   update public.broadcast_sessions set recording_deleted_at=coalesce(recording_deleted_at,now()),replay_status='deleted',
     state=case when state='processing_replay' then 'completed' else state end,revision=revision+1 where id=p_id;
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

-- 20261020075541's claim; recording work is also claimed, every 30 seconds
-- (15 minutes after a failure, e.g. a disconnected channel).
create or replace function public.broadcast_reconcile_claim() returns setof jsonb
language plpgsql security definer set search_path='' as $$
declare claimed_session public.broadcast_sessions; token uuid; template record;
begin
 -- Broadcasts whose feed did not return within the grace window end here, so
 -- the claim below completes them on YouTube in the same pass.
 perform public.sweep_stale_live_flags();
 -- A preparation that can no longer start (its window passed) is ended, which
 -- deletes its never-live YouTube broadcast and retires its feed.
 update public.broadcast_sessions set state='ending',termination_pending=true,end_reason='stale_expired',revision=revision+1
 where state='preparing' and expected_end_at<now();
 -- Revocation and transfer must also terminate provider media when the app is absent.
 update public.broadcast_sessions s set state='ending',termination_pending=true,end_reason='approval_revoked',revision=s.revision+1
 from public.channel_connections c,private.broadcast_provider r
 where s.channel_connection_id=c.id and r.session_id=s.id and s.state in ('preparing','live')
   and (not private.broadcast_permission(s.owner_id,s.org_id,s.broadcast_type,false)
     or not private.channel_owner(c.owner_profile_id,c.organization_id) or c.status<>'connected' or c.revision<>r.channel_revision
     or not exists(select 1 from public.device_sessions where user_id=s.owner_id and device_id=s.device_id and is_primary_broadcaster));
 -- broadcast-control settles a replay by 48 h after the end. One still open a
 -- day later could not be checked on YouTube: no replay is confirmed.
 update public.broadcast_sessions s set state='completed',replay_status='missing',revision=s.revision+1
 from private.broadcast_provider r
 where r.session_id=s.id and s.state='processing_replay'
   and coalesce(s.ended_at,s.expected_end_at)<now()-interval '72 hours'
   and (r.claimed_until is null or r.claimed_until<now());
 for template in select id from public.upcoming_schedules where organization_id is not null and cancelled_at is null loop
   begin perform private.broadcast_materialize(template.id);
   exception when exclusion_violation then null; end;
 end loop;
 for claimed_session in select b.* from public.broadcast_sessions b join private.broadcast_provider r on r.session_id=b.id
   where (b.state in ('preparing','live','ending','processing_replay') or (b.state in ('completed','cancelled') and not r.feed_retired
     and (r.provider_stream_id is not null or (r.needs_reconciliation and r.step='stream_create'))
     and coalesce(b.ended_at,b.expected_end_at,now())>now()-interval '7 days')
     or private.recording_work_pending(b,r))
   and (r.claimed_until is null or r.claimed_until<now())
   -- After the live only the feed and the replay are left: each check costs
   -- YouTube quota, and a processed replay takes hours. A privacy change or a
   -- deletion the owner asked for runs at once.
   and (r.checked_at is null or r.checked_at<now()-case
     when b.state in ('preparing','live','ending') then interval '30 seconds'
     when private.recording_work_pending(b,r) then
       case when r.last_error is null then interval '30 seconds' else interval '15 minutes' end
     when coalesce(b.ended_at,b.expected_end_at,now())>now()-interval '1 hour' then interval '5 minutes'
     when coalesce(b.ended_at,b.expected_end_at,now())>now()-interval '1 day' then interval '15 minutes'
     else interval '1 hour' end)
   order by r.checked_at nulls first limit 20 for update of r skip locked loop
   token:=gen_random_uuid();
   update private.broadcast_provider set operation=case when claimed_session.state='ending' then 'end' else 'observe' end,
     operation_token=token,actor_id=null,auth_session_id=null,claimed_until=now()+interval '2 minutes' where session_id=claimed_session.id;
   return next jsonb_build_object('id',claimed_session.id,'token',token);
 end loop;
end; $$;

commit;
