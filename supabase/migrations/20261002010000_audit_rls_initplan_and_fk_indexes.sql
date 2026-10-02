-- Performance audit 2026-09-28/10-02 (DB-01, DB-02). No behaviour change.
--
-- DB-01: an RLS policy that calls auth.uid() directly re-evaluates it for every
-- row scanned. Wrapping it as (select auth.uid()) makes Postgres evaluate it
-- once per statement (an InitPlan). The hosted advisor flagged 19 policies,
-- mostly on chat_messages, the hottest table in the app.
--
-- This rewrites whatever the CURRENT policy text is instead of re-declaring
-- known policies, so it stays correct on top of later migrations (the V1
-- migrations redefine some chat policies) and is idempotent: a policy that
-- already wraps its calls is left alone.
-- Postgres regular expressions have no lookbehind, so the already-wrapped form
-- (deparsed as "( SELECT auth.uid() AS uid)") is parked behind a placeholder,
-- every bare call is wrapped, and the placeholder is restored.
create or replace function pg_temp.wrap_auth_calls(expr text) returns text
language sql immutable as $fn$
  select replace(replace(replace(replace(replace(replace(expr,
    '( SELECT auth.uid() AS uid)', '@@UID@@'),
    '( SELECT auth.role() AS role)', '@@ROLE@@'),
    'auth.uid()', '(select auth.uid())'),
    'auth.role()', '(select auth.role())'),
    '@@UID@@', '(select auth.uid())'),
    '@@ROLE@@', '(select auth.role())')
$fn$;

do $$
declare
  r record;
  new_qual text;
  new_check text;
  stmt text;
  unwrapped text;
begin
  -- pg_policies deparses auth.uid() as uid() when the session search_path
  -- includes auth (supabase_admin does); pin it so the text is predictable.
  perform set_config('search_path', 'public, pg_catalog', true);
  for r in
    select schemaname, tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
  loop
    -- Skip policies that have no bare auth.uid()/auth.role() call left (the
    -- wrapped form is deparsed as "( SELECT auth.uid() AS uid)").
    unwrapped := replace(replace(coalesce(r.qual, '') || ' ' || coalesce(r.with_check, ''),
      '( SELECT auth.uid() AS uid)', ''), '( SELECT auth.role() AS role)', '');
    if unwrapped !~ 'auth\.(uid|role)\(\)' then
      continue;
    end if;
    new_qual := pg_temp.wrap_auth_calls(r.qual);
    new_check := pg_temp.wrap_auth_calls(r.with_check);
    stmt := format('alter policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);
    if new_qual is not null then
      stmt := stmt || ' using (' || new_qual || ')';
    end if;
    if new_check is not null then
      stmt := stmt || ' with check (' || new_check || ')';
    end if;
    execute stmt;
  end loop;
end
$$;

-- DB-02: foreign keys without a covering index make joins and, importantly,
-- cascading deletes (account/organization deletion) scan the referencing table.
-- Add a btree index for every public-schema foreign key that has none. The
-- tables are small today; this also covers the V1 tables as they are added.
do $$
declare
  r record;
  idx_name text;
begin
  for r in
    select c.conrelid, c.conname, n.nspname, t.relname, c.conkey,
           (select string_agg(quote_ident(a.attname), ', ' order by k.ord)
              from unnest(c.conkey) with ordinality as k(attnum, ord)
              join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.attnum) as cols
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where c.contype = 'f' and n.nspname = 'public'
      and not exists (
        select 1 from pg_index i
        where i.indrelid = c.conrelid
          and i.indisvalid
          and (i.indkey::int2[])[0:cardinality(c.conkey) - 1] = c.conkey
      )
  loop
    idx_name := left(r.relname || '_' || regexp_replace(r.cols, '[^a-z0-9_]+', '_', 'g') || '_fk_idx', 63);
    execute format('create index if not exists %I on %I.%I (%s)',
      idx_name, r.nspname, r.relname, r.cols);
  end loop;
end
$$;
