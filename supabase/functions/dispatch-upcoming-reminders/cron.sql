-- Run on the authorized non-production backend after deploying the function,
-- applying the migration and adding Vault secrets named below. Do not place
-- the service-role key in this file or in client build defines.
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

select cron.schedule('dispatch-upcoming-reminders', '* * * * *', $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets
      where name = 'upcoming_reminder_function_url'),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret
        from vault.decrypted_secrets where name = 'upcoming_reminder_service_key')
    ),
    body := '{}'::jsonb
  );
$$);
