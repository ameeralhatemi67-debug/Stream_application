-- P6 retest R02: conflict-aware broadcaster device claim.
--
-- The client used to read device_sessions and then call the boolean
-- claim_broadcaster_device() as two separate steps. Two problems came out of
-- the owner's two-phone retest:
--  * a primary device whose heartbeat stopped for 90 s (an Android phone the
--    OS froze in the background, a hidden browser tab) was taken over by the
--    second sign-in without any conflict prompt, and
--  * when the read failed or raced the claim, the boolean result gave the
--    client no information about who held the primary role, so it fell back
--    to "no conflict" and showed nothing.
-- This function answers both in one locked transaction: it either claims the
-- primary role or returns the device that currently holds it, fresh or stale,
-- so the user decides. The server stays the authority; forced transfer is
-- delegated to the existing claim path, which demotes the other device and
-- clears its live state. The older function is kept for installed clients.
begin;

create function public.claim_broadcaster_device_state(p_device_id text, p_name text,
  p_platform text, p_force boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_other public.device_sessions;
begin
  if v_uid is null or public.is_banned(v_uid) then
    raise exception 'Broadcast not permitted' using errcode = '42501';
  end if;
  if p_device_id is null or length(p_device_id) not between 1 and 128 then
    raise exception 'Invalid device';
  end if;
  if not (public.can_broadcast(null,'liveVideo') or exists(select 1 from public.organizations o
    where public.can_broadcast(o.id,'liveVideo') or public.can_broadcast(o.id,'liveAudio'))) then
    raise exception 'Broadcast not permitted' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(20260920, 12);
  select * into v_other from public.device_sessions
    where user_id = v_uid and device_id <> p_device_id and is_primary_broadcaster
    order by last_active_at desc limit 1;
  if found and not coalesce(p_force, false) then
    return jsonb_build_object('claimed', false, 'primary', jsonb_build_object(
      'device_id', v_other.device_id,
      'device_name', v_other.device_name,
      'platform', v_other.platform,
      'last_active_at', v_other.last_active_at,
      'stale', v_other.last_active_at <= now() - interval '90 seconds'));
  end if;
  return jsonb_build_object('claimed',
    public.claim_broadcaster_device(p_device_id, p_name, p_platform, true), 'primary', null);
end;
$$;
revoke execute on function public.claim_broadcaster_device_state(text,text,text,boolean) from public, anon;
grant execute on function public.claim_broadcaster_device_state(text,text,text,boolean) to authenticated;
comment on function public.claim_broadcaster_device_state(text,text,text,boolean) is
  'Claims the caller''s primary broadcaster device, or returns the other primary device (with a stale flag) without changing anything unless p_force is true. Forced claims reuse claim_broadcaster_device, which clears the displaced device''s live state.';

commit;
