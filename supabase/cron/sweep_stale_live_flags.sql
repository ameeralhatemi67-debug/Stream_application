-- Optional, run once by the owner on the hosted project (audit NET-04).
-- sweep_stale_live_flags() clears is_currently_live for broadcasters whose
-- primary device stopped heartbeating (> 90 s). Clients currently call it
-- opportunistically while reading the feed; scheduling it here makes it one
-- server job instead of one call per client per minute. Once this is running
-- the client call in AppProvider._fetchVerifiedStreamers can be removed.
create extension if not exists pg_cron with schema extensions;

select cron.schedule('sweep-stale-live-flags', '* * * * *',
  $$ select public.sweep_stale_live_flags(); $$);
