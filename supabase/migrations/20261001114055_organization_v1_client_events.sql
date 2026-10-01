begin;
create function public.broadcast_reserve_confirmed(p_id uuid,p_device text,p_sender text,p_operation text,
 p_connection_id uuid default null,p_channel_revision bigint default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); s public.broadcast_sessions; c public.channel_connections;
begin
 perform pg_advisory_xact_lock(20261001,3);
 select * into s from public.broadcast_sessions where id=p_id for update;
 if p_operation in ('prepare','start') then
   select * into c from public.channel_connections where id=p_connection_id for update;
   if not found or p_channel_revision is null or c.revision<>p_channel_revision or c.status<>'connected'
     or c.organization_id is distinct from s.org_id or (s.org_id is null and c.owner_profile_id<>actor)
     or (s.channel_connection_id is not null and s.channel_connection_id<>c.id) then
     raise exception 'Channel confirmation changed; review the destination' using errcode='42501'; end if;
 end if;
 return public.broadcast_reserve(p_id,p_device,p_sender,p_operation);
end; $$;
revoke execute on function public.broadcast_reserve(uuid,text,text,text) from authenticated;
revoke all on function public.broadcast_reserve_confirmed(uuid,text,text,text,uuid,bigint) from public,anon;
grant execute on function public.broadcast_reserve_confirmed(uuid,text,text,text,uuid,bigint) to authenticated;

create function public.broadcast_room(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare s public.broadcast_sessions;
begin
 select * into s from public.broadcast_sessions where id=p_id;
 if not found then return null; end if;
 if not (s.owner_id=auth.uid() or (auth.uid() is not null and (public.is_admin_tier()
   or (s.org_id is not null and public.org_v1_can(s.org_id,'schedule'))))
   or (s.state in ('scheduled','preparing','live','ending','processing_replay','completed') and s.accepted_at is not null
     and not public.is_banned(s.owner_id) and (s.org_id is null or exists(select 1 from public.organizations where id=s.org_id and is_verified)))) then return null; end if;
 return (to_jsonb(s)-'device_id') || case when s.owner_id=auth.uid() then jsonb_build_object('device_id',s.device_id) else '{}'::jsonb end;
end; $$;
revoke all on function public.broadcast_room(uuid) from public;
grant execute on function public.broadcast_room(uuid) to anon,authenticated;

create function public.broadcast_device_displaced() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if old.is_primary_broadcaster and not new.is_primary_broadcaster then
   update public.broadcast_sessions set state='ending',termination_pending=true,end_reason='device_transfer',revision=revision+1
     where owner_id=new.user_id and device_id=new.device_id and state in ('preparing','live');
 end if;
 return new;
end; $$;
create trigger broadcast_device_displaced after update of is_primary_broadcaster on public.device_sessions
 for each row execute function public.broadcast_device_displaced();
revoke all on function public.broadcast_device_displaced() from public,anon,authenticated;
create function public.broadcast_cancel_schedule(p_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); schedule public.upcoming_schedules;
begin
 perform pg_advisory_xact_lock(20261001,3);
 select * into schedule from public.upcoming_schedules where id=p_id for update;
 if not found or schedule.organization_id is null or not public.org_v1_can(schedule.organization_id,'schedule') then
   raise exception 'Schedule cancellation denied' using errcode='42501'; end if;
 perform set_config('app.org_schedule_write','1',true);
 update public.upcoming_schedules set cancelled_at=coalesce(cancelled_at,now()) where id=p_id;
 update public.broadcast_sessions set state='cancelled',ended_at=now(),end_reason='owner_end',accepted_at=null,revision=revision+1
   where schedule_id=p_id and state in ('draft','awaiting_acceptance','scheduled');
 perform set_config('app.org_schedule_write','',true);
 perform private.org_v1_audit(schedule.organization_id,'updatePermissions',jsonb_build_object('schedule',p_id,'operation','cancel'));
end; $$;
revoke all on function public.broadcast_cancel_schedule(uuid) from public,anon;
grant execute on function public.broadcast_cancel_schedule(uuid) to authenticated;
-- Canonical session chat authority. Organization scheduling conveys no moderation.
create or replace function public.owns_stream(p_stream_id text) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and not public.is_banned(auth.uid()) and (
   exists(select 1 from public.broadcast_sessions s where s.id::text=p_stream_id and (
     (s.org_id is null and s.owner_id=auth.uid()) or (s.org_id is not null and public.org_v1_can(s.org_id,'moderate'))))
   or exists(select 1 from public.stream_moderators m where m.profile_id=auth.uid() and
     (m.scope='global' or (m.scope='stream' and m.stream_id=p_stream_id and exists(
       select 1 from public.broadcast_sessions s where s.id::text=p_stream_id and s.org_id is null)))));
$$;

create function public.broadcast_can_delegate_chat(p_stream text) returns boolean
language sql stable security definer set search_path='' as $$
 select public.is_admin_tier() or exists(select 1 from public.broadcast_sessions s where s.id::text=p_stream
   and s.org_id is null and s.owner_id=auth.uid() and not public.is_banned(auth.uid()));
$$;
revoke all on function public.broadcast_can_delegate_chat(text) from public,anon;
grant execute on function public.broadcast_can_delegate_chat(text) to authenticated;
drop policy stream_moderators_insert_scoped on public.stream_moderators;
drop policy stream_moderators_update_scoped on public.stream_moderators;
create policy stream_moderators_insert_scoped on public.stream_moderators for insert to authenticated
 with check(assigned_by=auth.uid() and ((scope='stream' and public.broadcast_can_delegate_chat(stream_id))
   or (scope in ('global','organization') and public.is_admin_tier())));
create policy stream_moderators_update_scoped on public.stream_moderators for update to authenticated
 using(public.is_admin_tier() or (scope='stream' and public.broadcast_can_delegate_chat(stream_id)))
 with check(assigned_by=auth.uid() and ((scope='stream' and public.broadcast_can_delegate_chat(stream_id))
   or (scope in ('global','organization') and public.is_admin_tier())));
create policy chat_reports_select_scoped on public.chat_reports for select to authenticated using(public.owns_stream(stream_id));
create policy chat_reports_delete_scoped on public.chat_reports for delete to authenticated using(public.owns_stream(stream_id));

create function public.broadcast_chat_read(p_stream text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.broadcast_sessions s where s.id::text=p_stream
   and public.broadcast_room(s.id) is not null);
$$;
revoke all on function public.broadcast_chat_read(text) from public;
grant execute on function public.broadcast_chat_read(text) to anon,authenticated;
create policy chat_session_visibility on public.chat_messages as restrictive for select to anon,authenticated
 using(public.broadcast_chat_read(stream_id));
create policy chat_session_send on public.chat_messages as restrictive for insert to authenticated
 with check(exists(select 1 from public.broadcast_sessions s where s.id::text=stream_id and s.state='live')
   and public.broadcast_chat_read(stream_id));

create or replace function public.viewer_heartbeat(p_stream_id text,p_viewer_key text) returns boolean
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); s public.broadcast_sessions;
begin
 if p_stream_id is null or p_viewer_key is null or length(p_viewer_key) not between 8 and 128 then return false; end if;
 select * into s from public.broadcast_sessions where id::text=p_stream_id;
 if not found or s.state<>'live' or public.broadcast_room(s.id) is null or s.owner_id=actor
   or (actor is not null and public.is_banned(actor)) then return false; end if;
 if actor is not null then p_viewer_key:=actor::text; end if;
 insert into public.stream_viewers(stream_id,viewer_key,last_seen) values(p_stream_id,p_viewer_key,now())
 on conflict(stream_id,viewer_key) do update set last_seen=now()
 where public.stream_viewers.last_seen<now()-interval '10 seconds';
 delete from public.stream_viewers where last_seen<now()-interval '10 minutes';
 return true;
