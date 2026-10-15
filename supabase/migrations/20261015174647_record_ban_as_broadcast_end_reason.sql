-- A ban ended the banned broadcaster's session with end_reason 'ended'.
-- 20261001111022 rewrote sync_broadcast_session() to take the reason only from
-- app.broadcast_end_reason, which admin_update_account('ban') never sets, so
-- the 'ban' reason the earlier trigger derived (20260926020000) was lost and
-- the broadcasting device could not explain the end (AppProvider handles
-- 'ban' separately). Derive it again when no explicit reason was set; the rest
-- of the function is unchanged.
begin;

create or replace function public.sync_broadcast_session() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if coalesce(current_setting('app.session_summary',true),'')='1' then return new; end if;
 if new.is_currently_live and (tg_op='INSERT' or not old.is_currently_live or new.active_stream_id is distinct from old.active_stream_id)
   and not exists(select 1 from public.broadcast_sessions where owner_id=new.id and state='live' and stream_id=new.active_stream_id) then
   raise exception 'Provider-confirmed session required' using errcode='42501'; end if;
 if tg_op='UPDATE' and old.is_currently_live and not new.is_currently_live then
   update public.broadcast_sessions set state='ending',termination_pending=true,
     end_reason=coalesce(nullif(current_setting('app.broadcast_end_reason',true),''),
       case when public.is_banned(new.id) then 'ban' else 'ended' end),revision=revision+1
     where owner_id=new.id and state in ('preparing','live');
 end if;
 return new;
end; $$;

commit;
