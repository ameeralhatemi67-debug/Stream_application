-- YouTube returns rtmps://a.rtmps.youtube.com/live2 as its secure ingestion address.
-- The previous check accepted only *.rtmp.youtube.com, so every real feed was refused
-- after YouTube had already created it.
create or replace function public.broadcast_provider_step(p_id uuid,p_token uuid,p_step text,p_result jsonb default null,
 p_error text default null,p_ambiguous boolean default false) returns void
language plpgsql security definer set search_path='' as $$
declare r private.broadcast_provider; s public.broadcast_sessions; secret uuid;
begin
 select * into r from private.broadcast_provider where session_id=p_id for update;
 if not found or r.operation_token is distinct from p_token then raise exception 'Reservation changed' using errcode='40001'; end if;
 select * into s from public.broadcast_sessions where id=p_id for update;
 if p_step not in ('stream_create','broadcast_create','bind','transition_live','transition_complete','feed_delete','observe','reconcile','finish') then
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


-- Completed/cancelled sessions are only retried while a YouTube feed may still exist.
-- Shows that never created a feed were re-claimed every minute indefinitely.
create or replace function public.broadcast_reconcile_claim() returns setof jsonb
language plpgsql security definer set search_path='' as $$
declare claimed_session public.broadcast_sessions; token uuid; template record;
begin
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
