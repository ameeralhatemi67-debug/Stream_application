-- Run only in the disposable organization audit database. All fixtures roll back.
begin;
set local search_path=public,extensions;
select plan(22);
insert into public.app_flags(key,enabled) values('chat_enabled',true),('registrations_open',true)
  on conflict(key) do update set enabled=true;
insert into auth.users(id,email,email_confirmed_at) values
 ('91000000-0000-4000-8000-000000000001','owner@org.invalid',now()),
 ('91000000-0000-4000-8000-000000000002','presenter@org.invalid',now()),
 ('91000000-0000-4000-8000-000000000003','outsider@org.invalid',now());
insert into auth.sessions(id,user_id,created_at,updated_at) values
 ('92000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001',now(),now()),
 ('92000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000002',now(),now()),
 ('92000000-0000-4000-8000-000000000003','91000000-0000-4000-8000-000000000003',now(),now());
insert into public.profiles(id,is_streamer,is_verified) values
 ('91000000-0000-4000-8000-000000000001',true,true),
 ('91000000-0000-4000-8000-000000000002',false,false),
 ('91000000-0000-4000-8000-000000000003',false,false);
insert into public.organizations(id,owner_profile_id,name_en,name_ar,is_verified) values
 ('93000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','Test org','مؤسسة اختبار',true),
 ('93000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000003','Other org','أخرى',true);
insert into private.organization_v1_pilots values('93000000-0000-4000-8000-000000000001');
create temporary table invitation(value jsonb);
grant all on invitation to authenticated;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"92000000-0000-4000-8000-000000000001"}',true);
select is(public.org_v1_role('93000000-0000-4000-8000-000000000001'),'owner','Owner comes from canonical ownership');
select ok(not public.is_admin_tier(),'Organization owner has no global admin privilege');
select throws_ok($$insert into public.org_memberships values('93000000-0000-4000-8000-000000000001',auth.uid(),'manager','active','{}',now())$$,'42501',null,'Direct member writes denied');
insert into invitation select public.org_v1_invite('93000000-0000-4000-8000-000000000001','presenter@org.invalid','broadcaster','{"can_go_live_video":true}');
select ok((select (value->>'expires_at')::timestamptz between now()+interval '6 days' and now()+interval '8 days' from invitation),'Invitation expires in seven days');
select throws_ok($$select public.org_v1_invite('93000000-0000-4000-8000-000000000001','presenter@org.invalid')$$,'23505',null,'Duplicate invitation denied');
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000003","role":"authenticated","session_id":"92000000-0000-4000-8000-000000000003"}',true);
select throws_ok($$select public.org_v1_answer_invite((select (value->>'id')::uuid from invitation),true)$$,'42501',null,'Wrong account denied');
select throws_ok($$select public.org_v1_set_member('93000000-0000-4000-8000-000000000001',auth.uid(),'owner','active','{}')$$,'42501',null,'Cross organization authority denied');
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"92000000-0000-4000-8000-000000000002"}',true);
select lives_ok($$select public.org_v1_answer_invite((select (value->>'id')::uuid from invitation),true)$$,'Intended verified account can accept');
select is(public.org_v1_role('93000000-0000-4000-8000-000000000001'),'broadcaster','Acceptance establishes membership');
select ok(not public.can_broadcast('93000000-0000-4000-8000-000000000001','liveVideo'),'Membership cannot bypass platform review');
select throws_ok($$select public.org_v1_answer_invite((select (value->>'id')::uuid from invitation),true)$$,'55000',null,'Single use invitation');
select throws_ok($$select public.org_v1_set_member('93000000-0000-4000-8000-000000000001',auth.uid(),'manager','active','{}')$$,'42501',null,'Self escalation denied');
update public.profiles set personal_broadcast_approved=true,organization_broadcast_approved=true where id=auth.uid();
select ok((select not personal_broadcast_approved and not organization_broadcast_approved from public.profiles where id=auth.uid()),'Approval columns cannot be forged');
reset role;
update public.profiles set is_streamer=true,is_verified=true,personal_broadcast_approved=false,organization_broadcast_approved=true where id='91000000-0000-4000-8000-000000000002';
-- Trusted approval uses is_verified transition; simulate org-only approval explicitly.
update public.profiles set personal_broadcast_approved=false where id='91000000-0000-4000-8000-000000000002';
set local role authenticated;
select ok(public.can_broadcast('93000000-0000-4000-8000-000000000001','liveVideo'),'Approved presenter with grant can broadcast for enabled org');
select ok(not public.can_broadcast(null,'liveVideo'),'Organization-only approval does not grant personal broadcasting');
select ok(not public.can_broadcast('93000000-0000-4000-8000-000000000001','liveAudio'),'Video grant does not imply audio grant');
select throws_ok($$select * from private.organization_invite_tokens$$,'42501',null,'Tokens inaccessible through client SQL');
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"92000000-0000-4000-8000-000000000001"}',true);
select lives_ok($$select public.org_v1_set_member('93000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000002','manager','active','{}')$$,'Owner appoints manager');
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"92000000-0000-4000-8000-000000000002"}',true);
select ok(public.org_v1_can('93000000-0000-4000-8000-000000000001','schedule') and not public.org_v1_can('93000000-0000-4000-8000-000000000001','channel') and not public.org_v1_can('93000000-0000-4000-8000-000000000001','moderate'),'Manager actions remain scoped');
select throws_ok($$select public.org_v1_invite('93000000-0000-4000-8000-000000000001','outsider@org.invalid','co_owner')$$,'42501',null,'Manager cannot appoint leadership');
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"00000000-0000-4000-8000-000000000000"}',true);
select throws_ok($$select public.org_v1_invite('93000000-0000-4000-8000-000000000001','outsider@org.invalid')$$,'42501',null,'Expired auth session cannot mutate');
reset role;
select ok(exists(select 1 from public.audit_logs where organization_id='93000000-0000-4000-8000-000000000001' and metadata->>'profile_id'='91000000-0000-4000-8000-000000000002'),'Membership changes have a durable server audit');
select * from finish();
rollback;
