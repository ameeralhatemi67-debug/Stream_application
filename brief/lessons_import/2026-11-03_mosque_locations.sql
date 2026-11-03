-- Mosque locations found from OpenStreetMap (owner request 2026-11-03).
-- Needs migration 20261103180000 (location_check). Run with:
--   npx supabase db query --linked -f brief/lessons_import/2026-11-03_mosque_locations.sql
--
-- Only mosques whose name matched exactly ONE OpenStreetMap mosque AND whose pin
-- lies inside one of the areas the app has. They leave "Not set yet", get the
-- pin, and show a "Confirm location" chip until an admin confirms them. The
-- others stay in "Not set yet". Only mosques still in "Not set yet" are touched.
update public.mosques m set district_id = v.district_id, latitude = v.lat, longitude = v.lon,
  location_check = true, updated_at = now()
from (values
  ('جامع عمر بن عبدالعزيز', 'aqrabiyah', 26.2912402, 50.1925190)
) as v(name_ar, district_id, lat, lon)
where m.name_ar = v.name_ar and m.district_id = 'unassigned';
