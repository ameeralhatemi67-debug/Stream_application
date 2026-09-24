-- P6 retest R09: map visibility and organization revocation become
-- server-authorized, atomic and audited.
--
-- Before this migration the Admin Hub wrote is_temporarily_hidden_from_map
-- straight into profiles/organizations (no audit entry; a failed write was
-- turned into local success by the client), and the registry's "Delete
-- Streamer" button issued several separate table writes -- including deleting
-- the revoked user's organizations -- without any audit record. Personal
-- broadcaster revocation now goes through the existing audited
-- admin_update_account('revoke_streamer'); this migration adds the missing
-- actions. Any direct API write of the map flag is refused, so the only way to
-- change it leaves an actor/action/reason record in the same transaction.
begin;

-- Admit three new server-only audit actions, keeping the current predicate.
do $$
declare v_constraint text;
begin
 select pg_get_constraintdef(oid) into v_constraint from pg_constraint
   where conrelid='public.audit_logs'::regclass and conname='audit_logs_action_check';
 execute 'alter table public.audit_logs drop constraint audit_logs_action_check';
 execute 'alter table public.audit_logs add constraint audit_logs_action_check CHECK (' ||
   substr(v_constraint,8,length(v_constraint)-8) ||
   ' OR action = ANY (ARRAY[''broadcasterHiddenFromMap''::text,''broadcasterShownOnMap''::text,''organizationVerificationRevoked''::text]))';
end;
$$;

create or replace function public.log_audit_event(p_organization_id uuid,p_action text,
 p_description_en text,p_description_ar text,p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
begin
 if p_action in ('accountDeleted','accountSessionsRevoked','streamForceEnded','streamRemovedFromFeed',
   'appFlagChanged','chatKeywordAdded','chatKeywordUpdated','chatKeywordRemoved',
   'broadcasterHiddenFromMap','broadcasterShownOnMap','organizationVerificationRevoked') then
   raise exception 'Server-only audit action' using errcode='42501';
 end if;
 return public.log_audit_event_internal(p_organization_id,p_action,p_description_en,p_description_ar,p_metadata);
end;
$$;
revoke all on function public.log_audit_event(uuid,text,text,text,jsonb) from public,anon;
grant execute on function public.log_audit_event(uuid,text,text,text,jsonb) to authenticated;

-- API roles (including admins and the hidden broadcaster themself) cannot
-- change the flag directly. SECURITY DEFINER functions run as their owner,
-- so admin_moderate_broadcaster below passes.
create function public.guard_map_visibility_change() returns trigger
language plpgsql set search_path='' as $$
begin
 if new.is_temporarily_hidden_from_map is distinct from old.is_temporarily_hidden_from_map
    and current_user in ('authenticated','anon') then
   raise exception 'Map visibility changes require the audited moderation action' using errcode='42501';
 end if;
 return new;
end;
$$;
revoke all on function public.guard_map_visibility_change() from public,anon,authenticated;
create trigger guard_map_visibility before update on public.profiles
 for each row execute function public.guard_map_visibility_change();
create trigger guard_map_visibility before update on public.organizations
 for each row execute function public.guard_map_visibility_change();

create function public.admin_moderate_broadcaster(p_target_id uuid, p_is_organization boolean,
  p_action text, p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare v_hidden boolean; v_stream text; v_action text;
begin
 if auth.uid() is null or not public.is_admin_tier() or public.is_banned(auth.uid()) then
   raise exception 'Not permitted' using errcode='42501';
 end if;
 if p_action is null or p_action not in ('hide_from_map','show_on_map','revoke_organization')
   or p_is_organization is null
   or (p_action='revoke_organization' and not p_is_organization)
   or p_reason is null or length(trim(p_reason)) not between 1 and 500 then
   raise exception 'Invalid moderation action or reason' using errcode='22023';
 end if;
 perform pg_advisory_xact_lock(20260920,12);
 if p_is_organization then
   select is_temporarily_hidden_from_map, active_stream_id into v_hidden, v_stream
     from public.organizations where id=p_target_id for update;
 else
   select is_temporarily_hidden_from_map, active_stream_id into v_hidden, v_stream
     from public.profiles where id=p_target_id and is_streamer for update;
 end if;
 if not found then raise exception 'Broadcaster not found' using errcode='P0002'; end if;
 -- Same protection as the directory actions.
 if not p_is_organization and (p_target_id=auth.uid() or exists(select 1 from public.user_roles
     where profile_id=p_target_id and role='master_admin')
     or (not public.is_master_admin() and exists(select 1 from public.user_roles
       where profile_id=p_target_id and role='admin'))) then
   raise exception 'Protected administrator' using errcode='42501';
 end if;

 if p_action in ('hide_from_map','show_on_map') then
   if v_hidden = (p_action='hide_from_map') then return; end if;
   if p_is_organization then
     update public.organizations set is_temporarily_hidden_from_map=(p_action='hide_from_map') where id=p_target_id;
   else
     update public.profiles set is_temporarily_hidden_from_map=(p_action='hide_from_map') where id=p_target_id;
   end if;
   v_action := case when p_action='hide_from_map' then 'broadcasterHiddenFromMap' else 'broadcasterShownOnMap' end;
 else
   update public.organizations set is_verified=false,is_currently_live=false,broadcast_type='offline',
     active_stream_id=null,active_viewer_count=0 where id=p_target_id;
   if v_stream is not null then
     update public.profiles set is_currently_live=false,broadcast_type='offline',active_stream_id=null,
       active_viewer_count=0 where active_stream_id=v_stream;
   end if;
   v_action := 'organizationVerificationRevoked';
 end if;
 -- Atomic with the change: a failed audit insert rolls the change back.
 perform public.log_audit_event_internal(null,v_action,trim(p_reason),trim(p_reason),
   jsonb_build_object('target_id',p_target_id,'is_organization',p_is_organization,'action',p_action));
end;
$$;
revoke all on function public.admin_moderate_broadcaster(uuid,boolean,text,text) from public,anon;
grant execute on function public.admin_moderate_broadcaster(uuid,boolean,text,text) to authenticated;
comment on function public.admin_moderate_broadcaster(uuid,boolean,text,text) is
 'Admin-only, audited map visibility and organization verification revocation. Personal broadcaster revocation uses admin_update_account(''revoke_streamer''). Unchanged visibility is a no-op without an audit entry.';

commit;
