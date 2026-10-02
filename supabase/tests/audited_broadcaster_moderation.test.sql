-- Local-only pgTAP for 20260924110000_audited_broadcaster_moderation.sql.
begin;
select plan(26);
insert into auth.users(id,email) values
 ('66000000-0000-4000-8000-000000000001','admin@moderation.invalid'),
 ('66000000-0000-4000-8000-000000000002','caster@moderation.invalid'),
 ('66000000-0000-4000-8000-000000000003','master@moderation.invalid'),
 ('66000000-0000-4000-8000-000000000004','viewer@moderation.invalid'),
 ('66000000-0000-4000-8000-000000000005','owner@moderation.invalid');
insert into public.profiles(id,email,is_streamer,is_verified) values
 ('66000000-0000-4000-8000-000000000001','admin@moderation.invalid',false,false),
 ('66000000-0000-4000-8000-000000000002','caster@moderation.invalid',true,true),
 ('66000000-0000-4000-8000-000000000003','master@moderation.invalid',true,true),
 ('66000000-0000-4000-8000-000000000004','viewer@moderation.invalid',false,false),
 ('66000000-0000-4000-8000-000000000005','owner@moderation.invalid',true,true);
insert into public.user_roles(profile_id,role) values
 ('66000000-0000-4000-8000-000000000001','admin'),('66000000-0000-4000-8000-000000000003','master_admin');
insert into public.organizations(id,owner_profile_id,name_en,name_ar,is_verified) values
 ('67000000-0000-4000-8000-000000000001','66000000-0000-4000-8000-000000000005','Org','Org',true),
 ('67000000-0000-4000-8000-000000000002','66000000-0000-4000-8000-000000000002','Caster Org','Caster Org',true);
insert into public.broadcaster_applications(applicant_profile_id,account_type,applicant_name_en,applicant_name_ar,
 email,phone,category_id,status,latitude,longitude)
 values('66000000-0000-4000-8000-000000000002','individualScholar','Caster','Caster','caster@moderation.invalid',
 '0500000000','education','approved',26.30,50.14);

select ok(not has_function_privilege('anon','public.admin_moderate_broadcaster(uuid,boolean,text,text)','execute'),
 'anon cannot moderate');

set local role authenticated;
-- A broadcaster cannot unhide or hide itself directly, nor call the action.
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select throws_ok($$update public.profiles set is_temporarily_hidden_from_map=true where id=auth.uid()$$,
 '42501',null,'broadcaster cannot change own map flag directly');
select lives_ok($$update public.profiles set bio_en='still editable' where id=auth.uid()$$,
 'ordinary profile editing still works');
select throws_ok($$select public.admin_moderate_broadcaster('66000000-0000-4000-8000-000000000002',false,'hide_from_map','x')$$,
 '42501',null,'non-admin denied');

select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok($$update public.profiles set is_temporarily_hidden_from_map=true where id='66000000-0000-4000-8000-000000000002'$$,
 '42501',null,'admin direct write refused: no unaudited path');
select throws_ok($$select public.admin_moderate_broadcaster('66000000-0000-4000-8000-000000000002',false,'hide_from_map','  ')$$,
 '22023',null,'reason required');
select throws_ok($$select public.admin_moderate_broadcaster('66000000-0000-4000-8000-000000000004',false,'hide_from_map','x')$$,
 'P0002',null,'non-broadcaster target not found');
select throws_ok($$select public.admin_moderate_broadcaster('66000000-0000-4000-8000-000000000003',false,'hide_from_map','x')$$,
 '42501',null,'master admin protected');
select throws_ok($$select public.admin_moderate_broadcaster('66000000-0000-4000-8000-000000000002',false,'revoke_organization','x')$$,
 '22023',null,'organization action rejects a profile target');
select throws_ok($$select public.log_audit_event(null,'broadcasterHiddenFromMap','fake','fake','{}')$$,
 '42501',null,'client cannot forge a map audit entry');

select lives_ok($$select public.admin_moderate_broadcaster('66000000-0000-4000-8000-000000000002',false,'hide_from_map','spam venue')$$,
 'admin hides broadcaster from map');
reset role;
select ok((select is_temporarily_hidden_from_map from public.profiles where id='66000000-0000-4000-8000-000000000002'),
 'flag set');
select is((select count(*)::int from public.audit_logs where action='broadcasterHiddenFromMap'
  and actor_profile_id='66000000-0000-4000-8000-000000000001' and description_en='spam venue'
  and metadata->>'target_id'='66000000-0000-4000-8000-000000000002'),1,'hide audited with actor, reason and target');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.admin_moderate_broadcaster('66000000-0000-4000-8000-000000000002',false,'hide_from_map','again')$$,
 'unchanged state is a no-op');
reset role;
select is((select count(*)::int from public.audit_logs where action='broadcasterHiddenFromMap'
  and metadata->>'target_id'='66000000-0000-4000-8000-000000000002'),1,'no-op writes no audit entry');

-- Rollback: if the audit insert fails, the visibility change is undone.
alter table public.audit_logs add constraint p6_test_block_show check (action <> 'broadcasterShownOnMap');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.admin_moderate_broadcaster('66000000-0000-4000-8000-000000000002',false,'show_on_map','reopen')$$,
 '23514',null,'failed audit fails the action');
reset role;
select ok((select is_temporarily_hidden_from_map from public.profiles where id='66000000-0000-4000-8000-000000000002'),
 'failed audit left the flag unchanged');
alter table public.audit_logs drop constraint p6_test_block_show;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.admin_moderate_broadcaster('66000000-0000-4000-8000-000000000002',false,'show_on_map','reopen')$$,
 'admin shows broadcaster again');
select lives_ok($$select public.admin_moderate_broadcaster('67000000-0000-4000-8000-000000000001',true,'hide_from_map','org test')$$,
 'organization can be hidden');
reset role;
select is((select count(*)::int from public.audit_logs where action in ('broadcasterShownOnMap','broadcasterHiddenFromMap')
  and actor_profile_id='66000000-0000-4000-8000-000000000001'),3,'show and org hide audited');

-- Organization verification revocation ends broadcast rights and live state.
update public.organizations set is_currently_live=true,broadcast_type='liveVideo',active_stream_id='orgstream01'
 where id='67000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.admin_moderate_broadcaster('67000000-0000-4000-8000-000000000001',true,'revoke_organization','policy')$$,
 'admin revokes organization verification');
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000005","role":"authenticated"}',true);
select ok(not public.can_broadcast('67000000-0000-4000-8000-000000000001','liveVideo'),'revoked organization cannot broadcast');
reset role;
select ok((select not is_currently_live and active_stream_id is null from public.organizations
  where id='67000000-0000-4000-8000-000000000001'),'revocation cleared organization live state');
select is((select count(*)::int from public.audit_logs where action='organizationVerificationRevoked'
  and description_en='policy'),1,'organization revocation audited');

-- Personal revocation uses the audited directory action and no longer
-- deletes the revoked user's organizations (the old client path did).
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.admin_update_account('66000000-0000-4000-8000-000000000002','revoke_streamer','policy breach')$$,
 'admin revokes personal broadcaster approval');
reset role;
select is((select count(*)::int from public.organizations where owner_profile_id='66000000-0000-4000-8000-000000000002'),1,
 'revocation is not deletion: owned organization kept');
select * from finish();
rollback;
