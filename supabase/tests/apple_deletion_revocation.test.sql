-- W19 deletion proof, identity changes and API privileges. Fixtures roll back.
-- Source only in the Windows work order; run with the local pgTAP suite later.
begin;
set local search_path=public,extensions;
select no_plan();

insert into auth.users(id,email) values
 ('a1100000-0000-4000-8000-000000000001','apple@revocation.invalid'),
 ('a1100000-0000-4000-8000-000000000002','mixed@revocation.invalid'),
 ('a1100000-0000-4000-8000-000000000003','google@revocation.invalid');
insert into public.profiles(id,email,display_name_en) values
 ('a1100000-0000-4000-8000-000000000001','apple@revocation.invalid','Apple User'),
 ('a1100000-0000-4000-8000-000000000002','mixed@revocation.invalid','Mixed User'),
 ('a1100000-0000-4000-8000-000000000003','google@revocation.invalid','Google User');
insert into auth.identities(id,user_id,provider,provider_id,identity_data,
    created_at,updated_at,last_sign_in_at) values
 ('a1200000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000001',
  'apple','apple-subject','{"sub":"apple-subject"}',
  '2026-10-18T00:00:00Z','2026-10-18T00:00:00Z','2026-10-18T00:00:00Z'),
 ('a1200000-0000-4000-8000-000000000002','a1100000-0000-4000-8000-000000000002',
  'apple','mixed-apple-subject','{"sub":"mixed-apple-subject"}',
  '2026-10-18T00:00:00Z','2026-10-18T00:00:00Z','2026-10-18T00:00:00Z'),
 ('a1200000-0000-4000-8000-000000000003','a1100000-0000-4000-8000-000000000002',
  'google','mixed-google-subject','{"sub":"mixed-google-subject"}',
  '2026-10-18T00:00:00Z','2026-10-18T00:00:00Z','2026-10-18T00:00:00Z'),
 ('a1200000-0000-4000-8000-000000000004','a1100000-0000-4000-8000-000000000003',
  'google','google-subject','{"sub":"google-subject"}',
  '2026-10-18T00:00:00Z','2026-10-18T00:00:00Z','2026-10-18T00:00:00Z');
insert into public.audit_logs(actor_profile_id,actor_email,actor_name,action,
    description_en,description_ar) values
 ('a1100000-0000-4000-8000-000000000001','apple@revocation.invalid','Apple User',
  'accountSessionsRevoked','test','test');

-- Use the server-issued version, never duplicate its implementation in tests.
create temporary table initial_apple_version as
  select public.apple_deletion_identities('a1100000-0000-4000-8000-000000000001')->0->>'version' as value;
grant select on initial_apple_version to service_role;

set local role anon;
select throws_ok($$select public.apple_deletion_identities('a1100000-0000-4000-8000-000000000001')$$,
  '42501',null,'anon cannot enumerate Apple identities');
select throws_ok($$select public.record_apple_deletion_revocation(
  'a1100000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001','apple-subject','forged')$$,
  '42501',null,'anon cannot record a proof');
select throws_ok($$select * from private.apple_deletion_revocations$$,
  '42501',null,'anon cannot read proofs');
reset role;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1100000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.apple_deletion_identities('a1100000-0000-4000-8000-000000000001')$$,
  '42501',null,'authenticated cannot enumerate Apple identities');
select throws_ok($$select public.record_apple_deletion_revocation(
  'a1100000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001','apple-subject','forged')$$,
  '42501',null,'authenticated cannot record a proof');
select throws_ok($$select * from private.apple_deletion_revocations$$,
  '42501',null,'authenticated cannot read proofs');
select throws_ok($$insert into private.apple_deletion_revocations
  (identity_id,user_id,subject,identity_version) values
  ('a1200000-0000-4000-8000-000000000001','a1100000-0000-4000-8000-000000000001','apple-subject','forged')$$,
  '42501',null,'authenticated cannot forge a proof directly');
select is(public.prepare_account_deletion()->>'requires_apple_revocation','true','Apple deletion advertises revocation');
select throws_ok($$select public.delete_own_account()$$,
  '55000','apple_revocation_required','bypassing Dart cannot delete without proof');
reset role;
select is((select count(*)::int from auth.users where id='a1100000-0000-4000-8000-000000000001'),1,'refused deletion preserves account');
select is((select actor_email from public.audit_logs where actor_profile_id='a1100000-0000-4000-8000-000000000001'),
  'apple@revocation.invalid','trigger refusal rolls back earlier SQL cleanup');

set local role service_role;
select is(jsonb_array_length(public.apple_deletion_identities('a1100000-0000-4000-8000-000000000001')),1,
  'service role can enumerate the bound Apple identity');
select throws_ok($$select * from private.apple_deletion_revocations$$,
  '42501',null,'service role has no direct proof table access');
select throws_ok($$select public.record_apple_deletion_revocation(
  'a1100000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001',
  'wrong-subject',(select value from initial_apple_version))$$,
  '55000','Apple identity changed','wrong subject cannot record proof');
select throws_ok($$select public.record_apple_deletion_revocation(
  'a1100000-0000-4000-8000-000000000002','a1200000-0000-4000-8000-000000000001',
  'apple-subject',(select value from initial_apple_version))$$,
  '55000','Apple identity changed','another account cannot reuse the identity');
select lives_ok($$select public.record_apple_deletion_revocation(
  'a1100000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001',
  'apple-subject',(select value from initial_apple_version))$$,'service role can record current proof');
reset role;

