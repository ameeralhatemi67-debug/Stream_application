begin;
select no_plan();
insert into auth.users(id,email) values
 ('65000000-0000-4000-8000-000000000001','a@example.invalid'),
 ('65000000-0000-4000-8000-000000000002','u@example.invalid'),
 ('65000000-0000-4000-8000-000000000003','m@example.invalid');
insert into public.profiles(id,email,is_streamer,is_verified) values
 ('65000000-0000-4000-8000-000000000001','a@example.invalid',false,false),
 ('65000000-0000-4000-8000-000000000002','u@example.invalid',true,true),
 ('65000000-0000-4000-8000-000000000003','m@example.invalid',false,false);
insert into public.user_roles(profile_id,role) values
 ('65000000-0000-4000-8000-000000000001','admin'),('65000000-0000-4000-8000-000000000003','master_admin');
insert into auth.sessions(id,user_id) values
 ('65000000-0000-4000-8000-000000000011','65000000-0000-4000-8000-000000000001'),
 ('65000000-0000-4000-8000-000000000012','65000000-0000-4000-8000-000000000002');
insert into auth.refresh_tokens(token,user_id,session_id) values
 ('p6-test-refresh','65000000-0000-4000-8000-000000000002','65000000-0000-4000-8000-000000000012');
set local role anon;
select throws_ok($$select public.admin_auth_account_action('65000000-0000-4000-8000-000000000002','delete_account','test')$$,'42501',null,'anon denied');
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"65000000-0000-4000-8000-000000000002","session_id":"65000000-0000-4000-8000-000000000012","role":"authenticated"}',true);
select throws_ok($$select public.admin_auth_account_action('65000000-0000-4000-8000-000000000001','delete_account','test')$$,'42501',null,'viewer denied');
select set_config('request.jwt.claims','{"sub":"65000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.admin_auth_account_action('65000000-0000-4000-8000-000000000002','delete_account','test')$$,'42501',null,'missing or revoked caller session denied');
select set_config('request.jwt.claims','{"sub":"65000000-0000-4000-8000-000000000001","session_id":"65000000-0000-4000-8000-000000000011","role":"authenticated"}',true);
select throws_ok($$select public.admin_auth_account_action('65000000-0000-4000-8000-000000000001','delete_account','test')$$,'42501',null,'self protected');
select throws_ok($$select public.admin_auth_account_action('65000000-0000-4000-8000-000000000003','revoke_sessions','test')$$,'42501',null,'master protected');
select throws_ok($$select public.admin_auth_account_action('65000000-0000-4000-8000-000000000002','delete_account',' ')$$,'22023',null,'reason required');
select throws_ok($$select public.log_audit_event(null,'accountDeleted','fake','fake','{}')$$,'42501',null,'cannot forge action audit');
select throws_ok($$select public.log_audit_event_internal(null,'accountDeleted','fake','fake','{}')$$,'42501',null,'internal logger inaccessible');
select lives_ok($$select public.admin_auth_account_action('65000000-0000-4000-8000-000000000002','revoke_sessions','test')$$,'admin revokes Auth sessions');
reset role;
select is((select count(*)::int from auth.sessions where user_id='65000000-0000-4000-8000-000000000002'),0,'all sessions removed');
select is((select count(*)::int from auth.refresh_tokens where user_id='65000000-0000-4000-8000-000000000002'),0,'refresh tokens removed');
select is((select count(*)::int from auth.users where id='65000000-0000-4000-8000-000000000002'),1,'revocation preserves account');
update public.profiles set is_currently_live=true,broadcast_type='liveVideo',active_stream_id='abcdefghijk' where id='65000000-0000-4000-8000-000000000002';
insert into public.device_sessions(user_id,device_id,is_primary_broadcaster) values('65000000-0000-4000-8000-000000000002','test',true);
set local role authenticated;
select lives_ok($$select public.admin_auth_account_action('65000000-0000-4000-8000-000000000002','force_end','test')$$,'force end succeeds');
reset role;
select ok(not (select is_currently_live from public.profiles where id='65000000-0000-4000-8000-000000000002'),'live state cleared');
select ok(not (select is_primary_broadcaster from public.device_sessions where user_id='65000000-0000-4000-8000-000000000002'),'primary device released');
update public.profiles set is_currently_live=true,broadcast_type='liveVideo',active_stream_id='abcdefghijk' where id='65000000-0000-4000-8000-000000000002';
set local role authenticated;
select lives_ok($$select public.admin_auth_account_action('65000000-0000-4000-8000-000000000002','remove_from_feed','test')$$,'feed removal succeeds');
reset role;
select throws_ok($$update public.profiles set is_currently_live=true,active_stream_id='abcdefghijk' where id='65000000-0000-4000-8000-000000000002'$$,'42501',null,'even direct update cannot republish removed video');
insert into public.organizations(id,name_en,name_ar,owner_profile_id) values('65000000-0000-4000-8000-000000000020','Org','Org','65000000-0000-4000-8000-000000000002');
set local role authenticated;
select throws_ok($$select public.admin_auth_account_action('65000000-0000-4000-8000-000000000002','delete_account','test')$$,'23503',null,'org ownership must be transferred');
reset role;
delete from public.organizations where id='65000000-0000-4000-8000-000000000020';
-- Deliberately break audit insertion to prove the entire deletion rolls back.
create function pg_temp.reject_audit() returns trigger language plpgsql as $$begin raise exception 'audit unavailable'; end;$$;
create trigger test_audit_failure before insert on public.audit_logs for each row execute function pg_temp.reject_audit();
set local role authenticated;
select throws_ok($$select public.admin_auth_account_action('65000000-0000-4000-8000-000000000002','delete_account','test')$$,'P0001','audit unavailable','audit failure rejects deletion');
reset role;
select is((select count(*)::int from auth.users where id='65000000-0000-4000-8000-000000000002'),1,'account survives audit failure');
drop trigger test_audit_failure on public.audit_logs;
insert into public.banned_users(profile_id,email,reason) values('65000000-0000-4000-8000-000000000001','a@example.invalid','test');
set local role authenticated;
select throws_ok($$select public.admin_auth_account_action('65000000-0000-4000-8000-000000000002','delete_account','test')$$,'42501',null,'banned admin denied');
reset role;
delete from public.banned_users where profile_id='65000000-0000-4000-8000-000000000001';
set local role authenticated;
select lives_ok($$select public.admin_auth_account_action('65000000-0000-4000-8000-000000000002','delete_account','test')$$,'admin deletes account');
reset role;
select is((select count(*)::int from auth.users where id='65000000-0000-4000-8000-000000000002'),0,'Auth account deleted');
select is((select count(*)::int from public.profiles where id='65000000-0000-4000-8000-000000000002'),0,'profile cascade deleted');
select is((select count(*)::int from public.audit_logs where action in ('accountDeleted','accountSessionsRevoked','streamForceEnded','streamRemovedFromFeed') and metadata->>'target_profile_id'='65000000-0000-4000-8000-000000000002'),4,'all four actions leave surviving audits');
select * from finish();
rollback;
