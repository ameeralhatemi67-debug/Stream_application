-- Owner test notes 2026-11-03: admins add their own topics, languages and
-- audiences (kept or for one lesson), and their own cities and districts, and
-- the admin map moves to a chosen city or district.
--
-- * lesson_options: the topics, languages and audiences. The eight topics, seven
--   languages and five audiences stay as built-ins. An admin adds more with
--   lessons_add_option(); permanent = false means "for this lesson only": the
--   row exists so the lesson can name it, but pickers do not offer it again.
--   The CHECK lists on lessons are replaced by a trigger that asks this table.
-- * mosque_cities: the five cities (four plus "other") become rows with a map
--   centre; mosque_districts, preachers and preacher_applications point at them.
--   Districts get a map centre too (the thirteen from OpenStreetMap).
-- * lessons_add_city / lessons_add_district / lessons_set_place_location.
begin;

-- ---------------------------------------------------------------------------
-- Cities
-- ---------------------------------------------------------------------------
create table public.mosque_cities (
  id text primary key check (id ~ '^[a-z0-9_]{2,40}$'),
  name_ar text not null check (char_length(btrim(name_ar)) between 2 and 80),
  name_en text not null default '' check (char_length(name_en) <= 80),
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  zoom integer not null default 12 check (zoom between 5 and 18),
  sort integer not null default 0,
  check ((latitude is null) = (longitude is null))
);
comment on table public.mosque_cities is
  'Lessons: the cities of the district-then-mosque picker, each with a map centre. Public reference data.';

insert into public.mosque_cities(id, name_ar, name_en, latitude, longitude, zoom, sort) values
  ('khobar', 'الخبر', 'Al Khobar', 26.28, 50.21, 12, 10),
  ('dhahran', 'الظهران', 'Dhahran', 26.29, 50.12, 12, 20),
  ('dammam', 'الدمام', 'Dammam', 26.43, 50.09, 11, 30),
  ('qatif', 'القطيف', 'Qatif', 26.56, 50.01, 12, 40),
  ('other', 'أخرى', 'Other', null, null, 10, 900);

alter table public.mosque_districts drop constraint mosque_districts_city_check;
alter table public.mosque_districts add constraint mosque_districts_city_fkey
  foreign key (city) references public.mosque_cities(id);
alter table public.preachers drop constraint preachers_city_check;
alter table public.preachers add constraint preachers_city_fkey
  foreign key (city) references public.mosque_cities(id);
alter table public.preacher_applications drop constraint preacher_applications_city_check;
alter table public.preacher_applications add constraint preacher_applications_city_fkey
  foreign key (city) references public.mosque_cities(id);

-- ---------------------------------------------------------------------------
-- District centres
-- ---------------------------------------------------------------------------
alter table public.mosque_districts
  add column latitude double precision check (latitude between -90 and 90),
  add column longitude double precision check (longitude between -180 and 180),
  add constraint mosque_districts_pin_check check ((latitude is null) = (longitude is null));

update public.mosque_districts d set latitude = v.lat, longitude = v.lon
from (values
  ('aqrabiyah', 26.295254, 50.192623), ('thuqbah', 26.2744575, 50.1905645),
  ('khobar_north', 26.290894, 50.213508), ('rakah_south', 26.3516865, 50.199859),
  ('yarmouk', 26.3118538, 50.2197652), ('golden_belt', 26.3175035, 50.200547),
  ('doha_south', 26.3163569, 50.166205), ('qusur', 26.3490841, 50.1510713),
  ('faisaliyah', 26.392456, 50.0624695), ('shati_west', 26.4759515, 50.120869),
  ('badiyah', 26.4268598, 50.0909926), ('rayyan', 26.4051746, 50.0932491),
  ('qatif_central', 26.5652, 50.0121)
) as v(id, lat, lon) where d.id = v.id;

-- ---------------------------------------------------------------------------
-- Topics, languages and audiences
-- ---------------------------------------------------------------------------
create table public.lesson_options (
  kind text not null check (kind in ('topic', 'language', 'audience')),
  code text not null check (code ~ '^[a-z0-9_]{2,40}$'),
  name_ar text not null check (char_length(btrim(name_ar)) between 2 and 60),
  name_en text not null default '' check (char_length(name_en) <= 60),
  permanent boolean not null default true,
  built_in boolean not null default false,
  sort integer not null default 0,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (kind, code)
);
comment on table public.lesson_options is
  'Lessons: topics, languages and audiences. permanent = false is named by one lesson only and is not offered again.';

