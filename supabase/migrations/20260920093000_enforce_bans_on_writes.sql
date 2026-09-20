-- P1.5: restrictive guards combine with every existing permissive policy.
-- Existing owner/admin checks remain necessary; these policies grant no access.
begin;
revoke execute on function public.is_current_user_banned() from public, anon;
grant execute on function public.is_current_user_banned() to authenticated;

create policy profiles_insert_not_banned on public.profiles
as restrictive for insert to authenticated
with check (not public.is_current_user_banned());

create policy profiles_update_not_banned on public.profiles
as restrictive for update to authenticated
using (not public.is_current_user_banned())
with check (not public.is_current_user_banned());

create policy profiles_delete_not_banned on public.profiles
as restrictive for delete to authenticated
using (not public.is_current_user_banned());

create policy broadcaster_applications_insert_not_banned on public.broadcaster_applications
as restrictive for insert to authenticated
with check (not public.is_current_user_banned());

create policy broadcaster_applications_update_not_banned on public.broadcaster_applications
as restrictive for update to authenticated
using (not public.is_current_user_banned())
with check (not public.is_current_user_banned());

create policy broadcaster_applications_delete_not_banned on public.broadcaster_applications
as restrictive for delete to authenticated
using (not public.is_current_user_banned());

create policy affiliation_requests_insert_not_banned on public.affiliation_requests
as restrictive for insert to authenticated
with check (not public.is_current_user_banned());

create policy affiliation_requests_update_not_banned on public.affiliation_requests
as restrictive for update to authenticated
using (not public.is_current_user_banned())
with check (not public.is_current_user_banned());

create policy affiliation_requests_delete_not_banned on public.affiliation_requests
as restrictive for delete to authenticated
using (not public.is_current_user_banned());

create policy chat_messages_insert_not_banned on public.chat_messages
as restrictive for insert to authenticated
with check (not public.is_current_user_banned());

create policy chat_messages_update_not_banned on public.chat_messages
as restrictive for update to authenticated
using (not public.is_current_user_banned())
with check (not public.is_current_user_banned());

create policy chat_messages_delete_not_banned on public.chat_messages
as restrictive for delete to authenticated
using (not public.is_current_user_banned());

create policy streamer_custom_placeholders_insert_not_banned on public.streamer_custom_placeholders
as restrictive for insert to authenticated
with check (not public.is_current_user_banned());

create policy streamer_custom_placeholders_update_not_banned on public.streamer_custom_placeholders
as restrictive for update to authenticated
using (not public.is_current_user_banned())
with check (not public.is_current_user_banned());

create policy streamer_custom_placeholders_delete_not_banned on public.streamer_custom_placeholders
as restrictive for delete to authenticated
using (not public.is_current_user_banned());

create policy streamer_assets_insert_not_banned on storage.objects
as restrictive for insert to authenticated
with check (bucket_id <> 'streamer-assets' or not public.is_current_user_banned());

create policy streamer_assets_update_not_banned on storage.objects
as restrictive for update to authenticated
using (bucket_id <> 'streamer-assets' or not public.is_current_user_banned())
with check (bucket_id <> 'streamer-assets' or not public.is_current_user_banned());

create policy streamer_assets_delete_not_banned on storage.objects
as restrictive for delete to authenticated
using (bucket_id <> 'streamer-assets' or not public.is_current_user_banned());

commit;
