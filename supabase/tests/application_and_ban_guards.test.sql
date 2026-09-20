-- Local-only pgTAP acceptance for P1.4 and direct-write P1.5.
-- UNVERIFIED-STATIC until executed on local Supabase.
begin;
select plan(11);
insert into auth.users (id, email) values
 ('30000000-0000-4000-8000-000000000001', 'applicant@example.invalid'),
 ('30000000-0000-4000-8000-000000000002', 'owner@example.invalid');
insert into public.profiles (id, bio_en) values
 ('30000000-0000-4000-8000-000000000001', 'Original'),
 ('30000000-0000-4000-8000-000000000002', 'Owner');
insert into public.organizations (id, owner_profile_id, name_en, name_ar)
values ('40000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', 'Org', 'Org');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
insert into public.broadcaster_applications (id, applicant_profile_id, account_type,
 applicant_name_en, applicant_name_ar, email, phone, category_id, status, reviewed_by, admin_review_notes)
values ('50000000-0000-4000-8000-000000000001', auth.uid(), 'individualScholar',
 'Applicant', 'Applicant', 'applicant@example.invalid', '0500000000', 'education', 'approved',
 '30000000-0000-4000-8000-000000000002', 'Forged review');
select ok((select status = 'pending' and reviewed_by is null and reviewed_at is null and admin_review_notes is null
 from public.broadcaster_applications where id = '50000000-0000-4000-8000-000000000001'), 'A5 forged review INSERT is neutralized');
update public.broadcaster_applications set status = 'approved',
 reviewed_by = '30000000-0000-4000-8000-000000000002', phone = '0511111111'
where id = '50000000-0000-4000-8000-000000000001';
select ok((select status = 'pending' and reviewed_by is null from public.broadcaster_applications
 where id = '50000000-0000-4000-8000-000000000001'), 'A5 forged review UPDATE is neutralized');
select is((select phone from public.broadcaster_applications where id = '50000000-0000-4000-8000-000000000001'),
 '0511111111', 'Pending applicant content remains editable');
insert into public.affiliation_requests (id, organization_id, streamer_profile_id, direction, status, permissions)
values ('60000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', auth.uid(),
 'streamerToOrg', 'accepted', '{"can_change_location":true}');
select ok((select status = 'pending' and permissions->>'can_change_location' = 'false'
 from public.affiliation_requests where id = '60000000-0000-4000-8000-000000000001'), 'A6 cannot insert accepted membership or grants');
update public.affiliation_requests set status = 'accepted', permissions = '{"can_change_location":true}'
where id = '60000000-0000-4000-8000-000000000001';
select ok((select status = 'pending' and permissions->>'can_change_location' = 'false'
 from public.affiliation_requests where id = '60000000-0000-4000-8000-000000000001'), 'A6 cannot self-approve membership');

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
update public.affiliation_requests set status = 'accepted', permissions = '{"can_change_location":true}'
where id = '60000000-0000-4000-8000-000000000001';
select ok((select status = 'accepted' and permissions->>'can_change_location' = 'true'
 from public.affiliation_requests where id = '60000000-0000-4000-8000-000000000001'), 'P5 org owner can approve and grant');

reset role;
insert into public.banned_users (profile_id, email, reason)
values ('30000000-0000-4000-8000-000000000001', 'applicant@example.invalid', 'Test ban');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
update public.profiles set bio_en = 'Banned write' where id = auth.uid();
select is((select bio_en from public.profiles where id = auth.uid()), 'Original', 'A7 banned profile update affects no row');
select throws_ok($$insert into public.chat_messages (stream_id, sender_id, body)
 values ('lecture123A', auth.uid(), 'Banned message')$$, '42501', null, 'A7 banned chat insert denied');
select throws_ok($$insert into public.broadcaster_applications (applicant_profile_id, account_type,
 applicant_name_en, applicant_name_ar, email, phone, category_id)
 values (auth.uid(), 'individualScholar', 'A', 'A', 'applicant@example.invalid', '0500000000', 'education')$$,
 '42501', null, 'A7 banned application insert denied');
select throws_ok($$insert into storage.objects (bucket_id, name)
 values ('streamer-assets', '30000000-0000-4000-8000-000000000001/banned.png')$$,
 '42501', null, 'A7 banned asset insert denied');
reset role;
update public.banned_users set expires_at = now() - interval '1 second'
where profile_id = '30000000-0000-4000-8000-000000000001';
set local role authenticated;
update public.profiles set bio_en = 'After expiry' where id = auth.uid();
select is((select bio_en from public.profiles where id = auth.uid()), 'After expiry', 'Expired ban permits normal profile edit');
reset role;
select * from finish();
rollback;
