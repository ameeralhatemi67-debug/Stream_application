-- Required for the owner-approved broadcast recovery scheduler.
-- Scheduler credentials and the hosted URL are configured outside migrations.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
revoke usage on schema cron from anon, authenticated;
revoke all on all tables in schema cron from anon, authenticated;
revoke usage on schema net from public, anon, authenticated;
