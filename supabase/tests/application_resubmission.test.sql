-- A rejected application is resubmitted in place (20261028132919).
begin;
select plan(12);
insert into auth.users (id, email) values
 ('81000000-0000-4000-8000-000000000001', 'reapply@example.invalid'),
 ('81000000-0000-4000-8000-000000000002', 'other@example.invalid');
insert into public.profiles (id, email) values
 ('81000000-0000-4000-8000-000000000001', 'reapply@example.invalid'),
 ('81000000-0000-4000-8000-000000000002', 'other@example.invalid')
 on conflict (id) do nothing;

create temporary table app_row as
 select '81000000-0000-4000-8000-0000000000a1'::uuid as id;
grant select on app_row to authenticated;

-- The app saves with an upsert keyed on id.
create function pg_temp.save(p_name text, p_status text default 'pending') returns void
language sql as $$
 insert into public.broadcaster_applications (id, applicant_profile_id, account_type,
   applicant_name_en, applicant_name_ar, email, phone, category_id, city_id, latitude, longitude,
   youtube_channel_url, youtube_handle, tags, status)
 values ((select id from app_row), '81000000-0000-4000-8000-000000000001', 'individualScholar',
   p_name, 'تجربة', 'reapply@example.invalid', '0500000000', 'fiqh', 'khobar', 26.28, 50.20,
   'https://www.youtube.com/@reapply', '@reapply', '{}', p_status)
 on conflict (id) do update set applicant_name_en = excluded.applicant_name_en,
   status = excluded.status;
$$;
grant execute on function pg_temp.save(text, text) to authenticated;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"81000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select pg_temp.save('First');
reset role;
select is((select status from public.broadcaster_applications where id = (select id from app_row)),
 'pending', 'a new application is pending');

update public.broadcaster_applications set status = 'rejected', admin_review_notes = 'Add your bio',
 reviewed_at = now() - interval '1 day' where id = (select id from app_row);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"81000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($$select pg_temp.save('Second')$$, 'the applicant can resubmit a rejected application');
reset role;
select ok((select status = 'pending' and reviewed_at is null and reviewed_by is null
   and admin_review_notes is null and applicant_name_en = 'Second'
   from public.broadcaster_applications where id = (select id from app_row)),
 'the resubmission is back in the queue with the new content and no review fields');
select ok((select submitted_at > now() - interval '1 minute'
   from public.broadcaster_applications where id = (select id from app_row)),
 'the resubmission gets a new submitted time');
select ok(exists(select 1 from public.application_review_events
   where application_id = (select id from app_row) and action = 'rejected'
     and application_snapshot->>'applicant_name_en' = 'First' and reason = 'Add your bio'),
 'the history still holds the rejected version and its reason');
select is((select count(*)::int from public.broadcaster_applications
   where applicant_profile_id = '81000000-0000-4000-8000-000000000001'),
 1, 'resubmitting does not create a second application');

-- A forged decision on the resubmission is neutralized.
update public.broadcaster_applications set status = 'rejected' where id = (select id from app_row);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"81000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select pg_temp.save('Third', 'approved');
reset role;
select is((select status from public.broadcaster_applications where id = (select id from app_row)),
 'pending', 'an applicant cannot approve their own resubmission');

-- Someone else cannot resubmit it.
update public.broadcaster_applications set status = 'rejected' where id = (select id from app_row);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"81000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
update public.broadcaster_applications set applicant_name_en = 'Hijacked' where id = (select id from app_row);
reset role;
select ok((select status = 'rejected' and applicant_name_en = 'Third'
   from public.broadcaster_applications where id = (select id from app_row)),
 'another account cannot resubmit it');

-- A row an admin removed from the queue stays closed. (Fixture write: the
-- review trigger only lets a signed-in admin change queue visibility.)
set local session_replication_role = replica;
update public.broadcaster_applications set queue_archived_at = now() where id = (select id from app_row);
set local session_replication_role = origin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"81000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select throws_ok($$select pg_temp.save('Fourth')$$, '42501', null,
 'a removed application cannot be resubmitted in place');
reset role;

-- An approved application is still not writable through the form.
set local session_replication_role = replica;
update public.broadcaster_applications set queue_archived_at = null, status = 'approved'
 where id = (select id from app_row);
set local session_replication_role = origin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"81000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select throws_ok($$select pg_temp.save('Fifth')$$, '42501', null,
 'an approved application cannot be written over by the applicant');
reset role;
select is((select status from public.broadcaster_applications where id = (select id from app_row)),
 'approved', 'the approved application is unchanged');

-- A rejected profile edit stays closed; edits go through save_broadcaster_profile.
insert into public.broadcaster_applications (id, revision_of, applicant_profile_id, account_type,
  applicant_name_en, applicant_name_ar, email, phone, category_id, city_id, latitude, longitude,
  youtube_channel_url, youtube_handle, tags, status)
values ('81000000-0000-4000-8000-0000000000b1', (select id from app_row),
  '81000000-0000-4000-8000-000000000001', 'individualScholar', 'Edit', 'تعديل',
  'new@example.invalid', '0500000000', 'fiqh', 'khobar', 26.28, 50.20,
  'https://www.youtube.com/@reapply', '@reapply', '{}', 'rejected');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"81000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
update public.broadcaster_applications set applicant_name_en = 'Edit again'
 where id = '81000000-0000-4000-8000-0000000000b1';
reset role;
select ok((select status = 'rejected' and applicant_name_en = 'Edit'
   from public.broadcaster_applications where id = '81000000-0000-4000-8000-0000000000b1'),
 'a rejected profile edit cannot be reopened through the table');

select * from finish();
rollback;
