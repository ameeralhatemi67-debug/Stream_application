-- Review before installation. Store the dedicated BROADCAST_RECONCILE_KEY
-- in Vault as hadayah_broadcast_reconcile_key through a private setup step.
-- This job may complete revoked/ended YouTube broadcasts and retire their
-- bound feeds, reconcile ambiguous writes, and refresh schedules/replay status.
-- It never initiates an arbitrary public broadcast.
-- Release note (owner approval 2026-10-04): retain this recovery job in public
-- deployments. Remove temporary synthetic diagnostics before public launch;
-- they are documented in the streaming-regression evidence, not scheduled here.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
select cron.schedule('hadayah-reconcile-broadcasts','* * * * *',$job$
  select net.http_post(
    url := 'https://zkkmfjsjouqzibvnzkau.supabase.co/functions/v1/reconcile-broadcasts',
    headers := jsonb_build_object('Content-Type','application/json',
      'Authorization','Bearer ' || (select decrypted_secret from vault.decrypted_secrets
        where name='hadayah_broadcast_reconcile_key')),
    body := '{}'::jsonb,timeout_milliseconds := 30000);
$job$);
