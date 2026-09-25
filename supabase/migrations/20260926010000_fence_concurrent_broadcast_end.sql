-- The session read must happen AFTER the lock shared with start/transfer.
-- Otherwise an End waiting for that lock can clear a replacement broadcast.
begin;
create or replace function public.end_broadcast_session(p_session_id uuid, p_device_id text)
returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid := auth.uid(); v_session public.broadcast_sessions;
begin
  if v_uid is null then raise exception 'Not signed in' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(20260920, 12);
  select * into v_session from public.broadcast_sessions where id = p_session_id;
  if not found or v_session.owner_id <> v_uid then
    raise exception 'Broadcast session not found' using errcode='42501';
  end if;
  if v_session.state <> 'live' then return; end if;
  perform public.set_live_state(false, v_session.broadcast_type, null, p_device_id, null);
end;
$$;
revoke all on function public.end_broadcast_session(uuid,text) from public, anon;
grant execute on function public.end_broadcast_session(uuid,text) to authenticated;
commit;
