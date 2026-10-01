-- Upcoming Live announcements and account-scoped reminders. This migration
-- does not create YouTube events or alter live-session state.
begin;

create or replace function public.can_publish_upcoming(p_profile_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    where p.id = p_profile_id and p.is_streamer and p.is_verified
      and not public.is_banned(p.id)
  );
$$;
revoke execute on function public.can_publish_upcoming(uuid) from public;
grant execute on function public.can_publish_upcoming(uuid) to anon, authenticated, service_role;

create table public.upcoming_schedules (
  id uuid primary key default gen_random_uuid(),
  streamer_profile_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('weekly', 'once')),
  local_time time without time zone not null,
  weekdays smallint[] not null default '{}',
  one_time_start_at timestamptz,
  title_en text not null default '' check (char_length(title_en) <= 120),
  title_ar text not null default '' check (char_length(title_ar) <= 120),
  description_en text not null default '' check (char_length(description_en) <= 1000),
  description_ar text not null default '' check (char_length(description_ar) <= 1000),
  tags text[] not null default '{}',
  color_key text not null default 'green' check (color_key in ('green','gold','berry','slate')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint upcoming_title_required check (btrim(title_en) <> '' or btrim(title_ar) <> ''),
  constraint upcoming_time_shape check (
    (kind = 'weekly' and one_time_start_at is null and cardinality(weekdays) between 1 and 7)
    or (kind = 'once' and one_time_start_at is not null and cardinality(weekdays) = 0)
  ),
  constraint upcoming_valid_weekdays check (weekdays <@ array[1,2,3,4,5,6,7]::smallint[]),
  constraint upcoming_tag_limit check (cardinality(tags) <= 5)
);
create index upcoming_schedules_owner_idx on public.upcoming_schedules(streamer_profile_id);
create trigger set_upcoming_schedules_updated_at before update on public.upcoming_schedules
  for each row execute function public.set_updated_at();

create function public.guard_upcoming_schedule()
returns trigger language plpgsql security definer set search_path = '' as $$
declare t text;
begin
  if not public.can_publish_upcoming(new.streamer_profile_id) then
    raise exception 'Approved broadcaster required';
  end if;
  if tg_op = 'UPDATE' and new.streamer_profile_id <> old.streamer_profile_id then
    raise exception 'Cannot transfer a schedule';
  end if;
  if new.kind = 'once' and new.one_time_start_at <= now() then
    raise exception 'One-time schedule must be in the future';
  end if;
  if new.kind = 'once' and
      new.local_time <> (new.one_time_start_at at time zone 'Asia/Riyadh')::time then
    raise exception 'One-time Saudi date and time disagree';
  end if;
  foreach t in array new.tags loop
    if char_length(t) > 32 or not exists (
      select 1 from public.tags where name = t and status in ('approved', 'pending')
    ) then
      raise exception 'Tag must be submitted for moderation';
    end if;
  end loop;
  return new;
end;
$$;
create trigger guard_upcoming_schedule before insert or update on public.upcoming_schedules
  for each row execute function public.guard_upcoming_schedule();
revoke execute on function public.guard_upcoming_schedule() from public, anon, authenticated;

alter table public.upcoming_schedules enable row level security;
create policy upcoming_select_owner on public.upcoming_schedules for select to authenticated
  using (streamer_profile_id = (select auth.uid()));
create policy upcoming_insert_owner on public.upcoming_schedules for insert to authenticated
  with check (streamer_profile_id = (select auth.uid()) and public.can_publish_upcoming(streamer_profile_id)
    and not public.is_current_user_banned());
create policy upcoming_update_owner on public.upcoming_schedules for update to authenticated
  using (streamer_profile_id = (select auth.uid()) and not public.is_current_user_banned())
  with check (streamer_profile_id = (select auth.uid()) and public.can_publish_upcoming(streamer_profile_id)
    and not public.is_current_user_banned());
create policy upcoming_delete_owner on public.upcoming_schedules for delete to authenticated
  using (streamer_profile_id = (select auth.uid()) and not public.is_current_user_banned());
grant select, insert, update, delete on public.upcoming_schedules to authenticated;

-- Public read hides pending or subsequently blacklisted tags. The owner sees
-- pending tags in the editor; approval then makes them public automatically.
create function public.list_upcoming_schedules(p_streamer_id uuid)
returns setof jsonb language sql stable security definer set search_path = '' as $$
  select to_jsonb(s) || jsonb_build_object('tags', case
    when s.streamer_profile_id = auth.uid() then to_jsonb(s.tags)
    else coalesce((
    select jsonb_agg(t.name order by t.name) from public.tags t
    where t.status = 'approved' and t.name = any(s.tags)
  ), '[]'::jsonb) end)
  from public.upcoming_schedules s
  where s.streamer_profile_id = p_streamer_id
    and public.can_publish_upcoming(p_streamer_id)
    and (s.kind = 'weekly' or s.one_time_start_at > now());
