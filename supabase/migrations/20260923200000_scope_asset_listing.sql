-- Public asset URLs remain public. Listing metadata and overwriting assets
-- need SELECT permission only for their owner, organization owner, or admin.
begin;
drop policy streamer_assets_select_public on storage.objects;
create policy streamer_assets_select_owner on storage.objects
  for select to authenticated
  using (bucket_id = 'streamer-assets'
    and not public.is_current_user_banned()
    and public.can_write_streamer_asset(name));
commit;
