-- Lesson reminders were stored (lesson_reminders.remind_at) but nothing ever
-- read them, while the reminder sheet promised "Reminders arrive as a
-- notification in your inbox". The event dispatcher now claims due reminders
-- each minute: each one becomes a Lessons inbox notification once and is
-- returned with the viewer's push devices for a push.
begin;

alter table public.lesson_reminders add column sent_at timestamptz;
comment on column public.lesson_reminders.sent_at is
  'When the reminder was delivered (inbox and push). A new remind_at makes it due again.';

-- Changing when to be reminded (another lead, or the app recomputing the time
-- after the lesson moved) makes a delivered reminder due again.
create function private.lesson_reminder_rearm() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.remind_at is distinct from old.remind_at then new.sent_at := null; end if;
  return new;
end; $$;
create trigger lesson_reminder_rearm before update of remind_at on public.lesson_reminders
  for each row execute function private.lesson_reminder_rearm();
revoke all on function private.lesson_reminder_rearm() from public, anon, authenticated, service_role;

-- Service role only (the dispatcher). A reminder more than six hours late is
-- skipped rather than sent stale; a cancelled or past lesson is skipped too
-- (its cancellation already reached the inbox).
create function public.claim_due_lesson_reminders()
returns table(token text, profile_id uuid, language_code text, lesson_id uuid,
  title_ar text, title_en text, body_ar text, body_en text)
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
    perform private.lessons_notify(r.profile_id, 'clock', t_ar, t_en, b_ar, b_en,
      '/lessons/lesson/' || r.lesson_id);
    return query select d.token, r.profile_id, d.language_code, r.lesson_id, t_ar, t_en, b_ar, b_en
      from public.schedule_push_devices d where d.viewer_profile_id = r.profile_id;
  end loop;
end; $$;
revoke all on function public.claim_due_lesson_reminders() from public, anon, authenticated;
grant execute on function public.claim_due_lesson_reminders() to service_role;

commit;