end; $$;

create or replace function public.report_broadcast_ingest(p_session_id uuid,p_device_id text,p_state text) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); s public.broadcast_sessions;
begin
 if p_state is null or p_state not in ('sending','interrupted') then raise exception 'Invalid ingest state' using errcode='22023'; end if;
 select * into s from public.broadcast_sessions where id=p_session_id for update;
 if not found or s.owner_id<>actor or s.device_id is distinct from p_device_id or s.sender_mode<>'phone_direct'
   or not private.broadcast_primary(actor,p_device_id) or not private.broadcast_permission(actor,s.org_id,s.broadcast_type,false) then
   raise exception 'Assigned primary presenter required' using errcode='42501'; end if;
 if s.state not in ('preparing','live') then raise exception 'Broadcast session ended' using errcode='55000'; end if;
 update public.broadcast_sessions set ingest_state=p_state,ingest_observed_at=now(),
   interrupted_since=case when p_state='interrupted' then coalesce(interrupted_since,now()) end
   where id=p_session_id;
end; $$;


-- Badges describe authority in this room, never a role held in another org.
create or replace function public.chat_sender_info(p_profile_ids uuid[],p_stream_id text default null)
returns table(profile_id uuid,display_name text,avatar_url text,is_verified boolean,
 is_admin boolean,is_org_owner boolean,is_speaker boolean,is_moderator boolean)
language sql stable security definer set search_path='' as $$
 select p.id,coalesce(nullif(p.display_name_en,''),'Viewer'),p.avatar_url,p.is_verified,
   exists(select 1 from public.user_roles r where r.profile_id=p.id and r.role in ('master_admin','admin')),
   exists(select 1 from public.org_memberships m where m.organization_id=s.org_id and m.profile_id=p.id
     and m.status='active' and m.role in ('owner','co_owner')),
   s.owner_id=p.id,
   (exists(select 1 from public.org_memberships m where m.organization_id=s.org_id and m.profile_id=p.id
     and m.status='active' and m.role='moderator')
    or exists(select 1 from public.stream_moderators m where m.profile_id=p.id
      and (m.scope='global' or (s.org_id is null and m.scope='stream' and m.stream_id=p_stream_id))))
 from public.profiles p join public.broadcast_sessions s on s.id::text=p_stream_id
 where p.id=any(p_profile_ids) and public.broadcast_chat_read(p_stream_id) and not public.is_banned(p.id);
$$;
revoke all on function public.chat_sender_info(uuid[],text) from public,anon;
grant execute on function public.chat_sender_info(uuid[],text) to anon,authenticated;
commit;
