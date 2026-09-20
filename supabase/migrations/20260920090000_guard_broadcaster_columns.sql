-- P1.1: RLS limits rows, but must also protect server-owned columns.
-- Deliberately SECURITY INVOKER: current_user must be the calling SQL role.
-- Approved SECURITY DEFINER RPCs run as their owner and may update live state.
begin;

create or replace function public.guard_broadcaster_columns()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  protected jsonb;
begin
  if current_user not in ('authenticated', 'anon') or public.is_admin_tier() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    protected := jsonb_build_object(
      'is_verified', false, 'follower_count', 0,
      'is_currently_live', false, 'broadcast_type', 'offline',
      'active_stream_id', null, 'active_viewer_count', 0);
    if tg_table_name = 'profiles' then
      protected := protected || jsonb_build_object('is_streamer', false, 'total_lecture_hours', 0);
    else
      protected := protected || jsonb_build_object('active_live_venue_id', null, 'active_live_speaker_ids', '[]'::jsonb);
    end if;
  else
    protected := jsonb_build_object(
      'id', old.id, 'created_at', old.created_at,
      'is_verified', old.is_verified, 'follower_count', old.follower_count,
      'is_currently_live', old.is_currently_live, 'broadcast_type', old.broadcast_type,
      'active_stream_id', old.active_stream_id, 'active_viewer_count', old.active_viewer_count);
    if tg_table_name = 'profiles' then
      protected := protected || jsonb_build_object(
        'is_streamer', old.is_streamer, 'total_lecture_hours', old.total_lecture_hours);
    else
      protected := protected || jsonb_build_object(
        'owner_profile_id', old.owner_profile_id,
        'active_live_venue_id', old.active_live_venue_id,
        'active_live_speaker_ids', old.active_live_speaker_ids);
    end if;
  end if;
  new := jsonb_populate_record(new, protected);
  return new;
end;
$$;

revoke execute on function public.guard_broadcaster_columns() from public, anon, authenticated;

create trigger guard_profiles_broadcaster_columns
before insert or update on public.profiles
for each row execute function public.guard_broadcaster_columns();

create trigger guard_organizations_broadcaster_columns
before insert or update on public.organizations
for each row execute function public.guard_broadcaster_columns();

comment on function public.guard_broadcaster_columns() is
  'Preserves server-owned approval, live, count and ownership fields for ordinary API callers. Admin approval and guarded owner-executed RPCs retain access.';

commit;
