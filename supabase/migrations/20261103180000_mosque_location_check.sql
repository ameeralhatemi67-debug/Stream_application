-- Mosque locations found from a map search (owner request 2026-11-03).
--
-- location_check marks a mosque whose area and pin came from OpenStreetMap, not
-- from an admin: the admins' Mosques page shows a "Confirm location" chip until
-- an admin confirms it (the "Location is right" button) or saves the mosque.
-- lessons_upsert_mosque carries the new field; nothing else about it changes.
begin;

alter table public.mosques add column location_check boolean not null default false;
comment on column public.mosques.location_check is
  'The area and pin came from a map search and still wait for an admin to confirm them.';

create or replace function public.lessons_upsert_mosque(p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); mid uuid := nullif(p->>'id', '')::uuid;
begin
  if mid is null then
    insert into public.mosques(name_ar, name_en, district_id, latitude, longitude, maps_url, facilities,
      verified, location_check, created_by)
    values (btrim(p->>'name_ar'), btrim(coalesce(p->>'name_en', '')), p->>'district_id',
      (p->>'latitude')::double precision, (p->>'longitude')::double precision, nullif(p->>'maps_url', ''),
      coalesce(array(select jsonb_array_elements_text(p->'facilities')), '{}'),
      coalesce((p->>'verified')::boolean, true), coalesce((p->>'location_check')::boolean, false), actor)
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
      location_check = coalesce((p->>'location_check')::boolean, location_check),
      updated_at = now()
    where id = mid;
    if not found then raise exception 'Mosque not found' using errcode = '22023'; end if;
    perform private.lessons_audit('editMosque', m.name_ar, coalesce(nullif(m.name_en, ''), m.name_ar))
      from public.mosques m where m.id = mid;
  end if;
  return mid;
end; $$;

commit;
