-- Rollback-only smoke test. No network requests or YouTube resource creation.
begin;
set local role service_role;
do $check$ begin
  perform count(*) from public.broadcast_reconcile_claim();
end $check$;
reset role;
do $check$ begin
  if not has_function_privilege('service_role','public.broadcast_reconcile_claim()','EXECUTE')
     or has_function_privilege('authenticated','public.broadcast_reconcile_claim()','EXECUTE')
     or has_function_privilege('anon','public.broadcast_reconcile_claim()','EXECUTE') then
    raise exception 'Recovery authorization grants failed';
  end if;
  if has_schema_privilege('anon','cron','USAGE') or
     has_schema_privilege('authenticated','cron','USAGE') then
    raise exception 'Client roles can access scheduler definitions';
  end if;
end $check$;
select 'PASS: service-only recovery claims execute; client scheduler access denied' as result;
rollback;
