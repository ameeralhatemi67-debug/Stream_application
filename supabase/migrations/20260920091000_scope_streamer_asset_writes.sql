-- P1.3: public downloads, owner-scoped writes, no overwrite of another user.
begin;

create or replace function public.can_write_streamer_asset(object_name text)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select (select auth.uid()) is not null and (
    public.is_admin_tier()
    or split_part(object_name, '/', 1) = (select auth.uid())::text
    or (
      split_part(object_name, '/', 1) = 'org'
      and case
        when split_part(object_name, '/', 2) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then public.owns_organization(split_part(object_name, '/', 2)::uuid)
        else false
      end
    )
  );
$$;
revoke execute on function public.can_write_streamer_asset(text) from public, anon;
grant execute on function public.can_write_streamer_asset(text) to authenticated;

drop policy "Authenticated users can upload streamer assets" on storage.objects;
drop policy "Authenticated users can update streamer assets" on storage.objects;

create policy streamer_assets_insert_owner on storage.objects
for insert to authenticated
with check (bucket_id = 'streamer-assets' and public.can_write_streamer_asset(name));

create policy streamer_assets_update_owner on storage.objects
for update to authenticated
using (bucket_id = 'streamer-assets' and public.can_write_streamer_asset(name))
with check (bucket_id = 'streamer-assets' and public.can_write_streamer_asset(name));

create policy streamer_assets_delete_owner on storage.objects
for delete to authenticated
using (bucket_id = 'streamer-assets' and public.can_write_streamer_asset(name));

comment on function public.can_write_streamer_asset(text) is
  'Asset writes require an auth UID prefix, an owned org/UUID prefix, or platform admin. Existing flat paths remain publicly readable; only admins can replace/delete legacy paths.';
commit;
