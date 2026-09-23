begin;
select no_plan();
insert into auth.users(id,email) values
 ('67000000-0000-4000-8000-000000000001','kw-admin@example.invalid'),
 ('67000000-0000-4000-8000-000000000002','kw-viewer@example.invalid');
insert into public.profiles(id,email) values
 ('67000000-0000-4000-8000-000000000001','kw-admin@example.invalid'),
 ('67000000-0000-4000-8000-000000000002','kw-viewer@example.invalid');
insert into public.user_roles(profile_id,role) values('67000000-0000-4000-8000-000000000001','admin');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select throws_ok($$insert into public.chat_banned_keywords(keyword) values('kwaudittest')$$,'42501',null,'viewer cannot add keywords');
select is((select count(*)::int from public.chat_banned_keywords),0,'viewer cannot read the blocklist');
select is((select count(*)::int from public.audit_logs),0,'viewer cannot read audit logs');
select throws_ok($$select public.log_audit_event(null,'chatKeywordAdded','fake','fake','{}')$$,'42501',null,'keyword audit cannot be forged');
select set_config('request.jwt.claims','{"sub":"67000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select lives_ok($$insert into public.chat_banned_keywords(id,keyword) values('67000000-0000-4000-8000-000000000031','kwaudittest')$$,'admin adds keyword');
select is((select count(*)::int from public.audit_logs where action='chatKeywordAdded'
  and actor_profile_id='67000000-0000-4000-8000-000000000001'
  and metadata->>'keyword'='kwaudittest'),1,'add audited with actor and keyword');
select lives_ok($$update public.chat_banned_keywords set match_mode='substring' where id='67000000-0000-4000-8000-000000000031'$$,'admin changes match mode');
select is((select metadata->>'previous_match_mode' from public.audit_logs where action='chatKeywordUpdated'),'word','update audit keeps previous mode');
select lives_ok($$delete from public.chat_banned_keywords where id='67000000-0000-4000-8000-000000000031'$$,'admin removes keyword');
select is((select count(*)::int from public.audit_logs where action='chatKeywordRemoved' and metadata->>'keyword'='kwaudittest'),1,'removal audited');
select ok(exists(select 1 from public.audit_logs where action='chatKeywordAdded'),'admin reads keyword audit');
reset role;
create function pg_temp.reject_kw_audit() returns trigger language plpgsql as $$begin raise exception 'audit unavailable'; end;$$;
create trigger test_kw_audit_failure before insert on public.audit_logs for each row execute function pg_temp.reject_kw_audit();
set local role authenticated;
select throws_ok($$insert into public.chat_banned_keywords(keyword) values('kwrollback')$$,'P0001','audit unavailable','audit failure rejects keyword add');
reset role;
drop trigger test_kw_audit_failure on public.audit_logs;
select is((select count(*)::int from public.chat_banned_keywords where keyword='kwrollback'),0,'keyword not stored without audit');
select set_config('request.jwt.claims','',true);
select lives_ok($$insert into public.chat_banned_keywords(keyword) values('kwmaintenance')$$,'privileged maintenance write allowed');
select is((select actor_email from public.audit_logs where action='chatKeywordAdded' and metadata->>'keyword'='kwmaintenance'),'system','maintenance write audited as system');
select * from finish();
rollback;
