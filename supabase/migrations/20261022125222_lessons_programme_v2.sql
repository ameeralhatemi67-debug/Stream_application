-- Mosque lessons, version 2 (owner decisions 2026-10-22).
--
-- Replaces 20261021142359 (the "Taysir" programme), which held no data on
-- hosted except its seeded districts:
--
-- * One platform-wide programme. No organization owns preachers, mosques or
--   lessons, and nothing has to be switched on per organization.
-- * Only admins run it: admins, master admins and lessons-only admins
--   (is_lessons_admin()). There are no coordinators and no preacher accounts.
-- * A preacher is a person in the admins' list, never an organization. An
--   admin can link a preacher card to an existing Hadayah Live account (a
--   preacher who also streams), but nobody needs an account to be a preacher.
-- * Admins can give a preacher a link instead of an account: a one-time key
--   (the first phone that opens it keeps access until revoked or an optional
--   end) or a timed key (any phone, between a start and an end). Only a hash
--   of each key and of the bound phone's id is stored. Through the link a
--   preacher sees his lessons, proposes edits to his card and requests
--   lessons; an admin approves each one and chooses the mosque.
-- * Every write goes through a security definer function that checks the
--   caller. Phone numbers stay private and each reveal is logged.
begin;

-- ---------------------------------------------------------------------------
-- Remove version 1 (its export wrapper is replaced at the end; the core
-- export stays in private).
-- ---------------------------------------------------------------------------
drop function public.export_my_data();

drop table public.taysir_notifications, public.taysir_preferences, public.taysir_attendance,
  public.taysir_follows, public.taysir_reminders, public.taysir_audit, public.taysir_flags,
  public.taysir_lesson_reports, public.taysir_lessons, public.taysir_series,
  private.taysir_invites, private.taysir_preacher_contacts, public.taysir_preachers,
  public.taysir_mosques, public.taysir_organizations, public.taysir_districts;
delete from public.user_permissions where permission_key in ('activities.coordinate', 'activities.submit');

do $$
declare f regprocedure;
begin
  for f in select p.oid::regprocedure from pg_proc p
    where p.pronamespace in ('public'::regnamespace, 'private'::regnamespace)
      and p.proname like 'taysir\_%'
  loop
    execute format('drop function %s', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Reference data and places
-- ---------------------------------------------------------------------------
create table public.mosque_districts (
  id text primary key check (id ~ '^[a-z0-9_]{2,40}$'),
  city text not null check (city in ('khobar','dhahran','dammam','qatif','other')),
  name_ar text not null check (char_length(name_ar) between 2 and 80),
  name_en text not null check (char_length(name_en) between 2 and 80),
  sort integer not null default 0
);
comment on table public.mosque_districts is
  'Lessons: neighbourhoods for the district-then-mosque picker. Public reference data.';

insert into public.mosque_districts(id, city, name_ar, name_en, sort) values
  ('aqrabiyah','khobar','العقربية','Al-Aqrabiyah',10),
  ('thuqbah','khobar','الثقبة','Al-Thuqbah',20),
  ('khobar_north','khobar','الخبر الشمالية','North Khobar',30),
  ('rakah_south','khobar','الراكة الجنوبية','South Al-Rakah',40),
  ('yarmouk','khobar','اليرموك','Al-Yarmouk',50),
  ('golden_belt','khobar','الحزام الذهبي','Golden Belt',60),
  ('doha_south','dhahran','الدوحة الجنوبية','South Doha',10),
  ('qusur','dhahran','القصور','Al-Qusur',20),
  ('faisaliyah','dammam','الفيصلية','Al-Faisaliyah',10),
  ('shati_west','dammam','الشاطئ الغربي','West Shati',20),
  ('badiyah','dammam','البادية','Al-Badiyah',30),
  ('rayyan','dammam','الريان','Al-Rayyan',40),
  ('qatif_central','qatif','وسط القطيف','Central Qatif',10);

create table public.mosques (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null check (char_length(btrim(name_ar)) between 2 and 120),
  name_en text not null default '' check (char_length(name_en) <= 120),
  district_id text not null references public.mosque_districts(id),
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  -- Only https Google Maps links: a javascript: URL here was a stored XSS in
  -- the original programme.
  maps_url text check (maps_url is null or maps_url ~
    '^https://((www\.)?google\.[a-z.]{2,8}/maps|maps\.google\.[a-z.]{2,8}/|maps\.app\.goo\.gl/|goo\.gl/maps/)'),
  facilities text[] not null default '{}'
    check (facilities <@ array['women','parking','access','interp','kids']::text[]),
  verified boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((latitude is null) = (longitude is null))
);
create index mosques_district_idx on public.mosques(district_id);
comment on table public.mosques is
  'Lessons: the mosque directory, kept by admins. Hidden ones (verified = false) are not public.';

-- ---------------------------------------------------------------------------
-- Preachers
-- ---------------------------------------------------------------------------
create table public.preachers (
  id uuid primary key default gen_random_uuid(),
  linked_profile_id uuid unique references public.profiles(id) on delete set null,
  name_ar text not null check (char_length(btrim(name_ar)) between 3 and 120),
  name_en text not null default '' check (char_length(name_en) <= 120),
  title_ar text not null default '' check (char_length(title_ar) <= 120),
  title_en text not null default '' check (char_length(title_en) <= 120),
  bio_ar text not null default '' check (char_length(bio_ar) <= 1500),
  bio_en text not null default '' check (char_length(bio_en) <= 1500),
  photo_url text check (photo_url is null or photo_url ~ '^https://'),
  city text not null default 'khobar' check (city in ('khobar','dhahran','dammam','qatif','other')),
  affiliation text not null default 'coop' check (affiliation in ('coop','ministry')),
  languages text[] not null default '{ar}' check (cardinality(languages) between 1 and 7
    and languages <@ array['ar','en','ur','tl','bn','ml','id']::text[]),
  listed boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.preachers is
  'Lessons: the preachers admins manage. A person, never an organization; optionally linked to a Hadayah Live account that also streams.';

create table private.preacher_contacts (
  preacher_id uuid primary key references public.preachers(id) on delete cascade,
  phone text not null check (phone ~ '^\+?[0-9]{7,15}$')
);

-- A preacher's link. once: the first phone to open it keeps it (until
-- revoked, or valid_until when set). window: any phone, from valid_from to
-- valid_until.
create table private.preacher_keys (
  id uuid primary key default gen_random_uuid(),
  preacher_id uuid not null references public.preachers(id) on delete cascade,
  kind text not null check (kind in ('once','window')),
  token_hash text not null unique,
  valid_from timestamptz,
  valid_until timestamptz,
  device_hash text,
  opened_at timestamptz,
  last_used_at timestamptz,
  revoked_at timestamptz,
  note text not null default '' check (char_length(note) <= 200),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (kind = 'once' or (valid_from is not null and valid_until is not null)),
  check (valid_from is null or valid_until is null or valid_until > valid_from)
);
create index preacher_keys_preacher_idx on private.preacher_keys(preacher_id);

-- Card changes a preacher proposed through his link, waiting for an admin.
create table public.preacher_edits (
  id uuid primary key default gen_random_uuid(),
  preacher_id uuid not null references public.preachers(id) on delete cascade,
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reason text check (char_length(reason) <= 600),
  created_at timestamptz not null default now(),
  decided_by uuid references public.profiles(id) on delete set null,
  decided_at timestamptz
);
create index preacher_edits_pending_idx on public.preacher_edits(status, created_at);

-- ---------------------------------------------------------------------------
-- Lessons
-- ---------------------------------------------------------------------------
create table public.lesson_series (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  preacher_id uuid not null references public.preachers(id) on delete cascade,
  mosque_id uuid references public.mosques(id),
  title_ar text not null, title_en text not null default '',
  type text not null check (type in ('lesson','lecture','talk')),
  topic text not null,
  language text not null,
  audience text not null,
  slot text not null check (slot in ('fajr','dhuhr','asr','maghrib','isha')),
  total integer not null check (total between 2 and 60),
  status text not null default 'pending'
    check (status in ('pending','approved','rejected','withdrawn')),
  created_at timestamptz not null default now(),
  check (status <> 'approved' or mosque_id is not null)
);
comment on table public.lesson_series is 'Lessons: a weekly series entered or requested as one request.';

create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  series_id uuid references public.lesson_series(id) on delete cascade,
  seq integer check (seq between 1 and 60),
  type text not null check (type in ('lesson','lecture','talk')),
  topic text not null check (topic in ('aqeedah','fiqh','tafsir','hadith','seerah','family','raqaiq','intro')),
  title_ar text not null check (char_length(btrim(title_ar)) between 3 and 160),
  title_en text not null default '' check (char_length(title_en) <= 160),
  description_ar text not null default '' check (char_length(description_ar) <= 2000),
  description_en text not null default '' check (char_length(description_en) <= 2000),
  preacher_id uuid not null references public.preachers(id) on delete cascade,
  mosque_id uuid references public.mosques(id),
  lesson_date date not null,
  slot text not null check (slot in ('fajr','dhuhr','asr','maghrib','isha')),
  exact_time time,
  language text not null default 'ar' check (language in ('ar','en','ur','tl','bn','ml','id')),
  interpretation text check (interpretation in ('ar','en','ur','tl','bn','ml','id')),
  audience text not null default 'all' check (audience in ('all','men','women','youth','kids')),
  women_section boolean not null default false,
  streamed boolean not null default false,
  notify_followers boolean not null default true,
  status text not null default 'pending'
    check (status in ('pending','approved','rejected','cancelled','withdrawn')),
  -- admin: entered by an admin. preacher: requested through a preacher link.
  source text not null default 'admin' check (source in ('admin','preacher')),
  preacher_note text not null default '' check (char_length(preacher_note) <= 600),
  rejection_reason text check (char_length(rejection_reason) <= 600),
  cancel_reason text check (char_length(cancel_reason) <= 600),
  submitted_by uuid references public.profiles(id) on delete set null,
  submitted_at timestamptz not null default now(),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  updated_at timestamptz not null default now(),
  check (interpretation is null or interpretation <> language),
  check ((series_id is null) = (seq is null)),
  check (status not in ('approved','cancelled') or mosque_id is not null)
);
create index lessons_date_idx on public.lessons(lesson_date);
create index lessons_mosque_idx on public.lessons(mosque_id, lesson_date);
create index lessons_preacher_idx on public.lessons(preacher_id, lesson_date);
create index lessons_request_idx on public.lessons(request_id);
create index lessons_status_idx on public.lessons(status);
create index lessons_series_idx on public.lessons(series_id);
comment on table public.lessons is
  'Lessons: one dated activity (a single lecture or one session of a series). Public once approved.';

