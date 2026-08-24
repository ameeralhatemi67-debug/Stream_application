-- ===========================================================================
-- Migration: Streamer Assets Storage Bucket & Application Fields Support
-- ===========================================================================

-- 1. Create the streamer-assets storage bucket if it does not exist
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'streamer-assets',
  'streamer-assets',
  true,
  10485760, -- 10MB limit
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

-- 2. Storage RLS Policies for streamer-assets bucket
-- Anyone (authenticated or anon) can view/download public streamer avatars and banners
create policy "Public Access to Streamer Assets"
  on storage.objects for select
  using (bucket_id = 'streamer-assets');

-- Authenticated users can upload their own media
create policy "Authenticated users can upload streamer assets"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'streamer-assets');

-- Authenticated users can update their own media
create policy "Authenticated users can update streamer assets"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'streamer-assets');

-- 3. Extend broadcaster_applications with optional extra metadata columns if missing
alter table public.broadcaster_applications
  add column if not exists organization_type text,
  add column if not exists official_website_url text,
  add column if not exists seating_capacity integer default 100,
  add column if not exists branches_json jsonb default '[]'::jsonb,
  add column if not exists speakers_json jsonb default '[]'::jsonb;
