-- Local-only pgTAP for 20260924100000_broadcaster_device_claim_state.sql.
begin;
select plan(16);
insert into auth.users(id,email) values
 ('31000000-0000-4000-8000-000000000001','viewer@claimstate.invalid'),
 ('31000000-0000-4000-8000-000000000002','streamer@claimstate.invalid'),
 ('31000000-0000-4000-8000-000000000003','banned@claimstate.invalid');
insert into public.profiles(id,is_streamer,is_verified) values
 ('31000000-0000-4000-8000-000000000001',false,false),
 ('31000000-0000-4000-8000-000000000002',true,true),
 ('31000000-0000-4000-8000-000000000003',true,true);
insert into public.banned_users(profile_id,email,reason) values
 ('31000000-0000-4000-8000-000000000003','banned@claimstate.invalid','test');

select ok(not has_function_privilege('anon','public.claim_broadcaster_device_state(text,text,text,boolean)','execute'),
 'Anonymous callers cannot claim');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"31000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.claim_broadcaster_device_state('V','Viewer','web')$$,'42501','Broadcast not permitted',
 'Viewer cannot claim');
select set_config('request.jwt.claims','{"sub":"31000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.claim_broadcaster_device_state('X','Banned','web')$$,'42501','Broadcast not permitted',
 'Banned broadcaster cannot claim');

select set_config('request.jwt.claims','{"sub":"31000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is(public.claim_broadcaster_device_state('A','Phone A','android')->>'claimed','true','First device claims');
select is(public.claim_broadcaster_device_state('A','Phone A','android')->>'claimed','true','Primary device re-claim is idempotent');
select lives_ok($$select public.set_live_state(true,'liveVideo','abcdefghijk','A')$$,'Primary A goes live');

select is(public.claim_broadcaster_device_state('B','Phone B','android')->'primary'->>'device_id','A',
 'Second device learns which device is primary');
select is((select is_primary_broadcaster from public.device_sessions where user_id=auth.uid() and device_id='A'),true,
 'Unforced conflict leaves A primary');
select ok((select is_currently_live from public.profiles where id=auth.uid()),'Unforced conflict leaves A live');

reset role;
update public.device_sessions set last_active_at=now()-interval '5 minutes' where device_id='A';
set local role authenticated;
select is(public.claim_broadcaster_device_state('B','Phone B','android')->'primary'->>'stale','true',
 'A silent primary is still reported, flagged stale, instead of being taken over silently');
select is((select count(*) from public.device_sessions where user_id=auth.uid() and device_id='B'),0::bigint,
 'Unforced conflict writes no row for the second device');

select is(public.claim_broadcaster_device_state('B','Phone B','android',true)->>'claimed','true','Forced transfer claims B');
select ok(not (select is_currently_live from public.profiles where id=auth.uid()),'Transfer clears the displaced live state');
select ok(not public.device_heartbeat('A'),'Displaced heartbeat reports not primary');
select throws_ok($$select public.set_live_state(true,'liveVideo','abcdefghijk','A')$$,'42501','Primary device required',
 'Displaced device cannot restart');
select is(public.claim_broadcaster_device_state('A','Phone A','android')->'primary'->>'device_id','B',
 'Displaced device does not silently reclaim');
reset role;
select * from finish();
rollback;