create table public.lesson_reports (
  lesson_id uuid primary key references public.lessons(id) on delete cascade,
  attendance integer not null check (attendance between 0 and 100000),
  women integer not null default 0 check (women between 0 and 100000),
  issue text not null default 'none' check (issue in ('none','sound','time','place')),
  notes text not null default '' check (char_length(notes) <= 2000),
  submitted_by uuid references public.profiles(id) on delete set null,
  submitted_at timestamptz not null default now()
);
comment on table public.lesson_reports is 'Lessons: the after-lesson report (attendance, issues), filed by an admin.';

create table public.lesson_flags (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  kind text not null check (kind in ('time','place','cancel','other')),
  message text not null default '' check (char_length(message) <= 1000),
  reporter_id uuid references public.profiles(id) on delete cascade,
  status text not null default 'open' check (status in ('open','resolved')),
  created_at timestamptz not null default now(),
  resolved_by uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz
);
create index lesson_flags_status_idx on public.lesson_flags(status, created_at);
comment on table public.lesson_flags is 'Lessons: a viewer''s report of a wrong time or place.';

create table public.lesson_audit (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  -- Set when the action came through a preacher link.
  preacher_id uuid references public.preachers(id) on delete set null,
  action text not null,
  target_ar text not null default '',
  target_en text not null default '',
  created_at timestamptz not null default now()
);
create index lesson_audit_created_idx on public.lesson_audit(created_at desc);
comment on table public.lesson_audit is 'Lessons: read-only action log (who did what, when, to what).';

-- ---------------------------------------------------------------------------
-- Viewers' own data
-- ---------------------------------------------------------------------------
create table public.lesson_reminders (
  profile_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  lead text not null check (lead in ('adhan','30','day')),
  remind_at timestamptz not null,
  created_at timestamptz not null default now(),
  primary key (profile_id, lesson_id)
);
create index lesson_reminders_due_idx on public.lesson_reminders(remind_at);

create table public.lesson_follows (
  profile_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('preacher','series','mosque')),
  target_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (profile_id, kind, target_id)
);
create index lesson_follows_target_idx on public.lesson_follows(kind, target_id);

create table public.lesson_attendance (
  profile_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (profile_id, lesson_id)
);

