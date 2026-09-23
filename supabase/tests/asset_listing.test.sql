begin;
select plan(5);
insert into storage.objects(bucket_id,name) values
 ('streamer-assets','10000000-0000-4000-8000-000000000001/listing.png'),
 ('streamer-assets','10000000-0000-4000-8000-000000000002/listing.png');
select ok((select public from storage.buckets where id='streamer-assets'),
  'Public asset URL delivery remains enabled');
set local role anon;
select is((select count(*)::int from storage.objects where bucket_id='streamer-assets'),
  0, 'Anonymous callers cannot enumerate asset keys');
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is((select count(*)::int from storage.objects where name like '%/listing.png'),
  1,'Owner sees only owned metadata');
select is((select count(*)::int from storage.objects where name='10000000-0000-4000-8000-000000000002/listing.png'),
  0,'Other owner metadata stays hidden');
select lives_ok($$update storage.objects set metadata='{"verified":true}'::jsonb
  where name='10000000-0000-4000-8000-000000000001/listing.png'$$,
  'Owner SELECT still permits updating an owned asset');
reset role;
select * from finish();
rollback;
