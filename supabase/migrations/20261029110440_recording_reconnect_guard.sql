begin;

-- Hiding or deleting a recording reaches YouTube only while the channel's
-- token exists (owner report 2026-10-29: the old recordings stayed public and
-- two deletions never ran). Two causes: the stored token had stopped working
-- (Google drops it after 7 days while the consent screen is in "Testing"), and
-- the owner disconnected the channel, which erases the token, before the
-- queued changes ran.
--
-- 1. Disconnecting waits while YouTube still has hiding or deleting to do for
--    a recording of this channel. A change YouTube refused, or one that cannot
--    run because the token already stopped working, does not hold it back.
-- 2. The recording's status row reports "YouTube hasn't accepted the change"
--    also when the channel is not connected, instead of saying "updating".

create or replace function public.channel_disconnect(p_connection_id uuid) returns void
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
  if connection.status='connected' and exists(
    select 1 from public.broadcast_sessions s join private.broadcast_provider r on r.session_id=s.id
    where s.channel_connection_id=connection.id and private.recording_work_pending(s,r)
      and coalesce(r.last_error,'') not in ('oauth_failed','owner_reconnection_required')
      and (s.recording_delete_requested_at is not null
        or r.replay_privacy_refused is distinct from private.recording_privacy_wanted(s))) then
    raise exception 'YouTube is still applying changes to your recordings' using errcode='55000'; end if;
  update public.channel_connections set status='disconnected',revision=revision+1,updated_at=now() where id=connection.id;
  delete from private.channel_credentials where connection_id=connection.id;
  perform private.org_v1_audit(connection.organization_id,'updatePermissions',jsonb_build_object('channel_connection',connection.id,'operation','disconnect'));
end; $$;

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
    (private.recording_work_pending(s,r) and (r.last_error is not null or coalesce(cc.status,'disconnected')<>'connected'))
      or (s.recording_deleted_at is null and coalesce(r.replay_privacy,'public')<>private.recording_privacy_wanted(s)
        and r.replay_privacy_refused is not distinct from private.recording_privacy_wanted(s)),
    private.recording_deleter(p_channel)
  from public.broadcast_sessions s join private.broadcast_provider r on r.session_id=s.id
    left join public.channel_connections cc on cc.id=s.channel_connection_id
  where coalesce(s.org_id,s.owner_id)=p_channel and s.started_at is not null and s.stream_id is not null
    and s.state in ('live','ending','processing_replay','completed') and not r.broadcast_deleted
  order by s.stream_id,s.started_at desc;
end; $$;

commit;
