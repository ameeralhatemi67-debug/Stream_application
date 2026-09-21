-- brief/06 §2b — R1..R8 catalog probes, plus the two coherence checks that
-- would have caught the P1d privilege bug on the day it was introduced.
--
-- These assert properties of the CATALOG rather than the behaviour of any one
-- policy: RLS is on everywhere, every RLS table has a policy or is a
-- documented deny-all, no policy is addressed to PUBLIC, every anon-reachable
-- function is on a named allowlist, only intended tables are published to
-- realtime, and -- R10/R11 -- table privileges and policies agree with each
-- other in both directions.
--
-- R11 is the important one. Until 20260921110000 this schema had 110 policies
-- on tables that granted the API roles no DML at all, so every policy was
-- unreachable and the whole app was `42501 permission denied` when rebuilt
-- from its own migrations. A policy without the matching GRANT is dead code; a
-- GRANT without a matching policy is a table whose protection rests on one
-- layer instead of two. Both directions are now assertions.
--
-- R9 (`npx supabase db advisors --local --type security`) is a CLI call, not
-- SQL, so it stays outside this file. Its expected output is exactly two
-- `security_definer_view` ERRORs for the two documented public views, and
-- nothing else; R4 below is the in-database half of that check.
begin;
select plan(20);

-- ---------------------------------------------------------------------------
-- Intent lists. Everything that is deliberately wider than "signed-in only"
-- is named here, so widening the surface means editing this file too.
-- ---------------------------------------------------------------------------
create temporary table expected_deny_all(relname text) on commit drop;
insert into expected_deny_all values ('stream_viewers');

create temporary table expected_anon_select(relname text) on commit drop;
insert into expected_anon_select values
  ('academic_categories'),           -- public taxonomy
  ('tags'),                          -- approved tags only, per policy
  ('terms_and_conditions'),          -- legal text must be readable pre-sign-in
  ('chat_messages'),                 -- public chat is readable by guests
  ('chat_stream_settings'),          -- guests must see that chat is off
  ('streamer_custom_placeholders'),  -- approved custom cards
  ('streamer_public_profiles'),      -- non-PII view
  ('organization_public_profiles');  -- non-PII view

create temporary table expected_anon_execute(proname text) on commit drop;
insert into expected_anon_execute values
  ('viewer_heartbeat'),    -- D-08: guests are counted
  ('get_viewer_counts'),   -- D-08: guests see the count
  ('chat_sender_info');    -- guests see sender names and role badges

create temporary table expected_realtime(relname text) on commit drop;
insert into expected_realtime values
  ('chat_messages'), ('broadcaster_applications'), ('profiles'),
  ('academic_categories'), ('tags'), ('banned_users'), ('device_sessions');

-- ---------------------------------------------------------------------------
-- R1 — row-level security is enabled everywhere it must be.
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int from pg_class
    where relnamespace = 'public'::regnamespace
      and relkind = 'r' and not relrowsecurity),
  0, 'R1a every ordinary table in public has RLS enabled');

select ok(
  (select relrowsecurity from pg_class where oid = 'storage.objects'::regclass),
  'R1b storage.objects has RLS enabled');

-- ---------------------------------------------------------------------------
-- R2 — an RLS table with no policy denies everything. That is a valid design,
-- but only for the tables that say so on purpose.
-- ---------------------------------------------------------------------------
select is(
  (select coalesce(string_agg(c.relname, ',' order by c.relname), '')
     from pg_class c
    where c.relnamespace = 'public'::regnamespace
      and c.relkind = 'r' and c.relrowsecurity
      and not exists (select 1 from pg_policy p where p.polrelid = c.oid)
      and c.relname not in (select relname from expected_deny_all)),
  '', 'R2 every RLS table has a policy, except the documented deny-all list');

select is(
  (select coalesce(string_agg(e.relname, ',' order by e.relname), '')
     from expected_deny_all e
     join pg_class c on c.relname = e.relname
      and c.relnamespace = 'public'::regnamespace
    where exists (select 1 from pg_policy p where p.polrelid = c.oid)),
  '', 'R2b a table on the deny-all list has not quietly gained a policy');

-- ---------------------------------------------------------------------------
-- R3 — the anonymous read surface is exactly the intent list.
-- ---------------------------------------------------------------------------
select is(
  (select coalesce(string_agg(c.relname, ',' order by c.relname), '')
     from pg_class c
    where c.relnamespace = 'public'::regnamespace
      and c.relkind in ('r', 'v')
      and has_table_privilege('anon', c.oid, 'select')
      and c.relname not in (select relname from expected_anon_select)),
  '', 'R3a anon can select only from the intended relations');

select is(
  (select coalesce(string_agg(e.relname, ',' order by e.relname), '')
     from expected_anon_select e
    where not has_table_privilege('anon', ('public.' || e.relname)::regclass, 'select')),
  '', 'R3b every intended anon read is actually granted');

select is(
  (select count(*)::int from pg_class c
    where c.relnamespace = 'public'::regnamespace
      and c.relkind = 'r'
      and (has_table_privilege('anon', c.oid, 'insert')
        or has_table_privilege('anon', c.oid, 'update')
        or has_table_privilege('anon', c.oid, 'delete'))),
  0, 'R3c anon has no write privilege on any table');

