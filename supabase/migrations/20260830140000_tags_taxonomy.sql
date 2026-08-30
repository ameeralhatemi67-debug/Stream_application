-- Cluster 3 — Task 12: Tag Moderation
--
-- Topic tags (profiles.tags / organizations.tags / broadcaster_applications.tags)
-- have always been free-text arrays with no moderation step -- anything a
-- streamer typed on application went straight to a public filter chip. This
-- table adds an approval workflow on top without touching those existing
-- text[] columns: `name` is the normalized (lowercase, trimmed) tag string,
-- `status` gates whether it's suggested to/filterable by the public.
create table public.tags (
  name text primary key,
  status text not null default 'pending'
    check (status in ('approved', 'pending', 'blacklisted')),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_tags_updated_at
  before update on public.tags
  for each row execute function public.set_updated_at();

create index tags_status_idx on public.tags (status);

comment on table public.tags is
  'Tag moderation ledger for the free-text tags on profiles/organizations/broadcaster_applications. approved = shown in discovery filters and suggested on application; pending = awaiting admin review; blacklisted = hidden and never suggested.';

-- ---------------------------------------------------------------------------
-- RLS: anyone can read approved tags (discovery filter sheet, public
-- autocomplete); admin tiers can read everything (moderation queue). Any
-- authenticated user may submit a brand-new tag, but only as 'pending' --
-- they cannot self-approve or resurrect a blacklisted tag. Only admin tiers
-- may change status (approve / merge-rename / blacklist) or delete a row.
-- ---------------------------------------------------------------------------
alter table public.tags enable row level security;

create policy tags_select_approved_public
  on public.tags for select
  to anon, authenticated
  using (status = 'approved');

create policy tags_select_admin
  on public.tags for select
  to authenticated
  using (public.is_admin_tier());

create policy tags_insert_pending_self
  on public.tags for insert
  to authenticated
  with check (status = 'pending' and created_by = auth.uid());

create policy tags_write_admin
  on public.tags for update
  to authenticated
  using (public.is_admin_tier())
  with check (public.is_admin_tier());

create policy tags_delete_admin
  on public.tags for delete
  to authenticated
  using (public.is_admin_tier());

grant select on public.tags to anon, authenticated;

alter publication supabase_realtime add table public.tags;

-- ---------------------------------------------------------------------------
-- Seed the tags every screen used to hardcode (tags_filter_bottom_sheet.dart's
-- allTags and apply_step_3_professional.dart's availableTags) as pre-approved,
-- so a fresh deploy still has a non-empty discovery filter / application
-- autocomplete instead of an empty list until an admin approves something.
-- ---------------------------------------------------------------------------
insert into public.tags (name, status) values
  ('#AI', 'approved'),
  ('#Cloud', 'approved'),
  ('#Dev', 'approved'),
  ('#Software', 'approved'),
  ('#Sharia', 'approved'),
  ('#Podcast', 'approved'),
  ('#Quran', 'approved'),
  ('#Seerah', 'approved'),
  ('#Culture', 'approved'),
  ('#Dialogue', 'approved'),
  ('#History', 'approved'),
  ('#Solar', 'approved'),
  ('#CleanEnergy', 'approved'),
  ('#Innovation', 'approved'),
  ('#Cybersecurity', 'approved'),
  ('#ZeroTrust', 'approved'),
  ('#Networks', 'approved'),
  ('#IELTS', 'approved'),
  ('#English', 'approved'),
  ('#Medicine', 'approved'),
  ('#Engineering', 'approved'),
  ('#Academy', 'approved'),
  ('#Youth', 'approved')
on conflict (name) do nothing;
