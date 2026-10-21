-- Taysir in Hadayah Live: the mosque lessons programme, rebuilt natively.
--
-- Taysir (a separate Bolt.new app, reviewed in
-- brief/research/taysir/2026-10-21_TAYSIR_DNA_HEALTH_AND_INTEGRATION.md) let
-- preachers submit mosque lessons, coordinators approve them, and the public
-- browse approved ones. Its domain is kept (three activity types, prayer-time
-- slots, district then mosque, approval before publishing); its security
-- model is not. Here:
--
-- * Authority is two organization-scoped permission keys in the existing
--   user_permissions table, read through has_permission(): activities.coordinate
--   (granted by the organization owner/co-owner or an admin) and
--   activities.submit (granted when a preacher accepts a coordinator's
--   invitation). No new role tier, no role in user metadata.
-- * Every write goes through a security definer function that checks the
--   caller; clients hold no INSERT/UPDATE/DELETE on programme tables, except
--   their own reminders, follows, attendance log and preferences.
-- * Preacher phone numbers live in a private table. Coordinators see a mask;
--   each reveal is written to the action log.
-- * Invitations are single-use, expiring links (only a hash is stored). No
--   default passwords and no accounts created on anyone's behalf.
-- * The public reads approved and cancelled sessions of organizations that
--   have Taysir enabled, verified mosques and listed preachers. Nothing else.
-- * Weekday and Hijri date are derived on the client, never stored.
begin;

-- ---------------------------------------------------------------------------
-- Reference data
-- ---------------------------------------------------------------------------
create table public.taysir_districts (
  id text primary key check (id ~ '^[a-z0-9_]{2,40}$'),
  city text not null check (city in ('khobar','dhahran','dammam','qatif','other')),
  name_ar text not null check (char_length(name_ar) between 2 and 80),
  name_en text not null check (char_length(name_en) between 2 and 80),
  sort integer not null default 0
);
comment on table public.taysir_districts is
  'Taysir: neighbourhoods for the district-then-mosque picker. Public reference data.';

insert into public.taysir_districts(id, city, name_ar, name_en, sort) values
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

-- Organizations that run the programme. A master admin switches it on.
create table public.taysir_organizations (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  enabled boolean not null default true,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);
comment on table public.taysir_organizations is
  'Taysir: organizations with the lessons module switched on (public, no personal data).';

-- ---------------------------------------------------------------------------
-- Places and people
-- ---------------------------------------------------------------------------
create table public.taysir_mosques (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null check (char_length(btrim(name_ar)) between 2 and 120),
  name_en text not null default '' check (char_length(name_en) <= 120),
  district_id text not null references public.taysir_districts(id),
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  -- Only https Google Maps links: a javascript: URL here was a stored XSS in
  -- the original Taysir.
  maps_url text check (maps_url is null or maps_url ~
    '^https://((www\.)?google\.[a-z.]{2,8}/maps|maps\.google\.[a-z.]{2,8}/|maps\.app\.goo\.gl/|goo\.gl/maps/)'),
  facilities text[] not null default '{}'
    check (facilities <@ array['women','parking','access','interp','kids']::text[]),
  verified boolean not null default false,
  suggested_by uuid references public.profiles(id) on delete set null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((latitude is null) = (longitude is null))
);
create index taysir_mosques_district_idx on public.taysir_mosques(district_id);
comment on table public.taysir_mosques is
  'Taysir: a shared, platform-wide mosque directory. Suggestions stay hidden until a coordinator verifies them.';

create table public.taysir_preachers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  linked_profile_id uuid references public.profiles(id) on delete set null,
  name_ar text not null check (char_length(btrim(name_ar)) between 3 and 120),
  name_en text not null default '' check (char_length(name_en) <= 120),
  title_ar text not null default '' check (char_length(title_ar) <= 120),
  title_en text not null default '' check (char_length(title_en) <= 120),
  bio_ar text not null default '' check (char_length(bio_ar) <= 1500),
  bio_en text not null default '' check (char_length(bio_en) <= 1500),
  city text not null default 'khobar' check (city in ('khobar','dhahran','dammam','qatif','other')),
  affiliation text not null default 'coop' check (affiliation in ('coop','ministry')),
  languages text[] not null default '{ar}' check (cardinality(languages) between 1 and 7
    and languages <@ array['ar','en','ur','tl','bn','ml','id']::text[]),
  listed boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, linked_profile_id)
);
create index taysir_preachers_org_idx on public.taysir_preachers(organization_id);
create index taysir_preachers_profile_idx on public.taysir_preachers(linked_profile_id);
comment on table public.taysir_preachers is
  'Taysir: an organization''s preacher roster. A card grants nothing; authority is activities.submit in user_permissions.';

create table private.taysir_preacher_contacts (
  preacher_id uuid primary key references public.taysir_preachers(id) on delete cascade,
  phone text not null check (phone ~ '^\+?[0-9]{7,15}$')
);

create table private.taysir_invites (
  id uuid primary key default gen_random_uuid(),
  preacher_id uuid not null references public.taysir_preachers(id) on delete cascade,
  token_hash text not null unique,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  consumed_by uuid references public.profiles(id) on delete set null
);
create index taysir_invites_preacher_idx on private.taysir_invites(preacher_id);

-- ---------------------------------------------------------------------------
-- Lessons
-- ---------------------------------------------------------------------------
create table public.taysir_series (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  request_id uuid not null,
  preacher_id uuid not null references public.taysir_preachers(id) on delete cascade,
  mosque_id uuid not null references public.taysir_mosques(id),
  title_ar text not null, title_en text not null default '',
  type text not null check (type in ('lesson','lecture','talk')),
  topic text not null,
  language text not null,
  audience text not null,
  slot text not null check (slot in ('fajr','dhuhr','asr','maghrib','isha')),
  total integer not null check (total between 2 and 60),
  status text not null default 'pending'
    check (status in ('pending','approved','rejected','withdrawn')),
  created_at timestamptz not null default now()
);
create index taysir_series_org_idx on public.taysir_series(organization_id);
comment on table public.taysir_series is 'Taysir: a weekly series submitted as one request.';

create table public.taysir_lessons (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  request_id uuid not null,
  series_id uuid references public.taysir_series(id) on delete cascade,
  seq integer check (seq between 1 and 60),
  type text not null check (type in ('lesson','lecture','talk')),
  topic text not null check (topic in ('aqeedah','fiqh','tafsir','hadith','seerah','family','raqaiq','intro')),
  title_ar text not null check (char_length(btrim(title_ar)) between 3 and 160),
  title_en text not null default '' check (char_length(title_en) <= 160),
  description_ar text not null default '' check (char_length(description_ar) <= 2000),
  description_en text not null default '' check (char_length(description_en) <= 2000),
  preacher_id uuid not null references public.taysir_preachers(id) on delete cascade,
  mosque_id uuid not null references public.taysir_mosques(id),
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
  rejection_reason text check (char_length(rejection_reason) <= 600),
  cancel_reason text check (char_length(cancel_reason) <= 600),
  submitted_by uuid references public.profiles(id) on delete set null,
  submitted_at timestamptz not null default now(),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  updated_at timestamptz not null default now(),
  check (interpretation is null or interpretation <> language),
  check ((series_id is null) = (seq is null))
);
create index taysir_lessons_date_idx on public.taysir_lessons(lesson_date);
create index taysir_lessons_mosque_idx on public.taysir_lessons(mosque_id, lesson_date);
create index taysir_lessons_preacher_idx on public.taysir_lessons(preacher_id, lesson_date);
create index taysir_lessons_request_idx on public.taysir_lessons(request_id);
create index taysir_lessons_org_status_idx on public.taysir_lessons(organization_id, status);
create index taysir_lessons_series_idx on public.taysir_lessons(series_id);
comment on table public.taysir_lessons is
  'Taysir: one dated activity (a single lecture or one session of a series). Public only once approved.';

create table public.taysir_lesson_reports (
  lesson_id uuid primary key references public.taysir_lessons(id) on delete cascade,
  attendance integer not null check (attendance between 0 and 100000),
  women integer not null default 0 check (women between 0 and 100000),
  issue text not null default 'none' check (issue in ('none','sound','time','place')),
  notes text not null default '' check (char_length(notes) <= 2000),
  submitted_by uuid references public.profiles(id) on delete set null,
  submitted_at timestamptz not null default now()
);
comment on table public.taysir_lesson_reports is
  'Taysir: the preacher''s after-lesson report (attendance, issues). Feeds the monthly report.';

