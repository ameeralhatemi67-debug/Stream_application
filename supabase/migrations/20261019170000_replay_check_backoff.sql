-- Replay checks back off and end (hosted, 2026-10-19).
--
-- After a live, reconcile asked YouTube about the replay every minute until
-- videos.list said 'processed'. YouTube shows the recording at once but says
-- 'processed' only about 12 h later, and a recording it did not keep never
-- says it: four hosted sessions were re-checked every minute (~11,000
-- YouTube units a day, above the default 10,000), which would stop every
-- go-live once the quota ran out.
--
-- 1. Sessions past the live are claimed every 5 minutes in their first hour,
--    every 15 minutes up to a day, then hourly (live work keeps 30 seconds).
--    A failed check waits the same way.
-- 2. broadcast-control gives up 48 h after the end (replay missing). A replay
--    still unsettled after 72 h (YouTube unreachable for that channel) is
--    settled here as missing, without YouTube.
-- 3. Retiring the feed of a completed or cancelled session stops after 7 days.
begin;

-- 20261019155816's claim with the post-live backoff and caps above.
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
     and coalesce(b.ended_at,b.expected_end_at,now())>now()-interval '7 days'))
   and (r.claimed_until is null or r.claimed_until<now())
   -- After the live only the feed and the replay are left: each check costs
   -- YouTube quota, and a processed replay takes hours.
   and (r.checked_at is null or r.checked_at<now()-case
     when b.state in ('preparing','live','ending') then interval '30 seconds'
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
