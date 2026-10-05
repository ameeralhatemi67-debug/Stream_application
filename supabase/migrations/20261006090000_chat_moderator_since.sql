-- Chat sender profile window: when a chat moderator was appointed.
--
-- stream_moderators is readable only by the appointer, the appointee, whoever
-- could have appointed at that scope, and admins, so a viewer opening a
-- moderator's profile card in chat cannot select the row. This SECURITY DEFINER
-- function returns the single fact the card shows -- the earliest date the
-- profile was made a moderator for this stream (stream, organization or
-- platform scope) -- and nothing else: not who appointed them, not the scope.
create or replace function public.chat_moderator_since(
  p_stream_id text,
  p_profile_id uuid
)
returns timestamptz
language sql
stable
security definer
set search_path = public
as $$
  select min(sm.granted_at)
  from public.stream_moderators sm
  where sm.profile_id = p_profile_id
    and (
      sm.scope = 'global'
      or (sm.scope = 'stream' and sm.stream_id = p_stream_id)
      or (sm.scope = 'organization' and exists (
        select 1 from public.organizations o
        where o.id = sm.organization_id
          and o.active_stream_id = p_stream_id
      ))
    );
$$;

revoke all on function public.chat_moderator_since(text, uuid) from public;
grant execute on function public.chat_moderator_since(text, uuid) to anon, authenticated;
