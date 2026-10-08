-- The reminder dispatcher is called by pg_cron. Until now it required the
-- project service-role key to be copied into Vault. A dedicated Vault secret
-- (generated inside the database, never shown or copied) lets the job
-- authenticate without that key; the Edge Function checks it through this
-- service-role-only RPC.
begin;

create or replace function public.verify_reminder_dispatch_key(p_key text)
returns boolean language sql stable security definer
set search_path = '' as $$
  select coalesce(p_key, '') <> '' and exists (
    select 1 from vault.decrypted_secrets s
    where s.name = 'upcoming_reminder_dispatch_key'
      and s.decrypted_secret = p_key
  );
$$;
revoke execute on function public.verify_reminder_dispatch_key(text)
  from public, anon, authenticated;
grant execute on function public.verify_reminder_dispatch_key(text) to service_role;

commit;
