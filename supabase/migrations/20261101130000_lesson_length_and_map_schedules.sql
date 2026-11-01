-- What the new map needs from the server (owner request 2026-11-01).
--
-- * lessons.duration_minutes: how long a lesson runs, so the map knows when
--   "at the mosque now" ends and how many minutes are left. Empty means the
--   default for its type, which the app holds (lesson 60, lecture 75, talk 15).
-- * list_map_schedules(): every channel's published schedule in one read, for
--   "goes live soon" on the pins. list_upcoming_schedules() takes one channel,
--   which would mean one request per pin.
--
-- Both are additions: older app versions keep working. lessons_add and
-- lessons_edit_lesson change only to carry the new field.

alter table public.lessons add column duration_minutes integer
  check (duration_minutes between 5 and 480);
comment on column public.lessons.duration_minutes is
  'Minutes the lesson runs. Null means the default for its type, held by the app.';

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
    perform private.lessons_notify(f.profile_id, 'sparkle', 'درس جديد من داعية تتابعه', 'New lesson from a preacher you follow',
      pr.name_ar || ': ' || title_ar, coalesce(nullif(pr.name_en, ''), pr.name_ar) || ': ' || coalesce(nullif(title_en, ''), title_ar),
      '/lessons/requests/' || req)
    from (select distinct f.profile_id from public.lesson_follows f
           where (f.kind = 'preacher' and f.target_id = pr.id)
              or (f.kind = 'mosque' and f.target_id = mosque)) f
    where f.profile_id is distinct from actor;
  end if;
  return req;
end; $$;

create or replace function public.lessons_edit_lesson(p_lesson uuid, p jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  l public.lessons;
  moved boolean;
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
  where id = l.id;
  select (n.lesson_date, n.slot, n.exact_time, n.mosque_id) is distinct from (l.lesson_date, l.slot, l.exact_time, l.mosque_id)
    into moved from public.lessons n where n.id = l.id;
  if moved and l.status = 'approved' then
    perform private.lessons_notify(r.profile_id, 'clock', 'تغيّر موعد درس', 'A lesson time or place changed',
      l.title_ar, coalesce(nullif(l.title_en, ''), l.title_ar), '/lessons/lesson/' || l.id)
    from public.lesson_reminders r where r.lesson_id = l.id;
  end if;
  perform private.lessons_audit('edit', l.title_ar, coalesce(nullif(l.title_en, ''), l.title_ar), l.preacher_id);
end; $$;

-- Personal channels only: organizations are off, and their schedules hang on
-- the organization rather than on a publishing profile.
create function public.list_map_schedules() returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', s.id, 'streamer_profile_id', s.streamer_profile_id, 'kind', s.kind,
    'local_time', s.local_time, 'weekdays', s.weekdays,
    'one_time_start_at', s.one_time_start_at, 'title_en', s.title_en, 'title_ar', s.title_ar,
    'broadcast_type', s.broadcast_type, 'duration_minutes', s.duration_minutes)
  from public.upcoming_schedules s
  where s.organization_id is null
    and s.cancelled_at is null
    and public.can_publish_upcoming(s.streamer_profile_id)
    and (s.kind = 'weekly' or s.one_time_start_at > now());
$$;
revoke execute on function public.list_map_schedules() from public;
grant execute on function public.list_map_schedules() to anon, authenticated;
