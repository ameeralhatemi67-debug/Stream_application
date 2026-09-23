-- P6 review follow-up. Supabase's default grants gave anon and authenticated
-- TRUNCATE, TRIGGER and REFERENCES on every public table; 20260921110000 only
-- narrowed SELECT/INSERT/UPDATE/DELETE. None of the three is subject to RLS,
-- and TRUNCATE fires no row trigger, so it would bypass both the admin-only
-- policies and the keyword audit trail (20260923130000) as well as empty
-- audit_logs itself. PostgREST and pg_graphql expose no TRUNCATE or DDL, so
-- no API path is known; this closes the gap rather than relying on that.
begin;

revoke truncate, trigger, references on all tables in schema public from anon, authenticated;
-- Tables created by later migrations (run as postgres) must not regain them.
alter default privileges for role postgres in schema public
  revoke truncate, trigger, references on tables from anon, authenticated;

-- A privileged role can still truncate the blocklist; leave one record of it.
create function public.audit_chat_keyword_truncate() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into public.audit_logs(organization_id,actor_profile_id,actor_email,actor_name,
   action,description_en,description_ar,metadata)
 values(null,null,'system','Server maintenance','chatKeywordRemoved',
   'Removed every chat blocklist keyword.','تمت إزالة جميع كلمات قائمة الدردشة المحظورة.',
   jsonb_build_object('truncate',true,'db_role',session_user));
 return null;
end;
$$;
revoke all on function public.audit_chat_keyword_truncate() from public,anon,authenticated;
create trigger audit_chat_keyword_truncate after truncate on public.chat_banned_keywords
 for each statement execute function public.audit_chat_keyword_truncate();
commit;
