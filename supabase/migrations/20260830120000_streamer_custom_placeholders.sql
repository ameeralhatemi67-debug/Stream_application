-- Cluster 1 Task 4b -- Streamer Custom Stream-State Cards & Admin Moderation
--
-- A streamer uploads their own artwork for the "Starting Soon", "Break" and
-- "Ended" placeholder screens; an admin approves or rejects it before any
-- viewer ever sees it. Until a card for a given (streamer, type) reaches
-- status = 'approved', StreamStatePlaceholderOverlay falls back to the
-- default system placeholder -- so an unmoderated upload is inert, not
-- merely unflagged.
--
-- The artwork itself lives in the existing public 'streamer-assets' bucket
-- (20260828120000) under custom_placeholders/; this table holds only the
-- moderation record and the resulting public URL. That is deliberate: a
-- public bucket means the *URL* is not the access control -- the `status`
-- column is, and only this table is consulted at playback time.

create table if not exists public.streamer_custom_placeholders (
  id uuid primary key default gen_random_uuid(),
  streamer_id uuid not null references public.profiles(id) on delete cascade,
  placeholder_type text not null
    check (placeholder_type in ('starting_soon', 'intermission', 'ending')),
  image_url text not null,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  -- A rejection with no explanation is useless to the streamer receiving the
  -- notification, so the constraint makes "rejected" and "has a reason" the
  -- same state rather than two states an admin UI has to keep in sync.
  rejection_reason text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  constraint streamer_custom_placeholders_rejection_reason_required
    check (status <> 'rejected' or coalesce(btrim(rejection_reason), '') <> '')
);

create index if not exists streamer_custom_placeholders_streamer_idx
  on public.streamer_custom_placeholders (streamer_id, placeholder_type);

create index if not exists streamer_custom_placeholders_status_idx
  on public.streamer_custom_placeholders (status, created_at desc);

-- Only one approved card per (streamer, type) can be live at a time; a newly
-- approved card supersedes the previous one (see the trigger below).
create unique index if not exists streamer_custom_placeholders_one_approved_idx
  on public.streamer_custom_placeholders (streamer_id, placeholder_type)
  where status = 'approved';

alter table public.streamer_custom_placeholders enable row level security;

-- Viewers/players read approved cards only. Everything still pending or
-- rejected is invisible outside the owning streamer and the admin queue --
-- this is the policy that makes the "unapproved => default placeholder"
-- fallback a server-side guarantee rather than a client-side courtesy.
create policy streamer_custom_placeholders_select_approved
  on public.streamer_custom_placeholders for select
  to anon, authenticated
  using (status = 'approved');

-- A streamer sees every card they submitted, in any status, so the editor
-- sheet can show "Pending Review" / "Rejected: <reason>".
create policy streamer_custom_placeholders_select_own
  on public.streamer_custom_placeholders for select
  to authenticated
  using (streamer_id = auth.uid());

-- Admin tier sees the whole queue.
create policy streamer_custom_placeholders_select_admin
  on public.streamer_custom_placeholders for select
  to authenticated
  using (public.is_admin_tier());

-- A streamer may only ever insert a *pending* card for themselves: no
-- self-approval path exists at the RLS layer, not just in the UI.
create policy streamer_custom_placeholders_insert_own
  on public.streamer_custom_placeholders for insert
  to authenticated
  with check (streamer_id = auth.uid() and status = 'pending');

-- Moderation (approve / reject with reason) is admin-tier only.
create policy streamer_custom_placeholders_update_admin
  on public.streamer_custom_placeholders for update
  to authenticated
  using (public.is_admin_tier())
  with check (public.is_admin_tier());

-- A streamer can withdraw their own submission; admins can clear any row.
create policy streamer_custom_placeholders_delete_own_or_admin
  on public.streamer_custom_placeholders for delete
  to authenticated
  using (streamer_id = auth.uid() or public.is_admin_tier());

-- Approving a card demotes whichever card previously held that slot, so the
-- partial unique index above can never be violated by a legitimate approval.
-- Doing it in a trigger (rather than in the client's update call) keeps the
-- invariant true no matter which surface performs the approval.
create or replace function public.supersede_prior_approved_placeholder()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'approved'
     and (tg_op = 'INSERT' or old.status is distinct from 'approved') then
    update public.streamer_custom_placeholders
       set status = 'rejected',
           rejection_reason = coalesce(
             nullif(btrim(rejection_reason), ''),
             'Superseded by a newer approved card.'
           ),
           reviewed_at = now()
     where streamer_id = new.streamer_id
       and placeholder_type = new.placeholder_type
       and status = 'approved'
       and id <> new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists supersede_prior_approved_placeholder
  on public.streamer_custom_placeholders;

create trigger supersede_prior_approved_placeholder
  before insert or update on public.streamer_custom_placeholders
  for each row execute function public.supersede_prior_approved_placeholder();
