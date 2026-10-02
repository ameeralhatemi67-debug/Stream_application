-- The bundled map's inset navigation extent is the supported point area.
-- These product bounds are not municipal boundaries. Keep them in sync with
-- kTricityNavigationExtent in map_tricity_domain.dart.
begin;
create function public.guard_supported_broadcaster_location() returns trigger
language plpgsql security definer set search_path = '' as $$
declare base public.broadcaster_applications;
begin
  if tg_op = 'UPDATE' then
    if new.latitude is not distinct from old.latitude and
       new.longitude is not distinct from old.longitude and
       new.city_id is not distinct from old.city_id and
       new.venue_name_en is not distinct from old.venue_name_en and
       new.venue_name_ar is not distinct from old.venue_name_ar and
       (new.revision_of is not null or
        (new.status <> 'pending' and not
         (old.status <> 'approved' and new.status = 'approved')))
    then return new; end if;
  elsif new.revision_of is not null then
    -- A legacy approved point can survive a contact-only revision. Any move
    -- must use a supported point.
    select * into base from public.broadcaster_applications where id = new.revision_of;
    if new.latitude is not distinct from base.latitude and
       new.longitude is not distinct from base.longitude and
       new.city_id is not distinct from base.city_id and
       new.venue_name_en is not distinct from base.venue_name_en and
       new.venue_name_ar is not distinct from base.venue_name_ar
    then return new; end if;
  end if;
  if new.latitude is null or new.longitude is null or
     new.latitude < 25.97 or new.latitude > 26.78 or
     new.longitude < 49.72 or new.longitude > 50.43 then
    raise exception 'Location outside supported map area' using errcode = '22023';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_supported_broadcaster_location() from public, anon, authenticated;
create trigger guard_supported_broadcaster_location
before insert or update on public.broadcaster_applications
for each row execute function public.guard_supported_broadcaster_location();
commit;
