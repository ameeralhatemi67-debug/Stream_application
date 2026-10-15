-- Connection-loss grace window for live broadcasts (owner decision 2026-10-15).
--
-- Rule: when the broadcaster's video stops reaching YouTube, viewers see a
-- "we'll be right back" state. If the feed returns within the grace window
-- (2 minutes) the broadcast continues; otherwise it is ended for everyone and
-- the YouTube broadcast is completed. A dead phone, a killed app or a laptop
-- that lost its network cannot report this itself, so the server now watches
-- YouTube's own feed status instead of relying only on the phone.
--
-- Before this migration:
-- * Only the phone's own report (report_broadcast_ingest 'interrupted') marked
--   a session interrupted. That report needs the network that was just lost.
-- * sweep_stale_live_flags() ended phone sessions interrupted for 120 s, but
--   nothing scheduled it on the hosted project, and it skipped OBS sessions.
--
-- Now:
-- * reconcile-broadcasts (every minute) calls broadcast_observe_feed() for each
--   live broadcast with YouTube's liveStreams status. A lost feed marks the
--   session interrupted once per outage; a returning feed clears that mark
--   unless the phone has reported since (the phone's newer word wins).
-- * broadcast_reconcile_claim() runs the sweep first, so the grace window is
--   enforced on the same schedule without a separate cron job.
-- * The sweep covers every sender mode and adds a backstop: a feed YouTube has
--   not received for 10 minutes ends the broadcast even if the phone still
--   claims to be sending.
begin;

alter table private.broadcast_provider add column if not exists feed_lost_since timestamptz;

create or replace function public.broadcast_observe_feed(p_id uuid, p_token uuid, p_active boolean)
returns void language plpgsql security definer set search_path='' as $$
declare r private.broadcast_provider; s public.broadcast_sessions;
begin
 if p_active is null then raise exception 'Feed state required' using errcode='22023'; end if;
 select * into r from private.broadcast_provider
  where session_id=p_id and operation_token=p_token and claimed_until>now() for update;
 if not found then raise exception 'Reservation required' using errcode='42501'; end if;
 select * into s from public.broadcast_sessions where id=p_id for update;
 if s.state<>'live' then
   update private.broadcast_provider set feed_lost_since=null where session_id=p_id;
   return;
 end if;
 if not p_active then
   if r.feed_lost_since is null then
     update private.broadcast_provider set feed_lost_since=now() where session_id=p_id;
     update public.broadcast_sessions set ingest_state='interrupted',
       interrupted_since=coalesce(interrupted_since,now()) where id=p_id;
   end if;
 elsif r.feed_lost_since is not null then
   update private.broadcast_provider set feed_lost_since=null where session_id=p_id;
   -- Clear only the interruption the provider raised: a phone report made
   -- after the loss began describes the sender more recently than YouTube.
   update public.broadcast_sessions set ingest_state='sending',interrupted_since=null
    where id=p_id and ingest_state='interrupted'
      and (ingest_observed_at is null or ingest_observed_at<r.feed_lost_since);
 end if;
end; $$;
revoke all on function public.broadcast_observe_feed(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.broadcast_observe_feed(uuid,uuid,boolean) to service_role;
comment on function public.broadcast_observe_feed(uuid,uuid,boolean) is
 'Scheduled reconciliation only (reserved token). Records whether YouTube is receiving the live feed; sweep_stale_live_flags() ends broadcasts whose feed has not returned within the grace window.';

create or replace function public.sweep_stale_live_flags()
returns integer language plpgsql security definer set search_path='' as $$
declare affected integer;
begin
 -- Grace window: 2 minutes from the first sign of the outage (phone report or
 -- YouTube feed loss). Backstop: 10 minutes of no feed at YouTube.
 update public.broadcast_sessions s set state='ending',termination_pending=true,end_reason='ingest_lost',revision=revision+1
 where s.state='live' and (
   (s.ingest_state='interrupted' and s.interrupted_since<now()-interval '120 seconds')
   or exists(select 1 from private.broadcast_provider r
     where r.session_id=s.id and r.feed_lost_since<now()-interval '10 minutes'));
 get diagnostics affected=row_count;
 return affected;
end; $$;

create or replace function public.broadcast_reconcile_claim() returns setof jsonb
language plpgsql security definer set search_path='' as $$
declare claimed_session public.broadcast_sessions; token uuid; template record;
begin
 -- Broadcasts whose feed did not return within the grace window end here, so
 -- the claim below completes them on YouTube in the same pass.
 perform public.sweep_stale_live_flags();
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
