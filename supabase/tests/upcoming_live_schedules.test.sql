begin;
select no_plan();

insert into auth.users(id,email) values
 ('73000000-0000-4000-8000-000000000001','schedule-owner@example.invalid'),
 ('73000000-0000-4000-8000-000000000002','schedule-viewer@example.invalid');
insert into public.profiles(id,email,is_streamer,is_verified) values
 ('73000000-0000-4000-8000-000000000001','schedule-owner@example.invalid',true,true),
 ('73000000-0000-4000-8000-000000000002','schedule-viewer@example.invalid',false,false);

select is(public.next_riyadh_occurrence(array[1]::smallint[], '03:00',
  '2026-11-01 23:00+00'::timestamptz),
  '2026-11-02 00:00+00'::timestamptz,
  'Saudi Monday 3 a.m. is Sunday midnight UTC across month boundary');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"73000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select throws_ok($$insert into public.upcoming_schedules(streamer_profile_id,kind,
  local_time,weekdays,title_en) values
  ('73000000-0000-4000-8000-000000000002','weekly','03:00','{1}','Forged')$$,
  'P0001',null,'unapproved account cannot publish');

select set_config('request.jwt.claims',
  '{"sub":"73000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
insert into public.upcoming_schedules(id,streamer_profile_id,kind,
  local_time,weekdays,title_en,tags) values
  ('74000000-0000-4000-8000-000000000001',
   '73000000-0000-4000-8000-000000000001','weekly','03:00',
   array[extract(isodow from ((now() at time zone 'Asia/Riyadh')::date + 2))::smallint],
   'Weekly lecture','{}');
insert into public.upcoming_schedules(id,streamer_profile_id,kind,
  local_time,weekdays,one_time_start_at,title_ar)
select '74000000-0000-4000-8000-000000000002',
  '73000000-0000-4000-8000-000000000001','once',
  (date_trunc('minute', now()+interval '14 minutes') at time zone 'Asia/Riyadh')::time,
  '{}',date_trunc('minute', now()+interval '14 minutes'),'محاضرة خاصة';
select is((select count(*)::int from public.upcoming_schedules),2,
  'owner can create weekly and one-time announcements');

select set_config('request.jwt.claims',
  '{"sub":"73000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((select count(*)::int from public.upcoming_schedules),0,
  'viewer cannot read owner-only schedule table');
select is((select count(*)::int from public.list_upcoming_schedules(
  '73000000-0000-4000-8000-000000000001')),2,
  'viewer can see sanitized public announcements');
insert into public.channel_schedule_reminders(viewer_profile_id,streamer_profile_id)
  values ('73000000-0000-4000-8000-000000000002',
  '73000000-0000-4000-8000-000000000001');
insert into public.card_schedule_reminders(viewer_profile_id,schedule_id)
  values ('73000000-0000-4000-8000-000000000002',
  '74000000-0000-4000-8000-000000000002');
select public.register_schedule_push_device(
  'test-upcoming-device-token-00000001','android','en');

reset role;
select is((select count(*)::int from public.claim_due_schedule_reminders()),1,
  'overlapping channel and card choice claims one delivery');
select is((select count(*)::int from public.claim_due_schedule_reminders()),0,
  'claim lease prevents concurrent duplicate sends');
update public.schedule_reminder_deliveries set sent_at=now(),claimed_until=null;
select is((select count(*)::int from public.claim_due_schedule_reminders()),0,
  'sent occurrence is never sent again');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"73000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select public.register_schedule_push_device(
  'test-upcoming-device-token-00000001','android','ar');
select is((select viewer_profile_id from public.schedule_push_devices
  where token='test-upcoming-device-token-00000001'),
  '73000000-0000-4000-8000-000000000001'::uuid,
  'device account switch drops old account delivery ledger');
reset role;
select is((select count(*)::int from public.schedule_reminder_deliveries),0,
  'old account delivery ledger is removed on token transfer');
update public.profiles set is_verified=false
  where id='73000000-0000-4000-8000-000000000001';
select is((select count(*)::int from public.list_upcoming_schedules(
  '73000000-0000-4000-8000-000000000001')),0,
  'lost approval hides schedules');

select * from finish();
rollback;
