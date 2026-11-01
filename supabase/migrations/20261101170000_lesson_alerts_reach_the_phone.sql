-- Lesson alerts reach the phone (owner request 2026-11-01).
--
-- Until now only a due reminder became a push. Everything else stayed in the
-- Lessons inbox, so a cancelled lesson reached nobody who was not looking, and
-- its reminder was dropped.
--
-- * Every Lessons inbox row is now a push too, through one queue like the
--   organization events' (lesson_notifications.push_until says for how long).
-- * private.lesson_audience() is the one answer to "who hears about this
--   session": whoever set a reminder on it or follows its preacher, mosque or
--   series. Cancellations, moves and live alerts all use it.
-- * A streamed lesson going live alerts that audience; people who follow the
--   channel already hear through show_live.
-- * The evening digest, which had a switch and nothing behind it, is built.
-- * New-lesson alerts say whether the follow was the preacher or the mosque.
-- * A moved lesson's reminders move with it, and removing a preacher tells the
--   people who were expecting their lessons.
--
-- claim_due_lesson_reminders() is replaced by claim_lesson_pushes(), which the
-- deployed dispatcher starts calling once dispatch-organization-events is
-- redeployed: apply this first, then deploy. Until then the old dispatcher's
-- lesson claim fails on its own and event pushes keep working.
begin;

alter table public.lesson_notifications
  add column push_until timestamptz,
  add column dedupe_key text;
comment on column public.lesson_notifications.push_until is
  'Until when this row may still go out as a push. Null: inbox only (older rows).';
comment on column public.lesson_notifications.dedupe_key is
  'One row per account and key, for alerts that can fire twice (a live that reconnects).';
create unique index lesson_notifications_dedupe_idx
  on public.lesson_notifications(profile_id, dedupe_key) where dedupe_key is not null;
create index lesson_notifications_push_idx
  on public.lesson_notifications(push_until) where push_until is not null;

alter table public.notification_push_preferences
  add column lessons_enabled boolean not null default true;

-- As private.org_v1_event_deliveries: one row per notice and device.
create table private.lesson_notification_deliveries (
  notification_id uuid not null references public.lesson_notifications(id) on delete cascade,
  token text not null references public.schedule_push_devices(token) on delete cascade,
  claimed_until timestamptz,
  sent_at timestamptz,
  attempts integer not null default 0,
  primary key (notification_id, token)
);

-- The evenings whose digest has gone out, so the minute job sends it once.
create table private.lesson_digest_days (
  day date primary key,
  created_at timestamptz not null default now()
);
revoke all on private.lesson_notification_deliveries, private.lesson_digest_days
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Writing a notice
-- ---------------------------------------------------------------------------
create function private.lessons_alert(p_profile uuid, p_icon text, p_title_ar text, p_title_en text,
  p_body_ar text, p_body_en text, p_route text, p_stale interval, p_key text) returns void
language sql security definer set search_path = '' as $$
  insert into public.lesson_notifications(profile_id, icon, title_ar, title_en, body_ar, body_en, route, push_until, dedupe_key)
  select p_profile, p_icon, p_title_ar, p_title_en, coalesce(p_body_ar, ''), coalesce(p_body_en, ''), p_route,
    now() + p_stale, p_key
  where p_profile is not null and not public.is_banned(p_profile)
  on conflict (profile_id, dedupe_key) where dedupe_key is not null do nothing;
$$;