$$;
revoke execute on function public.list_upcoming_schedules(uuid) from public;
grant execute on function public.list_upcoming_schedules(uuid) to anon, authenticated;

create table public.channel_schedule_reminders (
  viewer_profile_id uuid not null references public.profiles(id) on delete cascade,
  streamer_profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(viewer_profile_id, streamer_profile_id)
);
create table public.card_schedule_reminders (
  viewer_profile_id uuid not null references public.profiles(id) on delete cascade,
  schedule_id uuid not null references public.upcoming_schedules(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(viewer_profile_id, schedule_id)
);
create table public.schedule_reminder_preferences (
  viewer_profile_id uuid primary key references public.profiles(id) on delete cascade,
  lead_minutes integer not null default 15 check (lead_minutes between 5 and 30 and lead_minutes % 5 = 0)
);
create table public.schedule_push_devices (
  token text primary key check (char_length(token) between 16 and 4096),
  viewer_profile_id uuid not null references public.profiles(id) on delete cascade,
  platform text not null check (platform in ('android','web')),
  language_code text not null default 'en' check (language_code in ('en','ar')),
  updated_at timestamptz not null default now()
);
create index schedule_push_devices_viewer_idx on public.schedule_push_devices(viewer_profile_id);

alter table public.channel_schedule_reminders enable row level security;
alter table public.card_schedule_reminders enable row level security;
alter table public.schedule_reminder_preferences enable row level security;
alter table public.schedule_push_devices enable row level security;
create policy channel_reminders_own on public.channel_schedule_reminders for all to authenticated
  using (viewer_profile_id = (select auth.uid()))
  with check (viewer_profile_id = (select auth.uid()) and public.can_publish_upcoming(streamer_profile_id)
    and not public.is_current_user_banned());
create function public.can_subscribe_upcoming(p_schedule_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.upcoming_schedules s where s.id = p_schedule_id
    and public.can_publish_upcoming(s.streamer_profile_id)
    and (s.kind = 'weekly' or s.one_time_start_at > now()));
$$;
revoke execute on function public.can_subscribe_upcoming(uuid) from public;
grant execute on function public.can_subscribe_upcoming(uuid) to authenticated;

create policy card_reminders_own on public.card_schedule_reminders for all to authenticated
  using (viewer_profile_id = (select auth.uid()))
  with check (viewer_profile_id = (select auth.uid()) and not public.is_current_user_banned()
    and public.can_subscribe_upcoming(schedule_id));
create policy reminder_preferences_own on public.schedule_reminder_preferences for all to authenticated
  using (viewer_profile_id = (select auth.uid()))
  with check (viewer_profile_id = (select auth.uid()) and not public.is_current_user_banned());
create policy push_devices_own on public.schedule_push_devices for all to authenticated
  using (viewer_profile_id = (select auth.uid()))
  with check (viewer_profile_id = (select auth.uid()) and not public.is_current_user_banned());
grant select, insert, update, delete on public.channel_schedule_reminders,
  public.card_schedule_reminders, public.schedule_reminder_preferences,
  public.schedule_push_devices to authenticated;

-- A device can change accounts without inheriting the previous account's
-- subscriptions. Keep sent ledger rows for a same-account language refresh.
create function public.register_schedule_push_device(
  p_token text, p_platform text, p_language_code text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or public.is_current_user_banned()
     or char_length(p_token) not between 16 and 4096
     or p_platform not in ('android','web')
     or p_language_code not in ('en','ar') then
    raise exception 'Invalid reminder device registration';
  end if;
  delete from public.schedule_push_devices
    where token = p_token and viewer_profile_id <> auth.uid();
  insert into public.schedule_push_devices(token,viewer_profile_id,platform,language_code)
    values (p_token,auth.uid(),p_platform,p_language_code)
  on conflict (token) do update set
    platform=excluded.platform,language_code=excluded.language_code,updated_at=now();
end;
$$;
revoke execute on function public.register_schedule_push_device(text,text,text) from public;
grant execute on function public.register_schedule_push_device(text,text,text) to authenticated;

-- The job claims each device/occurrence once. A crashed worker may retry after
-- its lease expires; a successful delivery is never claimed again.
create table public.schedule_reminder_deliveries (
  schedule_id uuid not null references public.upcoming_schedules(id) on delete cascade,
  token text not null references public.schedule_push_devices(token) on delete cascade,
  viewer_profile_id uuid not null references public.profiles(id) on delete cascade,
  occurrence_at timestamptz not null,
  lead_minutes integer not null,
  claimed_until timestamptz,
  sent_at timestamptz,
  attempts integer not null default 0,
  primary key(schedule_id, token, occurrence_at)
);
alter table public.schedule_reminder_deliveries enable row level security;
-- No client grants: only the service role can dispatch or inspect delivery rows.

create function public.next_riyadh_occurrence(
  p_weekdays smallint[], p_local_time time, p_after timestamptz)
returns timestamptz language sql stable set search_path = '' as $$
  select min((d.day + p_local_time) at time zone 'Asia/Riyadh')
  from (select ((p_after at time zone 'Asia/Riyadh')::date + n) as day
        from generate_series(0,7) n) d
  where extract(isodow from d.day)::int = any(p_weekdays)
    and ((d.day + p_local_time) at time zone 'Asia/Riyadh') > p_after;
$$;
revoke execute on function public.next_riyadh_occurrence(smallint[],time,timestamptz)
  from public, anon, authenticated;
grant execute on function public.next_riyadh_occurrence(smallint[],time,timestamptz)
  to service_role;

create function public.claim_due_schedule_reminders()
returns table(schedule_id uuid, token text, viewer_profile_id uuid,
  occurrence_at timestamptz, lead_minutes integer, title_en text,
  title_ar text, streamer_profile_id uuid, language_code text)
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.schedule_reminder_deliveries
    (schedule_id, token, viewer_profile_id, occurrence_at, lead_minutes)
  select s.id, d.token, subscriptions.viewer_profile_id,
    starts.occurrence_at, coalesce(p.lead_minutes, 15)
  from (
    select c.viewer_profile_id, s.id as schedule_id
      from public.channel_schedule_reminders c
      join public.upcoming_schedules s on s.streamer_profile_id = c.streamer_profile_id
    union
    select c.viewer_profile_id, c.schedule_id from public.card_schedule_reminders c
  ) subscriptions
  join public.upcoming_schedules s on s.id = subscriptions.schedule_id
  join public.schedule_push_devices d on d.viewer_profile_id = subscriptions.viewer_profile_id
  left join public.schedule_reminder_preferences p on p.viewer_profile_id = subscriptions.viewer_profile_id
  cross join lateral (select case when s.kind = 'once' then s.one_time_start_at
    else public.next_riyadh_occurrence(s.weekdays, s.local_time, now() - interval '31 minutes')
    end as occurrence_at) starts
  where public.can_publish_upcoming(s.streamer_profile_id)
    and not public.is_banned(subscriptions.viewer_profile_id)
    and starts.occurrence_at > now()
    and starts.occurrence_at - make_interval(mins => coalesce(p.lead_minutes, 15)) <= now()
  on conflict (schedule_id, token, occurrence_at) do update set
    lead_minutes = excluded.lead_minutes, claimed_until = null
  where public.schedule_reminder_deliveries.sent_at is null
    and public.schedule_reminder_deliveries.lead_minutes <> excluded.lead_minutes;

  return query
  update public.schedule_reminder_deliveries r
    set claimed_until = now() + interval '2 minutes', attempts = r.attempts + 1
  from public.upcoming_schedules s, public.schedule_push_devices d
  where r.schedule_id = s.id and r.token = d.token
    and r.sent_at is null and (r.claimed_until is null or r.claimed_until < now())
    and r.occurrence_at > now()
    and r.occurrence_at = case when s.kind = 'once' then s.one_time_start_at
      else public.next_riyadh_occurrence(s.weekdays, s.local_time,
        now() - interval '31 minutes') end
    and r.lead_minutes = coalesce((select p.lead_minutes
      from public.schedule_reminder_preferences p
      where p.viewer_profile_id = r.viewer_profile_id),15)
    and public.can_publish_upcoming(s.streamer_profile_id)
    and not public.is_banned(r.viewer_profile_id)
    and (exists (select 1 from public.channel_schedule_reminders c
      where c.viewer_profile_id = r.viewer_profile_id and c.streamer_profile_id = s.streamer_profile_id)
      or exists (select 1 from public.card_schedule_reminders c
      where c.viewer_profile_id = r.viewer_profile_id and c.schedule_id = s.id))
  returning r.schedule_id, r.token, r.viewer_profile_id, r.occurrence_at,
    r.lead_minutes, s.title_en, s.title_ar, s.streamer_profile_id, d.language_code;
end;
$$;
revoke execute on function public.claim_due_schedule_reminders() from public, anon, authenticated;
grant execute on function public.claim_due_schedule_reminders() to service_role;

commit;
