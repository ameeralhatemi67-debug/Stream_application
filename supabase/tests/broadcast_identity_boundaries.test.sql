begin;
select no_plan();
insert into auth.users(id,email) values
 ('68000000-0000-4000-8000-000000000001','identity-admin@example.invalid'),
 ('68000000-0000-4000-8000-000000000002','identity-owner@example.invalid'),
 ('68000000-0000-4000-8000-000000000003','identity-other@example.invalid');
insert into public.profiles(id,email,is_streamer,is_verified) values
 ('68000000-0000-4000-8000-000000000001','identity-admin@example.invalid',false,false),
 ('68000000-0000-4000-8000-000000000002','identity-owner@example.invalid',true,true),
 ('68000000-0000-4000-8000-000000000003','identity-other@example.invalid',true,true);
insert into public.user_roles(profile_id,role) values ('68000000-0000-4000-8000-000000000001','admin');
insert into auth.sessions(id,user_id) values ('68000000-0000-4000-8000-000000000011','68000000-0000-4000-8000-000000000001');
insert into public.device_sessions(user_id,device_id,is_primary_broadcaster,last_active_at) values
 ('68000000-0000-4000-8000-000000000002','identity-device',true,now()),
 ('68000000-0000-4000-8000-000000000003','other-device',true,now());
insert into public.organizations(id,name_en,name_ar,owner_profile_id,is_verified) values
 ('68000000-0000-4000-8000-000000000030','First','First','68000000-0000-4000-8000-000000000002',true),
 ('68000000-0000-4000-8000-000000000031','Second','Second','68000000-0000-4000-8000-000000000002',true);
create temporary table identity_ids(k text primary key,v uuid);
grant all on identity_ids to authenticated;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"68000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
insert into identity_ids select 'first',public.start_broadcast_session('liveVideo','IDENTITY001','identity-device','68000000-0000-4000-8000-000000000030','phone_direct');
insert into identity_ids select 'second',public.start_broadcast_session('liveVideo','IDENTITY001','identity-device','68000000-0000-4000-8000-000000000031','phone_direct');
select isnt((select v from identity_ids where k='first'),(select v from identity_ids where k='second'),'changing organization creates a new session even for the same watch ID');
select is((select org_id from public.broadcast_sessions where state='live'),'68000000-0000-4000-8000-000000000031'::uuid,'session belongs to selected organization');
select set_config('request.jwt.claims','{"sub":"68000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.start_broadcast_session('liveVideo','IDENTITY001','other-device',null,'obs_laptop')$$,'23505',null,'two accounts cannot concurrently list one watch ID');
select set_config('request.jwt.claims','{"sub":"68000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.end_broadcast_session((select v from identity_ids where k='second'),'identity-device')$$,'owner ends organization broadcast');
select set_config('request.jwt.claims','{"sub":"68000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select lives_ok($$select public.start_broadcast_session('liveVideo','IDENTITY001','other-device',null,'obs_laptop')$$,'another account may reuse an ended watch ID');
-- A stale legacy organization flag must not turn its watch ID into authority
-- over a different account. Such rows can exist at the migration boundary.
reset role;
update public.organizations set is_currently_live=true,broadcast_type='liveVideo',active_stream_id='IDENTITY001' where id='68000000-0000-4000-8000-000000000030';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"68000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"68000000-0000-4000-8000-000000000011"}',true);
select lives_ok($$select public.admin_moderate_broadcaster('68000000-0000-4000-8000-000000000030',true,'revoke_organization','scope regression')$$,'revoke stale organization');
reset role;
select ok((select is_currently_live from public.profiles where id='68000000-0000-4000-8000-000000000003'),'organization revocation cannot end an unrelated account reusing its watch ID');
select * from finish();
rollback;