create table public.lesson_preferences (
  profile_id uuid primary key default auth.uid() references public.profiles(id) on delete cascade,
  default_lead text not null default 'adhan' check (default_lead in ('adhan','30','day')),
  evening_digest boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.lesson_notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  icon text not null default 'bell',
  title_ar text not null, title_en text not null,
  body_ar text not null default '', body_en text not null default '',
  route text not null default '/lessons',
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index lesson_notifications_profile_idx on public.lesson_notifications(profile_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create function public.lessons_today() returns date
language sql stable set search_path = '' as $$
  select (now() at time zone 'Asia/Riyadh')::date;
$$;

-- The calling admin, or an error.
create function private.lessons_admin() returns uuid
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.is_lessons_admin() then
    raise exception 'Only admins manage preachers and lessons' using errcode = '42501';
  end if;
  return auth.uid();
end; $$;

-- A signed-in, not banned viewer, or an error.
create function private.lessons_viewer() returns uuid
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or public.is_banned(auth.uid()) then
    raise exception 'Sign in required' using errcode = '42501';
  end if;
  return auth.uid();
end; $$;

create function private.lessons_audit(p_action text, p_ar text, p_en text, p_preacher uuid default null)
returns void
language sql security definer set search_path = '' as $$
  insert into public.lesson_audit(actor_id, preacher_id, action, target_ar, target_en)
  values (auth.uid(), p_preacher, p_action, coalesce(p_ar, ''), coalesce(p_en, ''));
$$;

create function private.lessons_notify(p_profile uuid, p_icon text, p_title_ar text, p_title_en text,
  p_body_ar text, p_body_en text, p_route text) returns void
language sql security definer set search_path = '' as $$
  insert into public.lesson_notifications(profile_id, icon, title_ar, title_en, body_ar, body_en, route)
  select p_profile, p_icon, p_title_ar, p_title_en, coalesce(p_body_ar, ''), coalesce(p_body_en, ''), p_route
  where p_profile is not null;
$$;

-- Everyone who manages lessons, except the caller.
create function private.lessons_admins() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select distinct r.profile_id from public.user_roles r
   where r.role in ('master_admin','admin','lessons_admin') and r.organization_id is null
     and r.profile_id is distinct from auth.uid()
     and not public.is_banned(r.profile_id);
$$;

create function private.preacher_names(p_preacher uuid, out name_ar text, out name_en text)
language sql stable security definer set search_path = '' as $$
  select p.name_ar, coalesce(nullif(p.name_en, ''), p.name_ar)
  from public.preachers p where p.id = p_preacher;
$$;

create function private.clean_phone(p text) returns text
language sql immutable set search_path = '' as $$
  select nullif(regexp_replace(coalesce(p, ''), '[^0-9+]', '', 'g'), '');
$$;

create function private.sha256_hex(p text) returns text
language sql immutable set search_path = '' as $$
  select encode(sha256(convert_to(coalesce(p, ''), 'UTF8')), 'hex');
$$;

-- The key behind a preacher link, after checking it is usable now. A
-- one-time key binds to the first phone that opens it. Errors carry a hint
-- the app shows: revoked (or unknown), not_yet, expired, used.
create function private.preacher_key(p_key text, p_device text) returns private.preacher_keys
language plpgsql security definer set search_path = '' as $$
declare
  k private.preacher_keys;
  dev text;
begin
  select * into k from private.preacher_keys where token_hash = private.sha256_hex(p_key) for update;
  if not found or k.revoked_at is not null then
    raise exception 'This link is not valid' using errcode = '28000', hint = 'revoked';
  end if;
  if k.valid_from is not null and now() < k.valid_from then
    raise exception 'This link is not active yet' using errcode = '28000', hint = 'not_yet';
  end if;
  if k.valid_until is not null and now() > k.valid_until then
    raise exception 'This link has ended' using errcode = '28000', hint = 'expired';
  end if;
  if k.kind = 'once' then
    if char_length(coalesce(p_device, '')) < 16 then
      raise exception 'A device id is required' using errcode = '22023';
    end if;
    dev := private.sha256_hex(p_device);
    if k.device_hash is null then
      update private.preacher_keys set device_hash = dev, opened_at = now(), last_used_at = now()
       where id = k.id returning * into k;
    elsif k.device_hash <> dev then
      raise exception 'This link was already used on another phone' using errcode = '28000', hint = 'used';
    else
      update private.preacher_keys set last_used_at = now() where id = k.id returning * into k;
    end if;
  else
    update private.preacher_keys set last_used_at = now(), opened_at = coalesce(opened_at, now())
     where id = k.id returning * into k;
  end if;
  return k;
end; $$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------
alter table public.mosque_districts enable row level security;
alter table public.mosques enable row level security;
alter table public.preachers enable row level security;
alter table public.preacher_edits enable row level security;
alter table public.lesson_series enable row level security;
alter table public.lessons enable row level security;
alter table public.lesson_reports enable row level security;
alter table public.lesson_flags enable row level security;
alter table public.lesson_audit enable row level security;
alter table public.lesson_reminders enable row level security;
alter table public.lesson_follows enable row level security;
alter table public.lesson_attendance enable row level security;
alter table public.lesson_preferences enable row level security;
alter table public.lesson_notifications enable row level security;

revoke all on public.mosque_districts, public.mosques, public.preachers, public.preacher_edits,
  public.lesson_series, public.lessons, public.lesson_reports, public.lesson_flags, public.lesson_audit,
  public.lesson_reminders, public.lesson_follows, public.lesson_attendance, public.lesson_preferences,
  public.lesson_notifications
  from public, anon, authenticated;

-- The public catalogue (guests included); admins see everything.
grant select on public.mosque_districts, public.mosques, public.preachers, public.lesson_series,
  public.lessons to anon, authenticated;

create policy mosque_districts_read on public.mosque_districts for select
  to anon, authenticated using (true);

create policy mosques_read_public on public.mosques for select to anon using (verified);
create policy mosques_read on public.mosques for select to authenticated
  using (verified or public.is_lessons_admin());

create policy preachers_read_public on public.preachers for select to anon using (listed);
create policy preachers_read on public.preachers for select to authenticated
  using (listed or linked_profile_id = auth.uid() or public.is_lessons_admin());

create policy lesson_series_read_public on public.lesson_series for select to anon
  using (status = 'approved');
create policy lesson_series_read on public.lesson_series for select to authenticated
  using (status = 'approved' or public.is_lessons_admin());

create policy lessons_read_public on public.lessons for select to anon
  using (status in ('approved','cancelled'));
create policy lessons_read on public.lessons for select to authenticated
  using (status in ('approved','cancelled') or public.is_lessons_admin());

-- Admins only (and a reporter sees their own flags).
grant select on public.preacher_edits, public.lesson_reports, public.lesson_flags, public.lesson_audit
  to authenticated;
create policy preacher_edits_read on public.preacher_edits for select to authenticated
  using (public.is_lessons_admin());
create policy lesson_reports_read on public.lesson_reports for select to authenticated
  using (public.is_lessons_admin());
create policy lesson_flags_read on public.lesson_flags for select to authenticated
  using (reporter_id = auth.uid() or public.is_lessons_admin());
create policy lesson_audit_read on public.lesson_audit for select to authenticated
  using (public.is_lessons_admin());

-- Own rows only.
grant select, insert, update, delete on public.lesson_reminders, public.lesson_follows,
  public.lesson_attendance, public.lesson_preferences to authenticated;
create policy lesson_reminders_select on public.lesson_reminders for select to authenticated using (profile_id = auth.uid());
create policy lesson_reminders_insert on public.lesson_reminders for insert to authenticated with check (
  profile_id = auth.uid() and exists (select 1 from public.lessons l
    where l.id = lesson_id and l.status = 'approved'));
create policy lesson_reminders_update on public.lesson_reminders for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy lesson_reminders_delete on public.lesson_reminders for delete to authenticated using (profile_id = auth.uid());

create policy lesson_follows_select on public.lesson_follows for select to authenticated using (profile_id = auth.uid());
create policy lesson_follows_insert on public.lesson_follows for insert to authenticated with check (profile_id = auth.uid());
create policy lesson_follows_update on public.lesson_follows for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy lesson_follows_delete on public.lesson_follows for delete to authenticated using (profile_id = auth.uid());

create policy lesson_attendance_select on public.lesson_attendance for select to authenticated using (profile_id = auth.uid());
create policy lesson_attendance_insert on public.lesson_attendance for insert to authenticated with check (
  profile_id = auth.uid() and exists (select 1 from public.lessons l
    where l.id = lesson_id and l.status = 'approved' and l.lesson_date <= public.lessons_today()));
create policy lesson_attendance_update on public.lesson_attendance for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy lesson_attendance_delete on public.lesson_attendance for delete to authenticated using (profile_id = auth.uid());

create policy lesson_preferences_select on public.lesson_preferences for select to authenticated using (profile_id = auth.uid());
create policy lesson_preferences_insert on public.lesson_preferences for insert to authenticated with check (profile_id = auth.uid());
create policy lesson_preferences_update on public.lesson_preferences for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy lesson_preferences_delete on public.lesson_preferences for delete to authenticated using (profile_id = auth.uid());

grant select, delete on public.lesson_notifications to authenticated;
create policy lesson_notifications_select on public.lesson_notifications for select to authenticated using (profile_id = auth.uid());
create policy lesson_notifications_delete on public.lesson_notifications for delete to authenticated using (profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------
create function public.lessons_my_roles() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('admin', public.is_lessons_admin(), 'master', public.is_master_admin());
$$;

-- ---------------------------------------------------------------------------
-- Preachers (admins)
-- ---------------------------------------------------------------------------
create function public.lessons_upsert_preacher(p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  pid uuid := nullif(p->>'id', '')::uuid;
  phone text := private.clean_phone(p->>'phone');
begin
  if pid is null then
    insert into public.preachers(name_ar, name_en, title_ar, title_en, bio_ar, bio_en, photo_url,
      city, affiliation, languages, listed, linked_profile_id, created_by)
    values (btrim(p->>'name_ar'), btrim(coalesce(p->>'name_en', '')), btrim(coalesce(p->>'title_ar', '')),
      btrim(coalesce(p->>'title_en', '')), coalesce(p->>'bio_ar', ''), coalesce(p->>'bio_en', ''),
      nullif(p->>'photo_url', ''), coalesce(p->>'city', 'khobar'), coalesce(p->>'affiliation', 'coop'),
      coalesce(nullif(array(select jsonb_array_elements_text(p->'languages')), '{}'), '{ar}'),
      coalesce((p->>'listed')::boolean, true), nullif(p->>'linked_profile_id', '')::uuid, actor)
    returning id into pid;
    perform private.lessons_audit('addPreacher', btrim(p->>'name_ar'),
      coalesce(nullif(btrim(p->>'name_en'), ''), btrim(p->>'name_ar')));
  else
    update public.preachers set
      name_ar = coalesce(nullif(btrim(p->>'name_ar'), ''), name_ar),
      name_en = coalesce(p->>'name_en', name_en),
      title_ar = coalesce(p->>'title_ar', title_ar), title_en = coalesce(p->>'title_en', title_en),
      bio_ar = coalesce(p->>'bio_ar', bio_ar), bio_en = coalesce(p->>'bio_en', bio_en),
      photo_url = case when p ? 'photo_url' then nullif(p->>'photo_url', '') else photo_url end,
      city = coalesce(p->>'city', city), affiliation = coalesce(p->>'affiliation', affiliation),
      languages = coalesce(nullif(array(select jsonb_array_elements_text(p->'languages')), '{}'), languages),
      listed = coalesce((p->>'listed')::boolean, listed),
      linked_profile_id = case when p ? 'linked_profile_id'
        then nullif(p->>'linked_profile_id', '')::uuid else linked_profile_id end,
      updated_at = now()
    where id = pid;
    if not found then raise exception 'Preacher not found' using errcode = '22023'; end if;
    perform private.lessons_audit('editPreacher', n.name_ar, n.name_en, pid) from private.preacher_names(pid) n;
  end if;
  if p ? 'phone' then
    if phone is null then
      delete from private.preacher_contacts where preacher_id = pid;
    else
      insert into private.preacher_contacts(preacher_id, phone) values (pid, phone)
      on conflict (preacher_id) do update set phone = excluded.phone;
    end if;
  end if;
  return pid;
end; $$;

-- Removes a preacher and every lesson, series and link of theirs.
create function public.lessons_remove_preacher(p_preacher uuid) returns integer
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); names record; n integer;
begin
  select * into names from private.preacher_names(p_preacher);
  if names.name_ar is null then raise exception 'Preacher not found' using errcode = '22023'; end if;
  select count(*) into n from public.lessons where preacher_id = p_preacher;
  delete from public.lesson_follows where kind = 'preacher' and target_id = p_preacher;
  delete from public.preachers where id = p_preacher;
  perform private.lessons_audit('removePreacher', names.name_ar, names.name_en);
  return n;
end; $$;

create function public.lessons_import_preachers(p_rows jsonb) returns integer
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); r jsonb; pid uuid; n integer := 0;
begin
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 500 then
    raise exception 'Up to 500 rows' using errcode = '22023';
  end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    insert into public.preachers(name_ar, name_en, city, affiliation, created_by)
    values (btrim(r->>'name'), '', coalesce(r->>'city', 'khobar'), coalesce(r->>'affiliation', 'coop'), actor)
    returning id into pid;
    if private.clean_phone(r->>'phone') is not null then
      insert into private.preacher_contacts(preacher_id, phone) values (pid, private.clean_phone(r->>'phone'));
    end if;
    n := n + 1;
  end loop;
  perform private.lessons_audit('import', 'استيراد ' || n || ' داعية', 'Imported ' || n || ' preachers');
  return n;
end; $$;

-- The list as admins see it: masked phone, link state, pending changes.
create function public.lessons_roster() returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select to_jsonb(p) || jsonb_build_object(
    'phone_mask', case when c.phone is null then null
      else left(c.phone, 2) || '•• ••• ' || right(c.phone, 3) end,
    'active_keys', (select count(*) from private.preacher_keys k where k.preacher_id = p.id
      and k.revoked_at is null and (k.valid_until is null or k.valid_until > now())),
    'last_seen', (select max(k.last_used_at) from private.preacher_keys k where k.preacher_id = p.id),
    'pending_edits', (select count(*) from public.preacher_edits e where e.preacher_id = p.id and e.status = 'pending'),
    'lessons_30d', (select count(*) from public.lessons l where l.preacher_id = p.id
      and l.status = 'approved' and l.lesson_date between public.lessons_today() - 30 and public.lessons_today()))
  from public.preachers p
  left join private.preacher_contacts c on c.preacher_id = p.id
  where public.is_lessons_admin()
  order by p.name_ar;
$$;

create function public.lessons_reveal_phone(p_preacher uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); phone text;
begin
  if not exists (select 1 from public.preachers where id = p_preacher) then
    raise exception 'Preacher not found' using errcode = '22023';
  end if;
  select c.phone into phone from private.preacher_contacts c where c.preacher_id = p_preacher;
  perform private.lessons_audit('phone', n.name_ar, n.name_en, p_preacher) from private.preacher_names(p_preacher) n;
  return phone;
end; $$;

-- ---------------------------------------------------------------------------
-- Preacher links (admins)
-- ---------------------------------------------------------------------------
create function public.lessons_create_key(p_preacher uuid, p_kind text,
  p_valid_from timestamptz default null, p_valid_until timestamptz default null, p_note text default '')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  token text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  k private.preacher_keys;
  names record;
begin
  select * into names from private.preacher_names(p_preacher);
  if names.name_ar is null then raise exception 'Preacher not found' using errcode = '22023'; end if;
  if p_kind not in ('once','window') then raise exception 'Unknown link kind' using errcode = '22023'; end if;
  if p_kind = 'window' and (p_valid_from is null or p_valid_until is null) then
    raise exception 'A timed link needs a start and an end' using errcode = '22023';
  end if;
  if p_valid_until is not null and p_valid_until <= now() then
    raise exception 'The end must be in the future' using errcode = '22023';
  end if;
  insert into private.preacher_keys(preacher_id, kind, token_hash, valid_from, valid_until, note, created_by)
  values (p_preacher, p_kind, private.sha256_hex(token),
    case when p_kind = 'window' then p_valid_from end, p_valid_until, coalesce(btrim(p_note), ''), actor)
  returning * into k;
  perform private.lessons_audit(case when p_kind = 'once' then 'keyOnce' else 'keyWindow' end,
    names.name_ar, names.name_en, p_preacher);
  return jsonb_build_object('id', k.id, 'token', token, 'kind', k.kind,
    'valid_from', k.valid_from, 'valid_until', k.valid_until);
end; $$;

create function public.lessons_preacher_keys(p_preacher uuid) returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', k.id, 'kind', k.kind, 'valid_from', k.valid_from,
      'valid_until', k.valid_until, 'opened_at', k.opened_at, 'last_used_at', k.last_used_at,
      'revoked_at', k.revoked_at, 'note', k.note, 'created_at', k.created_at,
      'bound', k.device_hash is not null)
    from private.preacher_keys k
   where k.preacher_id = p_preacher and public.is_lessons_admin()
   order by k.created_at desc;
$$;

create function public.lessons_revoke_key(p_key uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); pid uuid;
begin
  update private.preacher_keys set revoked_at = coalesce(revoked_at, now()) where id = p_key
  returning preacher_id into pid;
  if pid is null then raise exception 'Link not found' using errcode = '22023'; end if;
  perform private.lessons_audit('keyRevoke', n.name_ar, n.name_en, pid) from private.preacher_names(pid) n;
end; $$;

-- Approve or reject a card change a preacher proposed. Approving applies it.
create function public.lessons_decide_edit(p_edit uuid, p_approve boolean, p_reason text default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); e public.preacher_edits; x jsonb;
begin
  select * into e from public.preacher_edits where id = p_edit and status = 'pending' for update;
  if not found then raise exception 'Nothing to decide' using errcode = '22023'; end if;
  if p_approve then
    x := e.payload;
    update public.preachers set
      name_ar = coalesce(nullif(btrim(x->>'name_ar'), ''), name_ar),
      name_en = coalesce(x->>'name_en', name_en),
      title_ar = coalesce(x->>'title_ar', title_ar), title_en = coalesce(x->>'title_en', title_en),
      bio_ar = coalesce(x->>'bio_ar', bio_ar), bio_en = coalesce(x->>'bio_en', bio_en),
      languages = coalesce(nullif(array(select jsonb_array_elements_text(x->'languages')), '{}'), languages),
      updated_at = now()
    where id = e.preacher_id;
  end if;
  update public.preacher_edits set status = case when p_approve then 'approved' else 'rejected' end,
    reason = nullif(btrim(coalesce(p_reason, '')), ''), decided_by = actor, decided_at = now()
  where id = e.id;
  perform private.lessons_audit(case when p_approve then 'editApproved' else 'editRejected' end,
    n.name_ar, n.name_en, e.preacher_id) from private.preacher_names(e.preacher_id) n;
end; $$;

-- ---------------------------------------------------------------------------
-- Lessons (admins)
-- ---------------------------------------------------------------------------
-- Adds one lesson or a weekly series, published at once. The mosque is an
-- existing one or a new one added here.
create function public.lessons_add(p jsonb) returns uuid
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
      description_en, preacher_id, mosque_id, lesson_date, slot, exact_time, language, interpretation,
      audience, women_section, streamed, notify_followers, status, source, submitted_by, reviewed_by, reviewed_at)
    values (req, ser, case when ser is null then null else i end, p->>'type', p->>'topic', title_ar, title_en,
      coalesce(p->>'description_ar', ''), coalesce(p->>'description_en', ''), pr.id, mosque, d, p->>'slot',
      nullif(p->>'exact_time', '')::time, coalesce(p->>'language', 'ar'), nullif(p->>'interpretation', ''),
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

-- Approve or reject requests that came through a preacher link. Approving
-- needs a mosque: the one given here is set on every session without one.
create function public.lessons_review(p_requests uuid[], p_decision text, p_reason text default null,
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
    perform private.lessons_audit(p_decision, r.title_ar || ' — ' || names.name_ar,
      coalesce(nullif(r.title_en, ''), r.title_ar) || ', ' || names.name_en, r.preacher_id);
    if next_status = 'approved' and r.notify_followers then
      perform private.lessons_notify(f.profile_id, 'sparkle', 'درس جديد من داعية تتابعه', 'New lesson from a preacher you follow',
        names.name_ar || ': ' || r.title_ar, names.name_en || ': ' || coalesce(nullif(r.title_en, ''), r.title_ar),
        '/lessons/requests/' || r.request_id)
      from (select distinct f.profile_id from public.lesson_follows f
             where (f.kind = 'preacher' and f.target_id = r.preacher_id)
                or (f.kind = 'mosque' and f.target_id in (select mosque_id from public.lessons where request_id = r.request_id))) f
      where f.profile_id is distinct from actor;
    end if;
  end loop;
  return n;
end; $$;

-- Undo a decision the caller made in the last 15 minutes.
create function public.lessons_undo_review(p_requests uuid[]) returns integer
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); n integer;
begin
  update public.lessons set status = 'pending', reviewed_by = null, reviewed_at = null,
      rejection_reason = null, updated_at = now()
    where request_id = any(p_requests) and status in ('approved','rejected') and reviewed_by = actor
      and reviewed_at > now() - interval '15 minutes' and source = 'preacher';
  get diagnostics n = row_count;
  update public.lesson_series s set status = 'pending' where s.request_id = any(p_requests)
    and s.status in ('approved','rejected')
    and exists (select 1 from public.lessons l where l.series_id = s.id and l.status = 'pending');
  if n > 0 then perform private.lessons_audit('undo', 'تراجع عن قرار', 'Undid a decision'); end if;
  return n;
end; $$;

-- Remove a pending request (an admin, or the preacher through his link).
create function public.lessons_withdraw(p_request uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); t_ar text; t_en text; pid uuid;
begin
  select title_ar, coalesce(nullif(title_en, ''), title_ar), preacher_id into t_ar, t_en, pid
    from public.lessons where request_id = p_request and status = 'pending' limit 1;
  if t_ar is null then raise exception 'Nothing to withdraw' using errcode = '22023'; end if;
  update public.lessons set status = 'withdrawn', updated_at = now() where request_id = p_request and status = 'pending';
  update public.lesson_series set status = 'withdrawn' where request_id = p_request and status = 'pending';
  perform private.lessons_audit('withdraw', t_ar, t_en, pid);
end; $$;

-- Cancel one approved, upcoming session. It stays visible, marked cancelled,
-- and everyone with a reminder is told at once.
create function public.lessons_cancel_lesson(p_lesson uuid, p_reason text) returns integer
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
  select count(*) into n from public.lesson_reminders where lesson_id = l.id;
  perform private.lessons_notify(r.profile_id, 'alert', 'أُلغي موعد: ' || l.title_ar,
    'Cancelled: ' || coalesce(nullif(l.title_en, ''), l.title_ar),
    to_char(l.lesson_date, 'YYYY-MM-DD') || ' — ' || reason, to_char(l.lesson_date, 'YYYY-MM-DD') || ': ' || reason,
    '/lessons/lesson/' || l.id)
  from public.lesson_reminders r where r.lesson_id = l.id and r.profile_id <> actor;
  perform private.lessons_audit('cancel', l.title_ar || ' — ' || to_char(l.lesson_date, 'YYYY-MM-DD'),
    coalesce(nullif(l.title_en, ''), l.title_ar) || ', ' || to_char(l.lesson_date, 'YYYY-MM-DD'), l.preacher_id);
  return n;
end; $$;

-- Correct a pending or approved session in place (time, place, title).
-- Reminder holders hear about a change of date, time or mosque.
create function public.lessons_edit_lesson(p_lesson uuid, p jsonb) returns void
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

create function public.lessons_post_report(p_lesson uuid, p_attendance integer, p_women integer,
  p_issue text, p_notes text) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); l public.lessons;
