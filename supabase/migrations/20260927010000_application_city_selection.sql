-- Preserve explicit city selection through application review. Legacy records
-- remain unknown; do not infer cities or move existing venue coordinates.
alter table public.broadcaster_applications
  add column city_id text check (city_id in ('khobar', 'dhahran', 'dammam'));
comment on column public.broadcaster_applications.city_id is
  'Applicant-selected three-city discovery membership; NULL means unknown, not an inferred location.';
