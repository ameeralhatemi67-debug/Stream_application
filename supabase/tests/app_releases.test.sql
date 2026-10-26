-- App releases for the update checker (20261026120000_app_releases.sql).
begin;
set local search_path = public, extensions;
select plan(25);

insert into auth.users(id, email, email_confirmed_at) values
  ('30000000-0000-4000-8000-0000000000c1', 'releases-master@example.invalid', now()),
  ('30000000-0000-4000-8000-0000000000c2', 'releases-admin@example.invalid', now()),
  ('30000000-0000-4000-8000-0000000000c3', 'releases-viewer@example.invalid', now());
insert into public.profiles(id, email, display_name_en, display_name_ar) values
  ('30000000-0000-4000-8000-0000000000c1', 'releases-master@example.invalid', 'Master', 'رئيسي'),
  ('30000000-0000-4000-8000-0000000000c2', 'releases-admin@example.invalid', 'Admin', 'مشرف'),
  ('30000000-0000-4000-8000-0000000000c3', 'releases-viewer@example.invalid', 'Viewer', 'مستمع');
insert into public.user_roles(profile_id, role) values
  ('30000000-0000-4000-8000-0000000000c1', 'master_admin'),
  ('30000000-0000-4000-8000-0000000000c2', 'admin');

create function pg_temp.as_user(p uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
$$;

-- Fixtures written as the table owner: two published APK releases, one draft,
-- one scheduled for later, and a published Play release.
insert into public.app_releases(channel, version_code, version_name, min_supported_code,
    download_url, sha256, size_bytes, notes_en, notes_ar, published_at) values
  ('apk', 1, '1.0.0', 0, 'https://example.supabase.co/storage/v1/object/public/app-releases/1.apk',
    repeat('a', 64), 1000, 'First', 'الأول', now() - interval '2 days'),
  ('apk', 2, '1.0.1', 1, 'https://example.supabase.co/storage/v1/object/public/app-releases/2.apk',
    repeat('b', 64), 1000, 'Second', 'الثاني', now() - interval '1 day'),
  ('apk', 3, '1.0.2', 2, 'https://example.supabase.co/storage/v1/object/public/app-releases/3.apk',
    null, null, 'Draft', 'مسودة', null),
  ('apk', 4, '1.0.3', 2, 'https://example.supabase.co/storage/v1/object/public/app-releases/4.apk',
    repeat('c', 64), 1000, 'Later', 'لاحقًا', now() + interval '1 day'),
  ('play', 2, '1.0.1', 0, 'https://play.google.com/store/apps/details?id=sa.hadayah.streamer_app',
    null, null, '', '', now() - interval '1 day');

select is((select count(*)::int from storage.buckets
            where id = 'app-releases' and public and file_size_limit = 209715200
              and allowed_mime_types @> array['application/vnd.android.package-archive']),
  1, 'A01 the public app-releases bucket exists for APK files');

-- Guests
set local role anon;
select is((select string_agg(version_code::text, ',' order by version_code)
             from public.app_releases where channel = 'apk'),
  '1,2', 'A02 a guest sees only published APK releases, not drafts or scheduled ones');
select is((select version_code from public.app_releases
            where channel = 'apk' order by version_code desc limit 1),
  2, 'A03 the newest release a guest can see is the newest published one');
select is((select min_supported_code from public.app_releases
            where channel = 'apk' order by version_code desc limit 1),
  1, 'A04 and it carries the minimum supported version');
select is((select version_code from public.app_releases
            where channel = 'play' order by version_code desc limit 1),
  2, 'A05 the Play channel is read separately');
select throws_ok($$insert into public.app_releases(channel, version_code, version_name, download_url)
    values ('apk', 9, '9.0.0', 'https://example.invalid/9.apk')$$,
  '42501', null, 'A06 a guest cannot add a release');
reset role;

-- A signed-in viewer and a plain admin
set local role authenticated;
select pg_temp.as_user('30000000-0000-4000-8000-0000000000c3');
select is((select count(*)::int from public.app_releases), 3,
  'A07 a viewer sees the published releases only');
select throws_ok($$insert into public.app_releases(channel, version_code, version_name, download_url)
    values ('apk', 9, '9.0.0', 'https://example.invalid/9.apk')$$,
  '42501', null, 'A08 a viewer cannot add a release');
update public.app_releases set min_supported_code = 2 where version_code = 2 and channel = 'apk';
select is((select min_supported_code from public.app_releases where version_code = 2 and channel = 'apk'),
  1, 'A09 a viewer cannot raise the minimum version');

select pg_temp.as_user('30000000-0000-4000-8000-0000000000c2');
select throws_ok($$insert into public.app_releases(channel, version_code, version_name, download_url)
    values ('apk', 9, '9.0.0', 'https://example.invalid/9.apk')$$,
  '42501', null, 'A10 a plain admin cannot add a release');
delete from public.app_releases where channel = 'apk';
reset role;
select is((select count(*)::int from public.app_releases where channel = 'apk'), 4,
  'A11 a plain admin cannot delete releases');

-- A master admin
set local role authenticated;
select pg_temp.as_user('30000000-0000-4000-8000-0000000000c1');
select is((select count(*)::int from public.app_releases), 5,
  'A12 a master admin sees drafts and scheduled releases too');
select lives_ok($$insert into public.app_releases(channel, version_code, version_name, min_supported_code, download_url)
    values ('apk', 5, '1.1.0', 2, 'https://example.supabase.co/storage/v1/object/public/app-releases/5.apk')$$,
  'A13 a master admin adds a draft release');
update public.app_releases set sha256 = repeat('d', 64), size_bytes = 2000, published_at = now()
 where channel = 'apk' and version_code = 5;
select is((select published_at is not null from public.app_releases where channel = 'apk' and version_code = 5),
  true, 'A14 and publishes it');
update public.app_releases set min_supported_code = 5 where channel = 'apk' and version_code = 5;
select is((select min_supported_code from public.app_releases where channel = 'apk' and version_code = 5),
  5, 'A15 and can require it');
select throws_ok($$update public.app_releases set published_at = now() where channel = 'apk' and version_code = 3$$,
  '23514', null, 'A16 an APK cannot be published without its size and checksum');
select lives_ok($$insert into public.app_releases(channel, version_code, version_name, download_url, published_at)
    values ('apk', 7, '2.0.0', 'https://play.google.com/store/apps/details?id=sa.hadayah.streamer_app', now())$$,
  'A16b the last APK release may point at the Play listing, without a file checksum');
delete from public.app_releases where channel = 'apk' and version_code = 7;

-- Shape checks
select throws_ok($$insert into public.app_releases(channel, version_code, version_name, min_supported_code, download_url)
    values ('apk', 6, '1.2.0', 7, 'https://example.invalid/6.apk')$$,
  '23514', null, 'A17 the minimum cannot be above the release itself');
select throws_ok($$insert into public.app_releases(channel, version_code, version_name, download_url)
    values ('apk', 6, '1.2.0', 'http://example.invalid/6.apk')$$,
  '23514', null, 'A18 a plain http link is refused');
select throws_ok($$insert into public.app_releases(channel, version_code, version_name, download_url)
    values ('play', 6, '1.2.0', 'https://example.invalid/6.apk')$$,
  '23514', null, 'A19 the Play channel can only point at its Play listing');
select throws_ok($$insert into public.app_releases(channel, version_code, version_name, download_url)
    values ('apk', 1, '1.0.0', 'https://example.invalid/again.apk')$$,
  '23505', null, 'A20 a version code is used once per channel');
select throws_ok($$insert into public.app_releases(channel, version_code, version_name, download_url)
    values ('apk', 6, 'one', 'https://example.invalid/6.apk')$$,
  '23514', null, 'A21 the version name is numbers and dots');
select throws_ok($$insert into public.app_releases(channel, version_code, version_name, download_url)
    values ('ios', 6, '1.2.0', 'https://example.invalid/6.apk')$$,
  '23514', null, 'A22 only the apk and play channels exist');
delete from public.app_releases where channel = 'apk' and version_code = 5;
reset role;
select is((select count(*)::int from public.app_releases where channel = 'apk' and version_code = 5), 0,
  'A23 a master admin can remove a release');

set local role anon;
select is((select version_code from public.app_releases
            where channel = 'apk' order by version_code desc limit 1),
  2, 'A24 after the removal guests see the previous release again');
reset role;

select * from finish();
rollback;