create table public.taysir_flags (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.taysir_lessons(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  kind text not null check (kind in ('time','place','cancel','other')),
  message text not null default '' check (char_length(message) <= 1000),
  reporter_id uuid references public.profiles(id) on delete cascade,
  status text not null default 'open' check (status in ('open','resolved')),
  created_at timestamptz not null default now(),
  resolved_by uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz
);
create index taysir_flags_org_idx on public.taysir_flags(organization_id, status);
comment on table public.taysir_flags is 'Taysir: a viewer''s report of a wrong time or place.';

create table public.taysir_audit (
  id bigint generated always as identity primary key,
  organization_id uuid references public.organizations(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  target_ar text not null default '',
  target_en text not null default '',
  created_at timestamptz not null default now()
);
create index taysir_audit_org_idx on public.taysir_audit(organization_id, created_at desc);
comment on table public.taysir_audit is 'Taysir: read-only action log (who did what, when, to what).';

-- ---------------------------------------------------------------------------
-- Viewers' own data
-- ---------------------------------------------------------------------------
create table public.taysir_reminders (
  profile_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  lesson_id uuid not null references public.taysir_lessons(id) on delete cascade,
  lead text not null check (lead in ('adhan','30','day')),
  remind_at timestamptz not null,
  created_at timestamptz not null default now(),
  primary key (profile_id, lesson_id)
);
create index taysir_reminders_due_idx on public.taysir_reminders(remind_at);

create table public.taysir_follows (
  profile_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('preacher','series','mosque')),
  target_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (profile_id, kind, target_id)
);
create index taysir_follows_target_idx on public.taysir_follows(kind, target_id);

create table public.taysir_attendance (
  profile_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  lesson_id uuid not null references public.taysir_lessons(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (profile_id, lesson_id)
);

create table public.taysir_preferences (
  profile_id uuid primary key default auth.uid() references public.profiles(id) on delete cascade,
  default_lead text not null default 'adhan' check (default_lead in ('adhan','30','day')),
  evening_digest boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.taysir_notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  icon text not null default 'bell',
  title_ar text not null, title_en text not null,
  body_ar text not null default '', body_en text not null default '',
  route text not null default '/taysir',
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index taysir_notifications_profile_idx on public.taysir_notifications(profile_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Authority helpers
-- ---------------------------------------------------------------------------
create function private.taysir_actor() returns uuid
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or public.is_banned(auth.uid()) then
    raise exception 'Sign in required' using errcode = '42501';
  end if;
  return auth.uid();
end; $$;

create function public.taysir_today() returns date
language sql stable set search_path = '' as $$
  select (now() at time zone 'Asia/Riyadh')::date;
$$;

-- The organization's leadership: owner, active co-owner, or an org_owner /
-- org_co_owner role grant.
create function public.taysir_is_org_leader(p_org uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and (
    exists (select 1 from public.organizations o where o.id = p_org and o.owner_profile_id = auth.uid())
    or exists (select 1 from public.org_memberships m where m.organization_id = p_org
      and m.profile_id = auth.uid() and m.status = 'active' and m.role in ('owner','co_owner'))
    or exists (select 1 from public.user_roles r where r.organization_id = p_org
      and r.profile_id = auth.uid() and r.role in ('org_owner','org_co_owner')));
$$;

create function public.taysir_is_coordinator(p_org uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and not public.is_banned(auth.uid()) and (
    public.is_admin_tier()
    or (exists (select 1 from public.taysir_organizations t where t.organization_id = p_org and t.enabled)
        and (public.has_permission('activities.coordinate', p_org) or public.taysir_is_org_leader(p_org))));
$$;

create function public.taysir_coordinates_any() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and not public.is_banned(auth.uid()) and (
    public.is_admin_tier()
    or exists (select 1 from public.taysir_organizations t
      where t.enabled and public.taysir_is_coordinator(t.organization_id)));
$$;

-- Is the caller the linked, permitted preacher of this card?
create function public.taysir_is_own_preacher(p_preacher uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.taysir_preachers p
      join public.taysir_organizations t on t.organization_id = p.organization_id and t.enabled
    where p.id = p_preacher and p.linked_profile_id = auth.uid()
      and auth.uid() is not null and not public.is_banned(auth.uid())
      and exists (select 1 from public.user_permissions u where u.profile_id = auth.uid()
        and u.permission_key = 'activities.submit' and u.organization_id = p.organization_id));
$$;

create function private.taysir_audit(p_org uuid, p_action text, p_ar text, p_en text) returns void
language sql security definer set search_path = '' as $$
  insert into public.taysir_audit(organization_id, actor_id, action, target_ar, target_en)
  values (p_org, auth.uid(), p_action, coalesce(p_ar, ''), coalesce(p_en, ''));
$$;

create function private.taysir_notify(p_profile uuid, p_icon text, p_title_ar text, p_title_en text,
  p_body_ar text, p_body_en text, p_route text) returns void
language sql security definer set search_path = '' as $$
  insert into public.taysir_notifications(profile_id, icon, title_ar, title_en, body_ar, body_en, route)
  select p_profile, p_icon, p_title_ar, p_title_en, coalesce(p_body_ar, ''), coalesce(p_body_en, ''), p_route
  where p_profile is not null;
$$;

-- Everyone who reviews this organization's requests (except the actor).
create function private.taysir_coordinators(p_org uuid) returns setof uuid
language sql stable security definer set search_path = '' as $$
  select distinct x.id from (
    select u.profile_id as id from public.user_permissions u
      where u.permission_key = 'activities.coordinate' and u.organization_id = p_org
    union select o.owner_profile_id from public.organizations o where o.id = p_org
    union select m.profile_id from public.org_memberships m
      where m.organization_id = p_org and m.status = 'active' and m.role in ('owner','co_owner')
  ) x where x.id is distinct from auth.uid();
$$;

create function private.taysir_preacher_names(p_preacher uuid, out name_ar text, out name_en text)
language sql stable security definer set search_path = '' as $$
  select p.name_ar, coalesce(nullif(p.name_en, ''), p.name_ar)
  from public.taysir_preachers p where p.id = p_preacher;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------
alter table public.taysir_districts enable row level security;
alter table public.taysir_organizations enable row level security;
alter table public.taysir_mosques enable row level security;
alter table public.taysir_preachers enable row level security;
alter table public.taysir_series enable row level security;
alter table public.taysir_lessons enable row level security;
alter table public.taysir_lesson_reports enable row level security;
alter table public.taysir_flags enable row level security;
alter table public.taysir_audit enable row level security;
alter table public.taysir_reminders enable row level security;
alter table public.taysir_follows enable row level security;
alter table public.taysir_attendance enable row level security;
alter table public.taysir_preferences enable row level security;
alter table public.taysir_notifications enable row level security;

revoke all on public.taysir_districts, public.taysir_organizations, public.taysir_mosques,
  public.taysir_preachers, public.taysir_series, public.taysir_lessons, public.taysir_lesson_reports,
  public.taysir_flags, public.taysir_audit, public.taysir_reminders, public.taysir_follows,
  public.taysir_attendance, public.taysir_preferences, public.taysir_notifications
  from public, anon, authenticated;

-- Public reference and catalogue reads (guests included).
grant select on public.taysir_districts, public.taysir_organizations, public.taysir_mosques,
  public.taysir_preachers, public.taysir_series, public.taysir_lessons to anon, authenticated;

create policy taysir_districts_read on public.taysir_districts for select
  to anon, authenticated using (true);
create policy taysir_organizations_read_public on public.taysir_organizations for select
  to anon using (enabled);
create policy taysir_organizations_read on public.taysir_organizations for select
  to authenticated using (enabled or public.is_admin_tier());

create policy taysir_mosques_read_public on public.taysir_mosques for select
  to anon using (verified);
create policy taysir_mosques_read on public.taysir_mosques for select
  to authenticated using (verified or suggested_by = auth.uid() or public.taysir_coordinates_any());

create policy taysir_preachers_read_public on public.taysir_preachers for select
  to anon using (listed and exists (select 1 from public.taysir_organizations t
    where t.organization_id = taysir_preachers.organization_id and t.enabled));
create policy taysir_preachers_read on public.taysir_preachers for select
  to authenticated using (
    (listed and exists (select 1 from public.taysir_organizations t
      where t.organization_id = taysir_preachers.organization_id and t.enabled))
    or linked_profile_id = auth.uid()
    or public.taysir_is_coordinator(organization_id));

create policy taysir_series_read_public on public.taysir_series for select
  to anon using (status = 'approved' and exists (select 1 from public.taysir_organizations t
    where t.organization_id = taysir_series.organization_id and t.enabled));
create policy taysir_series_read on public.taysir_series for select
  to authenticated using (
    (status = 'approved' and exists (select 1 from public.taysir_organizations t
      where t.organization_id = taysir_series.organization_id and t.enabled))
    or exists (select 1 from public.taysir_preachers p where p.id = taysir_series.preacher_id
      and p.linked_profile_id = auth.uid())
    or public.taysir_is_coordinator(organization_id));

create policy taysir_lessons_read_public on public.taysir_lessons for select
  to anon using (status in ('approved','cancelled') and exists (select 1 from public.taysir_organizations t
    where t.organization_id = taysir_lessons.organization_id and t.enabled));
create policy taysir_lessons_read on public.taysir_lessons for select
  to authenticated using (
    (status in ('approved','cancelled') and exists (select 1 from public.taysir_organizations t
      where t.organization_id = taysir_lessons.organization_id and t.enabled))
    or exists (select 1 from public.taysir_preachers p where p.id = taysir_lessons.preacher_id
      and p.linked_profile_id = auth.uid())
    or public.taysir_is_coordinator(organization_id));

-- Staff and the preacher themselves.
grant select on public.taysir_lesson_reports, public.taysir_flags, public.taysir_audit to authenticated;
create policy taysir_reports_read on public.taysir_lesson_reports for select to authenticated using (
  exists (select 1 from public.taysir_lessons l where l.id = taysir_lesson_reports.lesson_id
    and (public.taysir_is_coordinator(l.organization_id) or exists (select 1 from public.taysir_preachers p
      where p.id = l.preacher_id and p.linked_profile_id = auth.uid()))));
create policy taysir_flags_read on public.taysir_flags for select to authenticated using (
  reporter_id = auth.uid() or public.taysir_is_coordinator(organization_id));
create policy taysir_audit_read on public.taysir_audit for select to authenticated using (
  public.taysir_is_coordinator(organization_id));

-- Own rows only.
grant select, insert, update, delete on public.taysir_reminders, public.taysir_follows,
  public.taysir_attendance, public.taysir_preferences to authenticated;
create policy taysir_reminders_select on public.taysir_reminders for select to authenticated using (profile_id = auth.uid());
create policy taysir_reminders_insert on public.taysir_reminders for insert to authenticated with check (
  profile_id = auth.uid() and exists (select 1 from public.taysir_lessons l
    where l.id = lesson_id and l.status = 'approved'));
create policy taysir_reminders_update on public.taysir_reminders for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy taysir_reminders_delete on public.taysir_reminders for delete to authenticated using (profile_id = auth.uid());

create policy taysir_follows_select on public.taysir_follows for select to authenticated using (profile_id = auth.uid());
create policy taysir_follows_insert on public.taysir_follows for insert to authenticated with check (profile_id = auth.uid());
create policy taysir_follows_update on public.taysir_follows for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy taysir_follows_delete on public.taysir_follows for delete to authenticated using (profile_id = auth.uid());

create policy taysir_attendance_select on public.taysir_attendance for select to authenticated using (profile_id = auth.uid());
create policy taysir_attendance_insert on public.taysir_attendance for insert to authenticated with check (
  profile_id = auth.uid() and exists (select 1 from public.taysir_lessons l
    where l.id = lesson_id and l.status = 'approved' and l.lesson_date <= public.taysir_today()));
create policy taysir_attendance_update on public.taysir_attendance for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy taysir_attendance_delete on public.taysir_attendance for delete to authenticated using (profile_id = auth.uid());

create policy taysir_preferences_select on public.taysir_preferences for select to authenticated using (profile_id = auth.uid());
create policy taysir_preferences_insert on public.taysir_preferences for insert to authenticated with check (profile_id = auth.uid());
create policy taysir_preferences_update on public.taysir_preferences for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy taysir_preferences_delete on public.taysir_preferences for delete to authenticated using (profile_id = auth.uid());

-- Notifications: read and clear your own; written (and marked read) only by
-- the functions below.
grant select, delete on public.taysir_notifications to authenticated;
create policy taysir_notifications_select on public.taysir_notifications for select to authenticated using (profile_id = auth.uid());
create policy taysir_notifications_delete on public.taysir_notifications for delete to authenticated using (profile_id = auth.uid());

revoke all on function private.taysir_actor(), private.taysir_audit(uuid, text, text, text),
  private.taysir_notify(uuid, text, text, text, text, text, text), private.taysir_coordinators(uuid),
  private.taysir_preacher_names(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- My roles (drives the client: console, My lessons, Team)
-- ---------------------------------------------------------------------------
create function public.taysir_my_roles() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'admin', public.is_admin_tier(),
    'master', public.is_master_admin(),
    'coordinate', coalesce((select jsonb_agg(t.organization_id) from public.taysir_organizations t
      where public.taysir_is_coordinator(t.organization_id)), '[]'::jsonb),
    'lead', coalesce((select jsonb_agg(t.organization_id) from public.taysir_organizations t
      where public.taysir_is_org_leader(t.organization_id)), '[]'::jsonb),
    'preacher', coalesce((select jsonb_agg(jsonb_build_object('preacher_id', p.id,
        'organization_id', p.organization_id, 'can_submit', public.taysir_is_own_preacher(p.id)))
      from public.taysir_preachers p where p.linked_profile_id = auth.uid()), '[]'::jsonb))
  where auth.uid() is not null;
$$;

-- ---------------------------------------------------------------------------
-- Submitting
-- ---------------------------------------------------------------------------
create function public.taysir_submit(p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.taysir_actor();
  pr public.taysir_preachers;
  coord boolean;
  direct boolean := coalesce((p->>'direct')::boolean, false);
  status text;
  req uuid := gen_random_uuid();
  ser uuid;
  mosque uuid := nullif(p->>'mosque_id', '')::uuid;
  nm jsonb := p->'new_mosque';
  dates date[];
  d date;
  i integer := 0;
  today date := public.taysir_today();
  replaces uuid := nullif(p->>'replaces', '')::uuid;
  title_ar text := btrim(coalesce(p->>'title_ar', ''));
  title_en text := btrim(coalesce(p->>'title_en', ''));
  names record;
begin
  select * into pr from public.taysir_preachers where id = (p->>'preacher_id')::uuid;
  if not found then raise exception 'Preacher not found' using errcode = '22023'; end if;
  coord := public.taysir_is_coordinator(pr.organization_id);
  if not coord and not public.taysir_is_own_preacher(pr.id) then
    raise exception 'Submitting not permitted' using errcode = '42501';
  end if;
  if direct and not coord then raise exception 'Only coordinators publish directly' using errcode = '42501'; end if;
  if not public.is_admin_tier() and not exists (select 1 from public.taysir_organizations
      where organization_id = pr.organization_id and enabled) then
    raise exception 'Taysir is not enabled for this organization' using errcode = '42501';
  end if;

  select array_agg(distinct x::date order by x::date) into dates
    from jsonb_array_elements_text(coalesce(p->'dates', '[]'::jsonb)) x;
  if dates is null or cardinality(dates) not between 1 and 40 then
    raise exception 'Between 1 and 40 dates are required' using errcode = '22023';
  end if;
  if dates[1] < today or dates[cardinality(dates)] > today + 400 then
    raise exception 'Dates must be from today up to a year ahead' using errcode = '22023';
  end if;

  if nm is not null and jsonb_typeof(nm) = 'object' then
    insert into public.taysir_mosques(name_ar, name_en, district_id, latitude, longitude, maps_url,
      facilities, verified, suggested_by, created_by)
    values (btrim(nm->>'name_ar'), btrim(coalesce(nm->>'name_en', '')), nm->>'district_id',
      (nm->>'latitude')::double precision, (nm->>'longitude')::double precision, nullif(nm->>'maps_url', ''),
      coalesce(array(select jsonb_array_elements_text(nm->'facilities')), '{}'), coord, actor, actor)
    returning id into mosque;
  elsif mosque is null or not exists (select 1 from public.taysir_mosques m where m.id = mosque
      and (m.verified or m.suggested_by = actor or coord)) then
    raise exception 'Choose a mosque' using errcode = '22023';
  end if;

  if replaces is not null then
    update public.taysir_lessons set status = 'withdrawn', updated_at = now()
      where request_id = replaces and preacher_id = pr.id and status in ('pending','rejected');
    update public.taysir_series set status = 'withdrawn'
      where request_id = replaces and preacher_id = pr.id and status in ('pending','rejected');
  end if;

  status := case when direct then 'approved' else 'pending' end;
  if cardinality(dates) > 1 then
    insert into public.taysir_series(organization_id, request_id, preacher_id, mosque_id, title_ar, title_en,
      type, topic, language, audience, slot, total, status)
    values (pr.organization_id, req, pr.id, mosque, title_ar, title_en, p->>'type', p->>'topic',
      coalesce(p->>'language', 'ar'), coalesce(p->>'audience', 'all'), p->>'slot', cardinality(dates), status)
    returning id into ser;
  end if;

  foreach d in array dates loop
    i := i + 1;
    insert into public.taysir_lessons(organization_id, request_id, series_id, seq, type, topic, title_ar, title_en,
      description_ar, description_en, preacher_id, mosque_id, lesson_date, slot, exact_time, language,
      interpretation, audience, women_section, streamed, notify_followers, status, submitted_by,
      reviewed_by, reviewed_at)
    values (pr.organization_id, req, ser, case when ser is null then null else i end, p->>'type', p->>'topic',
      title_ar, title_en, coalesce(p->>'description_ar', ''), coalesce(p->>'description_en', ''),
      pr.id, mosque, d, p->>'slot', nullif(p->>'exact_time', '')::time, coalesce(p->>'language', 'ar'),
      nullif(p->>'interpretation', ''), coalesce(p->>'audience', 'all'),
      coalesce((p->>'women_section')::boolean, false), coalesce((p->>'streamed')::boolean, false),
      coalesce((p->>'notify_followers')::boolean, true), status, actor,
      case when direct then actor end, case when direct then now() end);
  end loop;

  select * into names from private.taysir_preacher_names(pr.id);
  if direct then
    perform private.taysir_audit(pr.organization_id, 'approve',
      title_ar || ' — ' || names.name_ar || ' (اعتماد مباشر)', coalesce(nullif(title_en, ''), title_ar) || ', ' || names.name_en || ' (approved on entry)');
    if coalesce((p->>'notify_followers')::boolean, true) then
      perform private.taysir_notify(f.profile_id, 'sparkle', 'درس جديد من داعية تتابعه', 'New lesson from a preacher you follow',
        names.name_ar || ': ' || title_ar, names.name_en || ': ' || coalesce(nullif(title_en, ''), title_ar), '/taysir/requests/' || req)
      from public.taysir_follows f where f.kind = 'preacher' and f.target_id = pr.id and f.profile_id <> actor;
    end if;
  else
    perform private.taysir_audit(pr.organization_id, 'submit', title_ar, coalesce(nullif(title_en, ''), title_ar));
    perform private.taysir_notify(c, 'inbox', 'طلب جديد بانتظار المراجعة', 'New request to review',
      title_ar || ' — ' || names.name_ar, coalesce(nullif(title_en, ''), title_ar) || ', ' || names.name_en, '/taysir/console/review')
    from private.taysir_coordinators(pr.organization_id) c;
  end if;
  return req;
end; $$;

-- ---------------------------------------------------------------------------
-- Reviewing
-- ---------------------------------------------------------------------------
create function public.taysir_review(p_requests uuid[], p_decision text, p_reason text default null)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.taysir_actor();
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
  next_status := case when p_decision = 'approve' then 'approved' else 'rejected' end;
  for r in
    select l.request_id, l.organization_id, l.preacher_id, l.title_ar, l.title_en, l.notify_followers, l.series_id
      from public.taysir_lessons l
     where l.request_id = any(p_requests) and l.status = 'pending'
     order by l.request_id, l.lesson_date
  loop
    if not public.taysir_is_coordinator(r.organization_id) then
      raise exception 'Review not permitted' using errcode = '42501';
    end if;
    -- One pass per request, on its first pending session.
    if not exists (select 1 from public.taysir_lessons where request_id = r.request_id and status = 'pending') then
      continue;
    end if;
    update public.taysir_lessons set status = next_status, reviewed_by = actor, reviewed_at = now(),
        rejection_reason = case when next_status = 'rejected' then reason end, updated_at = now()
      where request_id = r.request_id and status = 'pending';
    update public.taysir_series set status = next_status where request_id = r.request_id and status = 'pending';
    n := n + 1;
    select * into names from private.taysir_preacher_names(r.preacher_id);
    perform private.taysir_audit(r.organization_id, p_decision,
      r.title_ar || ' — ' || names.name_ar, coalesce(nullif(r.title_en, ''), r.title_ar) || ', ' || names.name_en);
    if next_status = 'approved' then
      perform private.taysir_notify(p.linked_profile_id, 'check', 'اعتُمد: ' || r.title_ar,
        'Approved: ' || coalesce(nullif(r.title_en, ''), r.title_ar),
        'ظهر الدرس للجميع وعلى الخريطة، وأُشعر متابعوك.', 'The lesson is public and on the map, and your followers were notified.',
        '/taysir/me/lessons?tab=approved')
      from public.taysir_preachers p where p.id = r.preacher_id;
      if r.notify_followers then
        perform private.taysir_notify(f.profile_id, 'sparkle', 'درس جديد من داعية تتابعه', 'New lesson from a preacher you follow',
          names.name_ar || ': ' || r.title_ar, names.name_en || ': ' || coalesce(nullif(r.title_en, ''), r.title_ar),
          '/taysir/requests/' || r.request_id)
        from (select distinct f.profile_id from public.taysir_follows f
               where (f.kind = 'preacher' and f.target_id = r.preacher_id)
                  or (f.kind = 'mosque' and f.target_id in (select mosque_id from public.taysir_lessons where request_id = r.request_id))) f
        where f.profile_id is distinct from actor;
      end if;
    else
      perform private.taysir_notify(p.linked_profile_id, 'x', 'لم يُعتمد: ' || r.title_ar,
        'Not approved: ' || coalesce(nullif(r.title_en, ''), r.title_ar), 'السبب: ' || reason, 'Reason: ' || reason,
        '/taysir/me/lessons?tab=rejected')
      from public.taysir_preachers p where p.id = r.preacher_id;
    end if;
  end loop;
  return n;
end; $$;

-- Undo a decision the caller made in the last 15 minutes.
create function public.taysir_undo_review(p_requests uuid[]) returns integer
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); n integer; org uuid;
begin
  select organization_id into org from public.taysir_lessons where request_id = any(p_requests) limit 1;
  update public.taysir_lessons set status = 'pending', reviewed_by = null, reviewed_at = null,
      rejection_reason = null, updated_at = now()
    where request_id = any(p_requests) and status in ('approved','rejected') and reviewed_by = actor
      and reviewed_at > now() - interval '15 minutes' and public.taysir_is_coordinator(organization_id);
  get diagnostics n = row_count;
  update public.taysir_series s set status = 'pending' where s.request_id = any(p_requests)
    and s.status in ('approved','rejected')
    and exists (select 1 from public.taysir_lessons l where l.series_id = s.id and l.status = 'pending');
  if n > 0 then
    perform private.taysir_audit(org, 'undo', 'تراجع عن قرار', 'Undid a decision');
  end if;
  return n;
end; $$;

create function public.taysir_withdraw(p_request uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); pr uuid; org uuid; t_ar text; t_en text;
begin
  select preacher_id, organization_id, title_ar, coalesce(nullif(title_en, ''), title_ar)
    into pr, org, t_ar, t_en
    from public.taysir_lessons where request_id = p_request and status = 'pending' limit 1;
  if pr is null then raise exception 'Nothing to withdraw' using errcode = '22023'; end if;
  if not public.taysir_is_own_preacher(pr) and not public.taysir_is_coordinator(org) then
    raise exception 'Withdraw not permitted' using errcode = '42501';
  end if;
  update public.taysir_lessons set status = 'withdrawn', updated_at = now()
    where request_id = p_request and status = 'pending';
  update public.taysir_series set status = 'withdrawn' where request_id = p_request and status = 'pending';
  perform private.taysir_audit(org, 'withdraw', t_ar, t_en);
end; $$;

-- Cancel one approved, upcoming session. It stays visible, marked cancelled,
-- and everyone with a reminder is told at once.
create function public.taysir_cancel_lesson(p_lesson uuid, p_reason text) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.taysir_actor();
  l public.taysir_lessons;
  coord boolean;
  n integer;
  reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  select * into l from public.taysir_lessons where id = p_lesson for update;
  if not found or l.status <> 'approved' or l.lesson_date < public.taysir_today() then
    raise exception 'Only an upcoming approved session can be cancelled' using errcode = '22023';
  end if;
  coord := public.taysir_is_coordinator(l.organization_id);
  if not coord and not public.taysir_is_own_preacher(l.preacher_id) then
    raise exception 'Cancel not permitted' using errcode = '42501';
  end if;
  if reason is null then raise exception 'A reason is required' using errcode = '22023'; end if;
  update public.taysir_lessons set status = 'cancelled', cancel_reason = reason, updated_at = now() where id = l.id;
  select count(*) into n from public.taysir_reminders where lesson_id = l.id;
  perform private.taysir_notify(r.profile_id, 'alert', 'أُلغي موعد: ' || l.title_ar,
    'Cancelled: ' || coalesce(nullif(l.title_en, ''), l.title_ar),
    to_char(l.lesson_date, 'YYYY-MM-DD') || ' — ' || reason, to_char(l.lesson_date, 'YYYY-MM-DD') || ': ' || reason,
    '/taysir/lessons/' || l.id)
  from public.taysir_reminders r where r.lesson_id = l.id and r.profile_id <> actor;
  if not coord then
    perform private.taysir_notify(c, 'alert', 'ألغى داعية موعدًا', 'A preacher cancelled a session',
      l.title_ar || ' — ' || to_char(l.lesson_date, 'YYYY-MM-DD'),
      coalesce(nullif(l.title_en, ''), l.title_ar) || ', ' || to_char(l.lesson_date, 'YYYY-MM-DD'),
      '/taysir/lessons/' || l.id)
    from private.taysir_coordinators(l.organization_id) c;
  end if;
  perform private.taysir_audit(l.organization_id, 'cancel', l.title_ar || ' — ' || to_char(l.lesson_date, 'YYYY-MM-DD'),
    coalesce(nullif(l.title_en, ''), l.title_ar) || ', ' || to_char(l.lesson_date, 'YYYY-MM-DD'));
  return n;
end; $$;

-- A coordinator corrects an approved session in place (time, place, title).
-- Reminder holders hear about a change of date, time or mosque.
create function public.taysir_edit_lesson(p_lesson uuid, p jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.taysir_actor();
  l public.taysir_lessons;
  moved boolean;
begin
  select * into l from public.taysir_lessons where id = p_lesson for update;
  if not found or not public.taysir_is_coordinator(l.organization_id) then
    raise exception 'Edit not permitted' using errcode = '42501';
  end if;
  if l.status not in ('approved','pending') then
    raise exception 'Only pending or approved sessions can be edited' using errcode = '22023';
  end if;
  if p ? 'mosque_id' and not exists (select 1 from public.taysir_mosques where id = (p->>'mosque_id')::uuid) then
    raise exception 'Choose a mosque' using errcode = '22023';
  end if;
  update public.taysir_lessons set
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
    into moved from public.taysir_lessons n where n.id = l.id;
  if moved and l.status = 'approved' then
    perform private.taysir_notify(r.profile_id, 'clock', 'تغيّر موعد درس', 'A lesson time or place changed',
      l.title_ar, coalesce(nullif(l.title_en, ''), l.title_ar), '/taysir/lessons/' || l.id)
    from public.taysir_reminders r where r.lesson_id = l.id;
  end if;
  perform private.taysir_audit(l.organization_id, 'edit', l.title_ar, coalesce(nullif(l.title_en, ''), l.title_ar));
end; $$;

create function public.taysir_post_report(p_lesson uuid, p_attendance integer, p_women integer,
  p_issue text, p_notes text) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); l public.taysir_lessons;
begin
  select * into l from public.taysir_lessons where id = p_lesson;
  if not found or l.status <> 'approved' or l.lesson_date > public.taysir_today() then
    raise exception 'Reports are for sessions that have been held' using errcode = '22023';
  end if;
  if not public.taysir_is_own_preacher(l.preacher_id) and not public.taysir_is_coordinator(l.organization_id) then
    raise exception 'Report not permitted' using errcode = '42501';
  end if;
  insert into public.taysir_lesson_reports(lesson_id, attendance, women, issue, notes, submitted_by)
  values (l.id, p_attendance, coalesce(p_women, 0), coalesce(p_issue, 'none'), coalesce(p_notes, ''), actor)
  on conflict (lesson_id) do update set attendance = excluded.attendance, women = excluded.women,
    issue = excluded.issue, notes = excluded.notes, submitted_by = excluded.submitted_by, submitted_at = now();
  perform private.taysir_audit(l.organization_id, 'report', l.title_ar, coalesce(nullif(l.title_en, ''), l.title_ar));
end; $$;

-- ---------------------------------------------------------------------------
-- Viewer reports of a wrong time or place
-- ---------------------------------------------------------------------------
create function public.taysir_flag(p_lesson uuid, p_kind text, p_message text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); l public.taysir_lessons; id uuid;
begin
  select * into l from public.taysir_lessons where taysir_lessons.id = p_lesson and status in ('approved','cancelled');
  if not found then raise exception 'Lesson not found' using errcode = '22023'; end if;
  if (select count(*) from public.taysir_flags f where f.reporter_id = actor
       and f.created_at > now() - interval '1 day') >= 10 then
    raise exception 'Too many reports today' using errcode = '54000';
  end if;
  insert into public.taysir_flags(lesson_id, organization_id, kind, message, reporter_id)
  values (l.id, l.organization_id, p_kind, btrim(coalesce(p_message, '')), actor) returning taysir_flags.id into id;
  perform private.taysir_notify(c, 'flag', 'بلاغ جديد من مستخدم', 'New report from a user',
    l.title_ar, coalesce(nullif(l.title_en, ''), l.title_ar), '/taysir/console/review?filter=reports')
  from private.taysir_coordinators(l.organization_id) c;
  return id;
end; $$;

create function public.taysir_resolve_flag(p_flag uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); org uuid;
begin
  select organization_id into org from public.taysir_flags where id = p_flag;
  if org is null or not public.taysir_is_coordinator(org) then
    raise exception 'Not permitted' using errcode = '42501';
  end if;
  update public.taysir_flags set status = 'resolved', resolved_by = actor, resolved_at = now() where id = p_flag;
  perform private.taysir_audit(org, 'resolve', 'بلاغ على درس', 'Report on a lesson');
end; $$;

-- ---------------------------------------------------------------------------
-- Preacher roster
-- ---------------------------------------------------------------------------
create function private.taysir_clean_phone(p text) returns text
language sql immutable set search_path = '' as $$
  select nullif(regexp_replace(coalesce(p, ''), '[^0-9+]', '', 'g'), '');
$$;
revoke all on function private.taysir_clean_phone(text) from public, anon, authenticated;

create function public.taysir_upsert_preacher(p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.taysir_actor();
  pid uuid := nullif(p->>'id', '')::uuid;
  org uuid;
  phone text := private.taysir_clean_phone(p->>'phone');
begin
  if pid is null then
    org := (p->>'organization_id')::uuid;
  else
    select organization_id into org from public.taysir_preachers where id = pid;
  end if;
  if org is null or not public.taysir_is_coordinator(org) then
    raise exception 'Roster management not permitted' using errcode = '42501';
  end if;
  if pid is null then
    insert into public.taysir_preachers(organization_id, name_ar, name_en, title_ar, title_en, bio_ar, bio_en,
      city, affiliation, languages, listed, created_by)
    values (org, btrim(p->>'name_ar'), btrim(coalesce(p->>'name_en', '')), btrim(coalesce(p->>'title_ar', '')),
      btrim(coalesce(p->>'title_en', '')), coalesce(p->>'bio_ar', ''), coalesce(p->>'bio_en', ''),
      coalesce(p->>'city', 'khobar'), coalesce(p->>'affiliation', 'coop'),
      coalesce(nullif(array(select jsonb_array_elements_text(p->'languages')), '{}'), '{ar}'),
      coalesce((p->>'listed')::boolean, true), actor)
    returning id into pid;
    perform private.taysir_audit(org, 'addPreacher', btrim(p->>'name_ar'), coalesce(nullif(btrim(p->>'name_en'), ''), btrim(p->>'name_ar')));
  else
    update public.taysir_preachers set
      name_ar = coalesce(nullif(btrim(p->>'name_ar'), ''), name_ar),
      name_en = coalesce(p->>'name_en', name_en),
      title_ar = coalesce(p->>'title_ar', title_ar), title_en = coalesce(p->>'title_en', title_en),
      bio_ar = coalesce(p->>'bio_ar', bio_ar), bio_en = coalesce(p->>'bio_en', bio_en),
      city = coalesce(p->>'city', city), affiliation = coalesce(p->>'affiliation', affiliation),
      languages = coalesce(nullif(array(select jsonb_array_elements_text(p->'languages')), '{}'), languages),
      listed = coalesce((p->>'listed')::boolean, listed), updated_at = now()
    where id = pid;
    perform private.taysir_audit(org, 'editPreacher', n.name_ar, n.name_en) from private.taysir_preacher_names(pid) n;
  end if;
  if p ? 'phone' then
    if phone is null then
      delete from private.taysir_preacher_contacts where preacher_id = pid;
    else
      insert into private.taysir_preacher_contacts(preacher_id, phone) values (pid, phone)
      on conflict (preacher_id) do update set phone = excluded.phone;
    end if;
  end if;
  return pid;
end; $$;

create function public.taysir_import_preachers(p_org uuid, p_rows jsonb) returns integer
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); r jsonb; pid uuid; n integer := 0;
begin
  if not public.taysir_is_coordinator(p_org) then
    raise exception 'Roster management not permitted' using errcode = '42501';
  end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 500 then
    raise exception 'Up to 500 rows' using errcode = '22023';
  end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    insert into public.taysir_preachers(organization_id, name_ar, name_en, city, affiliation, created_by)
    values (p_org, btrim(r->>'name'), '', coalesce(r->>'city', 'khobar'), coalesce(r->>'affiliation', 'coop'), actor)
    returning id into pid;
    if private.taysir_clean_phone(r->>'phone') is not null then
      insert into private.taysir_preacher_contacts(preacher_id, phone) values (pid, private.taysir_clean_phone(r->>'phone'));
    end if;
    n := n + 1;
  end loop;
  perform private.taysir_audit(p_org, 'import', 'استيراد ' || n || ' داعية', 'Imported ' || n || ' preachers');
  return n;
end; $$;

-- The roster as a coordinator sees it: masked phone, account state, permission.
create function public.taysir_roster(p_org uuid) returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select to_jsonb(p) || jsonb_build_object(
    'phone_mask', case when c.phone is null then null
      else left(c.phone, 2) || '•• ••• ' || right(c.phone, 3) end,
    'account', case when p.linked_profile_id is not null then 'linked'
      when exists (select 1 from private.taysir_invites i where i.preacher_id = p.id
        and i.consumed_at is null and i.expires_at > now()) then 'invited' else 'none' end,
    'can_submit', p.linked_profile_id is not null and exists (select 1 from public.user_permissions u
      where u.profile_id = p.linked_profile_id and u.permission_key = 'activities.submit'
        and u.organization_id = p.organization_id),
    'lessons_30d', (select count(*) from public.taysir_lessons l where l.preacher_id = p.id
      and l.status = 'approved' and l.lesson_date between public.taysir_today() - 30 and public.taysir_today()))
  from public.taysir_preachers p
  left join private.taysir_preacher_contacts c on c.preacher_id = p.id
  where p.organization_id = p_org and public.taysir_is_coordinator(p_org)
  order by p.name_ar;
$$;

create function public.taysir_reveal_phone(p_preacher uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); org uuid; phone text;
begin
  select organization_id into org from public.taysir_preachers where id = p_preacher;
  if org is null or not public.taysir_is_coordinator(org) then
    raise exception 'Not permitted' using errcode = '42501';
  end if;
  select c.phone into phone from private.taysir_preacher_contacts c where c.preacher_id = p_preacher;
  perform private.taysir_audit(org, 'phone', n.name_ar, n.name_en) from private.taysir_preacher_names(p_preacher) n;
  return phone;
end; $$;

create function public.taysir_set_submit(p_preacher uuid, p_enabled boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); pr public.taysir_preachers;
begin
  select * into pr from public.taysir_preachers where id = p_preacher;
  if not found or not public.taysir_is_coordinator(pr.organization_id) then
    raise exception 'Not permitted' using errcode = '42501';
  end if;
  if pr.linked_profile_id is null then
    raise exception 'The preacher has not linked an account yet' using errcode = '22023';
  end if;
  if p_enabled then
    insert into public.user_permissions(profile_id, permission_key, organization_id, granted_by)
    values (pr.linked_profile_id, 'activities.submit', pr.organization_id, actor)
    on conflict (profile_id, permission_key, organization_id) do nothing;
  else
    delete from public.user_permissions where profile_id = pr.linked_profile_id
      and permission_key = 'activities.submit' and organization_id = pr.organization_id;
  end if;
  perform private.taysir_audit(pr.organization_id, case when p_enabled then 'grantSubmit' else 'revokeSubmit' end,
    pr.name_ar, coalesce(nullif(pr.name_en, ''), pr.name_ar));
end; $$;

create function public.taysir_unlink_preacher(p_preacher uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); pr public.taysir_preachers;
begin
  select * into pr from public.taysir_preachers where id = p_preacher for update;
  if not found or not public.taysir_is_coordinator(pr.organization_id) then
    raise exception 'Not permitted' using errcode = '42501';
  end if;
  if pr.linked_profile_id is not null then
    delete from public.user_permissions where profile_id = pr.linked_profile_id
      and permission_key = 'activities.submit' and organization_id = pr.organization_id;
    update public.taysir_preachers set linked_profile_id = null, updated_at = now() where id = pr.id;
  end if;
  perform private.taysir_audit(pr.organization_id, 'unlink', pr.name_ar, coalesce(nullif(pr.name_en, ''), pr.name_ar));
end; $$;

-- ---------------------------------------------------------------------------
-- Invitations (replace Taysir's shared default password)
-- ---------------------------------------------------------------------------
create function public.taysir_create_invite(p_preacher uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.taysir_actor();
  pr public.taysir_preachers;
  token text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  expires timestamptz := now() + interval '14 days';
begin
  select * into pr from public.taysir_preachers where id = p_preacher;
  if not found or not public.taysir_is_coordinator(pr.organization_id) then
    raise exception 'Not permitted' using errcode = '42501';
  end if;
  if pr.linked_profile_id is not null then
    raise exception 'This preacher already linked an account' using errcode = '22023';
  end if;
  update private.taysir_invites set consumed_at = now() where preacher_id = pr.id and consumed_at is null;
  insert into private.taysir_invites(preacher_id, token_hash, created_by, expires_at)
  values (pr.id, encode(sha256(convert_to(token, 'UTF8')), 'hex'), actor, expires);
  perform private.taysir_audit(pr.organization_id, 'invite', pr.name_ar, coalesce(nullif(pr.name_en, ''), pr.name_ar));
  return jsonb_build_object('token', token, 'expires_at', expires);
end; $$;

-- What an invitation link shows before sign-in: the preacher's name and the
-- organization. Nothing personal; the token itself is the secret.
create function public.taysir_invite_info(p_token text) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('preacher_id', p.id, 'name_ar', p.name_ar, 'name_en', p.name_en,
      'city', p.city, 'affiliation', p.affiliation, 'languages', p.languages,
      'organization_id', o.id, 'organization_name_ar', o.name_ar, 'organization_name_en', o.name_en,
      'expires_at', i.expires_at)
    from private.taysir_invites i
    join public.taysir_preachers p on p.id = i.preacher_id
    join public.organizations o on o.id = p.organization_id
   where i.token_hash = encode(sha256(convert_to(coalesce(p_token, ''), 'UTF8')), 'hex')
     and i.consumed_at is null and i.expires_at > now() and p.linked_profile_id is null;
$$;

create function public.taysir_claim_invite(p_token text, p_languages text[] default null) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.taysir_actor();
  inv private.taysir_invites;
  pr public.taysir_preachers;
begin
  select * into inv from private.taysir_invites
   where token_hash = encode(sha256(convert_to(coalesce(p_token, ''), 'UTF8')), 'hex') for update;
  if not found or inv.consumed_at is not null or inv.expires_at <= now() then
    raise exception 'Invitation expired or already used' using errcode = '55000';
  end if;
  select * into pr from public.taysir_preachers where id = inv.preacher_id for update;
  if pr.linked_profile_id is not null then
    raise exception 'Invitation expired or already used' using errcode = '55000';
  end if;
  if exists (select 1 from public.taysir_preachers where organization_id = pr.organization_id
      and linked_profile_id = actor) then
    raise exception 'Your account is already linked to another preacher in this organization' using errcode = '23505';
  end if;
  update private.taysir_invites set consumed_at = now(), consumed_by = actor where id = inv.id;
  update public.taysir_preachers set linked_profile_id = actor,
    languages = coalesce(nullif(p_languages, '{}'), languages), updated_at = now() where id = pr.id;
  insert into public.user_permissions(profile_id, permission_key, organization_id, granted_by)
  values (actor, 'activities.submit', pr.organization_id, inv.created_by)
  on conflict (profile_id, permission_key, organization_id) do nothing;
  perform private.taysir_audit(pr.organization_id, 'claim', pr.name_ar, coalesce(nullif(pr.name_en, ''), pr.name_ar));
  perform private.taysir_notify(c, 'user', 'ربط داعية حسابه', 'A preacher linked their account',
    pr.name_ar, coalesce(nullif(pr.name_en, ''), pr.name_ar), '/taysir/console/preachers')
  from private.taysir_coordinators(pr.organization_id) c;
  return pr.id;
end; $$;

-- ---------------------------------------------------------------------------
-- Mosque directory
-- ---------------------------------------------------------------------------
create function public.taysir_upsert_mosque(p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); mid uuid := nullif(p->>'id', '')::uuid;
begin
  if not public.taysir_coordinates_any() then
    raise exception 'Mosque management not permitted' using errcode = '42501';
  end if;
  if mid is null then
    insert into public.taysir_mosques(name_ar, name_en, district_id, latitude, longitude, maps_url,
      facilities, verified, created_by)
    values (btrim(p->>'name_ar'), btrim(coalesce(p->>'name_en', '')), p->>'district_id',
      (p->>'latitude')::double precision, (p->>'longitude')::double precision, nullif(p->>'maps_url', ''),
      coalesce(array(select jsonb_array_elements_text(p->'facilities')), '{}'), true, actor)
    returning id into mid;
    perform private.taysir_audit(null, 'addMosque', btrim(p->>'name_ar'), coalesce(nullif(btrim(p->>'name_en'), ''), btrim(p->>'name_ar')));
  else
    update public.taysir_mosques set
      name_ar = coalesce(nullif(btrim(p->>'name_ar'), ''), name_ar), name_en = coalesce(p->>'name_en', name_en),
      district_id = coalesce(p->>'district_id', district_id),
      latitude = case when p ? 'latitude' then (p->>'latitude')::double precision else latitude end,
      longitude = case when p ? 'longitude' then (p->>'longitude')::double precision else longitude end,
      maps_url = case when p ? 'maps_url' then nullif(p->>'maps_url', '') else maps_url end,
      facilities = case when p ? 'facilities'
        then array(select jsonb_array_elements_text(p->'facilities')) else facilities end,
      updated_at = now()
    where id = mid;
  end if;
  return mid;
end; $$;

create function public.taysir_verify_mosque(p_mosque uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); m public.taysir_mosques;
begin
  if not public.taysir_coordinates_any() then raise exception 'Not permitted' using errcode = '42501'; end if;
  update public.taysir_mosques set verified = true, updated_at = now() where id = p_mosque returning * into m;
  if m.id is null then raise exception 'Mosque not found' using errcode = '22023'; end if;
  perform private.taysir_audit(null, 'verifyMosque', m.name_ar, coalesce(nullif(m.name_en, ''), m.name_ar));
end; $$;

-- Reject a suggestion, or merge a duplicate into an existing mosque (its
-- sessions move with it).
create function public.taysir_reject_mosque(p_mosque uuid, p_merge_into uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); m public.taysir_mosques;
begin
  if not public.taysir_coordinates_any() then raise exception 'Not permitted' using errcode = '42501'; end if;
  select * into m from public.taysir_mosques where id = p_mosque for update;
  if not found then raise exception 'Mosque not found' using errcode = '22023'; end if;
  if p_merge_into is not null then
    if p_merge_into = p_mosque or not exists (select 1 from public.taysir_mosques where id = p_merge_into and verified) then
      raise exception 'Merge into a verified mosque' using errcode = '22023';
    end if;
    update public.taysir_lessons set mosque_id = p_merge_into, updated_at = now() where mosque_id = p_mosque;
    update public.taysir_series set mosque_id = p_merge_into where mosque_id = p_mosque;
    update public.taysir_follows set target_id = p_merge_into where kind = 'mosque' and target_id = p_mosque
      and not exists (select 1 from public.taysir_follows f2 where f2.profile_id = taysir_follows.profile_id
        and f2.kind = 'mosque' and f2.target_id = p_merge_into);
  elsif exists (select 1 from public.taysir_lessons where mosque_id = p_mosque and status in ('approved','cancelled')) then
    raise exception 'Approved sessions use this mosque. Merge it instead.' using errcode = '23503';
  else
    update public.taysir_lessons set status = 'rejected', rejection_reason = 'المسجد غير معتمد / The mosque was not verified',
      reviewed_by = actor, reviewed_at = now() where mosque_id = p_mosque and status = 'pending';
    delete from public.taysir_lessons where mosque_id = p_mosque;
    delete from public.taysir_series where mosque_id = p_mosque;
  end if;
  delete from public.taysir_follows where kind = 'mosque' and target_id = p_mosque;
  delete from public.taysir_mosques where id = p_mosque;
  perform private.taysir_audit(null, case when p_merge_into is null then 'rejectMosque' else 'mergeMosque' end,
    m.name_ar, coalesce(nullif(m.name_en, ''), m.name_ar));
end; $$;

create function public.taysir_mark_notifications_read(p_ids uuid[] default null) returns integer
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); n integer;
begin
  update public.taysir_notifications set read_at = now()
   where profile_id = actor and read_at is null and (p_ids is null or id = any(p_ids));
  get diagnostics n = row_count;
  return n;
end; $$;

-- ---------------------------------------------------------------------------
-- Team and module
-- ---------------------------------------------------------------------------
create function public.taysir_team(p_org uuid) returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('profile_id', x.profile_id, 'role', x.role,
      'name_ar', coalesce(p.display_name_ar, p.display_name_en, ''), 'name_en', coalesce(p.display_name_en, p.display_name_ar, ''),
      'avatar_url', p.avatar_url,
      'coordinator', u.profile_id is not null, 'granted_at', u.granted_at,
      'granted_by_name_ar', g.display_name_ar, 'granted_by_name_en', g.display_name_en)
  from (
    select o.owner_profile_id as profile_id, 'owner'::text as role from public.organizations o where o.id = p_org
    union
    select m.profile_id, m.role from public.org_memberships m
      where m.organization_id = p_org and m.status = 'active' and m.role <> 'owner'
    union
    select u2.profile_id, 'coordinator' from public.user_permissions u2
      where u2.organization_id = p_org and u2.permission_key = 'activities.coordinate'
        and not exists (select 1 from public.org_memberships m2 where m2.organization_id = p_org
          and m2.profile_id = u2.profile_id and m2.status = 'active')
        and u2.profile_id <> (select owner_profile_id from public.organizations where id = p_org)
  ) x
  join public.profiles p on p.id = x.profile_id
  left join public.user_permissions u on u.profile_id = x.profile_id
    and u.permission_key = 'activities.coordinate' and u.organization_id = p_org
  left join public.profiles g on g.id = u.granted_by
  where public.taysir_is_coordinator(p_org) or public.taysir_is_org_leader(p_org)
  order by x.role = 'owner' desc, p.display_name_en;
$$;

create function public.taysir_set_coordinator(p_org uuid, p_profile uuid, p_enabled boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); who text;
begin
  if not (public.is_admin_tier() or public.taysir_is_org_leader(p_org)) then
    raise exception 'Only the organization owner or an admin grants coordinator' using errcode = '42501';
  end if;
  if p_enabled and not exists (select 1 from public.org_memberships m where m.organization_id = p_org
      and m.profile_id = p_profile and m.status = 'active')
    and not exists (select 1 from public.organizations o where o.id = p_org and o.owner_profile_id = p_profile)
    and not public.is_admin_tier() then
    raise exception 'Coordinators must be members of the organization' using errcode = '22023';
  end if;
  if p_enabled then
    insert into public.user_permissions(profile_id, permission_key, organization_id, granted_by)
    values (p_profile, 'activities.coordinate', p_org, actor)
    on conflict (profile_id, permission_key, organization_id) do update set granted_by = excluded.granted_by,
      granted_at = now();
  else
    delete from public.user_permissions where profile_id = p_profile
      and permission_key = 'activities.coordinate' and organization_id = p_org;
  end if;
  select coalesce(display_name_ar, display_name_en, '') into who from public.profiles where id = p_profile;
  perform private.taysir_audit(p_org, case when p_enabled then 'grant' else 'revoke' end,
    who || ' ← منسق', who || ' → coordinator');
end; $$;

create function public.taysir_set_org_enabled(p_org uuid, p_enabled boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); o public.organizations;
begin
  if not public.is_master_admin() then
    raise exception 'Only a master admin enables Taysir' using errcode = '42501';
  end if;
  select * into o from public.organizations where id = p_org;
  if not found then raise exception 'Organization not found' using errcode = '22023'; end if;
  insert into public.taysir_organizations(organization_id, enabled, updated_by)
  values (p_org, p_enabled, actor)
  on conflict (organization_id) do update set enabled = excluded.enabled, updated_by = actor, updated_at = now();
  perform private.taysir_audit(p_org, case when p_enabled then 'enable' else 'disable' end, o.name_ar, o.name_en);
end; $$;

create function public.taysir_admin_organizations() returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('organization_id', o.id, 'name_ar', o.name_ar, 'name_en', o.name_en,
      'is_verified', o.is_verified, 'enabled', coalesce(t.enabled, false))
    from public.organizations o
    left join public.taysir_organizations t on t.organization_id = o.id
   where public.is_admin_tier()
   order by coalesce(t.enabled, false) desc, o.name_en;
$$;

-- Admins manage coordinators across organizations: everyone who holds
-- activities.coordinate, and one person's organizations set in one step
-- (adding, changing and removing a coordinator are the same call).
create function public.taysir_admin_coordinators() returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('profile_id', p.id,
      'name_ar', coalesce(nullif(p.display_name_ar, ''), p.display_name_en, ''),
      'name_en', coalesce(nullif(p.display_name_en, ''), p.display_name_ar, ''),
      'email', p.email,
      'organizations', jsonb_agg(u.organization_id order by u.granted_at))
    from public.user_permissions u
    join public.profiles p on p.id = u.profile_id
   where u.permission_key = 'activities.coordinate' and u.organization_id is not null
     and public.is_admin_tier() and not public.is_banned(auth.uid())
   group by p.id
   order by min(u.granted_at);
$$;

create function public.taysir_set_coordinator_orgs(p_profile uuid, p_orgs uuid[]) returns integer
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.taysir_actor(); who text; r record; n integer := 0;
begin
  if not public.is_admin_tier() then
    raise exception 'Only an admin manages coordinators across organizations' using errcode = '42501';
  end if;
  p_orgs := coalesce(p_orgs, '{}');
  if cardinality(p_orgs) > 100 then
    raise exception 'Too many organizations' using errcode = '22023';
  end if;
  select coalesce(nullif(display_name_ar, ''), nullif(display_name_en, ''), email, '') into who
    from public.profiles where id = p_profile;
  if not found then raise exception 'Account not found' using errcode = '22023'; end if;
  if cardinality(p_orgs) > 0 and public.is_banned(p_profile) then
    raise exception 'A banned account cannot coordinate' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(p_orgs) x where not exists (select 1 from public.organizations o where o.id = x)) then
    raise exception 'Organization not found' using errcode = '22023';
  end if;
  for r in delete from public.user_permissions
      where profile_id = p_profile and permission_key = 'activities.coordinate'
        and organization_id is not null and not (organization_id = any(p_orgs))
      returning organization_id loop
    perform private.taysir_audit(r.organization_id, 'revoke', who || ' ← منسق', who || ' → coordinator');
    n := n + 1;
  end loop;
  for r in insert into public.user_permissions(profile_id, permission_key, organization_id, granted_by)
      select distinct p_profile, 'activities.coordinate', x, actor from unnest(p_orgs) x
      on conflict (profile_id, permission_key, organization_id) do nothing
      returning organization_id loop
    perform private.taysir_audit(r.organization_id, 'grant', who || ' ← منسق', who || ' → coordinator');
    n := n + 1;
  end loop;
  return n;
end; $$;

-- Public organization names for lesson cards ("Organized by").
create function public.taysir_public_organizations() returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('organization_id', o.id, 'name_ar', o.name_ar, 'name_en', o.name_en,
      'avatar_url', o.avatar_url, 'is_verified', o.is_verified)
    from public.organizations o
    join public.taysir_organizations t on t.organization_id = o.id and t.enabled;
$$;

-- ---------------------------------------------------------------------------
-- Function privileges
-- ---------------------------------------------------------------------------
do $$
declare f regprocedure;
begin
  for f in select p.oid::regprocedure from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname like 'taysir\_%'
  loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
-- Guests read the module's organizations and open an invitation link.
grant execute on function public.taysir_public_organizations() to anon;
grant execute on function public.taysir_invite_info(text) to anon;

-- ---------------------------------------------------------------------------
-- Data rights: the account export carries Taysir's personal data too.
-- ---------------------------------------------------------------------------
alter function public.export_my_data() rename to export_my_data_core;
alter function public.export_my_data_core() set schema private;
revoke all on function private.export_my_data_core() from public, anon, authenticated;

create function public.export_my_data() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v uuid := auth.uid();
begin
  if v is null then raise exception 'Not signed in' using errcode = '42501'; end if;
  return private.export_my_data_core() || jsonb_build_object('taysir', jsonb_build_object(
    'reminders', coalesce((select jsonb_agg(to_jsonb(r) - 'profile_id') from public.taysir_reminders r where r.profile_id = v), '[]'::jsonb),
    'follows', coalesce((select jsonb_agg(to_jsonb(f) - 'profile_id') from public.taysir_follows f where f.profile_id = v), '[]'::jsonb),
    'attendance_log', coalesce((select jsonb_agg(to_jsonb(a) - 'profile_id') from public.taysir_attendance a where a.profile_id = v), '[]'::jsonb),
    'preferences', (select to_jsonb(p) - 'profile_id' from public.taysir_preferences p where p.profile_id = v),
    'notifications', coalesce((select jsonb_agg(to_jsonb(n) - 'profile_id' order by n.created_at) from public.taysir_notifications n where n.profile_id = v), '[]'::jsonb),
    'reports_filed', coalesce((select jsonb_agg(jsonb_build_object('lesson_id', f.lesson_id, 'kind', f.kind,
        'message', f.message, 'status', f.status, 'created_at', f.created_at)) from public.taysir_flags f where f.reporter_id = v), '[]'::jsonb),
    'preacher_cards', coalesce((select jsonb_agg(to_jsonb(p)) from public.taysir_preachers p where p.linked_profile_id = v), '[]'::jsonb),
    'lessons_submitted', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'title_ar', l.title_ar,
        'title_en', l.title_en, 'lesson_date', l.lesson_date, 'status', l.status, 'submitted_at', l.submitted_at))
      from public.taysir_lessons l where l.submitted_by = v), '[]'::jsonb)));
end; $$;
revoke all on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;

commit;
