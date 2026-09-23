begin;
select no_plan();
insert into auth.users(id,email) values
 ('66000000-0000-4000-8000-000000000001','flag-master@example.invalid'),
 ('66000000-0000-4000-8000-000000000002','flag-viewer@example.invalid'),
 ('66000000-0000-4000-8000-000000000003','flag-sender@example.invalid');
insert into public.profiles(id,email) values
 ('66000000-0000-4000-8000-000000000001','flag-master@example.invalid'),
 ('66000000-0000-4000-8000-000000000002','flag-viewer@example.invalid'),
 ('66000000-0000-4000-8000-000000000003','flag-sender@example.invalid');
insert into public.user_roles(profile_id,role) values('66000000-0000-4000-8000-000000000001','master_admin');
insert into auth.sessions(id,user_id) values('66000000-0000-4000-8000-000000000011','66000000-0000-4000-8000-000000000001');
insert into public.chat_messages(id,stream_id,sender_id,body) values
 ('66000000-0000-4000-8000-000000000021','chatstream1','66000000-0000-4000-8000-000000000003','Salaam');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.admin_set_app_flag('chat_enabled',false,'test')$$,'42501',null,'viewer cannot toggle app flags');
select throws_ok($$update public.app_flags set enabled=false$$,'42501',null,'direct flag writes denied');
select throws_ok($$select * from public.removed_live_streams$$,'42501',null,'removed-stream registry not readable');
select throws_ok($$insert into public.chat_user_blocks(blocker_id,blocked_id) values('66000000-0000-4000-8000-000000000001','66000000-0000-4000-8000-000000000003')$$,'42501',null,'cannot create another viewer block');
select lives_ok($$insert into public.chat_user_blocks(blocker_id,blocked_id) values(auth.uid(),'66000000-0000-4000-8000-000000000003')$$,'viewer owns block');
select is((select count(*)::int from public.chat_messages where id='66000000-0000-4000-8000-000000000021'),0,'server hides blocked messages');
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select is((select count(*)::int from public.chat_user_blocks),0,'other viewers cannot enumerate blocks');
select is((select count(*)::int from public.chat_messages where id='66000000-0000-4000-8000-000000000021'),1,'block is viewer scoped');
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select lives_ok($$delete from public.chat_user_blocks where blocker_id=auth.uid()$$,'viewer can unblock');
select is((select count(*)::int from public.chat_messages where id='66000000-0000-4000-8000-000000000021'),1,'unblock restores access');
select throws_ok($$insert into public.chat_reports(message_id,stream_id,reported_sender_id,reporter_id,reason) values('66000000-0000-4000-8000-000000000021','chatstream1','66000000-0000-4000-8000-000000000003',auth.uid(),'invented')$$,'23514',null,'unknown reason rejected');
select throws_ok($$insert into public.chat_reports(message_id,stream_id,reported_sender_id,reporter_id,reason) values('66000000-0000-4000-8000-000000000021','wrongstream','66000000-0000-4000-8000-000000000003',auth.uid(),'spam')$$,'22023',null,'forged stream rejected');
select lives_ok($$insert into public.chat_reports(message_id,stream_id,reported_sender_id,reporter_id,reason) values('66000000-0000-4000-8000-000000000021','chatstream1','66000000-0000-4000-8000-000000000003',auth.uid(),'spam')$$,'valid report accepted');
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","session_id":"66000000-0000-4000-8000-000000000011","role":"authenticated"}',true);
select throws_ok($$select public.admin_set_app_flag('unknown',false,'test')$$,'22023',null,'unknown flag rejected');
select throws_ok($$select public.admin_set_app_flag('chat_enabled',false,' ')$$,'22023',null,'flag change requires reason');
select lives_ok($$select public.admin_set_app_flag('chat_enabled',false,'test')$$,'master disables global chat');
reset role;
select throws_ok($$insert into public.chat_messages(stream_id,sender_id,body) values('chatstream1','66000000-0000-4000-8000-000000000003','Salaam')$$,'42501','Feature temporarily disabled','global chat switch blocks even trusted inserts');
set local role authenticated;
select lives_ok($$select public.admin_set_app_flag('registrations_open',false,'test')$$,'master disables registration');
reset role;
select throws_ok($$insert into auth.users(id,email) values('66000000-0000-4000-8000-000000000099','new@example.invalid')$$,'42501','Feature temporarily disabled','Auth registration blocked at database');
create function pg_temp.reject_flag_audit() returns trigger language plpgsql as $$begin raise exception 'audit unavailable'; end;$$;
create trigger test_audit_failure before insert on public.audit_logs for each row execute function pg_temp.reject_flag_audit();
set local role authenticated;
select throws_ok($$select public.admin_set_app_flag('chat_enabled',true,'test')$$,'P0001','audit unavailable','audit failure rolls flag change back');
select ok(not (select enabled from public.app_flags where key='chat_enabled'),'flag unchanged after audit failure');
reset role;
drop trigger test_audit_failure on public.audit_logs;
set local role authenticated;
select lives_ok($$select public.admin_set_app_flag('registrations_open',true,'test')$$,'master reopens registration');
select lives_ok($$select public.admin_set_app_flag('chat_enabled',true,'test')$$,'master reopens chat');
select throws_ok($$select public.log_audit_event(null,'appFlagChanged','fake','fake','{}')$$,'42501',null,'flag audit cannot be forged');
reset role;
select lives_ok($$insert into auth.users(id,email) values('66000000-0000-4000-8000-000000000099','new@example.invalid')$$,'registration restored');
select is((select count(*)::int from public.audit_logs where action='appFlagChanged' and actor_profile_id='66000000-0000-4000-8000-000000000001'),4,'successful toggles audited');
select * from finish();
rollback;
