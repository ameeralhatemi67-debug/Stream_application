-- Cluster 3 — Task 10/11: Academic Categories Taxonomy
--
-- Categories were previously a hardcoded Dart constant (kAcademicTopics) with
-- free-text category_id strings on profiles/organizations/broadcaster_applications.
-- This table becomes the single source of truth so Discovery, the Map's topic
-- dropdown, and the tag filter sheet all read the same live list, and admins
-- can create/edit/reorder/deactivate categories platform-wide (Task 11)
-- without a client release. category_id columns elsewhere stay free text
-- (no FK) -- same rationale as chat_messages.stream_id: a category can be
-- soft-deactivated without needing to migrate every row that references it.
create table public.academic_categories (
  id text primary key,
  name_en text not null,
  name_ar text not null,
  icon_name text not null default 'school',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_academic_categories_updated_at
  before update on public.academic_categories
  for each row execute function public.set_updated_at();

create index academic_categories_sort_idx on public.academic_categories (sort_order);

comment on table public.academic_categories is
  'Admin-managed academic category taxonomy. Drives Discovery/Map/tag-filter category chips platform-wide. Port of AcademicCategoryModel.';

-- ---------------------------------------------------------------------------
-- RLS: public read (anon + authenticated -- same audience as the discovery
-- feed/map itself, which guest viewers can browse), admin-tier write only.
-- ---------------------------------------------------------------------------
alter table public.academic_categories enable row level security;

create policy academic_categories_select_public
  on public.academic_categories for select
  to anon, authenticated
  using (true);

create policy academic_categories_write_admin
  on public.academic_categories for all
  to authenticated
  using (public.is_admin_tier())
  with check (public.is_admin_tier());

grant select on public.academic_categories to anon, authenticated;

-- Required for AppProvider to live-refresh every client when an admin
-- adds/edits/reorders/deactivates a category (same pattern as profiles/
-- organizations realtime subscriptions in AppProvider).
alter publication supabase_realtime add table public.academic_categories;

-- ---------------------------------------------------------------------------
-- Seed the existing default pool so behavior is unchanged on first deploy --
-- these are the same 8 categories the client used to hardcode.
-- ---------------------------------------------------------------------------
insert into public.academic_categories (id, name_en, name_ar, icon_name, sort_order) values
  ('islamic_studies', 'Islamic Studies', 'الدراسات الإسلامية', 'mosque', 0),
  ('computer_science', 'Computer Science', 'علوم الحاسب', 'computer', 1),
  ('engineering', 'Engineering', 'الهندسة', 'engineering', 2),
  ('medicine', 'Medicine', 'الطب', 'medical_services', 3),
  ('business', 'Business', 'إدارة الأعمال', 'business_center', 4),
  ('linguistics', 'Linguistics', 'اللغويات', 'translate', 5),
  ('mathematics', 'Mathematics', 'الرياضيات', 'functions', 6),
  ('architecture', 'Architecture', 'العمارة', 'architecture', 7)
on conflict (id) do nothing;
