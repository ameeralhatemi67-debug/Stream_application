-- Owner test notes 2026-11-03 (second round): admins edit and delete the topics,
-- languages, audiences, cities and areas they added.
--
-- * Built-ins (the eight topics, seven languages, five audiences, and the five
--   cities) are named by the app's translations, so they cannot be renamed or
--   deleted here. Areas can be renamed and deleted, built-in or not.
-- * Delete refuses what is still used: an option named by a lesson or series, a
--   city with areas or preachers, an area with mosques (SQLSTATE 23503).
begin;

create function public.lessons_update_option(p_kind text, p_code text, p_name_ar text, p_name_en text, p_permanent boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  ar text := btrim(coalesce(p_name_ar, ''));
  en text := btrim(coalesce(p_name_en, ''));
  o public.lesson_options;
begin
  select * into o from public.lesson_options where kind = p_kind and code = p_code;
  if not found then raise exception 'Not found' using errcode = '22023'; end if;
  if o.built_in then raise exception 'A built-in option cannot be changed' using errcode = '22023'; end if;
  if char_length(ar) not between 2 and 60 or char_length(en) > 60 then
    raise exception 'Enter a name' using errcode = '22023';
  end if;
  if exists (select 1 from public.lesson_options where kind = p_kind and name_ar = ar and code <> p_code) then
    raise exception 'This name is already in the list' using errcode = '23505';
  end if;
  update public.lesson_options set name_ar = ar, name_en = en, permanent = coalesce(p_permanent, permanent)
  where kind = p_kind and code = p_code;
  perform private.lessons_audit('editOption', ar, coalesce(nullif(en, ''), ar));
end; $$;

create function public.lessons_delete_option(p_kind text, p_code text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  o public.lesson_options;
  used boolean;
begin
  select * into o from public.lesson_options where kind = p_kind and code = p_code;
  if not found then raise exception 'Not found' using errcode = '22023'; end if;
  if o.built_in then raise exception 'A built-in option cannot be deleted' using errcode = '22023'; end if;
  used := case p_kind
    when 'topic' then exists (select 1 from public.lessons where topic = p_code) or exists (select 1 from public.lesson_series where topic = p_code)
    when 'language' then exists (select 1 from public.lessons where language = p_code or interpretation = p_code)
      or exists (select 1 from public.lesson_series where language = p_code)
    else exists (select 1 from public.lessons where audience = p_code) or exists (select 1 from public.lesson_series where audience = p_code)
  end;
  if used then raise exception 'A lesson still uses it' using errcode = '23503'; end if;
  delete from public.lesson_options where kind = p_kind and code = p_code;
  perform private.lessons_audit('deleteOption', o.name_ar, coalesce(nullif(o.name_en, ''), o.name_ar));
end; $$;

create function public.lessons_update_city(p_id text, p_name_ar text, p_name_en text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  ar text := btrim(coalesce(p_name_ar, ''));
  en text := btrim(coalesce(p_name_en, ''));
begin
  if p_id in ('khobar', 'dhahran', 'dammam', 'qatif', 'other') then
    raise exception 'A built-in city cannot be changed' using errcode = '22023';
  end if;
  if char_length(ar) not between 2 and 80 or char_length(en) > 80 then
    raise exception 'Enter a name' using errcode = '22023';
  end if;
  if exists (select 1 from public.mosque_cities where name_ar = ar and id <> p_id) then
    raise exception 'This city is already in the list' using errcode = '23505';
  end if;
  update public.mosque_cities set name_ar = ar, name_en = en where id = p_id;
  if not found then raise exception 'Not found' using errcode = '22023'; end if;
  perform private.lessons_audit('editCity', ar, coalesce(nullif(en, ''), ar));
end; $$;

create function public.lessons_delete_city(p_id text) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); n text;
begin
  if p_id in ('khobar', 'dhahran', 'dammam', 'qatif', 'other') then
    raise exception 'A built-in city cannot be deleted' using errcode = '22023';
  end if;
  select name_ar into n from public.mosque_cities where id = p_id;
  if not found then raise exception 'Not found' using errcode = '22023'; end if;
  begin
    delete from public.mosque_cities where id = p_id;
  exception when foreign_key_violation then
    raise exception 'The city still has areas or preachers' using errcode = '23503';
  end;
  perform private.lessons_audit('deleteCity', n, n);
end; $$;

create function public.lessons_update_district(p_id text, p_name_ar text, p_name_en text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  ar text := btrim(coalesce(p_name_ar, ''));
  en text := btrim(coalesce(p_name_en, ''));
  dcity text;
begin
  if char_length(ar) not between 2 and 80 or char_length(en) > 80 then
    raise exception 'Enter a name' using errcode = '22023';
  end if;
  select d.city into dcity from public.mosque_districts d where d.id = p_id;
  if not found then raise exception 'Not found' using errcode = '22023'; end if;
  if exists (select 1 from public.mosque_districts where city = dcity and name_ar = ar and id <> p_id) then
    raise exception 'This area is already in the list' using errcode = '23505';
  end if;
  update public.mosque_districts set name_ar = ar, name_en = case when en = '' then ar else en end where id = p_id;
  perform private.lessons_audit('editDistrict', ar, coalesce(nullif(en, ''), ar));
end; $$;

create function public.lessons_delete_district(p_id text) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); n text;
begin
  select name_ar into n from public.mosque_districts where id = p_id;
  if not found then raise exception 'Not found' using errcode = '22023'; end if;
  begin
    delete from public.mosque_districts where id = p_id;
  exception when foreign_key_violation then
    raise exception 'The area still has mosques' using errcode = '23503';
  end;
  perform private.lessons_audit('deleteDistrict', n, n);
end; $$;

revoke all on function public.lessons_update_option(text, text, text, text, boolean), public.lessons_delete_option(text, text),
  public.lessons_update_city(text, text, text), public.lessons_delete_city(text),
  public.lessons_update_district(text, text, text), public.lessons_delete_district(text) from public, anon;
grant execute on function public.lessons_update_option(text, text, text, text, boolean), public.lessons_delete_option(text, text),
  public.lessons_update_city(text, text, text), public.lessons_delete_city(text),
  public.lessons_update_district(text, text, text), public.lessons_delete_district(text) to authenticated;

commit;
