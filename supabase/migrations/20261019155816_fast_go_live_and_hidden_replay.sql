-- Faster go-live and "hide the video when the live ends" (owner request 2026-10-19).
--
-- 1. hide_replay: the presenter can choose, before going live or from the live
--    screen's options menu, to hide the recording inside the app once the live
--    ends. When a session that went live leaves 'live' with the switch on, its
--    YouTube video id is added to hidden_channel_content (the same list the
--    channel page's long-press hide uses), so the owner can show it again.
-- 2. Live signal: viewers could not see another account's live state change
--    over Realtime (profiles RLS), so the feed found a new live only on its
--    15/30 s catalog poll. Every change into or out of 'live' now sends a
--    content-free public Realtime broadcast ('catalog_changed' on
--    'public_streamers_discovery'); clients re-read the catalog within ~1 s.
-- 3. The studio prepares a personal phone broadcast in the background as soon
--    as it opens. broadcast_update_personal() lets it apply the title and
--    video/audio choice the presenter makes afterwards.
-- 4. A prepared session whose window has passed can never start
--    (broadcast_reserve refuses it). The scheduled reconcile claim now ends it,
--    so an abandoned preparation is removed from YouTube instead of lingering.
begin;

alter table public.broadcast_sessions add column if not exists hide_replay boolean not null default false;
comment on column public.broadcast_sessions.hide_replay is
 'Presenter choice: when this session leaves live, add its video to hidden_channel_content. Changed only by broadcast_set_hide_replay().';

create or replace function public.broadcast_set_hide_replay(p_id uuid, p_hidden boolean)
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); s public.broadcast_sessions;
begin
 if p_hidden is null then raise exception 'Choice required' using errcode='22023'; end if;
 select * into s from public.broadcast_sessions where id=p_id for update;
 if not found or s.owner_id<>actor then raise exception 'Session unavailable' using errcode='42501'; end if;
 -- After the live the recording is hidden or shown from the channel page.
 if s.state not in ('scheduled','preparing','live') then raise exception 'Session already ended' using errcode='55000'; end if;
 update public.broadcast_sessions set hide_replay=p_hidden where id=p_id and hide_replay is distinct from p_hidden;
end; $$;
revoke all on function public.broadcast_set_hide_replay(uuid,boolean) from public,anon;
grant execute on function public.broadcast_set_hide_replay(uuid,boolean) to authenticated;

create or replace function private.broadcast_hide_replay() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 -- Only a live leaves a recording. Hidden once, when it ends: unhiding later
 -- from the channel page must stick.
 if new.hide_replay and new.stream_id is not null and new.started_at is not null then
   insert into public.hidden_channel_content(streamer_id,kind,item_id,hidden_by)
   values(coalesce(new.org_id,new.owner_id),'video',new.stream_id,new.owner_id)
   on conflict do nothing;
 end if;
 return null;
end; $$;
drop trigger if exists broadcast_hide_replay on public.broadcast_sessions;
create trigger broadcast_hide_replay after update of state on public.broadcast_sessions
 for each row when (old.state='live' and new.state<>'live')
 execute function private.broadcast_hide_replay();

create or replace function private.broadcast_live_signal() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 -- No ids or titles: a hidden session must not be revealed, and every client
 -- re-reads what it may see. Best effort; never blocks the state change.
 begin
   perform realtime.send('{}'::jsonb,'catalog_changed','public_streamers_discovery',false);
 exception when others then null;
 end;
 return null;
end; $$;
drop trigger if exists broadcast_live_signal on public.broadcast_sessions;
create trigger broadcast_live_signal after update of state,hidden_from_discovery on public.broadcast_sessions
 for each row when ((old.state='live') is distinct from (new.state='live')
   or (new.state='live' and old.hidden_from_discovery is distinct from new.hidden_from_discovery))
 execute function private.broadcast_live_signal();
drop trigger if exists broadcast_live_signal_insert on public.broadcast_sessions;
create trigger broadcast_live_signal_insert after insert on public.broadcast_sessions
 for each row when (new.state='live')
 execute function private.broadcast_live_signal();

create or replace function public.broadcast_update_personal(p_id uuid,p_title text,p_type text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.org_v1_actor(); s public.broadcast_sessions;
begin
 select * into s from public.broadcast_sessions where id=p_id for update;
 if not found or s.owner_id<>actor or s.org_id is not null or s.state not in ('scheduled','preparing')
   or p_type not in ('liveVideo','liveAudio') or nullif(btrim(p_title),'') is null or char_length(p_title)>100
   or not private.broadcast_permission(actor,null,p_type) then
   raise exception 'Personal session unavailable' using errcode='42501'; end if;
 if s.title_en is distinct from p_title or s.broadcast_type<>p_type then
   update public.broadcast_sessions set title_en=p_title,broadcast_type=p_type,revision=revision+1
    where id=p_id returning * into s;
 end if;
 -- The presenter's own row; the YouTube title follows on 'start'.
 return to_jsonb(s);
end; $$;
revoke all on function public.broadcast_update_personal(uuid,text,text) from public,anon;
grant execute on function public.broadcast_update_personal(uuid,text,text) to authenticated;

-- 20261015191428's claim plus the end of expired, never-started preparations.
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
 for template in select id from public.upcoming_schedules where organization_id is not null and cancelled_at is null loop
   begin perform private.broadcast_materialize(template.id);
   exception when exclusion_violation then null; end;
 end loop;
 for claimed_session in select b.* from public.broadcast_sessions b join private.broadcast_provider r on r.session_id=b.id
   where (b.state in ('preparing','live','ending','processing_replay') or (b.state in ('completed','cancelled') and not r.feed_retired
     and (r.provider_stream_id is not null or (r.needs_reconciliation and r.step='stream_create'))))
   and (r.claimed_until is null or r.claimed_until<now()) and (r.checked_at is null or r.checked_at<now()-interval '30 seconds')
   order by r.checked_at nulls first limit 20 for update of r skip locked loop
   token:=gen_random_uuid();
   update private.broadcast_provider set operation=case when claimed_session.state='ending' then 'end' else 'observe' end,
     operation_token=token,actor_id=null,auth_session_id=null,claimed_until=now()+interval '2 minutes' where session_id=claimed_session.id;
   return next jsonb_build_object('id',claimed_session.id,'token',token);
 end loop;
end; $$;

commit;
