begin;
select plan(33);
insert into auth.users(id,email) values
 ('64000000-0000-4000-8000-000000000001','directory-admin@example.invalid'),
 ('64000000-0000-4000-8000-000000000002','directory-viewer@example.invalid'),
 ('64000000-0000-4000-8000-000000000003','directory-master@example.invalid'),
 ('64000000-0000-4000-8000-000000000004','directory-owner@example.invalid');
insert into public.profiles(id,email,display_name_en,is_streamer,is_verified) values
 ('64000000-0000-4000-8000-000000000001','directory-admin@example.invalid','Admin',false,false),
 ('64000000-0000-4000-8000-000000000002','directory-viewer@example.invalid','Search%Literal',true,true),
 ('64000000-0000-4000-8000-000000000003','directory-master@example.invalid','Master',false,false),
 ('64000000-0000-4000-8000-000000000004','directory-owner@example.invalid','Owner',false,false);
insert into public.user_roles(profile_id,role) values
 ('64000000-0000-4000-8000-000000000001','admin'),
 ('64000000-0000-4000-8000-000000000003','master_admin');
insert into public.device_sessions(user_id,device_id) values('64000000-0000-4000-8000-000000000002','test-device');
set local role anon;
select throws_ok($$select public.admin_user_directory('',0)$$,'42501',null,'anon denied directory');
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"64000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.admin_user_directory('',0)$$,'42501',null,'viewer denied directory');
select throws_ok($$select public.admin_user_detail('64000000-0000-4000-8000-000000000001')$$,'42501',null,'viewer denied details');
select throws_ok($$select public.admin_update_account('64000000-0000-4000-8000-000000000001','ban','test')$$,'42501',null,'viewer denied mutation');
select is((select count(*)::int from public.device_sessions),1,'viewer sees own device');
select set_config('request.jwt.claims','{"sub":"64000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select throws_ok($$select public.admin_user_directory('',0)$$,'42501',null,'ordinary account denied directory');
select is((select count(*)::int from public.device_sessions),0,'ordinary account sees no other device');
select set_config('request.jwt.claims','{"sub":"64000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is(jsonb_array_length(public.admin_user_directory('%',0)),1,'percent is literal');
select is((select count(*)::int from public.device_sessions where user_id='64000000-0000-4000-8000-000000000002'),1,'admin reads another device');
select is(jsonb_array_length(public.admin_user_detail('64000000-0000-4000-8000-000000000002')->'devices'),1,'detail includes devices');
select throws_ok($$select public.admin_update_account('64000000-0000-4000-8000-000000000001','ban','test')$$,'42501',null,'self protected');
select throws_ok($$select public.admin_update_account('64000000-0000-4000-8000-000000000003','ban','test')$$,'42501',null,'master admin protected');
select throws_ok($$select public.admin_update_account('64000000-0000-4000-8000-000000000002','ban','')$$,'22023',null,'reason required');
select lives_ok($$select public.admin_update_account('64000000-0000-4000-8000-000000000002','ban','test')$$,'admin can ban');
select ok(exists(select 1 from public.banned_users where profile_id='64000000-0000-4000-8000-000000000002'),'ban effective');
select is((select count(*)::int from public.audit_logs where action='accountBanned' and metadata->>'target_profile_id'='64000000-0000-4000-8000-000000000002'),1,'audit written');
select lives_ok($$select public.admin_update_account('64000000-0000-4000-8000-000000000002','unban','test')$$,'admin can unban');
select ok(not exists(select 1 from public.banned_users where profile_id='64000000-0000-4000-8000-000000000002'),'unban effective');
select lives_ok($$select public.admin_update_account('64000000-0000-4000-8000-000000000002','revoke_verified','test revoke')$$,'admin revokes verification');
select ok(not (public.admin_user_detail('64000000-0000-4000-8000-000000000002')->>'is_verified')::boolean,'verification removed');
select lives_ok($$select public.admin_update_account('64000000-0000-4000-8000-000000000002','revoke_streamer','test revoke')$$,'admin revokes personal streaming');
select ok(not (public.admin_user_detail('64000000-0000-4000-8000-000000000002')->>'is_streamer')::boolean,'streamer removed');
select is((select count(*)::int from public.audit_logs where action in
  ('accountUnbanned','accountVerificationRevoked','accountStreamerRevoked')
  and metadata->>'target_profile_id'='64000000-0000-4000-8000-000000000002'),3,'all later actions audited');
select throws_ok($$select public.admin_update_account('64000000-0000-4000-8000-000000000002','delete','test')$$,'22023',null,'unsupported delete rejected');
select throws_ok($$select public.admin_user_directory('',-1)$$,'22023',null,'negative offset rejected');
reset role;
insert into public.device_sessions(user_id,device_id) values('64000000-0000-4000-8000-000000000001','admin-device');
insert into public.banned_users(profile_id,email,reason) values('64000000-0000-4000-8000-000000000001','directory-admin@example.invalid','test banned admin');
set local role authenticated;
select throws_ok($$select public.admin_user_directory('',0)$$,'42501',null,'banned admin denied directory');
select throws_ok($$select public.admin_user_detail('64000000-0000-4000-8000-000000000002')$$,'42501',null,'banned admin denied detail');
select throws_ok($$select public.admin_update_account('64000000-0000-4000-8000-000000000002','ban','test')$$,'42501',null,'banned admin denied mutation');
select is((select count(*)::int from public.device_sessions where user_id='64000000-0000-4000-8000-000000000002'),0,'banned admin denied other devices');
select is((select count(*)::int from public.device_sessions where user_id=auth.uid()),0,'banned admin denied own devices');
select set_config('request.jwt.claims','{"sub":"64000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select lives_ok($$select public.admin_user_directory('',0)$$,'master admin can read directory');
select throws_ok($$select public.admin_update_account('64000000-0000-4000-8000-000000000003','ban','test')$$,'42501',null,'master admin self protected');
select is((select count(*)::int from public.device_sessions where user_id='64000000-0000-4000-8000-000000000002'),1,'master admin reads another device');
select * from finish();
rollback;
