-- v0.6 Live Chat & Realtime Engagement — Checkpoint 3, Phase 3: Basic Keyword
-- Filter
--
-- Apple Guideline 1.2 review specifically looks for an *active* filter on
-- insert, not just after-the-fact reporting (Checkpoint 3 Phase 1) or
-- moderator cleanup (Phase 2) -- this is that first line of defense.
--
-- The banned-word list lives in its own admin-managed table rather than
-- being hardcoded into the trigger function, so it can be extended without a
-- new migration for every addition. The starter list here is intentionally
-- small and generic (mild profanity/harassment placeholders) -- curating a
-- real production blocklist is an ongoing moderation task for admins via
-- this table, not something one migration can responsibly settle once.
create table public.chat_banned_keywords (
  id uuid primary key default gen_random_uuid(),
  keyword text not null unique,
  created_at timestamptz not null default now()
);

comment on table public.chat_banned_keywords is
  'Substrings (case-insensitive) that block a chat_messages insert. Managed by admin tiers.';

alter table public.chat_banned_keywords enable row level security;

create policy chat_banned_keywords_admin_only
  on public.chat_banned_keywords for all
  to authenticated
  using (public.is_admin_tier())
  with check (public.is_admin_tier());

insert into public.chat_banned_keywords (keyword) values
  ('damn'),
  ('hell'),
  ('idiot'),
  ('stupid'),
  ('shut up'),
  ('kill yourself')
on conflict (keyword) do nothing;

-- security definer: the inserting user has no SELECT grant on
-- chat_banned_keywords (admin-only per the policy above), so the check
-- itself has to run with the function owner's privileges, same reasoning as
-- chat_sender_info/chat_is_muted needing security definer to see across
-- users' data the caller can't query directly.
create or replace function public.chat_check_banned_keywords()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.chat_banned_keywords k
    where new.body ilike '%' || k.keyword || '%'
  ) then
    raise exception 'Message rejected: contains a banned keyword.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger chat_messages_check_keywords
  before insert on public.chat_messages
  for each row execute function public.chat_check_banned_keywords();
