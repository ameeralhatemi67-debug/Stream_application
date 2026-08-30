-- Cluster 4 — Task 15: Stream Moderator Labels & Delegation Hierarchy
--
-- A streamer or org owner/co-owner can appoint another profile as a chat
-- moderator, scoped to one stream, one whole organization (every stream that
-- org ever runs), or -- admin-tier only -- the entire platform. This is a
-- delegation ledger (who appointed whom, when, at what scope), not a
-- role-hierarchy tier like user_roles -- a stream moderator has no
-- admin/org_owner powers outside chat moderation.
create table public.stream_moderators (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  assigned_by uuid not null references public.profiles (id) on delete cascade,
  scope text not null check (scope in ('stream', 'organization', 'global')),
  stream_id text,
  organization_id uuid references public.organizations (id) on delete cascade,
  granted_at timestamptz not null default now(),

  constraint stream_moderators_scope_shape_chk check (
    (scope = 'stream' and stream_id is not null and organization_id is null)
    or (scope = 'organization' and organization_id is not null and stream_id is null)
    or (scope = 'global' and stream_id is null and organization_id is null)
  ),
  unique (profile_id, scope, stream_id, organization_id)
);

create index stream_moderators_profile_idx on public.stream_moderators (profile_id);
create index stream_moderators_stream_idx on public.stream_moderators (stream_id);
create index stream_moderators_org_idx on public.stream_moderators (organization_id);

comment on table public.stream_moderators is
  'Chat moderator delegation ledger. scope=stream/organization is appointed by that stream/org''s owner; scope=global is admin-tier only. Drives the 🛡️ MOD chat badge and grants chat moderation rights via owns_stream().';

alter table public.stream_moderators enable row level security;

-- Read: the appointer, the appointee, anyone who could have appointed at that
-- scope (so a co-owner can see another owner's appointments), or admin tier.
create policy stream_moderators_select_relevant
  on public.stream_moderators for select
  to authenticated
  using (
    profile_id = auth.uid()
    or assigned_by = auth.uid()
    or public.is_admin_tier()
    or (scope = 'organization' and public.owns_organization(organization_id))
    or (scope = 'stream' and public.owns_stream(stream_id))
  );

-- Write: a stream-scoped grant requires the appointer to already own that
-- stream; an organization-scoped grant requires org ownership; a global grant
-- is admin-tier only. assigned_by must be the actor themselves.
create policy stream_moderators_write_scoped
  on public.stream_moderators for all
  to authenticated
  using (
    assigned_by = auth.uid()
    or public.is_admin_tier()
  )
  with check (
    assigned_by = auth.uid()
    and (
      (scope = 'stream' and public.owns_stream(stream_id))
      or (scope = 'organization' and public.owns_organization(organization_id))
      or (scope = 'global' and public.is_admin_tier())
    )
  );

grant execute on function public.owns_stream(text) to authenticated;

-- ---------------------------------------------------------------------------
-- owns_stream() now also grants moderation rights to a delegated moderator --
-- this is the ONLY change needed to make appointed moderators able to
-- mute/delete in their scoped stream(s): chat_messages_delete_owner_or_admin,
-- chat_muted_users' insert/select/delete policies, and chat_can_moderate all
-- already key off owns_stream(), so extending it here flows through to every
-- one of them without touching those policies again.
create or replace function public.owns_stream(p_stream_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and active_stream_id = p_stream_id
  )
  or exists (
    select 1 from public.organizations o
    where o.active_stream_id = p_stream_id
      and public.owns_organization(o.id)
  )
  or exists (
    select 1 from public.stream_moderators sm
    where sm.profile_id = auth.uid()
      and (
        sm.scope = 'global'
        or (sm.scope = 'stream' and sm.stream_id = p_stream_id)
        or (sm.scope = 'organization' and exists (
          select 1 from public.organizations o
          where o.id = sm.organization_id and o.active_stream_id = p_stream_id
        ))
      )
  );
$$;

-- ---------------------------------------------------------------------------
-- chat_sender_info gains is_moderator so the chat widget can render the
-- 🛡️ MOD badge for a delegated moderator (distinct from is_admin, which is
-- the platform admin tier, not a stream-scoped delegation). Return shape
-- changed, so the function must be dropped and recreated rather than
-- CREATE OR REPLACE'd in place.
-- ---------------------------------------------------------------------------
drop function if exists public.chat_sender_info(uuid[]);

create or replace function public.chat_sender_info(p_profile_ids uuid[], p_stream_id text default null)
returns table (
  profile_id uuid,
  display_name text,
  avatar_url text,
  is_verified boolean,
  is_admin boolean,
  is_org_owner boolean,
  is_speaker boolean,
  is_moderator boolean
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
    ),
    (
      p_stream_id is not null
      and exists (
        select 1 from public.stream_moderators sm
        where sm.profile_id = p.id
          and (
            sm.scope = 'global'
            or (sm.scope = 'stream' and sm.stream_id = p_stream_id)
            or (sm.scope = 'organization' and exists (
              select 1 from public.organizations o
              where o.id = sm.organization_id and o.active_stream_id = p_stream_id
            ))
          )
      )
    )
  from public.profiles p
  where p.id = any(p_profile_ids);
$$;

grant execute on function public.chat_sender_info(uuid[], text) to authenticated;