insert into public.lesson_options(kind, code, name_ar, name_en, built_in, sort) values
  ('topic', 'aqeedah', 'العقيدة', 'Aqeedah', true, 10), ('topic', 'fiqh', 'الفقه', 'Fiqh', true, 20),
  ('topic', 'tafsir', 'التفسير', 'Tafsir', true, 30), ('topic', 'hadith', 'الحديث', 'Hadith', true, 40),
  ('topic', 'seerah', 'السيرة', 'Seerah', true, 50), ('topic', 'family', 'الأسرة والتربية', 'Family', true, 60),
  ('topic', 'raqaiq', 'الرقائق', 'Reflections', true, 70), ('topic', 'intro', 'التعريف بالإسلام', 'Intro to Islam', true, 80),
  ('language', 'ar', 'العربية', 'Arabic', true, 10), ('language', 'en', 'الإنجليزية', 'English', true, 20),
  ('language', 'ur', 'الأردية', 'Urdu', true, 30), ('language', 'tl', 'التغالوغ', 'Tagalog', true, 40),
  ('language', 'bn', 'البنغالية', 'Bengali', true, 50), ('language', 'ml', 'المليالم', 'Malayalam', true, 60),
  ('language', 'id', 'الإندونيسية', 'Indonesian', true, 70),
  ('audience', 'all', 'الجميع', 'Everyone', true, 10), ('audience', 'men', 'رجال', 'Men', true, 20),
  ('audience', 'women', 'نساء', 'Women', true, 30), ('audience', 'youth', 'شباب', 'Youth', true, 40),
  ('audience', 'kids', 'أطفال', 'Children', true, 50);

alter table public.lessons
  drop constraint lessons_topic_check, drop constraint lessons_language_check,
  drop constraint lessons_interpretation_check, drop constraint lessons_audience_check;

create function private.check_lesson_options() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.lesson_options where kind = 'topic' and code = new.topic) then
    raise exception 'Unknown topic' using errcode = '23514';
  end if;
  if not exists (select 1 from public.lesson_options where kind = 'language' and code = new.language) then
    raise exception 'Unknown language' using errcode = '23514';
  end if;
  if new.interpretation is not null
     and not exists (select 1 from public.lesson_options where kind = 'language' and code = new.interpretation) then
    raise exception 'Unknown language' using errcode = '23514';
  end if;
  if not exists (select 1 from public.lesson_options where kind = 'audience' and code = new.audience) then
    raise exception 'Unknown audience' using errcode = '23514';
  end if;
  return new;
end; $$;
revoke all on function private.check_lesson_options() from public, anon, authenticated;
create trigger lessons_check_options before insert or update of topic, language, interpretation, audience
  on public.lessons for each row execute function private.check_lesson_options();

-- ---------------------------------------------------------------------------
-- Reads: public reference data, no direct writes
-- ---------------------------------------------------------------------------
alter table public.mosque_cities enable row level security;
alter table public.lesson_options enable row level security;
create policy mosque_cities_read on public.mosque_cities for select to anon, authenticated using (true);
create policy lesson_options_read on public.lesson_options for select to anon, authenticated using (true);
revoke all on public.mosque_cities, public.lesson_options from public, anon, authenticated;
grant select on public.mosque_cities, public.lesson_options to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Admin writes
-- ---------------------------------------------------------------------------
create function public.lessons_add_option(p_kind text, p_name_ar text, p_name_en text, p_permanent boolean)
returns text language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  ar text := btrim(coalesce(p_name_ar, ''));
  en text := btrim(coalesce(p_name_en, ''));
  c text;
