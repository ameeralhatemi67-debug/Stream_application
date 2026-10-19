begin;
set local search_path=public,extensions;
select plan(7);
insert into auth.users(id,email) values
 ('10000000-0000-4000-8000-0000000000a1','hide-owner@example.invalid'),
 ('10000000-0000-4000-8000-0000000000a2','hide-other@example.invalid');
insert into public.profiles(id,email) values
 ('10000000-0000-4000-8000-0000000000a1','hide-owner@example.invalid'),
 ('10000000-0000-4000-8000-0000000000a2','hide-other@example.invalid');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-0000000000a1","role":"authenticated"}',true);
select lives_ok($$insert into public.hidden_channel_content(streamer_id,kind,item_id)
  values ('10000000-0000-4000-8000-0000000000a1','video','abc123')$$,
  'A streamer can hide a video on their own channel');
select throws_ok($$insert into public.hidden_channel_content(streamer_id,kind,item_id)
  values ('10000000-0000-4000-8000-0000000000a2','video','abc123')$$,
  '42501', null, 'A streamer cannot hide content on another channel');
select throws_ok($$insert into public.hidden_channel_content(streamer_id,kind,item_id)
  values ('10000000-0000-4000-8000-0000000000a1','clip','abc123')$$,
  '23514', null, 'Only videos and playlists can be hidden');

select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-0000000000a2","role":"authenticated"}',true);
select is((select count(*)::int from public.hidden_channel_content), 1,
  'Other signed-in users can read the list');
delete from public.hidden_channel_content where item_id='abc123';
reset role;
select is((select count(*)::int from public.hidden_channel_content), 1,
  'Another user cannot show the hidden item again');

set local role anon;
select is((select count(*)::int from public.hidden_channel_content), 1,
  'Signed-out viewers can read the list');
select throws_ok($$insert into public.hidden_channel_content(streamer_id,kind,item_id)
  values ('10000000-0000-4000-8000-0000000000a1','video','zzz')$$,
  '42501', null, 'Signed-out callers cannot write');
reset role;
select * from finish();
rollback;
