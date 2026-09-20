-- P1c (RPC ban audit): public.is_banned(uuid) is called by every broadcast RPC
-- in 20260920120000_guarded_broadcast_sessions.sql (can_broadcast,
-- claim_broadcaster_device, device_heartbeat, set_live_state) but was never
-- defined: 20260830170000_banned_users.sql only defines the no-argument
-- is_current_user_banned(). can_broadcast is a SQL-language function, so its
-- body is parsed when it is created -- the guarded-sessions migration would
-- therefore fail to apply at all. This file is timestamped before it so a
-- fresh database and a database still at 20260831100000 both get the helper
-- first; no existing migration is edited.
--
-- Same semantics as is_current_user_banned(): a row in banned_users means
-- banned, expires_at null = permanent, a past expires_at = expired ban.
begin;

create or replace function public.is_banned(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_profile_id is not null and exists (
    select 1 from public.banned_users
    where profile_id = p_profile_id
      and (expires_at is null or expires_at > now())
  );
$$;

comment on function public.is_banned(uuid) is
  'True while the given profile has an active platform ban. SECURITY DEFINER so it can read banned_users regardless of the caller; EXECUTE is granted to no client role -- it is called only from other SECURITY DEFINER functions, which run with the definer''s privileges. Clients check themselves with is_current_user_banned().';

-- Not exposed to clients: a per-uuid ban probe would let any signed-in user
-- enumerate who is banned. The RPCs that need it are SECURITY DEFINER and so
-- execute it as the owner (D-21: revoke from public/anon, grant back only
-- what the access matrix needs -- here, nothing).
revoke execute on function public.is_banned(uuid) from public, anon, authenticated;

commit;
