-- P6 server safety foundations. Client management and block-cache sync follow.
begin;
create table public.chat_user_blocks (
 blocker_id uuid not null references public.profiles(id) on delete cascade,
 blocked_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(blocker_id,blocked_id), check(blocker_id <> blocked_id)
);
alter table public.chat_user_blocks enable row level security;
revoke all on public.chat_user_blocks from public,anon,authenticated;
grant select,insert,delete on public.chat_user_blocks to authenticated;
create policy chat_blocks_read_own on public.chat_user_blocks for select to authenticated using(blocker_id=auth.uid());
create policy chat_blocks_insert_own on public.chat_user_blocks for insert to authenticated
 with check(blocker_id=auth.uid() and not public.is_current_user_banned());
create policy chat_blocks_delete_own on public.chat_user_blocks for delete to authenticated using(blocker_id=auth.uid());
create policy chat_messages_respect_blocks on public.chat_messages as restrictive for select to authenticated
 using(not exists(select 1 from public.chat_user_blocks b where b.blocker_id=auth.uid() and b.blocked_id=sender_id));

-- Preserve old free-text reports; enforce the client's stable codes for new writes.
alter table public.chat_reports add constraint chat_reports_reason_code
 check(reason in ('spam','harassment','hate_speech','other')) not valid;
create function public.guard_chat_report_identity() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.chat_messages m where m.id=new.message_id
   and m.sender_id=new.reported_sender_id and m.stream_id=new.stream_id) then
   raise exception 'Report does not match message' using errcode='22023';
 end if;
 return new;
end;
$$;
revoke all on function public.guard_chat_report_identity() from public,anon,authenticated;
create trigger guard_chat_report_identity before insert or update on public.chat_reports
 for each row execute function public.guard_chat_report_identity();

create table public.app_flags (
 key text primary key check(key in ('chat_enabled','registrations_open')),
 enabled boolean not null,
 updated_at timestamptz not null default now()
);
insert into public.app_flags(key,enabled) values('chat_enabled',true),('registrations_open',true);
alter table public.app_flags enable row level security;
revoke all on public.app_flags from public,anon,authenticated;
grant select on public.app_flags to anon,authenticated;
create policy app_flags_read on public.app_flags for select to anon,authenticated using(true);

-- Extend the existing vocabulary without dropping any historical action.
do $$
declare v_constraint text;
begin
 select pg_get_constraintdef(oid) into v_constraint from pg_constraint
   where conrelid='public.audit_logs'::regclass and conname='audit_logs_action_check';
 -- Keep the original predicate and admit exactly one additional server event.
 execute 'alter table public.audit_logs drop constraint audit_logs_action_check';
 execute 'alter table public.audit_logs add constraint audit_logs_action_check CHECK (' ||
   substr(v_constraint,8,length(v_constraint)-8) || ' OR action = ''appFlagChanged'')';
end;
$$;
create or replace function public.log_audit_event(p_organization_id uuid,p_action text,
 p_description_en text,p_description_ar text,p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
begin
 if p_action in ('accountDeleted','accountSessionsRevoked','streamForceEnded','streamRemovedFromFeed','appFlagChanged') then
   raise exception 'Server-only audit action' using errcode='42501';
 end if;
 return public.log_audit_event_internal(p_organization_id,p_action,p_description_en,p_description_ar,p_metadata);
end;
$$;
create function public.admin_set_app_flag(p_key text,p_enabled boolean,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare v_old boolean;
begin
 if auth.uid() is null or not public.is_master_admin() or public.is_banned(auth.uid())
   or not exists(select 1 from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id') then
   raise exception 'Not permitted' using errcode='42501';
 end if;
 if p_enabled is null or p_reason is null or length(trim(p_reason)) not between 1 and 500 then
   raise exception 'Invalid flag or reason' using errcode='22023';
 end if;
 select enabled into v_old from public.app_flags where key=p_key for update;
 if not found then raise exception 'Unknown flag' using errcode='22023'; end if;
 update public.app_flags set enabled=p_enabled,updated_at=now() where key=p_key;
 perform public.log_audit_event_internal(null,'appFlagChanged',trim(p_reason),trim(p_reason),
   jsonb_build_object('key',p_key,'previous',v_old,'enabled',p_enabled));
end;
$$;
revoke all on function public.admin_set_app_flag(text,boolean,text) from public,anon;
grant execute on function public.admin_set_app_flag(text,boolean,text) to authenticated;
create function public.enforce_app_flag() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if not coalesce((select enabled from public.app_flags where key=TG_ARGV[0]),false) then
   raise exception 'Feature temporarily disabled' using errcode='42501';
 end if;
 return new;
end;
$$;
revoke all on function public.enforce_app_flag() from public,anon,authenticated;
create trigger enforce_global_chat before insert on public.chat_messages
 for each row execute function public.enforce_app_flag('chat_enabled');
create trigger enforce_registrations before insert on auth.users
 for each row execute function public.enforce_app_flag('registrations_open');
commit;