begin
  select * into l from public.lessons where id = p_lesson;
  if not found or l.status <> 'approved' or l.lesson_date > public.lessons_today() then
    raise exception 'Reports are for sessions that have been held' using errcode = '22023';
  end if;
  insert into public.lesson_reports(lesson_id, attendance, women, issue, notes, submitted_by)
  values (l.id, p_attendance, coalesce(p_women, 0), coalesce(p_issue, 'none'), coalesce(p_notes, ''), actor)
  on conflict (lesson_id) do update set attendance = excluded.attendance, women = excluded.women,
    issue = excluded.issue, notes = excluded.notes, submitted_by = excluded.submitted_by, submitted_at = now();
  perform private.lessons_audit('report', l.title_ar, coalesce(nullif(l.title_en, ''), l.title_ar), l.preacher_id);
end; $$;

create function public.lessons_resolve_flag(p_flag uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin();
begin
  update public.lesson_flags set status = 'resolved', resolved_by = actor, resolved_at = now() where id = p_flag;
  if not found then raise exception 'Report not found' using errcode = '22023'; end if;
  perform private.lessons_audit('resolve', 'بلاغ على درس', 'Report on a lesson');
end; $$;

-- ---------------------------------------------------------------------------
-- Mosques (admins)
-- ---------------------------------------------------------------------------
create function public.lessons_upsert_mosque(p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); mid uuid := nullif(p->>'id', '')::uuid;
begin
  if mid is null then
    insert into public.mosques(name_ar, name_en, district_id, latitude, longitude, maps_url, facilities,
      verified, created_by)
    values (btrim(p->>'name_ar'), btrim(coalesce(p->>'name_en', '')), p->>'district_id',
      (p->>'latitude')::double precision, (p->>'longitude')::double precision, nullif(p->>'maps_url', ''),
      coalesce(array(select jsonb_array_elements_text(p->'facilities')), '{}'),
      coalesce((p->>'verified')::boolean, true), actor)
    returning id into mid;
    perform private.lessons_audit('addMosque', btrim(p->>'name_ar'), coalesce(nullif(btrim(p->>'name_en'), ''), btrim(p->>'name_ar')));
  else
    update public.mosques set
      name_ar = coalesce(nullif(btrim(p->>'name_ar'), ''), name_ar), name_en = coalesce(p->>'name_en', name_en),
      district_id = coalesce(p->>'district_id', district_id),
      latitude = case when p ? 'latitude' then (p->>'latitude')::double precision else latitude end,
      longitude = case when p ? 'longitude' then (p->>'longitude')::double precision else longitude end,
      maps_url = case when p ? 'maps_url' then nullif(p->>'maps_url', '') else maps_url end,
      facilities = case when p ? 'facilities'
        then array(select jsonb_array_elements_text(p->'facilities')) else facilities end,
      verified = coalesce((p->>'verified')::boolean, verified),
      updated_at = now()
    where id = mid;
    if not found then raise exception 'Mosque not found' using errcode = '22023'; end if;
    perform private.lessons_audit('editMosque', m.name_ar, coalesce(nullif(m.name_en, ''), m.name_ar))
      from public.mosques m where m.id = mid;
  end if;
  return mid;
end; $$;

-- Remove a mosque, or merge a duplicate into another (its sessions move).
create function public.lessons_remove_mosque(p_mosque uuid, p_merge_into uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); m public.mosques;
begin
  select * into m from public.mosques where id = p_mosque for update;
  if not found then raise exception 'Mosque not found' using errcode = '22023'; end if;
  if p_merge_into is not null then
    if p_merge_into = p_mosque or not exists (select 1 from public.mosques where id = p_merge_into) then
      raise exception 'Merge into another mosque' using errcode = '22023';
    end if;
    update public.lessons set mosque_id = p_merge_into, updated_at = now() where mosque_id = p_mosque;
    update public.lesson_series set mosque_id = p_merge_into where mosque_id = p_mosque;
    update public.lesson_follows set target_id = p_merge_into where kind = 'mosque' and target_id = p_mosque
      and not exists (select 1 from public.lesson_follows f2 where f2.profile_id = lesson_follows.profile_id
        and f2.kind = 'mosque' and f2.target_id = p_merge_into);
  elsif exists (select 1 from public.lessons where mosque_id = p_mosque) then
    raise exception 'Sessions use this mosque. Merge it instead.' using errcode = '23503';
  end if;
  delete from public.lesson_follows where kind = 'mosque' and target_id = p_mosque;
  delete from public.mosques where id = p_mosque;
  perform private.lessons_audit(case when p_merge_into is null then 'removeMosque' else 'mergeMosque' end,
    m.name_ar, coalesce(nullif(m.name_en, ''), m.name_ar));
end; $$;

-- ---------------------------------------------------------------------------
-- Viewers
-- ---------------------------------------------------------------------------
create function public.lessons_flag(p_lesson uuid, p_kind text, p_message text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_viewer(); l public.lessons; fid uuid;
begin
  select * into l from public.lessons where id = p_lesson and status in ('approved','cancelled');
  if not found then raise exception 'Lesson not found' using errcode = '22023'; end if;
  if (select count(*) from public.lesson_flags f where f.reporter_id = actor
       and f.created_at > now() - interval '1 day') >= 10 then
    raise exception 'Too many reports today' using errcode = '54000';
  end if;
  insert into public.lesson_flags(lesson_id, kind, message, reporter_id)
  values (l.id, p_kind, btrim(coalesce(p_message, '')), actor) returning id into fid;
  perform private.lessons_notify(a, 'flag', 'بلاغ جديد من مستخدم', 'New report from a user',
    l.title_ar, coalesce(nullif(l.title_en, ''), l.title_ar), '/admin/lessons/reports')
  from private.lessons_admins() a;
  return fid;
end; $$;

create function public.lessons_mark_notifications_read(p_ids uuid[] default null) returns integer
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_viewer(); n integer;
begin
  update public.lesson_notifications set read_at = now()
   where profile_id = actor and read_at is null and (p_ids is null or id = any(p_ids));
  get diagnostics n = row_count;
  return n;
end; $$;

-- ---------------------------------------------------------------------------
-- Through a preacher link (no account; guests may call these)
-- ---------------------------------------------------------------------------
-- What the preacher sees: his card, the link's end, his recent and coming
-- lessons with their state, and a change he is waiting on.
create function public.lessons_key_open(p_key text, p_device text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare k private.preacher_keys := private.preacher_key(p_key, p_device);
begin
  return jsonb_build_object(
    'preacher', (select jsonb_build_object('id', p.id, 'name_ar', p.name_ar, 'name_en', p.name_en,
        'title_ar', p.title_ar, 'title_en', p.title_en, 'bio_ar', p.bio_ar, 'bio_en', p.bio_en,
        'photo_url', p.photo_url, 'city', p.city, 'languages', p.languages, 'listed', p.listed)
      from public.preachers p where p.id = k.preacher_id),
    'key', jsonb_build_object('kind', k.kind, 'valid_until', k.valid_until),
    'pending_edit', (select e.payload from public.preacher_edits e
      where e.preacher_id = k.preacher_id and e.status = 'pending' order by e.created_at desc limit 1),
    'lessons', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'request_id', l.request_id,
        'series_id', l.series_id, 'seq', l.seq, 'title_ar', l.title_ar, 'title_en', l.title_en, 'type', l.type,
        'topic', l.topic, 'lesson_date', l.lesson_date, 'slot', l.slot, 'exact_time', l.exact_time,
        'status', l.status, 'source', l.source, 'preacher_note', l.preacher_note,
        'rejection_reason', l.rejection_reason, 'cancel_reason', l.cancel_reason,
        'mosque_name_ar', m.name_ar, 'mosque_name_en', m.name_en) order by l.lesson_date, l.slot)
      from public.lessons l left join public.mosques m on m.id = l.mosque_id
      where l.preacher_id = k.preacher_id and l.status <> 'withdrawn'
        and l.lesson_date >= public.lessons_today() - 60), '[]'::jsonb));
