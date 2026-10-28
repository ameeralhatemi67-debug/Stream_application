-- Run after deploying the function and applying 20261028110000. It sends
-- the pushes for org_v1_events: "live now" for followed channels, the
-- admins' decisions on applications, and the organization events. It reuses
-- the Vault-held key of dispatch-upcoming-reminders (that cron.sql creates
-- it), so no key is copied anywhere. Re-running is safe: existing secrets are
-- kept and the job is replaced by name.
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

select vault.create_secret(
  'https://<project-ref>.supabase.co/functions/v1/dispatch-organization-events',
  'organization_events_function_url')
where not exists (select 1 from vault.secrets where name = 'organization_events_function_url');

select cron.schedule('dispatch-organization-events', '* * * * *', $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets
      where name = 'organization_events_function_url'),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret
        from vault.decrypted_secrets where name = 'upcoming_reminder_dispatch_key')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
$$);
