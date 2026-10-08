-- Run after deploying the function and applying the migrations. The dispatch
-- key is generated inside the database and never leaves Vault; the service-role
-- key is not needed. Re-running is safe: existing secrets are kept.
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

select vault.create_secret(
  encode(extensions.gen_random_bytes(32), 'hex'), 'upcoming_reminder_dispatch_key')
where not exists (select 1 from vault.secrets where name = 'upcoming_reminder_dispatch_key');

select vault.create_secret(
  'https://<project-ref>.supabase.co/functions/v1/dispatch-upcoming-reminders',
  'upcoming_reminder_function_url')
where not exists (select 1 from vault.secrets where name = 'upcoming_reminder_function_url');

select cron.schedule('dispatch-upcoming-reminders', '* * * * *', $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets
      where name = 'upcoming_reminder_function_url'),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret
        from vault.decrypted_secrets where name = 'upcoming_reminder_dispatch_key')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
$$);
