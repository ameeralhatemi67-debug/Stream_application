-- claim_due_schedule_reminders() (20260930010000) has never run. Its
-- RETURNS TABLE output columns schedule_id, token and occurrence_at are
-- PL/pgSQL variables, so the bare `on conflict (schedule_id, token,
-- occurrence_at)` inference list is ambiguous and every call fails with
-- 42702 before any reminder is claimed. Name the primary key instead; the
-- body is otherwise unchanged and existing grants (service_role only) stay.
begin;

create or replace function public.claim_due_schedule_reminders()
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
  on conflict on constraint schedule_reminder_deliveries_pkey do update set
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
