-- P6: every change to the chat keyword blocklist leaves a server-written audit
-- record in the same transaction. The admin keyword manager writes the table
-- directly under its admin-tier RLS policies; this trigger is what makes those
-- writes accountable, and a failed audit insert rolls the keyword change back.
begin;

-- Keep the current predicate and admit exactly three server-only events.
do $$
declare v_constraint text;
begin
 select pg_get_constraintdef(oid) into v_constraint from pg_constraint
   where conrelid='public.audit_logs'::regclass and conname='audit_logs_action_check';
 execute 'alter table public.audit_logs drop constraint audit_logs_action_check';
 execute 'alter table public.audit_logs add constraint audit_logs_action_check CHECK (' ||
   substr(v_constraint,8,length(v_constraint)-8) ||
   ' OR action = ANY (ARRAY[''chatKeywordAdded''::text,''chatKeywordUpdated''::text,''chatKeywordRemoved''::text]))';
end;
$$;

create or replace function public.log_audit_event(p_organization_id uuid,p_action text,
 p_description_en text,p_description_ar text,p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
begin
 if p_action in ('accountDeleted','accountSessionsRevoked','streamForceEnded','streamRemovedFromFeed',
   'appFlagChanged','chatKeywordAdded','chatKeywordUpdated','chatKeywordRemoved') then
   raise exception 'Server-only audit action' using errcode='42501';
 end if;
 return public.log_audit_event_internal(p_organization_id,p_action,p_description_en,p_description_ar,p_metadata);
end;
$$;
revoke all on function public.log_audit_event(uuid,text,text,text,jsonb) from public,anon;
grant execute on function public.log_audit_event(uuid,text,text,text,jsonb) to authenticated;

-- An API write always carries auth.uid(): anon has neither a grant nor a
-- policy on this table. A write without one therefore comes from a privileged
-- database role (migration, service role, SQL maintenance); it is recorded as
-- a system action instead of being refused, so the trail has no gap.
create function public.audit_chat_keyword_change() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_action text; v_en text; v_ar text; v_meta jsonb;
begin
 if TG_OP='INSERT' then
   v_action:='chatKeywordAdded';
   v_en:='Added a chat blocklist keyword.';
   v_ar:='تمت إضافة كلمة إلى قائمة الدردشة المحظورة.';
   v_meta:=jsonb_build_object('keyword_id',new.id,'keyword',new.keyword,'match_mode',new.match_mode);
 elsif TG_OP='UPDATE' then
   v_action:='chatKeywordUpdated';
   v_en:='Changed a chat blocklist keyword.';
   v_ar:='تم تعديل كلمة في قائمة الدردشة المحظورة.';
   v_meta:=jsonb_build_object('keyword_id',new.id,'previous_keyword',old.keyword,'keyword',new.keyword,
     'previous_match_mode',old.match_mode,'match_mode',new.match_mode);
 else
   v_action:='chatKeywordRemoved';
   v_en:='Removed a chat blocklist keyword.';
   v_ar:='تمت إزالة كلمة من قائمة الدردشة المحظورة.';
   v_meta:=jsonb_build_object('keyword_id',old.id,'keyword',old.keyword,'match_mode',old.match_mode);
 end if;
 if auth.uid() is null then
   insert into public.audit_logs(organization_id,actor_profile_id,actor_email,actor_name,
     action,description_en,description_ar,metadata)
   values(null,null,'system','Server maintenance',v_action,v_en,v_ar,v_meta);
 else
   perform public.log_audit_event_internal(null,v_action,v_en,v_ar,v_meta);
 end if;
 return case when TG_OP='DELETE' then old else new end;
end;
$$;
revoke all on function public.audit_chat_keyword_change() from public,anon,authenticated;
create trigger audit_chat_keyword_change after insert or update or delete on public.chat_banned_keywords
 for each row execute function public.audit_chat_keyword_change();
commit;
