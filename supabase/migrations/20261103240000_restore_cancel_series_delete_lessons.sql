-- Owner round 3, 2026-11-03: undo and bulk actions for lessons.
--
-- * lessons_restore_lesson: a cancelled session goes back to approved (and its
--   whole series' cancelled upcoming sessions with it when asked). Whoever was
--   told it was cancelled is told it is back on.
-- * lessons_cancel_series: every upcoming approved session of a series at once.
--   Each person hears once, not once per session.
-- * lessons_delete_lesson / lessons_delete_series: for mistakes and wrong
--   imports, past or upcoming. A series left with one session becomes a single
--   lesson; one with more is renumbered. Whoever expected an upcoming session is
--   told once, before it goes.
-- Editing a past session needs no change: lessons_edit_lesson never refused it
-- (only the screen did).
begin;

create function public.lessons_restore_lesson(p_lesson uuid, p_whole_series boolean default false) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  l public.lessons;
  s public.lessons;
  n integer := 0;
  today date := public.lessons_today();
begin
  select * into l from public.lessons where id = p_lesson for update;
  if not found or l.status <> 'cancelled' then
    raise exception 'Only a cancelled session can be restored' using errcode = '22023';
  end if;
  for s in
    select * from public.lessons
    where id = l.id or (p_whole_series and series_id is not null and series_id = l.series_id
      and status = 'cancelled' and lesson_date >= today)
    order by lesson_date for update
  loop
    update public.lessons set status = 'approved', cancel_reason = null, updated_at = now() where id = s.id;
    if s.lesson_date >= today then
      perform private.lessons_notify(a, 'sparkle', 'عاد موعد: ' || s.title_ar,
        'Back on: ' || coalesce(nullif(s.title_en, ''), s.title_ar),
        to_char(s.lesson_date, 'YYYY-MM-DD'), to_char(s.lesson_date, 'YYYY-MM-DD'), '/lessons/lesson/' || s.id)
      from private.lesson_audience(s) a where a is distinct from actor;
    end if;
    n := n + 1;
  end loop;
  perform private.lessons_log('restore', l.title_ar || ' — ' || to_char(l.lesson_date, 'YYYY-MM-DD'),
    coalesce(nullif(l.title_en, ''), l.title_ar) || ', ' || to_char(l.lesson_date, 'YYYY-MM-DD'), l.preacher_id,
    case when n > 1 then n || ' sessions' else null end);
  return n;
end; $$;

create function public.lessons_cancel_series(p_series uuid, p_reason text) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  ser public.lesson_series;
  ids uuid[];
  n integer;
  reason text := nullif(btrim(coalesce(p_reason, '')), '');
  today date := public.lessons_today();
begin
  select * into ser from public.lesson_series where id = p_series;
  if not found then raise exception 'Series not found' using errcode = '22023'; end if;
  if reason is null then raise exception 'A reason is required' using errcode = '22023'; end if;
  with c as (
    update public.lessons set status = 'cancelled', cancel_reason = reason, updated_at = now()
    where series_id = p_series and status = 'approved' and lesson_date >= today returning id)
  select array_agg(id) into ids from c;
  n := coalesce(cardinality(ids), 0);
  if n = 0 then raise exception 'No upcoming session to cancel' using errcode = '22023'; end if;
  perform private.lessons_notify(x.a, 'alert', 'أُلغيت سلسلة: ' || ser.title_ar,
    'Series cancelled: ' || coalesce(nullif(ser.title_en, ''), ser.title_ar),
    n || ' — ' || reason, n || ': ' || reason, '/lessons/series/' || p_series)
  from (select distinct private.lesson_audience(l) as a from public.lessons l
         where l.id = any(ids)) x
  where x.a is distinct from actor;
  perform private.lessons_log('cancelSeries', ser.title_ar, coalesce(nullif(ser.title_en, ''), ser.title_ar), ser.preacher_id,
    n || ' sessions. ' || reason);
  return n;
end; $$;

-- Takes a session (or a whole series) out for good.
create function private.lessons_drop(p_lessons uuid[], p_reason text, p_title_ar text, p_title_en text, p_preacher uuid, p_actor uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  -- Whoever expected an upcoming session hears once, before it goes.
  perform private.lessons_notify(x.a, 'alert', 'أُزيل موعد: ' || p_title_ar, 'Removed: ' || p_title_en,
    coalesce(p_reason, ''), coalesce(p_reason, ''), '/lessons')
  from (select distinct private.lesson_audience(l) as a from public.lessons l
         where l.id = any(p_lessons) and l.status = 'approved' and l.lesson_date >= public.lessons_today()) x
  where x.a is distinct from p_actor;
end; $$;
revoke all on function private.lessons_drop(uuid[], text, text, text, uuid, uuid) from public, anon, authenticated;

create function public.lessons_delete_lesson(p_lesson uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  l public.lessons;
  reason text := nullif(btrim(coalesce(p_reason, '')), '');
  left_n integer;
begin
  select * into l from public.lessons where id = p_lesson for update;
  if not found then raise exception 'Lesson not found' using errcode = '22023'; end if;
  if l.status = 'approved' and l.lesson_date >= public.lessons_today() and reason is null then
    raise exception 'A reason is required' using errcode = '22023';
  end if;
  perform private.lessons_drop(array[l.id], reason, l.title_ar, coalesce(nullif(l.title_en, ''), l.title_ar), l.preacher_id, actor);
  delete from public.lessons where id = l.id;
  if l.series_id is not null then
    select count(*) into left_n from public.lessons where series_id = l.series_id;
    if left_n = 0 then
      delete from public.lesson_follows where kind = 'series' and target_id = l.series_id;
      delete from public.lesson_series where id = l.series_id;
    elsif left_n = 1 then
      update public.lessons set series_id = null, seq = null where series_id = l.series_id;
      delete from public.lesson_follows where kind = 'series' and target_id = l.series_id;
      delete from public.lesson_series where id = l.series_id;
    else
      update public.lesson_series set total = left_n where id = l.series_id;
      update public.lessons x set seq = r.n from
        (select id, row_number() over (order by lesson_date, id) as n from public.lessons where series_id = l.series_id) r
        where x.id = r.id;
    end if;
  end if;
  perform private.lessons_log('deleteLesson', l.title_ar || ' — ' || to_char(l.lesson_date, 'YYYY-MM-DD'),
    coalesce(nullif(l.title_en, ''), l.title_ar) || ', ' || to_char(l.lesson_date, 'YYYY-MM-DD'), l.preacher_id, reason);
end; $$;

create function public.lessons_delete_series(p_series uuid, p_reason text default null) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  ser public.lesson_series;
  ids uuid[];
  reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  select * into ser from public.lesson_series where id = p_series for update;
  if not found then raise exception 'Series not found' using errcode = '22023'; end if;
  select array_agg(id) into ids from public.lessons where series_id = p_series;
  ids := coalesce(ids, '{}');
  if reason is null and exists (select 1 from public.lessons where id = any(ids) and status = 'approved' and lesson_date >= public.lessons_today()) then
    raise exception 'A reason is required' using errcode = '22023';
  end if;
  perform private.lessons_drop(ids, reason, ser.title_ar, coalesce(nullif(ser.title_en, ''), ser.title_ar), ser.preacher_id, actor);
  delete from public.lesson_follows where kind = 'series' and target_id = p_series;
  delete from public.lesson_series where id = p_series;   -- its sessions go with it
  perform private.lessons_log('deleteSeries', ser.title_ar, coalesce(nullif(ser.title_en, ''), ser.title_ar), ser.preacher_id,
    cardinality(ids) || ' sessions' || coalesce('. ' || reason, ''));
  return cardinality(ids);
end; $$;

revoke all on function public.lessons_restore_lesson(uuid, boolean), public.lessons_cancel_series(uuid, text),
  public.lessons_delete_lesson(uuid, text), public.lessons_delete_series(uuid, text) from public, anon;
grant execute on function public.lessons_restore_lesson(uuid, boolean), public.lessons_cancel_series(uuid, text),
  public.lessons_delete_lesson(uuid, text), public.lessons_delete_series(uuid, text) to authenticated;

commit;
