-- Local-only pgTAP. UNVERIFIED-STATIC until run with the local database.
begin;
select plan(22);
insert into auth.users(id,email) values
 ('30000000-0000-4000-8000-000000000001','viewer@broadcast.invalid'),
 ('30000000-0000-4000-8000-000000000002','streamer@broadcast.invalid'),
 ('30000000-0000-4000-8000-000000000003','member@broadcast.invalid');
insert into public.profiles(id,is_streamer,is_verified) values
 ('30000000-0000-4000-8000-000000000001',false,false),
 ('30000000-0000-4000-8000-000000000002',true,true),
 ('30000000-0000-4000-8000-000000000003',false,false);
insert into public.organizations(id,owner_profile_id,name_en,name_ar,is_verified) values
 ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002','Org','Org',true);
insert into public.org_speakers(organization_id,linked_profile_id,name_en,name_ar,role_or_title_en,role_or_title_ar,permissions)
 values('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000003','Speaker','Speaker','Member','Member',
 '{"can_go_live_video":false,"can_go_audio_only":true}');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.claim_broadcaster_device('viewer','Viewer','web')$$,'42501','Broadcast not permitted','Viewer cannot claim primary');
select throws_ok($$insert into public.device_sessions(user_id,device_id,is_primary_broadcaster) values(auth.uid(),'forged',true)$$,
 '42501',null,'Direct device insert denied');
select throws_ok($$select public.set_live_state(true,'liveVideo','abcdefghijk','forged')$$,'42501','Primary device required','Viewer cannot go live');
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select ok(public.claim_broadcaster_device('A','Phone A','android'),'Streamer claims A');
select ok(not public.claim_broadcaster_device('B','Phone B','android'),'Fresh primary requires explicit transfer');
select ok(public.device_heartbeat('A'),'Primary heartbeat succeeds');
select throws_ok($$select public.set_live_state(true,'liveVideo','bad','A')$$,'P0001','Invalid YouTube video ID','Invalid ID denied');
select lives_ok($$select public.set_live_state(true,'liveVideo','abcdefghijk','A')$$,'P3 primary starts live');
select ok(public.owns_stream('abcdefghijk'),'P4 real owner can moderate');
select ok(public.claim_broadcaster_device('B','Phone B','android',true),'Explicit transfer succeeds');
select ok(not public.owns_stream('abcdefghijk'),'Transfer clears displaced live ownership');
select throws_ok($$select public.set_live_state(true,'liveVideo','abcdefghijk','A')$$,'42501','Primary device required','Displaced device cannot restart');
select is((select count(*) from public.device_sessions where user_id=auth.uid() and is_primary_broadcaster),1::bigint,'Exactly one primary');
reset role;
update public.device_sessions set last_active_at=now()-interval '91 seconds' where device_id='B';
set local role authenticated;
select ok(public.claim_broadcaster_device('A','Phone A','android'),'Stale primary claim needs no transfer approval');
select lives_ok($$select public.set_live_state(true,'liveVideo','abcdefghijk','A')$$,'Reclaimed primary starts live');
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select ok(not public.owns_stream('abcdefghijk'),'Non-owner cannot moderate');
select ok(public.claim_broadcaster_device('C','Phone C','android'),'Org audio member can claim');
select throws_ok($$select public.set_live_state(true,'liveVideo','lmnopqrstuv','C','40000000-0000-4000-8000-000000000001')$$,
 '42501','Broadcast not permitted','Org audio permission does not authorize video');
select throws_ok($$select public.set_live_state(true,'liveAudio','abcdefghijk','C','40000000-0000-4000-8000-000000000001')$$,
 '23505',null,'Duplicate live stream ID denied across principals');
select lives_ok($$select public.set_live_state(true,'liveAudio','lmnopqrstuv','C','40000000-0000-4000-8000-000000000001')$$,'Permitted org audio starts');
select lives_ok($$select public.release_broadcaster_device('C')$$,'Release succeeds');
select ok(not public.owns_stream('lmnopqrstuv'),'Release clears live ownership');
reset role;
select * from finish();
rollback;
