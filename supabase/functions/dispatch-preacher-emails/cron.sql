-- Run after deploying the function and applying 20261029103349. It sends the
-- preachers' emails (invitations, decisions, lesson changes, day-before
-- reminders) every minute. It reuses the Vault-held key of
-- dispatch-upcoming-reminders (that cron.sql creates it), so no key is copied
-- anywhere. Until RESEND_API_KEY and EMAIL_FROM are set as function secrets
-- the function answers 503 and the emails wait. Re-running is safe: existing
-- secrets are kept and the job is replaced by name.
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

select vault.create_secret(
  'https://<project-ref>.supabase.co/functions/v1/dispatch-preacher-emails',
  'preacher_emails_function_url')
where not exists (select 1 from vault.secrets where name = 'preacher_emails_function_url');

select cron.schedule('dispatch-preacher-emails', '* * * * *', $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets
      where name = 'preacher_emails_function_url'),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret
        from vault.decrypted_secrets where name = 'upcoming_reminder_dispatch_key')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
$$);