begin
  if p_kind not in ('topic', 'language', 'audience') then
    raise exception 'Unknown kind' using errcode = '22023';
  end if;
  if char_length(ar) not between 2 and 60 or char_length(en) > 60 then
    raise exception 'Enter a name' using errcode = '22023';
  end if;
  -- The same name again gives the same option: a kept one is reused, and a
  -- one-time one is kept when asked to be.
  select o.code into c from public.lesson_options o where o.kind = p_kind and o.name_ar = ar;
  if c is not null then
    if coalesce(p_permanent, false) then
      update public.lesson_options set permanent = true where kind = p_kind and code = c;
    end if;
    return c;
  end if;
  c := 'x' || substr(md5(random()::text || clock_timestamp()::text), 1, 8);
  insert into public.lesson_options(kind, code, name_ar, name_en, permanent, sort, created_by)
  values (p_kind, c, ar, en, coalesce(p_permanent, false),
    coalesce((select max(sort) from public.lesson_options where kind = p_kind), 0) + 10, actor);
  perform private.lessons_audit('addOption', ar, coalesce(nullif(en, ''), ar));
  return c;
end; $$;

create function public.lessons_add_city(p_name_ar text, p_name_en text, p_lat double precision, p_lon double precision)
returns text language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  ar text := btrim(coalesce(p_name_ar, ''));
  en text := btrim(coalesce(p_name_en, ''));
  cid text;
begin
  if char_length(ar) not between 2 and 80 or char_length(en) > 80 then
    raise exception 'Enter a name' using errcode = '22023';
  end if;
  if exists (select 1 from public.mosque_cities where name_ar = ar) then
    raise exception 'This city is already in the list' using errcode = '23505';
  end if;
  cid := 'c' || substr(md5(random()::text || clock_timestamp()::text), 1, 8);
  insert into public.mosque_cities(id, name_ar, name_en, latitude, longitude, sort)
  values (cid, ar, en, p_lat, p_lon,
    coalesce((select max(sort) from public.mosque_cities where id <> 'other'), 0) + 10);
  perform private.lessons_audit('addCity', ar, coalesce(nullif(en, ''), ar));
  return cid;
end; $$;

create function public.lessons_add_district(p_city text, p_name_ar text, p_name_en text,
  p_lat double precision, p_lon double precision)
returns text language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  ar text := btrim(coalesce(p_name_ar, ''));
  en text := btrim(coalesce(p_name_en, ''));
  did text;
begin
  if not exists (select 1 from public.mosque_cities where id = p_city) then
    raise exception 'Choose a city' using errcode = '22023';
  end if;
  if char_length(ar) not between 2 and 80 or char_length(en) > 80 then
    raise exception 'Enter a name' using errcode = '22023';
  end if;
  if exists (select 1 from public.mosque_districts where city = p_city and name_ar = ar) then
    raise exception 'This area is already in the list' using errcode = '23505';
  end if;
  did := 'd' || substr(md5(random()::text || clock_timestamp()::text), 1, 8);
  insert into public.mosque_districts(id, city, name_ar, name_en, sort, latitude, longitude)
  values (did, p_city, ar, case when en = '' then ar else en end,
    coalesce((select max(sort) from public.mosque_districts where city = p_city and id <> 'unassigned'), 0) + 10,
    p_lat, p_lon);
  perform private.lessons_audit('addDistrict', ar, coalesce(nullif(en, ''), ar));
  return did;
end; $$;

create function public.lessons_set_place_location(p_kind text, p_id text, p_lat double precision, p_lon double precision)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin();
begin
  if p_kind = 'city' then
    update public.mosque_cities set latitude = p_lat, longitude = p_lon where id = p_id;
  elsif p_kind = 'district' then
    update public.mosque_districts set latitude = p_lat, longitude = p_lon where id = p_id;
  else
    raise exception 'Unknown kind' using errcode = '22023';
  end if;
  if not found then raise exception 'Not found' using errcode = '22023'; end if;
end; $$;

revoke all on function public.lessons_add_option(text, text, text, boolean),
  public.lessons_add_city(text, text, double precision, double precision),
  public.lessons_add_district(text, text, text, double precision, double precision),
  public.lessons_set_place_location(text, text, double precision, double precision) from public, anon;
grant execute on function public.lessons_add_option(text, text, text, boolean),
  public.lessons_add_city(text, text, double precision, double precision),
  public.lessons_add_district(text, text, text, double precision, double precision),
  public.lessons_set_place_location(text, text, double precision, double precision) to authenticated;

commit;