-- Deliberately corrupt a stored proof as postgres to test the deletion guard too.
update private.apple_deletion_revocations set subject='wrong-subject'
  where user_id='a1100000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($$select public.delete_own_account()$$,
  '55000','apple_revocation_required','guard rejects a proof for the wrong subject');
reset role;
update private.apple_deletion_revocations
  set subject='apple-subject',revoked_at=clock_timestamp()-interval '11 minutes'
  where user_id='a1100000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($$select public.delete_own_account()$$,
  '55000','apple_revocation_required','proof older than ten minutes cannot delete');
reset role;

update private.apple_deletion_revocations set revoked_at=clock_timestamp()
  where user_id='a1100000-0000-4000-8000-000000000001';
-- GoTrue repeat sign-in can update only last_sign_in_at and identity_data.
update auth.identities set last_sign_in_at=last_sign_in_at+interval '1 second'
  where id='a1200000-0000-4000-8000-000000000001';
select is((select updated_at from auth.identities where id='a1200000-0000-4000-8000-000000000001'),
  '2026-10-18T00:00:00Z'::timestamptz,'repeat sign-in fixture leaves updated_at unchanged');
select isnt(public.apple_deletion_identities('a1100000-0000-4000-8000-000000000001')->0->>'version',
  (select value from initial_apple_version),'new sign-in changes version with unchanged updated_at and data');
set local role authenticated;
select throws_ok($$select public.delete_own_account()$$,
  '55000','apple_revocation_required','new sign-in invalidates stored proof');
reset role;
set local role service_role;
select throws_ok($$select public.record_apple_deletion_revocation(
  'a1100000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001',
  'apple-subject',(select value from initial_apple_version))$$,
  '55000','Apple identity changed','sign-in during exchange prevents stale proof recording');
select lives_ok($$select public.record_apple_deletion_revocation(
  'a1100000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001',
  'apple-subject',public.apple_deletion_identities('a1100000-0000-4000-8000-000000000001')->0->>'version')$$,
  'fresh revocation can replace stale proof');
reset role;

update initial_apple_version set value=
  public.apple_deletion_identities('a1100000-0000-4000-8000-000000000001')->0->>'version';
update auth.identities set updated_at=updated_at+interval '1 second'
  where id='a1200000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($$select public.delete_own_account()$$,
  '55000','apple_revocation_required','updated_at alone invalidates stored proof');
reset role;
set local role service_role;
select lives_ok($$select public.record_apple_deletion_revocation(
  'a1100000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001',
  'apple-subject',public.apple_deletion_identities('a1100000-0000-4000-8000-000000000001')->0->>'version')$$,
  'current updated_at permits a fresh proof');
select throws_ok($$select public.record_apple_deletion_revocation(
  'a1100000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001',
  'apple-subject',(select value from initial_apple_version))$$,
  '55000','Apple identity changed','updated_at change prevents stale proof recording');
reset role;
update initial_apple_version set value=
  public.apple_deletion_identities('a1100000-0000-4000-8000-000000000001')->0->>'version';
update auth.identities set identity_data=identity_data||'{"email":"relay@revocation.invalid"}'::jsonb
  where id='a1200000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($$select public.delete_own_account()$$,
  '55000','apple_revocation_required','identity data alone invalidates stored proof');
reset role;

set local role service_role;
select throws_ok($$select public.record_apple_deletion_revocation(
  'a1100000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001',
  'apple-subject',(select value from initial_apple_version))$$,
  '55000','Apple identity changed','identity data change prevents stale proof recording');
set local time zone 'Pacific/Honolulu';
select lives_ok($$select public.record_apple_deletion_revocation(
  'a1100000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001',
  'apple-subject',public.apple_deletion_identities('a1100000-0000-4000-8000-000000000001')->0->>'version')$$,
  'current identity permits valid proof');
reset role;
set local time zone 'UTC';
set local role authenticated;
select lives_ok($$select public.delete_own_account()$$,'valid proof permits deletion across time zones');
reset role;
select is((select count(*)::int from auth.users where id='a1100000-0000-4000-8000-000000000001'),0,'valid proof deletes account');
select is((select count(*)::int from private.apple_deletion_revocations where user_id='a1100000-0000-4000-8000-000000000001'),0,
  'deletion cascades proof');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1100000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is(public.prepare_account_deletion()->>'requires_apple_revocation','true','Apple plus Google still requires Apple revocation');
select throws_ok($$select public.delete_own_account()$$,
  '55000','apple_revocation_required','Google identity cannot bypass Apple requirement');
reset role;
set local role service_role;
select is(jsonb_array_length(public.apple_deletion_identities('a1100000-0000-4000-8000-000000000002')),1,
  'mixed account returns only Apple identity');
select lives_ok($$select public.record_apple_deletion_revocation(
  'a1100000-0000-4000-8000-000000000002','a1200000-0000-4000-8000-000000000002',
  'mixed-apple-subject',public.apple_deletion_identities('a1100000-0000-4000-8000-000000000002')->0->>'version')$$,
  'mixed account can record Apple proof');
reset role;
set local role authenticated;
select lives_ok($$select public.delete_own_account()$$,'mixed account deletes with valid Apple proof');
reset role;
select is((select count(*)::int from auth.identities where user_id='a1100000-0000-4000-8000-000000000002'),0,
  'mixed account deletion cascades both identities');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1100000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select is(public.prepare_account_deletion()->>'requires_apple_revocation','false','Google-only account needs no Apple proof');
select lives_ok($$select public.delete_own_account()$$,'non-Apple deletion is unchanged');
reset role;
select is((select count(*)::int from auth.users where id='a1100000-0000-4000-8000-000000000003'),0,'non-Apple account removed without proof');

select * from finish();
rollback;
