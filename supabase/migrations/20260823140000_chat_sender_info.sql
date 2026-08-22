-- v0.6 Live Chat & Realtime Engagement — Checkpoint 2, Phase 2: role badges
--
-- Fixes a real gap Checkpoint 1 left unnoticed (never caught live -- testing
-- only ever had the viewer resolving their OWN sender profile): chat's
-- sender-name resolution queried the base `profiles` table directly, but
-- Checkpoint 1's RLS (profiles_select_own / profiles_select_admin) only lets
-- a viewer read their own row or an admin's -- so any OTHER sender's name
-- silently fell back to "Viewer" for everyone except themselves and admins.
--
-- The roadmap's badge set (Speaker / Organization / Admin / Verified) also
-- doesn't map onto user_roles alone -- Speaker comes from org_speakers,
-- Verified from profiles.is_verified, neither of which a regular viewer can
-- read cross-user either (same RLS shape as above for user_roles;
-- org_speakers is member/admin-gated per Checkpoint 1).
--
-- One SECURITY DEFINER RPC batches both problems: given a list of profile
-- ids, returns only the fields chat display actually needs (name, avatar,
-- verified, three role booleans) -- never email/phone or anything else --
-- the same "narrow public subset" pattern streamer_public_profiles already
-- uses, just parameterized by id list instead of is_streamer=true.
create or replace function public.chat_sender_info(p_profile_ids uuid[])
returns table (
  profile_id uuid,
  display_name text,
  avatar_url text,
  is_verified boolean,
  is_admin boolean,
  is_org_owner boolean,
  is_speaker boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    coalesce(nullif(p.display_name_en, ''), 'Viewer'),
    p.avatar_url,
    p.is_verified,
    exists (
      select 1 from public.user_roles ur
      where ur.profile_id = p.id and ur.role in ('master_admin', 'admin')
    ),
    exists (
      select 1 from public.user_roles ur
      where ur.profile_id = p.id and ur.role in ('org_owner', 'org_co_owner')
    ),
    exists (
      select 1 from public.org_speakers os
      where os.linked_profile_id = p.id
    )
  from public.profiles p
  where p.id = any(p_profile_ids);
$$;

grant execute on function public.chat_sender_info(uuid[]) to authenticated;
