-- Add-lesson, owner request 2026-11-03.
--
-- * A guest preacher: an admin can name a preacher for one lesson without
--   adding him to the list. He is a preachers row (every lesson needs one)
--   flagged one_off, hidden from the roster and the add-lesson list, and
--   created through lessons_add_guest_preacher(). With an email the admin
--   uses the normal lessons_upsert_preacher() and he joins the list.
-- * A hidden preacher (listed = false, a guest, or one loaded from a file)
--   was unreadable to the public, so his lessons showed without a name. A
--   preacher whose lessons are public is now readable too; listed still
--   decides who appears in the public lists.
-- * "Not set yet" area in Khobar: mosques loaded from a file that names no
--   neighbourhood wait there until an admin moves each to its real area.
begin;

alter table public.preachers add column one_off boolean not null default false;
comment on column public.preachers.one_off is
  'A guest named for one lesson. Never listed, not in the roster or the add-lesson list.';

create function public.lessons_add_guest_preacher(p_name text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  nm text := btrim(coalesce(p_name, ''));
  pid uuid;
begin
  if char_length(nm) not between 3 and 120 then
    raise exception 'Enter the preacher''s name' using errcode = '22023';
  end if;
  insert into public.preachers(name_ar, listed, one_off, created_by)
  values (nm, false, true, actor) returning id into pid;
  perform private.lessons_log('addGuest', nm, nm, pid, null);
  return pid;
end; $$;
revoke all on function public.lessons_add_guest_preacher(text) from public, anon;
grant execute on function public.lessons_add_guest_preacher(text) to authenticated;

-- A preacher with a public lesson can be read; listed still decides the lists.
drop policy preachers_read_public on public.preachers;
create policy preachers_read_public on public.preachers for select to anon
  using (listed or exists (select 1 from public.lessons l
    where l.preacher_id = preachers.id and l.status in ('approved','cancelled')));
drop policy preachers_read on public.preachers;
create policy preachers_read on public.preachers for select to authenticated
  using (listed or linked_profile_id = auth.uid() or public.is_lessons_admin()
    or exists (select 1 from public.lessons l
      where l.preacher_id = preachers.id and l.status in ('approved','cancelled')));

-- The roster leaves guests out.
create or replace function public.lessons_roster() returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select to_jsonb(p) || jsonb_build_object(
    'phone_mask', case when c.phone is null then null
      else left(c.phone, 2) || '•• ••• ' || right(c.phone, 3) end,
    'email_mask', private.mask_email(c.email),
    'active_keys', (select count(*) from private.preacher_keys k where k.preacher_id = p.id
      and k.revoked_at is null and (k.valid_until is null or k.valid_until > now())),
    'last_seen', (select max(k.last_used_at) from private.preacher_keys k where k.preacher_id = p.id),
    'pending_edits', (select count(*) from public.preacher_edits e where e.preacher_id = p.id and e.status = 'pending'),
    'lessons_30d', (select count(*) from public.lessons l where l.preacher_id = p.id
      and l.status = 'approved' and l.lesson_date between public.lessons_today() - 30 and public.lessons_today()))
  from public.preachers p
  left join private.preacher_contacts c on c.preacher_id = p.id
  where public.is_lessons_admin() and not p.one_off
  order by p.name_ar;
$$;

insert into public.mosque_districts(id, city, name_ar, name_en, sort)
values ('unassigned', 'khobar', 'غير محدد', 'Not set yet', 90);

commit;