-- ---------------------------------------------------------------------------
-- R4 — views. `security_invoker = false` bypasses the base table's RLS, so
-- each one needs a stated reason (D-21); the comment IS the justification.
-- ---------------------------------------------------------------------------
select is(
  (select coalesce(string_agg(c.relname, ',' order by c.relname), '')
     from pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind = 'v'
      and coalesce((select option_value from pg_options_to_table(c.reloptions)
                     where option_name = 'security_invoker'), 'false') = 'false'
      and obj_description(c.oid, 'pg_class') is null),
  '', 'R4 every security_invoker=false view carries a justifying comment');

-- ---------------------------------------------------------------------------
-- R5 — function reachability and search_path.
-- ---------------------------------------------------------------------------
select is(
  (select coalesce(string_agg(distinct p.proname, ',' order by p.proname), '')
     from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and has_function_privilege('anon', p.oid, 'execute')
      and p.proname not in (select proname from expected_anon_execute)),
  '', 'R5a anon may execute only the three documented functions');

select is(
  (select coalesce(string_agg(e.proname, ',' order by e.proname), '')
     from expected_anon_execute e
    where not exists (select 1 from pg_proc p
                       where p.pronamespace = 'public'::regnamespace
                         and p.proname = e.proname
                         and has_function_privilege('anon', p.oid, 'execute'))),
  '', 'R5b each documented anon function is actually executable by anon');

select is(
  (select coalesce(string_agg(p.proname, ',' order by p.proname), '')
     from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.prosecdef
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}'::text[])) cfg
                       where cfg like 'search_path=%')),
  '', 'R5c every security definer function in public pins search_path');

-- A per-uuid ban probe is an information leak in client hands: it answers
-- "is this account banned" for any id. It is called only from other definer
-- functions (P1c decision 6).
select ok(
  not has_function_privilege('anon', 'public.is_banned(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'public.is_banned(uuid)', 'execute'),
  'R5d is_banned(uuid) is not executable by any client role');

-- ---------------------------------------------------------------------------
-- R6 — policy shape.
-- ---------------------------------------------------------------------------
select is(
  (select coalesce(string_agg(policyname, ',' order by policyname), '')
     from pg_policies where schemaname = 'public' and roles = '{public}'),
  '', 'R6a no policy in public is addressed to PUBLIC');

select is(
  (select coalesce(string_agg(tablename || '.' || policyname, ',' order by tablename), '')
     from pg_policies
    where schemaname = 'public' and permissive = 'PERMISSIVE' and cmd = 'ALL'),
  '', 'R6b no permissive policy in public uses FOR ALL');

select is(
  (select coalesce(string_agg(tablename || '.' || policyname, ',' order by tablename), '')
     from pg_policies
    where schemaname = 'public' and permissive = 'PERMISSIVE'
      and cmd in ('INSERT', 'UPDATE', 'ALL')
      and btrim(coalesce(with_check, '')) = 'true'),
  '', 'R6c no write policy accepts every row with a bare with check (true)');

-- ---------------------------------------------------------------------------
-- R7 — storage.
-- ---------------------------------------------------------------------------
select is(
  (select coalesce(string_agg(id, ',' order by id), '')
     from storage.buckets where public and id <> 'streamer-assets'),
  '', 'R7a streamer-assets is the only public bucket');

select is(
  (select count(distinct cmd)::int from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and permissive = 'PERMISSIVE'
      and coalesce(qual, '') || coalesce(with_check, '') like '%streamer-assets%'),
  4, 'R7b streamer-assets has a permissive policy for each of the four commands');

-- ---------------------------------------------------------------------------
-- R8 — realtime publication.
-- ---------------------------------------------------------------------------
select is(
  (select coalesce(string_agg(tablename, ',' order by tablename), '')
     from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename not in (select relname from expected_realtime)),
  '', 'R8 the realtime publication carries only the intended tables');

-- ---------------------------------------------------------------------------
-- R10 / R11 — privileges and policies must agree.
--
-- R11 is the regression guard for the P1d finding: table privileges are
-- checked BEFORE RLS, so a policy with no matching GRANT can never fire.
-- ---------------------------------------------------------------------------
select is(
  (select coalesce(string_agg(t.relname || '.' || t.cmd, ',' order by t.relname, t.cmd), '')
     from (
       select c.relname, lower(p.cmd) as cmd
         from pg_class c
         join pg_policies p
           on p.schemaname = 'public' and p.tablename = c.relname
        where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
          and p.permissive = 'PERMISSIVE' and p.cmd <> 'ALL'
          and 'authenticated' = any(p.roles)
          and not has_table_privilege('authenticated', c.oid, p.cmd)
       group by 1, 2
     ) t),
  '', 'R11 every policy granted to authenticated has the matching table privilege');

select is(
  (select coalesce(string_agg(t.relname || '.' || t.cmd, ',' order by t.relname, t.cmd), '')
     from (
       select c.relname, x.cmd
         from pg_class c
         cross join (values ('select'), ('insert'), ('update'), ('delete')) as x(cmd)
        where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
          and has_table_privilege('authenticated', c.oid, x.cmd)
          and not exists (
            select 1 from pg_policies p
             where p.schemaname = 'public' and p.tablename = c.relname
               and p.permissive = 'PERMISSIVE'
               and (p.cmd = 'ALL' or lower(p.cmd) = x.cmd)
               and 'authenticated' = any(p.roles))
     ) t),
  '', 'R10 no table privilege is granted to authenticated without a policy behind it');

select * from finish();
rollback;