end; $$;

-- Proposes changes to his card; one pending proposal at a time (a new one
-- replaces it). An admin approves before anyone else sees them.
create function public.lessons_key_update_profile(p_key text, p_device text, p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  k private.preacher_keys := private.preacher_key(p_key, p_device);
  x jsonb := '{}'::jsonb;
  f text;
  eid uuid;
  names record;
begin
  if jsonb_typeof(p) <> 'object' then raise exception 'Nothing to change' using errcode = '22023'; end if;
  foreach f in array array['name_ar','name_en','title_ar','title_en','bio_ar','bio_en'] loop
    if p ? f then x := x || jsonb_build_object(f, btrim(coalesce(p->>f, ''))); end if;
  end loop;
  if p ? 'languages' then x := x || jsonb_build_object('languages', p->'languages'); end if;
  if x = '{}'::jsonb then raise exception 'Nothing to change' using errcode = '22023'; end if;
  if (x ? 'name_ar' and char_length(x->>'name_ar') not between 3 and 120)
     or char_length(coalesce(x->>'name_en', '')) > 120
     or char_length(coalesce(x->>'title_ar', '')) > 120 or char_length(coalesce(x->>'title_en', '')) > 120
     or char_length(coalesce(x->>'bio_ar', '')) > 1500 or char_length(coalesce(x->>'bio_en', '')) > 1500
     or (x ? 'languages' and (jsonb_typeof(x->'languages') <> 'array'
       or jsonb_array_length(x->'languages') not between 1 and 7
       or not (array(select jsonb_array_elements_text(x->'languages')) <@ array['ar','en','ur','tl','bn','ml','id']::text[]))) then
    raise exception 'Check the lengths and languages' using errcode = '22023';
  end if;
  update public.preacher_edits set payload = x, created_at = now()
   where preacher_id = k.preacher_id and status = 'pending' returning id into eid;
  if eid is null then
    insert into public.preacher_edits(preacher_id, payload) values (k.preacher_id, x) returning id into eid;
  end if;
  select * into names from private.preacher_names(k.preacher_id);
  perform private.lessons_audit('preacherEdit', names.name_ar, names.name_en, k.preacher_id);
  perform private.lessons_notify(a, 'user', 'داعية اقترح تعديلًا على بطاقته', 'A preacher proposed a card change',
    names.name_ar, names.name_en, '/admin/lessons/approvals')
  from private.lessons_admins() a;
  return eid;
end; $$;

-- Requests a lesson (one date) or a weekly series (several dates). It waits
-- for an admin, who chooses the mosque.
create function public.lessons_key_request_lesson(p_key text, p_device text, p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  k private.preacher_keys := private.preacher_key(p_key, p_device);
  req uuid := gen_random_uuid();
  ser uuid;
  dates date[];
  d date;
  i integer := 0;
  today date := public.lessons_today();
  title_ar text := btrim(coalesce(p->>'title_ar', ''));
  names record;
begin
  if (select count(distinct request_id) from public.lessons
       where preacher_id = k.preacher_id and status = 'pending') >= 20 then
    raise exception 'Too many requests are waiting' using errcode = '54000';
  end if;
  select array_agg(distinct x::date order by x::date) into dates
    from jsonb_array_elements_text(coalesce(p->'dates', '[]'::jsonb)) x;
  if dates is null or cardinality(dates) not between 1 and 12 then
    raise exception 'Between 1 and 12 dates are required' using errcode = '22023';
  end if;
  if dates[1] < today or dates[cardinality(dates)] > today + 180 then
    raise exception 'Dates must be from today up to six months ahead' using errcode = '22023';
  end if;
  if cardinality(dates) > 1 then
    insert into public.lesson_series(request_id, preacher_id, title_ar, type, topic, language, audience, slot, total)
    values (req, k.preacher_id, title_ar, p->>'type', p->>'topic', coalesce(p->>'language', 'ar'),
      coalesce(p->>'audience', 'all'), p->>'slot', cardinality(dates))
    returning id into ser;
  end if;
  foreach d in array dates loop
    i := i + 1;
    insert into public.lessons(request_id, series_id, seq, type, topic, title_ar, preacher_id, lesson_date, slot,
      language, audience, status, source, preacher_note)
    values (req, ser, case when ser is null then null else i end, p->>'type', p->>'topic', title_ar, k.preacher_id,
      d, p->>'slot', coalesce(p->>'language', 'ar'), coalesce(p->>'audience', 'all'), 'pending', 'preacher',
      btrim(coalesce(p->>'note', '')));
  end loop;
  select * into names from private.preacher_names(k.preacher_id);
  perform private.lessons_audit('request', title_ar || ' — ' || names.name_ar, title_ar || ', ' || names.name_en, k.preacher_id);
  perform private.lessons_notify(a, 'inbox', 'طلب درس جديد من داعية', 'A preacher requested a lesson',
    title_ar || ' — ' || names.name_ar, title_ar || ', ' || names.name_en, '/admin/lessons/approvals')
  from private.lessons_admins() a;
  return req;
end; $$;

create function public.lessons_key_withdraw(p_key text, p_device text, p_request uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare k private.preacher_keys := private.preacher_key(p_key, p_device); t_ar text;
begin
  select title_ar into t_ar from public.lessons
   where request_id = p_request and preacher_id = k.preacher_id and status = 'pending' limit 1;
  if t_ar is null then raise exception 'Nothing to withdraw' using errcode = '22023'; end if;
  update public.lessons set status = 'withdrawn', updated_at = now() where request_id = p_request and status = 'pending';
  update public.lesson_series set status = 'withdrawn' where request_id = p_request and status = 'pending';
  perform private.lessons_audit('withdraw', t_ar, t_ar, k.preacher_id);
end; $$;

-- ---------------------------------------------------------------------------
-- Function privileges
-- ---------------------------------------------------------------------------
revoke all on function private.lessons_admin(), private.lessons_viewer(),
  private.lessons_audit(text, text, text, uuid),
  private.lessons_notify(uuid, text, text, text, text, text, text), private.lessons_admins(),
  private.preacher_names(uuid), private.clean_phone(text), private.sha256_hex(text),
  private.preacher_key(text, text)
  from public, anon, authenticated;

do $$
declare f regprocedure;
begin
  for f in select p.oid::regprocedure from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname like 'lessons\_%'
  loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
grant execute on function public.lessons_today() to anon;
grant execute on function public.lessons_key_open(text, text) to anon;
grant execute on function public.lessons_key_update_profile(text, text, jsonb) to anon;
grant execute on function public.lessons_key_request_lesson(text, text, jsonb) to anon;
grant execute on function public.lessons_key_withdraw(text, text, uuid) to anon;

-- ---------------------------------------------------------------------------
-- Data rights: the account export carries a viewer's lessons data too.
-- ---------------------------------------------------------------------------
create function public.export_my_data() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v uuid := auth.uid();
begin
  if v is null then raise exception 'Not signed in' using errcode = '42501'; end if;
  return private.export_my_data_core() || jsonb_build_object('lessons', jsonb_build_object(
    'reminders', coalesce((select jsonb_agg(to_jsonb(r) - 'profile_id') from public.lesson_reminders r where r.profile_id = v), '[]'::jsonb),
    'follows', coalesce((select jsonb_agg(to_jsonb(f) - 'profile_id') from public.lesson_follows f where f.profile_id = v), '[]'::jsonb),
    'attendance_log', coalesce((select jsonb_agg(to_jsonb(a) - 'profile_id') from public.lesson_attendance a where a.profile_id = v), '[]'::jsonb),
    'preferences', (select to_jsonb(p) - 'profile_id' from public.lesson_preferences p where p.profile_id = v),
    'notifications', coalesce((select jsonb_agg(to_jsonb(n) - 'profile_id' order by n.created_at) from public.lesson_notifications n where n.profile_id = v), '[]'::jsonb),
    'reports_filed', coalesce((select jsonb_agg(jsonb_build_object('lesson_id', f.lesson_id, 'kind', f.kind,
        'message', f.message, 'status', f.status, 'created_at', f.created_at)) from public.lesson_flags f where f.reporter_id = v), '[]'::jsonb),
    'preacher_card', (select to_jsonb(p) from public.preachers p where p.linked_profile_id = v)));
end; $$;
revoke all on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;

commit;
