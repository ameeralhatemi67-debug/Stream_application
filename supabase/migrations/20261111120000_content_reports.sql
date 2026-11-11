-- Reports of a broadcast or a channel (2026-11-11).
--
-- Google Play's user-generated content rule asks for a way, inside the app,
-- to report content and the accounts that publish it. Until now only chat
-- messages could be reported (chat_reports). This table takes a report of a
-- live or recorded broadcast, or of a channel as a whole, and shows it to
-- admin tiers only.
--
-- NOT APPLIED to the hosted project. The owner approves and applies it.
-- Until it is applied, the app's Report action answers "could not send".

create table public.content_reports (
  id uuid primary key default gen_random_uuid(),
  target_kind text not null check (target_kind in ('stream', 'channel')),
  -- The channel the report is about (for a stream: the channel it is on).
  channel_profile_id uuid not null references public.profiles (id) on delete cascade,
  -- The broadcast or recording, when the report is about one.
  stream_id text check (stream_id is null or char_length(stream_id) between 1 and 64),
  reporter_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  reason text not null check (reason in
    ('wrong_teaching', 'hate_speech', 'harassment', 'inappropriate', 'spam', 'impersonation', 'other')),
  note text check (note is null or char_length(note) <= 500),
  created_at timestamptz not null default now(),
  constraint content_reports_stream_has_id
    check (target_kind <> 'stream' or stream_id is not null)
);

-- One report per person per thing; a second one answers "already reported".
create unique index content_reports_once_idx
  on public.content_reports (reporter_id, target_kind, channel_profile_id, coalesce(stream_id, ''));
create index content_reports_created_idx on public.content_reports (created_at desc);
create index content_reports_channel_idx on public.content_reports (channel_profile_id);

comment on table public.content_reports is
  'Reports of a broadcast or a channel, visible only to admin tiers. One row per (reporter, thing).';

-- At most 20 reports per account per day, so the queue cannot be flooded.
create function public.guard_content_report() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.content_reports r
      where r.reporter_id = new.reporter_id
        and r.created_at > now() - interval '1 day') >= 20 then
    raise exception 'Too many reports today' using errcode = '53400';
  end if;
  if not exists (select 1 from public.profiles p where p.id = new.channel_profile_id) then
    raise exception 'Unknown channel' using errcode = '22023';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_content_report() from public, anon, authenticated;
create trigger guard_content_report before insert on public.content_reports
  for each row execute function public.guard_content_report();

alter table public.content_reports enable row level security;

-- A signed-in, unbanned person reports as themselves, never their own channel.
create policy content_reports_insert_self
  on public.content_reports for insert
  to authenticated
  with check (
    reporter_id = auth.uid()
    and channel_profile_id <> auth.uid()
    and not public.is_current_user_banned()
  );

-- Only admin tiers read the queue and clear a report after acting on it.
create policy content_reports_select_admin
  on public.content_reports for select
  to authenticated
  using (public.is_admin_tier());

create policy content_reports_delete_admin
  on public.content_reports for delete
  to authenticated
  using (public.is_admin_tier());

revoke all on public.content_reports from anon;
grant select, insert, delete on public.content_reports to authenticated;
