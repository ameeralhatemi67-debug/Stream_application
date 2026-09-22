-- Owner decision D-33: the public map intentionally exposes exact coordinates
-- for self-disclosed public venues so the Google Maps action opens the correct
-- place. This path must not be used for home addresses.
comment on view public.streamer_public_profiles is
  'Public projection for feed and map. Exact latitude/longitude are intentional for self-disclosed public venues, not home addresses, so users can open the correct venue in Google Maps. Venue availability is open by default at the product level; a future availability field may mark a venue closed. The view must not gain email, phone, or residential-address data.';