-- Every existing caller now reaches the phone as well as the inbox.
create or replace function private.lessons_notify(p_profile uuid, p_icon text, p_title_ar text, p_title_en text,
  p_body_ar text, p_body_en text, p_route text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.lessons_alert(p_profile, p_icon, p_title_ar, p_title_en, p_body_ar, p_body_en, p_route,
    interval '24 hours', null);
end; $$;

-- Who hears about a session.
create function private.lesson_audience(l public.lessons) returns setof uuid
language sql stable security definer set search_path = '' as $$
  select r.profile_id from public.lesson_reminders r where r.lesson_id = l.id
  union
  select f.profile_id from public.lesson_follows f
   where (f.kind = 'preacher' and f.target_id = l.preacher_id)
      or (f.kind = 'mosque' and f.target_id = l.mosque_id)
      or (f.kind = 'series' and f.target_id = l.series_id);
$$;

-- A new lesson, in words that match why this person hears about it.
create function private.lessons_new_lesson_notice(p_request uuid, p_preacher uuid, p_mosques uuid[],
  p_name_ar text, p_name_en text, p_title_ar text, p_title_en text, p_actor uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.lessons_notify(f.profile_id, 'sparkle',
    case when f.preacher then 'درس جديد من داعية تتابعه' else 'درس جديد في مسجد تتابعه' end,
    case when f.preacher then 'New lesson from a preacher you follow' else 'New lesson at a mosque you follow' end,
    p_name_ar || ': ' || p_title_ar, p_name_en || ': ' || p_title_en, '/lessons/requests/' || p_request)
  from (select lf.profile_id, bool_or(lf.kind = 'preacher') as preacher
          from public.lesson_follows lf
         where (lf.kind = 'preacher' and lf.target_id = p_preacher)
            or (lf.kind = 'mosque' and lf.target_id = any(p_mosques))
         group by lf.profile_id) f
  where f.profile_id is distinct from p_actor;
end; $$;

-- ---------------------------------------------------------------------------
-- Lessons: new, cancelled, moved, removed
-- ---------------------------------------------------------------------------
-- Same as 20261101095634; the new-lesson notice names its reason.
create or replace function public.lessons_add(p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  pr public.preachers;
  req uuid := gen_random_uuid();
  ser uuid;
  mosque uuid := nullif(p->>'mosque_id', '')::uuid;
  nm jsonb := p->'new_mosque';
  dates date[];
  d date;
  i integer := 0;
  today date := public.lessons_today();
  title_ar text := btrim(coalesce(p->>'title_ar', ''));
  title_en text := btrim(coalesce(p->>'title_en', ''));
begin
  select * into pr from public.preachers where id = (p->>'preacher_id')::uuid;
  if not found then raise exception 'Preacher not found' using errcode = '22023'; end if;
  select array_agg(distinct x::date order by x::date) into dates
    from jsonb_array_elements_text(coalesce(p->'dates', '[]'::jsonb)) x;
  if dates is null or cardinality(dates) not between 1 and 40 then
    raise exception 'Between 1 and 40 dates are required' using errcode = '22023';
  end if;
  if dates[1] < today - 60 or dates[cardinality(dates)] > today + 400 then
    raise exception 'Dates must be within the last 60 days or the next year' using errcode = '22023';
  end if;
  if nm is not null and jsonb_typeof(nm) = 'object' then
    insert into public.mosques(name_ar, name_en, district_id, latitude, longitude, maps_url, facilities, created_by)
    values (btrim(nm->>'name_ar'), btrim(coalesce(nm->>'name_en', '')), nm->>'district_id',
      (nm->>'latitude')::double precision, (nm->>'longitude')::double precision, nullif(nm->>'maps_url', ''),
      coalesce(array(select jsonb_array_elements_text(nm->'facilities')), '{}'), actor)
    returning id into mosque;
    perform private.lessons_audit('addMosque', btrim(nm->>'name_ar'), coalesce(nullif(btrim(nm->>'name_en'), ''), btrim(nm->>'name_ar')));
  elsif mosque is null or not exists (select 1 from public.mosques where id = mosque) then
    raise exception 'Choose a mosque' using errcode = '22023';
  end if;

  if cardinality(dates) > 1 then
    insert into public.lesson_series(request_id, preacher_id, mosque_id, title_ar, title_en, type, topic,
      language, audience, slot, total, status)
    values (req, pr.id, mosque, title_ar, title_en, p->>'type', p->>'topic', coalesce(p->>'language', 'ar'),
      coalesce(p->>'audience', 'all'), p->>'slot', cardinality(dates), 'approved')
    returning id into ser;
  end if;
  foreach d in array dates loop
    i := i + 1;
    insert into public.lessons(request_id, series_id, seq, type, topic, title_ar, title_en, description_ar,
      description_en, preacher_id, mosque_id, lesson_date, slot, exact_time, duration_minutes, language, interpretation,
      audience, women_section, streamed, notify_followers, status, source, submitted_by, reviewed_by, reviewed_at)
    values (req, ser, case when ser is null then null else i end, p->>'type', p->>'topic', title_ar, title_en,
      coalesce(p->>'description_ar', ''), coalesce(p->>'description_en', ''), pr.id, mosque, d, p->>'slot',
      nullif(p->>'exact_time', '')::time, nullif(p->>'duration_minutes', '')::integer, coalesce(p->>'language', 'ar'), nullif(p->>'interpretation', ''),
      coalesce(p->>'audience', 'all'), coalesce((p->>'women_section')::boolean, false),
      coalesce((p->>'streamed')::boolean, false), coalesce((p->>'notify_followers')::boolean, true),
      'approved', 'admin', actor, actor, now());
  end loop;

  perform private.lessons_audit('add', title_ar || ' — ' || pr.name_ar,
    coalesce(nullif(title_en, ''), title_ar) || ', ' || coalesce(nullif(pr.name_en, ''), pr.name_ar), pr.id);
  if coalesce((p->>'notify_followers')::boolean, true) then
    perform private.lessons_new_lesson_notice(req, pr.id, array[mosque], pr.name_ar,
      coalesce(nullif(pr.name_en, ''), pr.name_ar), title_ar, coalesce(nullif(title_en, ''), title_ar), actor);
  end if;
  return req;
end; $$;

-- Same as 20261029103349; the new-lesson notice names its reason.
create or replace function public.lessons_review(p_requests uuid[], p_decision text, p_reason text default null,
  p_mosque uuid default null) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  r record;
  names record;
  n integer := 0;
  next_status text;
  reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  if p_decision not in ('approve','reject') then raise exception 'Unknown decision' using errcode = '22023'; end if;
  if p_decision = 'reject' and (reason is null or char_length(reason) < 3) then
    raise exception 'A reason is required to reject' using errcode = '22023';
  end if;
  if p_mosque is not null and not exists (select 1 from public.mosques where id = p_mosque) then
    raise exception 'Choose a mosque' using errcode = '22023';
  end if;
  next_status := case when p_decision = 'approve' then 'approved' else 'rejected' end;
  for r in
    select distinct on (l.request_id) l.request_id, l.preacher_id, l.title_ar, l.title_en, l.notify_followers
      from public.lessons l
     where l.request_id = any(p_requests) and l.status = 'pending'
     order by l.request_id, l.lesson_date
  loop
    if next_status = 'approved' then
      update public.lessons set mosque_id = coalesce(mosque_id, p_mosque)
       where request_id = r.request_id and status = 'pending';
      update public.lesson_series set mosque_id = coalesce(mosque_id, p_mosque)
       where request_id = r.request_id and status = 'pending';
      if exists (select 1 from public.lessons where request_id = r.request_id and status = 'pending' and mosque_id is null) then
        raise exception 'Choose a mosque for this request' using errcode = '22023';
      end if;
    end if;
    update public.lessons set status = next_status, reviewed_by = actor, reviewed_at = now(),
        rejection_reason = case when next_status = 'rejected' then reason end, updated_at = now()
      where request_id = r.request_id and status = 'pending';
    update public.lesson_series set status = next_status where request_id = r.request_id and status = 'pending';
    n := n + 1;
    select * into names from private.preacher_names(r.preacher_id);
    perform private.lessons_log(p_decision, r.title_ar || ' — ' || names.name_ar,
      coalesce(nullif(r.title_en, ''), r.title_ar) || ', ' || names.name_en, r.preacher_id, reason);
    if next_status = 'approved' and r.notify_followers then
      perform private.lessons_new_lesson_notice(r.request_id, r.preacher_id,
        array(select mosque_id from public.lessons where request_id = r.request_id),
        names.name_ar, names.name_en, r.title_ar, coalesce(nullif(r.title_en, ''), r.title_ar), actor);
    end if;
  end loop;
  return n;
end; $$;

-- Same as 20261029103349, for the whole audience; the count is who was told.
create or replace function public.lessons_cancel_lesson(p_lesson uuid, p_reason text) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  l public.lessons;
  n integer;
  reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  select * into l from public.lessons where id = p_lesson for update;
  if not found or l.status <> 'approved' or l.lesson_date < public.lessons_today() then
    raise exception 'Only an upcoming approved session can be cancelled' using errcode = '22023';
  end if;
  if reason is null then raise exception 'A reason is required' using errcode = '22023'; end if;
  update public.lessons set status = 'cancelled', cancel_reason = reason, updated_at = now() where id = l.id;
  select count(*) into n from private.lesson_audience(l) a where a is distinct from actor;
  perform private.lessons_notify(a, 'alert', 'أُلغي موعد: ' || l.title_ar,
    'Cancelled: ' || coalesce(nullif(l.title_en, ''), l.title_ar),
    to_char(l.lesson_date, 'YYYY-MM-DD') || ' — ' || reason, to_char(l.lesson_date, 'YYYY-MM-DD') || ': ' || reason,
    '/lessons/lesson/' || l.id)
  from private.lesson_audience(l) a where a is distinct from actor;
  perform private.lessons_log('cancel', l.title_ar || ' — ' || to_char(l.lesson_date, 'YYYY-MM-DD'),
    coalesce(nullif(l.title_en, ''), l.title_ar) || ', ' || to_char(l.lesson_date, 'YYYY-MM-DD'), l.preacher_id, reason);
  return n;
end; $$;

-- Same as 20261101095634, plus: the whole audience hears, including a new
-- mosque's followers, and reminders move with the date (the prayer times live
-- in the app, which puts them on the exact minute when it next opens).
create or replace function public.lessons_edit_lesson(p_lesson uuid, p jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  l public.lessons;
  edited public.lessons;
begin
  select * into l from public.lessons where id = p_lesson for update;
  if not found then raise exception 'Lesson not found' using errcode = '22023'; end if;
  if l.status not in ('approved','pending') then
    raise exception 'Only pending or approved sessions can be edited' using errcode = '22023';
  end if;
  if p ? 'mosque_id' and not exists (select 1 from public.mosques where id = (p->>'mosque_id')::uuid) then
    raise exception 'Choose a mosque' using errcode = '22023';
  end if;
  update public.lessons set
    title_ar = coalesce(nullif(btrim(p->>'title_ar'), ''), title_ar),
    title_en = coalesce(p->>'title_en', title_en),
    description_ar = coalesce(p->>'description_ar', description_ar),
    description_en = coalesce(p->>'description_en', description_en),
    type = coalesce(p->>'type', type),
    topic = coalesce(p->>'topic', topic),
    mosque_id = coalesce((p->>'mosque_id')::uuid, mosque_id),
    lesson_date = coalesce((p->>'lesson_date')::date, lesson_date),
    slot = coalesce(p->>'slot', slot),
    exact_time = case when p ? 'exact_time' then nullif(p->>'exact_time', '')::time else exact_time end,
    duration_minutes = case when p ? 'duration_minutes' then nullif(p->>'duration_minutes', '')::integer else duration_minutes end,
    language = coalesce(p->>'language', language),
    interpretation = case when p ? 'interpretation' then nullif(p->>'interpretation', '') else interpretation end,
    audience = coalesce(p->>'audience', audience),
    women_section = coalesce((p->>'women_section')::boolean, women_section),
    streamed = coalesce((p->>'streamed')::boolean, streamed),
    updated_at = now()
  where id = l.id
  returning * into edited;
  if l.status = 'approved' and edited.lesson_date >= public.lessons_today()
    and (edited.lesson_date, edited.slot, edited.exact_time, edited.mosque_id)
      is distinct from (l.lesson_date, l.slot, l.exact_time, l.mosque_id) then
    if edited.lesson_date <> l.lesson_date then
      update public.lesson_reminders set remind_at = remind_at + (edited.lesson_date - l.lesson_date) * interval '1 day'
       where lesson_id = l.id;
    end if;
    perform private.lessons_notify(x.a, 'clock', 'تغيّر موعد درس', 'A lesson time or place changed',
      edited.title_ar || ' — ' || to_char(edited.lesson_date, 'YYYY-MM-DD'),
      coalesce(nullif(edited.title_en, ''), edited.title_ar) || ', ' || to_char(edited.lesson_date, 'YYYY-MM-DD'),
      '/lessons/lesson/' || l.id)
    from (select private.lesson_audience(l) as a union select private.lesson_audience(edited)) x
    where x.a is distinct from actor;
  end if;
  perform private.lessons_audit('edit', l.title_ar, coalesce(nullif(l.title_en, ''), l.title_ar), l.preacher_id);
end; $$;

-- Same as 20261022125222, plus: whoever expected their upcoming lessons is
-- told once, before the lessons and follows are gone.
create or replace function public.lessons_remove_preacher(p_preacher uuid) returns integer
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); names record; n integer;
begin
  select * into names from private.preacher_names(p_preacher);
  if names.name_ar is null then raise exception 'Preacher not found' using errcode = '22023'; end if;
  select count(*) into n from public.lessons where preacher_id = p_preacher;
  perform private.lessons_notify(x.a, 'alert', 'أُلغيت دروس ' || names.name_ar, 'Lessons cancelled: ' || names.name_en,
    'أُلغيت الدروس القادمة لهذا الداعية.', 'The upcoming lessons by this preacher were cancelled.', '/lessons')
  from (select distinct private.lesson_audience(l) as a from public.lessons l
         where l.preacher_id = p_preacher and l.status = 'approved' and l.lesson_date >= public.lessons_today()) x
  where x.a is distinct from actor;
  delete from public.lesson_follows where kind = 'preacher' and target_id = p_preacher;
  delete from public.preachers where id = p_preacher;
  perform private.lessons_audit('removePreacher', names.name_ar, names.name_en);
  return n;
end; $$;

-- ---------------------------------------------------------------------------
-- A streamed lesson goes live
-- ---------------------------------------------------------------------------
-- Whether a stream at p_at (Riyadh time) can be this lesson. The server has no
-- prayer times, so a slot is a window wide enough for every season and city:
-- it only has to tell a preacher's Isha lesson from a stream that morning.
create function private.lesson_is_near(l public.lessons, p_at timestamp) returns boolean
language sql immutable set search_path = '' as $$
  select case when l.exact_time is not null then
      p_at between l.lesson_date + l.exact_time - interval '1 hour'
        and l.lesson_date + l.exact_time + make_interval(mins => coalesce(l.duration_minutes, 120))
    else p_at::time between
      case l.slot when 'fajr' then time '03:00' when 'dhuhr' then time '11:00' when 'asr' then time '14:30'
        when 'maghrib' then time '16:30' else time '18:00' end
      and case l.slot when 'fajr' then time '07:00' when 'dhuhr' then time '14:30' when 'asr' then time '17:00'
        when 'maghrib' then time '20:00' else time '23:59' end
    end;
$$;

-- Runs inside the state change that puts a broadcast on air, so nothing here
-- may stop a broadcast: a failure costs the alert, never the live.
create function private.lesson_live_alerts() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  at_riyadh timestamp := now() at time zone 'Asia/Riyadh';
  l public.lessons;
  names record;
begin
  if new.state <> 'live' or new.hidden_from_discovery or (tg_op = 'UPDATE' and old.state = 'live') then
    return null;
  end if;
  select ls.* into l from public.lessons ls
    join public.preachers p on p.id = ls.preacher_id
   where p.linked_profile_id = new.owner_id and ls.streamed and ls.status = 'approved'
     and ls.lesson_date = at_riyadh::date and private.lesson_is_near(ls, at_riyadh)
   order by ls.exact_time nulls last, array_position(array['isha','maghrib','asr','dhuhr','fajr'], ls.slot)
   limit 1;
  if not found then return null; end if;
  select * into names from private.preacher_names(l.preacher_id);
  perform private.lessons_alert(a, 'radio', 'بدأ البث: ' || l.title_ar,
    'Live now: ' || coalesce(nullif(l.title_en, ''), l.title_ar),
    'مع ' || names.name_ar, 'With ' || names.name_en, '/lessons/lesson/' || l.id,
    interval '30 minutes', 'live:' || new.id)
  from private.lesson_audience(l) a
  where a is distinct from new.owner_id
    and not exists (select 1 from public.follows f
      where f.follower_profile_id = a and f.target_id = new.owner_id::text);
  return null;
exception when others then
  raise warning 'Lesson live alert failed: %', sqlerrm;
  return null;
end; $$;
create trigger lesson_live_alerts after insert or update of state on public.broadcast_sessions
  for each row execute function private.lesson_live_alerts();

-- ---------------------------------------------------------------------------
-- Due reminders and the evening digest
-- ---------------------------------------------------------------------------
-- As claim_due_lesson_reminders() in 20261028133020, writing the notice only:
-- the queue below sends it. A reminder is no use two hours late.
create function private.lessons_emit_due_reminders() returns void
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  t_ar text; t_en text; b_ar text; b_en text;
  prayer_ar text; prayer_en text;
begin
  for r in
    select lr.profile_id, lr.lesson_id, lr.lead, l.status, l.lesson_date, l.slot,
      l.title_ar as lesson_ar, coalesce(nullif(l.title_en, ''), l.title_ar) as lesson_en,
      m.name_ar as mosque_ar, coalesce(nullif(m.name_en, ''), m.name_ar) as mosque_en
    from public.lesson_reminders lr
    join public.lessons l on l.id = lr.lesson_id
    left join public.mosques m on m.id = l.mosque_id
    where lr.sent_at is null and lr.remind_at <= now() and lr.remind_at > now() - interval '6 hours'
    order by lr.remind_at
    limit 500
    for update of lr skip locked
  loop
    update public.lesson_reminders set sent_at = now()
      where lesson_reminders.profile_id = r.profile_id and lesson_reminders.lesson_id = r.lesson_id;
    if r.status <> 'approved' or r.lesson_date < public.lessons_today() or public.is_banned(r.profile_id) then
      continue;
    end if;
    select v.ar, v.en into prayer_ar, prayer_en from (values
      ('fajr', 'الفجر', 'Fajr'), ('dhuhr', 'الظهر', 'Dhuhr'), ('asr', 'العصر', 'Asr'),
      ('maghrib', 'المغرب', 'Maghrib'), ('isha', 'العشاء', 'Isha')) v(slot, ar, en)
      where v.slot = r.slot;
    t_ar := 'تذكير بدرس: ' || r.lesson_ar;
    t_en := 'Lesson reminder: ' || r.lesson_en;
    b_ar := case r.lead
      when 'day' then 'غداً بعد صلاة ' || coalesce(prayer_ar, '')
      when '30' then 'يبدأ بعد نحو ٣٠ دقيقة'
      else 'اليوم بعد صلاة ' || coalesce(prayer_ar, '') end
      || coalesce(' في ' || r.mosque_ar, '') || '.';
    b_en := case r.lead
      when 'day' then 'Tomorrow after ' || coalesce(prayer_en, 'the prayer')
      when '30' then 'Starts in about 30 minutes'
      else 'Today after ' || coalesce(prayer_en, 'the prayer') end
      || coalesce(' at ' || r.mosque_en, '') || '.';
    perform private.lessons_alert(r.profile_id, 'clock', t_ar, t_en, b_ar, b_en,
      '/lessons/lesson/' || r.lesson_id, interval '2 hours', null);
  end loop;
end; $$;

-- Tomorrow's lessons for each account with any: the sessions it set a reminder
-- on or follows, once an evening at 9 PM Riyadh, after Isha everywhere it runs.
create function private.lessons_emit_digests(p_at timestamptz default now()) returns void
language plpgsql security definer set search_path = '' as $$
declare
  at_riyadh timestamp := p_at at time zone 'Asia/Riyadh';
  tomorrow date := at_riyadh::date + 1;
  r record;
begin
  if at_riyadh::time < time '21:00' then return; end if;
  insert into private.lesson_digest_days(day) values (tomorrow) on conflict do nothing;
  if not found then return; end if;
  for r in
    select a.profile_id, count(*) as n,
      (array_agg(l.id order by l.lesson_date, array_position(array['fajr','dhuhr','asr','maghrib','isha'], l.slot), l.id))[1] as first_lesson,
      (array_agg(l.title_ar order by array_position(array['fajr','dhuhr','asr','maghrib','isha'], l.slot), l.id))[1:3] as titles_ar,
      (array_agg(coalesce(nullif(l.title_en, ''), l.title_ar)
        order by array_position(array['fajr','dhuhr','asr','maghrib','isha'], l.slot), l.id))[1:3] as titles_en
    from public.lessons l
    cross join lateral private.lesson_audience(l) a(profile_id)
    left join public.lesson_preferences p on p.profile_id = a.profile_id
    where l.lesson_date = tomorrow and l.status = 'approved' and coalesce(p.evening_digest, true)
    group by a.profile_id
  loop
    perform private.lessons_alert(r.profile_id, 'calendar', 'دروس الغد', 'Tomorrow''s lessons',
      array_to_string(r.titles_ar, '، ') || case when r.n > 3 then ' وغيرها' else '' end,
      array_to_string(r.titles_en, ', ') || case when r.n > 3 then ' and more' else '' end,
      case when r.n = 1 then '/lessons/lesson/' || r.first_lesson else '/lessons' end,
      interval '3 hours', 'digest:' || tomorrow);
  end loop;
end; $$;

drop function public.claim_due_lesson_reminders();

-- ---------------------------------------------------------------------------
-- The queue (service role: the dispatch-organization-events function)
-- ---------------------------------------------------------------------------
-- As claim_org_v1_event_pushes: a failed send is retried by a later run, at
-- most five times, until its notice is read or stale.
create function public.claim_lesson_pushes()
returns table(notification_id uuid, token text, profile_id uuid, language_code text,
  title_ar text, title_en text, body_ar text, body_en text, route text, ttl_seconds integer)
language plpgsql security definer set search_path = '' as $$
begin
  perform private.lessons_emit_due_reminders();
  perform private.lessons_emit_digests();
  insert into private.lesson_notification_deliveries(notification_id, token)
    select n.id, d.token from public.lesson_notifications n
    join public.schedule_push_devices d on d.viewer_profile_id = n.profile_id
    left join public.notification_push_preferences p on p.viewer_profile_id = n.profile_id
    where n.read_at is null and n.push_until > now()
      and coalesce(p.lessons_enabled, true) and not public.is_banned(n.profile_id)
    on conflict do nothing;
  return query update private.lesson_notification_deliveries r
      set claimed_until = now() + interval '2 minutes', attempts = r.attempts + 1
    from public.lesson_notifications n, public.schedule_push_devices d
    where r.notification_id = n.id and r.token = d.token and (r.notification_id, r.token) in (
      select q.notification_id, q.token from private.lesson_notification_deliveries q
      join public.lesson_notifications qn on qn.id = q.notification_id
      where q.sent_at is null and q.attempts < 5 and (q.claimed_until is null or q.claimed_until < now())
        and qn.read_at is null and qn.push_until > now()
      order by qn.created_at limit 200 for update of q skip locked)
    returning r.notification_id, r.token, n.profile_id, d.language_code, n.title_ar, n.title_en, n.body_ar, n.body_en,
      n.route, greatest(ceil(extract(epoch from n.push_until - now()))::integer, 60);
end; $$;

create function public.lesson_push_sent(p_notification uuid, p_token text) returns void
language sql security definer set search_path = '' as $$
  update private.lesson_notification_deliveries set sent_at = now(), claimed_until = null
   where notification_id = p_notification and token = p_token;
$$;

revoke all on function private.lessons_alert(uuid, text, text, text, text, text, text, interval, text),
  private.lesson_audience(public.lessons),
  private.lessons_new_lesson_notice(uuid, uuid, uuid[], text, text, text, text, uuid),
  private.lesson_is_near(public.lessons, timestamp), private.lesson_live_alerts(),
  private.lessons_emit_due_reminders(), private.lessons_emit_digests(timestamptz)
  from public, anon, authenticated, service_role;
revoke all on function public.claim_lesson_pushes(), public.lesson_push_sent(uuid, text)
  from public, anon, authenticated;
grant execute on function public.claim_lesson_pushes(), public.lesson_push_sent(uuid, text) to service_role;

commit;
