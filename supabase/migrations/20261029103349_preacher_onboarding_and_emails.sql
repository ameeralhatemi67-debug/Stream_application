-- Preachers join two ways, emails reach them, and every action is logged by
-- name (owner request 2026-10-29, ADR-020).
--
-- * Invited: an admin adds the preacher with his email, initial mosque and
--   photo, and can email him his link (lessons_create_key(..., p_email)).
-- * Accepted: a signed-in person applies from the welcome page or Settings
--   (lessons_apply). An admin approves (a preacher card linked to that
--   account is created) or declines with a reason. A preacher with an
--   account opens his page from Settings (lessons_me_*), no link needed;
--   preachers without an account keep using links (ADR-015).
-- * Every preacher has one initial mosque (home_mosque_id) to start; lessons
--   can be at any mosque. A preacher may suggest the mosque of a request.
-- * Emails go through a private outbox that the dispatch-preacher-emails
--   function sends each minute (Resend). An email is queued for: an invite,
--   an application received / approved / declined, a lesson assigned, a
--   request approved / declined, a lesson cancelled or moved, a card change
--   approved / declined, and the day before each lesson. Decisions wait 15
--   minutes, the window in which an admin can undo them. Content is read when
--   the email is sent, so it always matches the current lesson.
-- * The action log keeps the actor's name and email as they were, and a note
--   (the reason given) for declines and cancellations.
-- * Photos: admins upload to the public bucket preacher-photos (preachers/).
--   Applicants upload to their own streamer-assets folder, which account
--   deletion already cleans; a deleted account's photo leaves the card.
-- * Account deletion also anonymises the names kept in the action log, as it
--   does for the platform log.
--
-- Backwards compatible with the app built before it: no column the old app
-- reads changes, and every function it calls keeps its name and arguments.
begin;

-- ---------------------------------------------------------------------------
-- Preachers: initial mosque, how they joined, private email
-- ---------------------------------------------------------------------------
alter table public.preachers
  add column home_mosque_id uuid references public.mosques(id) on delete set null,
  add column joined_via text not null default 'admin' check (joined_via in ('admin','application'));
create index preachers_home_mosque_idx on public.preachers(home_mosque_id);
comment on column public.preachers.home_mosque_id is
  'The mosque the preacher starts at. His lessons can be at any mosque.';

alter table private.preacher_contacts
  alter column phone drop not null,
  add column email text check (email is null
    or (char_length(email) <= 254 and email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'));

create function private.mask_email(p text) returns text
language sql immutable set search_path = '' as $$
  select case when p is null then null
    else left(split_part(p, '@', 1), 2) || '•••@' || split_part(p, '@', 2) end;
$$;

create function private.clean_email(p text) returns text
language sql immutable set search_path = '' as $$
  select nullif(lower(btrim(coalesce(p, ''))), '');
$$;

-- ---------------------------------------------------------------------------
-- Action log: who (name and email kept as they were) and why
-- ---------------------------------------------------------------------------
alter table public.lesson_audit
  add column actor_name text not null default '',
  add column actor_email text not null default '',
  add column note text not null default '' check (char_length(note) <= 600);
create index lesson_audit_preacher_idx on public.lesson_audit(preacher_id, created_at desc);

update public.lesson_audit a
   set actor_name = coalesce(nullif(p.display_name_en, ''), nullif(p.display_name_ar, ''), p.email, ''),
       actor_email = coalesce(p.email, '')
  from public.profiles p where p.id = a.actor_id;

create function private.lessons_log(p_action text, p_ar text, p_en text, p_preacher uuid, p_note text)
returns void
language sql security definer set search_path = '' as $$
  insert into public.lesson_audit(actor_id, preacher_id, action, target_ar, target_en, actor_name, actor_email, note)
  select auth.uid(), p_preacher, p_action, coalesce(p_ar, ''), coalesce(p_en, ''),
    coalesce((select coalesce(nullif(p.display_name_en, ''), nullif(p.display_name_ar, ''), p.email)
      from public.profiles p where p.id = auth.uid()), ''),
    coalesce((select p.email from public.profiles p where p.id = auth.uid()), ''),
    left(coalesce(btrim(p_note), ''), 600);
$$;

create or replace function private.lessons_audit(p_action text, p_ar text, p_en text, p_preacher uuid default null)
returns void
language sql security definer set search_path = '' as $$
  select private.lessons_log(p_action, p_ar, p_en, p_preacher, null);
$$;

-- ---------------------------------------------------------------------------
-- Applications
-- ---------------------------------------------------------------------------
create table public.preacher_applications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  name_ar text not null check (char_length(btrim(name_ar)) between 3 and 120),
  name_en text not null default '' check (char_length(name_en) <= 120),
  title_ar text not null default '' check (char_length(title_ar) <= 120),
  bio_ar text not null default '' check (char_length(bio_ar) <= 1500),
  photo_url text check (photo_url is null or photo_url ~ '^https://'),
  city text not null check (city in ('khobar','dhahran','dammam','qatif','other')),
  -- A listed mosque, or one he names with its area for an admin to add.
  mosque_id uuid references public.mosques(id) on delete set null,
  new_mosque_name text check (char_length(new_mosque_name) between 2 and 120),
  new_mosque_district text references public.mosque_districts(id),
  languages text[] not null default '{ar}' check (cardinality(languages) between 1 and 7
    and languages <@ array['ar','en','ur','tl','bn','ml','id']::text[]),
  phone text not null check (phone ~ '^\+?[0-9]{7,15}$'),
  email text not null check (char_length(email) <= 254 and email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  experience text not null default '' check (char_length(experience) <= 2000),
  sample_url text check (sample_url is null or (sample_url ~ '^https://' and char_length(sample_url) <= 500)),
  status text not null default 'pending' check (status in ('pending','approved','rejected','withdrawn')),
  reason text check (char_length(reason) <= 600),
  preacher_id uuid references public.preachers(id) on delete set null,
  decided_by uuid references public.profiles(id) on delete set null,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index preacher_applications_one_pending on public.preacher_applications(profile_id)
  where status = 'pending';
create index preacher_applications_status_idx on public.preacher_applications(status, created_at desc);
comment on table public.preacher_applications is
  'Lessons: a signed-in person asking to give lessons. Admins approve (a preacher card linked to the account) or decline.';

alter table public.preacher_applications enable row level security;
revoke all on public.preacher_applications from public, anon, authenticated;
grant select on public.preacher_applications to authenticated;
create policy preacher_applications_read on public.preacher_applications for select to authenticated
  using (profile_id = (select auth.uid()) or public.is_lessons_admin());

-- ---------------------------------------------------------------------------
-- Email outbox (private; the dispatcher reads it with the service role)
-- ---------------------------------------------------------------------------
create table private.preacher_emails (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('invite','application_received','application_approved',
    'application_rejected','lesson_assigned','request_approved','request_rejected','lesson_cancelled',
    'lesson_changed','card_approved','card_rejected','lesson_tomorrow')),
  preacher_id uuid references public.preachers(id) on delete cascade,
  application_id uuid references public.preacher_applications(id) on delete cascade,
  -- By kind: the link (invite), the request (lesson_assigned, request_*),
  -- the session (lesson_*), the card change (card_*).
  ref_id uuid,
  -- Only what cannot be read back when sending: an invite's key, removed
  -- once the email is sent or given up.
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'queued' check (status in ('queued','sent','failed','skipped','cancelled')),
  to_email text,
  attempts integer not null default 0,
  last_error text,
  send_after timestamptz not null default now(),
  leased_until timestamptz,
  provider_id text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  check (preacher_id is not null or application_id is not null)
);
create unique index preacher_emails_one_queued
  on private.preacher_emails(kind, (coalesce(ref_id, application_id, preacher_id))) where status = 'queued';
create index preacher_emails_due_idx on private.preacher_emails(send_after) where status = 'queued';
create index preacher_emails_preacher_idx on private.preacher_emails(preacher_id, created_at desc);
create index preacher_emails_ref_idx on private.preacher_emails(kind, ref_id);

-- Queues an email. Repeats of one kind for one thing collapse into the
-- queued one (a lesson moved twice sends one email). Preachers without an
-- email are skipped here; applicants always have one.
create function private.preacher_email(p_kind text, p_preacher uuid, p_ref uuid,
  p_delay interval default interval '2 minutes', p_application uuid default null,
  p_payload jsonb default '{}'::jsonb) returns void
language sql security definer set search_path = '' as $$
  insert into private.preacher_emails(kind, preacher_id, application_id, ref_id, payload, send_after, created_by)
  select p_kind, p_preacher, p_application, p_ref, coalesce(p_payload, '{}'::jsonb), now() + p_delay, auth.uid()
   where p_application is not null
      or exists (select 1 from private.preacher_contacts c where c.preacher_id = p_preacher and c.email is not null)
  on conflict (kind, (coalesce(ref_id, application_id, preacher_id))) where status = 'queued'
  do update set send_after = excluded.send_after,
    payload = private.preacher_emails.payload || excluded.payload;
$$;

-- An in-app notice for a preacher who has an account.
create function private.preacher_notify(p_preacher uuid, p_icon text, p_title_ar text, p_title_en text,
  p_body_ar text, p_body_en text) returns void
language sql security definer set search_path = '' as $$
  select private.lessons_notify(p.linked_profile_id, p_icon, p_title_ar, p_title_en, p_body_ar, p_body_en,
    '/lessons/me/preacher')
  from public.preachers p where p.id = p_preacher and p.linked_profile_id is not null;
$$;

-- ---------------------------------------------------------------------------
-- Preachers (admins): email, initial mosque
-- ---------------------------------------------------------------------------
create or replace function public.lessons_upsert_preacher(p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  pid uuid := nullif(p->>'id', '')::uuid;
  phone text := private.clean_phone(p->>'phone');
  email text := private.clean_email(p->>'email');
  home uuid := nullif(p->>'home_mosque_id', '')::uuid;
begin
  if email is not null and email !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Check the email address' using errcode = '22023';
  end if;
  if home is not null and not exists (select 1 from public.mosques where id = home) then
    raise exception 'Choose a mosque' using errcode = '22023';
  end if;
  if pid is null then
    insert into public.preachers(name_ar, name_en, title_ar, title_en, bio_ar, bio_en, photo_url,
      city, affiliation, languages, listed, linked_profile_id, home_mosque_id, created_by)
    values (btrim(p->>'name_ar'), btrim(coalesce(p->>'name_en', '')), btrim(coalesce(p->>'title_ar', '')),
      btrim(coalesce(p->>'title_en', '')), coalesce(p->>'bio_ar', ''), coalesce(p->>'bio_en', ''),
      nullif(p->>'photo_url', ''), coalesce(p->>'city', 'khobar'), coalesce(p->>'affiliation', 'coop'),
      coalesce(nullif(array(select jsonb_array_elements_text(p->'languages')), '{}'), '{ar}'),
      coalesce((p->>'listed')::boolean, true), nullif(p->>'linked_profile_id', '')::uuid, home, actor)
    returning id into pid;
    perform private.lessons_log('addPreacher', btrim(p->>'name_ar'),
      coalesce(nullif(btrim(p->>'name_en'), ''), btrim(p->>'name_ar')), pid, null);
  else
    update public.preachers set
      name_ar = coalesce(nullif(btrim(p->>'name_ar'), ''), name_ar),
      name_en = coalesce(p->>'name_en', name_en),
      title_ar = coalesce(p->>'title_ar', title_ar), title_en = coalesce(p->>'title_en', title_en),
      bio_ar = coalesce(p->>'bio_ar', bio_ar), bio_en = coalesce(p->>'bio_en', bio_en),
      photo_url = case when p ? 'photo_url' then nullif(p->>'photo_url', '') else photo_url end,
      city = coalesce(p->>'city', city), affiliation = coalesce(p->>'affiliation', affiliation),
      languages = coalesce(nullif(array(select jsonb_array_elements_text(p->'languages')), '{}'), languages),
      listed = coalesce((p->>'listed')::boolean, listed),
      linked_profile_id = case when p ? 'linked_profile_id'
        then nullif(p->>'linked_profile_id', '')::uuid else linked_profile_id end,
      home_mosque_id = case when p ? 'home_mosque_id' then home else home_mosque_id end,
      updated_at = now()
    where id = pid;
    if not found then raise exception 'Preacher not found' using errcode = '22023'; end if;
    perform private.lessons_audit('editPreacher', n.name_ar, n.name_en, pid) from private.preacher_names(pid) n;
  end if;
  if p ? 'phone' or p ? 'email' then
    insert into private.preacher_contacts(preacher_id, phone, email) values (pid, phone, email)
    on conflict (preacher_id) do update set
      phone = case when p ? 'phone' then excluded.phone else private.preacher_contacts.phone end,
      email = case when p ? 'email' then excluded.email else private.preacher_contacts.email end;
    delete from private.preacher_contacts c where c.preacher_id = pid and c.phone is null and c.email is null;
  end if;
  return pid;
end; $$;

create or replace function public.lessons_roster() returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select to_jsonb(p) || jsonb_build_object(
    'phone_mask', case when c.phone is null then null
      else left(c.phone, 2) || '•• ••• ' || right(c.phone, 3) end,
    'email_mask', private.mask_email(c.email),
    'active_keys', (select count(*) from private.preacher_keys k where k.preacher_id = p.id
      and k.revoked_at is null and (k.valid_until is null or k.valid_until > now())),
    'last_seen', (select max(k.last_used_at) from private.preacher_keys k where k.preacher_id = p.id),
    'pending_edits', (select count(*) from public.preacher_edits e where e.preacher_id = p.id and e.status = 'pending'),
    'lessons_30d', (select count(*) from public.lessons l where l.preacher_id = p.id
      and l.status = 'approved' and l.lesson_date between public.lessons_today() - 30 and public.lessons_today()))
  from public.preachers p
  left join private.preacher_contacts c on c.preacher_id = p.id
  where public.is_lessons_admin()
  order by p.name_ar;
$$;

create function public.lessons_reveal_email(p_preacher uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); email text;
begin
  if not exists (select 1 from public.preachers where id = p_preacher) then
    raise exception 'Preacher not found' using errcode = '22023';
  end if;
  select c.email into email from private.preacher_contacts c where c.preacher_id = p_preacher;
  perform private.lessons_audit('email', n.name_ar, n.name_en, p_preacher) from private.preacher_names(p_preacher) n;
  return email;
end; $$;

-- A new link, emailed to the preacher when p_email (an invitation). The
-- arguments before p_email are those of 20261022125222.
drop function public.lessons_create_key(uuid, text, timestamptz, timestamptz, text);
create function public.lessons_create_key(p_preacher uuid, p_kind text,
  p_valid_from timestamptz default null, p_valid_until timestamptz default null, p_note text default '',
  p_email boolean default false)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  token text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  k private.preacher_keys;
  names record;
begin
  select * into names from private.preacher_names(p_preacher);
  if names.name_ar is null then raise exception 'Preacher not found' using errcode = '22023'; end if;
  if p_kind not in ('once','window') then raise exception 'Unknown link kind' using errcode = '22023'; end if;
  if p_kind = 'window' and (p_valid_from is null or p_valid_until is null) then
    raise exception 'A timed link needs a start and an end' using errcode = '22023';
  end if;
  if p_valid_until is not null and p_valid_until <= now() then
    raise exception 'The end must be in the future' using errcode = '22023';
  end if;
  if coalesce(p_email, false) and not exists (select 1 from private.preacher_contacts c
      where c.preacher_id = p_preacher and c.email is not null) then
    raise exception 'This preacher has no email address' using errcode = '22023', hint = 'no_email';
  end if;
  insert into private.preacher_keys(preacher_id, kind, token_hash, valid_from, valid_until, note, created_by)
  values (p_preacher, p_kind, private.sha256_hex(token),
    case when p_kind = 'window' then p_valid_from end, p_valid_until, coalesce(btrim(p_note), ''), actor)
  returning * into k;
  perform private.lessons_audit(case when p_kind = 'once' then 'keyOnce' else 'keyWindow' end,
    names.name_ar, names.name_en, p_preacher);
  if coalesce(p_email, false) then
    perform private.preacher_email('invite', p_preacher, k.id, interval '0 minutes', null,
      jsonb_build_object('token', token));
    perform private.lessons_log('invite', names.name_ar, names.name_en, p_preacher, null);
  end if;
  return jsonb_build_object('id', k.id, 'token', token, 'kind', k.kind,
    'valid_from', k.valid_from, 'valid_until', k.valid_until, 'emailed', coalesce(p_email, false));
end; $$;

-- A revoked link's invitation is not sent, and its key is not kept.
create function private.preacher_key_revoked() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.revoked_at is not null and old.revoked_at is null then
    update private.preacher_emails set status = 'cancelled', payload = payload - 'token'
     where kind = 'invite' and ref_id = new.id and status = 'queued';
  end if;
  return null;
end; $$;
create trigger preacher_key_revoked after update of revoked_at on private.preacher_keys
  for each row execute function private.preacher_key_revoked();

-- Same as 20261022125222, with the proposed email applied and the reason logged.
create or replace function public.lessons_decide_edit(p_edit uuid, p_approve boolean, p_reason text default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); e public.preacher_edits; x jsonb;
begin
  select * into e from public.preacher_edits where id = p_edit and status = 'pending' for update;
  if not found then raise exception 'Nothing to decide' using errcode = '22023'; end if;
  if p_approve then
    x := e.payload;
    update public.preachers set
      name_ar = coalesce(nullif(btrim(x->>'name_ar'), ''), name_ar),
      name_en = coalesce(x->>'name_en', name_en),
      title_ar = coalesce(x->>'title_ar', title_ar), title_en = coalesce(x->>'title_en', title_en),
      bio_ar = coalesce(x->>'bio_ar', bio_ar), bio_en = coalesce(x->>'bio_en', bio_en),
      languages = coalesce(nullif(array(select jsonb_array_elements_text(x->'languages')), '{}'), languages),
      updated_at = now()
    where id = e.preacher_id;
    if private.clean_email(x->>'email') is not null then
      insert into private.preacher_contacts(preacher_id, email) values (e.preacher_id, private.clean_email(x->>'email'))
      on conflict (preacher_id) do update set email = excluded.email;
    end if;
  end if;
  update public.preacher_edits set status = case when p_approve then 'approved' else 'rejected' end,
    reason = nullif(btrim(coalesce(p_reason, '')), ''), decided_by = actor, decided_at = now()
  where id = e.id;
  perform private.lessons_log(case when p_approve then 'editApproved' else 'editRejected' end,
    n.name_ar, n.name_en, e.preacher_id, p_reason) from private.preacher_names(e.preacher_id) n;
end; $$;

-- Same as 20261022125222, with the decline reason in the log.
create or replace function public.lessons_review(p_requests uuid[], p_decision text, p_reason text default null,
  p_mosque uuid default null) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  r record;
  names record;
  n integer := 0;
  next_status text;
  reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  if p_decision not in ('approve','reject') then raise exception 'Unknown decision' using errcode = '22023'; end if;
  if p_decision = 'reject' and (reason is null or char_length(reason) < 3) then
    raise exception 'A reason is required to reject' using errcode = '22023';
  end if;
  if p_mosque is not null and not exists (select 1 from public.mosques where id = p_mosque) then
    raise exception 'Choose a mosque' using errcode = '22023';
  end if;
  next_status := case when p_decision = 'approve' then 'approved' else 'rejected' end;
  for r in
    select distinct on (l.request_id) l.request_id, l.preacher_id, l.title_ar, l.title_en, l.notify_followers
      from public.lessons l
     where l.request_id = any(p_requests) and l.status = 'pending'
     order by l.request_id, l.lesson_date
  loop
    if next_status = 'approved' then
      update public.lessons set mosque_id = coalesce(mosque_id, p_mosque)
       where request_id = r.request_id and status = 'pending';
      update public.lesson_series set mosque_id = coalesce(mosque_id, p_mosque)
       where request_id = r.request_id and status = 'pending';
      if exists (select 1 from public.lessons where request_id = r.request_id and status = 'pending' and mosque_id is null) then
        raise exception 'Choose a mosque for this request' using errcode = '22023';
      end if;
    end if;
    update public.lessons set status = next_status, reviewed_by = actor, reviewed_at = now(),
        rejection_reason = case when next_status = 'rejected' then reason end, updated_at = now()
      where request_id = r.request_id and status = 'pending';
    update public.lesson_series set status = next_status where request_id = r.request_id and status = 'pending';
    n := n + 1;
    select * into names from private.preacher_names(r.preacher_id);
    perform private.lessons_log(p_decision, r.title_ar || ' — ' || names.name_ar,
      coalesce(nullif(r.title_en, ''), r.title_ar) || ', ' || names.name_en, r.preacher_id, reason);
    if next_status = 'approved' and r.notify_followers then
      perform private.lessons_notify(f.profile_id, 'sparkle', 'درس جديد من داعية تتابعه', 'New lesson from a preacher you follow',
        names.name_ar || ': ' || r.title_ar, names.name_en || ': ' || coalesce(nullif(r.title_en, ''), r.title_ar),
        '/lessons/requests/' || r.request_id)
      from (select distinct f.profile_id from public.lesson_follows f
             where (f.kind = 'preacher' and f.target_id = r.preacher_id)
                or (f.kind = 'mosque' and f.target_id in (select mosque_id from public.lessons where request_id = r.request_id))) f
      where f.profile_id is distinct from actor;
    end if;
  end loop;
  return n;
end; $$;

-- Same as 20261022125222, with the reason in the log.
create or replace function public.lessons_cancel_lesson(p_lesson uuid, p_reason text) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  l public.lessons;
  n integer;
  reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  select * into l from public.lessons where id = p_lesson for update;
  if not found or l.status <> 'approved' or l.lesson_date < public.lessons_today() then
    raise exception 'Only an upcoming approved session can be cancelled' using errcode = '22023';
  end if;
  if reason is null then raise exception 'A reason is required' using errcode = '22023'; end if;
  update public.lessons set status = 'cancelled', cancel_reason = reason, updated_at = now() where id = l.id;
  select count(*) into n from public.lesson_reminders where lesson_id = l.id;
  perform private.lessons_notify(r.profile_id, 'alert', 'أُلغي موعد: ' || l.title_ar,
    'Cancelled: ' || coalesce(nullif(l.title_en, ''), l.title_ar),
    to_char(l.lesson_date, 'YYYY-MM-DD') || ' — ' || reason, to_char(l.lesson_date, 'YYYY-MM-DD') || ': ' || reason,
    '/lessons/lesson/' || l.id)
  from public.lesson_reminders r where r.lesson_id = l.id and r.profile_id <> actor;
  perform private.lessons_log('cancel', l.title_ar || ' — ' || to_char(l.lesson_date, 'YYYY-MM-DD'),
    coalesce(nullif(l.title_en, ''), l.title_ar) || ', ' || to_char(l.lesson_date, 'YYYY-MM-DD'), l.preacher_id, reason);
  return n;
end; $$;

-- Same as 20261022125222; a merged mosque's preachers and applications move too.
create or replace function public.lessons_remove_mosque(p_mosque uuid, p_merge_into uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); m public.mosques;
begin
  select * into m from public.mosques where id = p_mosque for update;
  if not found then raise exception 'Mosque not found' using errcode = '22023'; end if;
  if p_merge_into is not null then
    if p_merge_into = p_mosque or not exists (select 1 from public.mosques where id = p_merge_into) then
      raise exception 'Merge into another mosque' using errcode = '22023';
    end if;
    update public.lessons set mosque_id = p_merge_into, updated_at = now() where mosque_id = p_mosque;
    update public.lesson_series set mosque_id = p_merge_into where mosque_id = p_mosque;
    update public.preachers set home_mosque_id = p_merge_into where home_mosque_id = p_mosque;
    update public.preacher_applications set mosque_id = p_merge_into where mosque_id = p_mosque;
    update public.lesson_follows set target_id = p_merge_into where kind = 'mosque' and target_id = p_mosque
      and not exists (select 1 from public.lesson_follows f2 where f2.profile_id = lesson_follows.profile_id
        and f2.kind = 'mosque' and f2.target_id = p_merge_into);
  elsif exists (select 1 from public.lessons where mosque_id = p_mosque) then
    raise exception 'Sessions use this mosque. Merge it instead.' using errcode = '23503';
  end if;
  delete from public.lesson_follows where kind = 'mosque' and target_id = p_mosque;
  delete from public.mosques where id = p_mosque;
  perform private.lessons_audit(case when p_merge_into is null then 'removeMosque' else 'mergeMosque' end,
    m.name_ar, coalesce(nullif(m.name_en, ''), m.name_ar));
end; $$;

-- ---------------------------------------------------------------------------
-- Roles: whether the account is a preacher, and its latest application
-- ---------------------------------------------------------------------------
create or replace function public.lessons_my_roles() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('admin', public.is_lessons_admin(), 'master', public.is_master_admin(),
    'preacher_id', (select p.id from public.preachers p
      where p.linked_profile_id = auth.uid() and auth.uid() is not null),
    'application', (select jsonb_build_object('id', a.id, 'status', a.status, 'reason', a.reason,
        'created_at', a.created_at, 'decided_at', a.decided_at)
      from public.preacher_applications a where a.profile_id = auth.uid()
      order by a.created_at desc limit 1));
$$;

-- ---------------------------------------------------------------------------
-- Applying (any signed-in account) and deciding (admins)
-- ---------------------------------------------------------------------------
create function public.lessons_apply(p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_viewer();
  aid uuid;
  v_name text := btrim(coalesce(p->>'name_ar', ''));
  v_name_en text := btrim(coalesce(p->>'name_en', ''));
  v_city text := coalesce(p->>'city', '');
  v_mosque uuid := nullif(p->>'mosque_id', '')::uuid;
  v_new text := nullif(btrim(coalesce(p->>'new_mosque_name', '')), '');
  v_district text := nullif(p->>'new_mosque_district', '');
  v_phone text := private.clean_phone(p->>'phone');
  v_email text := private.clean_email(p->>'email');
  v_photo text := nullif(btrim(coalesce(p->>'photo_url', '')), '');
begin
  if jsonb_typeof(p) <> 'object' then raise exception 'Nothing to send' using errcode = '22023'; end if;
  if exists (select 1 from public.preachers where linked_profile_id = actor) then
    raise exception 'This account is already a preacher' using errcode = '23505', hint = 'already_preacher';
  end if;
  if exists (select 1 from public.preacher_applications where profile_id = actor and status = 'pending') then
    raise exception 'An application is already waiting' using errcode = '23505', hint = 'pending';
  end if;
  if (select count(*) from public.preacher_applications
       where profile_id = actor and created_at > now() - interval '30 days') >= 3 then
    raise exception 'Too many applications this month' using errcode = '54000';
  end if;
  if v_mosque is not null then
    if not exists (select 1 from public.mosques m join public.mosque_districts d on d.id = m.district_id
        where m.id = v_mosque and m.verified and d.city = v_city) then
      raise exception 'Choose a mosque in your city' using errcode = '22023';
    end if;
    v_new := null;
    v_district := null;
  elsif v_new is null or not exists (select 1 from public.mosque_districts d
      where d.id = v_district and d.city = v_city) then
    raise exception 'Choose your mosque, or name it and its area' using errcode = '22023';
  end if;
  if v_phone is null then raise exception 'A mobile number is required' using errcode = '22023'; end if;
  if v_email is null or v_email !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'A valid email is required' using errcode = '22023';
  end if;
  -- Only a photo this account uploaded to its own folder.
  if v_photo is not null and position('/storage/v1/object/public/streamer-assets/' || actor::text || '/' in v_photo) = 0 then
    raise exception 'Upload the photo from the form' using errcode = '22023';
  end if;
  insert into public.preacher_applications(profile_id, name_ar, name_en, title_ar, bio_ar, photo_url, city,
    mosque_id, new_mosque_name, new_mosque_district, languages, phone, email, experience, sample_url)
  values (actor, v_name, v_name_en, btrim(coalesce(p->>'title_ar', '')), btrim(coalesce(p->>'bio_ar', '')),
    v_photo, v_city, v_mosque, v_new, v_district,
    coalesce(nullif(array(select jsonb_array_elements_text(p->'languages')), '{}'), '{ar}'),
    v_phone, v_email, btrim(coalesce(p->>'experience', '')),
    nullif(btrim(coalesce(p->>'sample_url', '')), ''))
  returning id into aid;
  perform private.lessons_log('applicationReceived', v_name, coalesce(nullif(v_name_en, ''), v_name), null, null);
  perform private.lessons_notify(a, 'user', 'طلب انضمام جديد من داعية', 'A new preacher application',
    v_name, coalesce(nullif(v_name_en, ''), v_name), '/admin/lessons/approvals')
  from private.lessons_admins() a;
  perform private.preacher_email('application_received', null, aid, interval '0 minutes', aid);
  return aid;
end; $$;

create function public.lessons_withdraw_application() returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_viewer(); a public.preacher_applications;
begin
  update public.preacher_applications set status = 'withdrawn', updated_at = now()
   where profile_id = actor and status = 'pending' returning * into a;
  if not found then raise exception 'Nothing to withdraw' using errcode = '22023'; end if;
  update private.preacher_emails set status = 'cancelled'
   where application_id = a.id and status = 'queued';
  perform private.lessons_log('applicationWithdrawn', a.name_ar, coalesce(nullif(a.name_en, ''), a.name_ar), null, null);
end; $$;

-- Approving creates the preacher card, linked to the applicant's account,
-- with his contacts and initial mosque. p may set mosque_id (another
-- mosque), affiliation and listed. Without a listed mosque, the one he named
-- is added to the directory.
create function public.lessons_decide_application(p_application uuid, p_approve boolean,
  p_reason text default null, p jsonb default '{}'::jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.lessons_admin();
  a public.preacher_applications;
  mid uuid;
  pid uuid;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_name_en text;
begin
  select * into a from public.preacher_applications where id = p_application and status = 'pending' for update;
  if not found then raise exception 'Nothing to decide' using errcode = '22023'; end if;
  v_name_en := coalesce(nullif(a.name_en, ''), a.name_ar);
  if not coalesce(p_approve, false) then
    if v_reason is null or char_length(v_reason) < 3 then
      raise exception 'A reason is required to decline' using errcode = '22023';
    end if;
    update public.preacher_applications set status = 'rejected', reason = v_reason, decided_by = actor,
      decided_at = now(), updated_at = now() where id = a.id;
    perform private.lessons_log('applicationRejected', a.name_ar, v_name_en, null, v_reason);
    perform private.lessons_notify(a.profile_id, 'x', 'لم يُقبل طلب انضمامك داعيةً', 'Your preacher application was declined',
      v_reason, v_reason, '/lessons/apply');
    perform private.preacher_email('application_rejected', null, a.id, interval '15 minutes', a.id);
    return null;
  end if;
  if exists (select 1 from public.preachers where linked_profile_id = a.profile_id) then
    raise exception 'This account is already a preacher' using errcode = '23505', hint = 'already_preacher';
  end if;
  if coalesce(p->>'affiliation', 'coop') not in ('coop','ministry') then
    raise exception 'Unknown affiliation' using errcode = '22023';
  end if;
  mid := coalesce(nullif(p->>'mosque_id', '')::uuid, a.mosque_id);
  if mid is null then
    if a.new_mosque_name is null or a.new_mosque_district is null then
      raise exception 'Choose a mosque' using errcode = '22023';
    end if;
    insert into public.mosques(name_ar, district_id, created_by)
    values (a.new_mosque_name, a.new_mosque_district, actor) returning id into mid;
    perform private.lessons_audit('addMosque', a.new_mosque_name, a.new_mosque_name);
  elsif not exists (select 1 from public.mosques where id = mid) then
    raise exception 'Choose a mosque' using errcode = '22023';
  end if;
  insert into public.preachers(name_ar, name_en, title_ar, bio_ar, photo_url, city, affiliation, languages, listed,
    linked_profile_id, home_mosque_id, joined_via, created_by)
  values (a.name_ar, a.name_en, a.title_ar, a.bio_ar, a.photo_url, a.city, coalesce(p->>'affiliation', 'coop'),
    a.languages, coalesce((p->>'listed')::boolean, true), a.profile_id, mid, 'application', actor)
  returning id into pid;
  insert into private.preacher_contacts(preacher_id, phone, email) values (pid, a.phone, a.email);
  update public.preacher_applications set status = 'approved', preacher_id = pid, mosque_id = mid,
    reason = v_reason, decided_by = actor, decided_at = now(), updated_at = now() where id = a.id;
  perform private.lessons_log('applicationApproved', a.name_ar, v_name_en, pid, v_reason);
  perform private.lessons_notify(a.profile_id, 'check', 'قُبلتَ داعيةً في برنامج الدروس',
    'You are now a preacher in the lessons programme', 'صفحتك في الإعدادات: صفحتي داعيةً.',
    'Your page is in Settings: My preacher page.', '/lessons/me/preacher');
  perform private.preacher_email('application_approved', pid, a.id, interval '15 minutes', a.id);
  return pid;
end; $$;

-- Undo a decision on an application within 15 minutes (the emails wait that
-- long). Undoing an approval removes the card it created, if nothing was
-- added to it yet.
create function public.lessons_undo_application(p_application uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); a public.preacher_applications;
begin
  select * into a from public.preacher_applications where id = p_application for update;
  if not found or a.status not in ('approved','rejected') or a.decided_by is distinct from actor
     or a.decided_at < now() - interval '15 minutes' then
    raise exception 'Only your decision of the last 15 minutes can be undone' using errcode = '22023';
  end if;
  if a.status = 'approved' then
    if exists (select 1 from public.lessons where preacher_id = a.preacher_id) then
      raise exception 'Lessons were added for this preacher' using errcode = '23503';
    end if;
    delete from public.preachers where id = a.preacher_id;
  end if;
  update private.preacher_emails set status = 'cancelled'
   where application_id = a.id and status = 'queued' and kind in ('application_approved','application_rejected');
  update public.preacher_applications set status = 'pending', reason = null, preacher_id = null,
    decided_by = null, decided_at = null, updated_at = now() where id = a.id;
  perform private.lessons_log('undo', a.name_ar, coalesce(nullif(a.name_en, ''), a.name_ar), null, null);
end; $$;

-- ---------------------------------------------------------------------------
-- A preacher's page: through a link (no account) or through his account
-- ---------------------------------------------------------------------------
create function private.preacher_page(p_preacher uuid, p_access jsonb) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'preacher', (select jsonb_build_object('id', p.id, 'name_ar', p.name_ar, 'name_en', p.name_en,
        'title_ar', p.title_ar, 'title_en', p.title_en, 'bio_ar', p.bio_ar, 'bio_en', p.bio_en,
        'photo_url', p.photo_url, 'city', p.city, 'languages', p.languages, 'listed', p.listed,
        'home_mosque_id', p.home_mosque_id)
      from public.preachers p where p.id = p_preacher),
    'key', p_access,
    'email_set', exists (select 1 from private.preacher_contacts c where c.preacher_id = p_preacher and c.email is not null),
    'pending_edit', (select e.payload from public.preacher_edits e
      where e.preacher_id = p_preacher and e.status = 'pending' order by e.created_at desc limit 1),
    'lessons', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'request_id', l.request_id,
        'series_id', l.series_id, 'seq', l.seq, 'title_ar', l.title_ar, 'title_en', l.title_en, 'type', l.type,
        'topic', l.topic, 'lesson_date', l.lesson_date, 'slot', l.slot, 'exact_time', l.exact_time,
        'status', l.status, 'source', l.source, 'preacher_note', l.preacher_note,
        'rejection_reason', l.rejection_reason, 'cancel_reason', l.cancel_reason, 'mosque_id', l.mosque_id,
        'mosque_name_ar', m.name_ar, 'mosque_name_en', m.name_en) order by l.lesson_date, l.slot)
      from public.lessons l left join public.mosques m on m.id = l.mosque_id
      where l.preacher_id = p_preacher and l.status <> 'withdrawn'
        and l.lesson_date >= public.lessons_today() - 60), '[]'::jsonb));
$$;

-- Card changes for an admin to approve; one pending proposal at a time.
create function private.preacher_propose(p_preacher uuid, p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  x jsonb := '{}'::jsonb;
  f text;
  eid uuid;
  names record;
begin
  if jsonb_typeof(p) <> 'object' then raise exception 'Nothing to change' using errcode = '22023'; end if;
  foreach f in array array['name_ar','name_en','title_ar','title_en','bio_ar','bio_en'] loop
    if p ? f then x := x || jsonb_build_object(f, btrim(coalesce(p->>f, ''))); end if;
  end loop;
  if p ? 'languages' then x := x || jsonb_build_object('languages', p->'languages'); end if;
  if private.clean_email(p->>'email') is not null then
    x := x || jsonb_build_object('email', private.clean_email(p->>'email'));
  end if;
  if x = '{}'::jsonb then raise exception 'Nothing to change' using errcode = '22023'; end if;
  if (x ? 'name_ar' and char_length(x->>'name_ar') not between 3 and 120)
     or char_length(coalesce(x->>'name_en', '')) > 120
     or char_length(coalesce(x->>'title_ar', '')) > 120 or char_length(coalesce(x->>'title_en', '')) > 120
     or char_length(coalesce(x->>'bio_ar', '')) > 1500 or char_length(coalesce(x->>'bio_en', '')) > 1500
     or (x ? 'email' and (char_length(x->>'email') > 254
       or x->>'email' !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'))
     or (x ? 'languages' and (jsonb_typeof(x->'languages') <> 'array'
       or jsonb_array_length(x->'languages') not between 1 and 7
       or not (array(select jsonb_array_elements_text(x->'languages')) <@ array['ar','en','ur','tl','bn','ml','id']::text[]))) then
    raise exception 'Check the lengths and languages' using errcode = '22023';
  end if;
  update public.preacher_edits set payload = x, created_at = now()
   where preacher_id = p_preacher and status = 'pending' returning id into eid;
  if eid is null then
    insert into public.preacher_edits(preacher_id, payload) values (p_preacher, x) returning id into eid;
  end if;
  select * into names from private.preacher_names(p_preacher);
  perform private.lessons_audit('preacherEdit', names.name_ar, names.name_en, p_preacher);
  perform private.lessons_notify(a, 'user', 'داعية اقترح تعديلًا على بطاقته', 'A preacher proposed a card change',
    names.name_ar, names.name_en, '/admin/lessons/approvals')
  from private.lessons_admins() a;
  return eid;
end; $$;

-- A lesson (one date) or weekly series (several dates), waiting for an admin.
-- He may suggest the mosque (any listed one); the admin can change it.
create function private.preacher_request(p_preacher uuid, p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  req uuid := gen_random_uuid();
  ser uuid;
  dates date[];
  d date;
  i integer := 0;
  today date := public.lessons_today();
  title_ar text := btrim(coalesce(p->>'title_ar', ''));
  mosque uuid := nullif(p->>'mosque_id', '')::uuid;
  names record;
begin
  if (select count(distinct request_id) from public.lessons
       where preacher_id = p_preacher and status = 'pending') >= 20 then
    raise exception 'Too many requests are waiting' using errcode = '54000';
  end if;
  if mosque is not null and not exists (select 1 from public.mosques where id = mosque and verified) then
    raise exception 'Choose a mosque' using errcode = '22023';
  end if;
  select array_agg(distinct x::date order by x::date) into dates
    from jsonb_array_elements_text(coalesce(p->'dates', '[]'::jsonb)) x;
  if dates is null or cardinality(dates) not between 1 and 12 then
    raise exception 'Between 1 and 12 dates are required' using errcode = '22023';
  end if;
  if dates[1] < today or dates[cardinality(dates)] > today + 180 then
    raise exception 'Dates must be from today up to six months ahead' using errcode = '22023';
  end if;
  if cardinality(dates) > 1 then
    insert into public.lesson_series(request_id, preacher_id, mosque_id, title_ar, type, topic, language, audience, slot, total)
    values (req, p_preacher, mosque, title_ar, p->>'type', p->>'topic', coalesce(p->>'language', 'ar'),
      coalesce(p->>'audience', 'all'), p->>'slot', cardinality(dates))
    returning id into ser;
  end if;
  foreach d in array dates loop
    i := i + 1;
    insert into public.lessons(request_id, series_id, seq, type, topic, title_ar, preacher_id, mosque_id, lesson_date,
      slot, language, audience, status, source, preacher_note)
    values (req, ser, case when ser is null then null else i end, p->>'type', p->>'topic', title_ar, p_preacher,
      mosque, d, p->>'slot', coalesce(p->>'language', 'ar'), coalesce(p->>'audience', 'all'), 'pending', 'preacher',
      btrim(coalesce(p->>'note', '')));
  end loop;
  select * into names from private.preacher_names(p_preacher);
  perform private.lessons_audit('request', title_ar || ' — ' || names.name_ar, title_ar || ', ' || names.name_en, p_preacher);
  perform private.lessons_notify(a, 'inbox', 'طلب درس جديد من داعية', 'A preacher requested a lesson',
    title_ar || ' — ' || names.name_ar, title_ar || ', ' || names.name_en, '/admin/lessons/approvals')
  from private.lessons_admins() a;
  return req;
end; $$;

create function private.preacher_withdraw(p_preacher uuid, p_request uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare t_ar text;
begin
  select title_ar into t_ar from public.lessons
   where request_id = p_request and preacher_id = p_preacher and status = 'pending' limit 1;
  if t_ar is null then raise exception 'Nothing to withdraw' using errcode = '22023'; end if;
  update public.lessons set status = 'withdrawn', updated_at = now() where request_id = p_request and status = 'pending';
  update public.lesson_series set status = 'withdrawn' where request_id = p_request and status = 'pending';
  perform private.lessons_audit('withdraw', t_ar, t_ar, p_preacher);
end; $$;

-- Through a link: unchanged arguments; the bodies now share the code above.
create or replace function public.lessons_key_open(p_key text, p_device text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare k private.preacher_keys := private.preacher_key(p_key, p_device);
begin
  return private.preacher_page(k.preacher_id, jsonb_build_object('kind', k.kind, 'valid_until', k.valid_until));
end; $$;

create or replace function public.lessons_key_update_profile(p_key text, p_device text, p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare k private.preacher_keys := private.preacher_key(p_key, p_device);
begin
  return private.preacher_propose(k.preacher_id, p);
end; $$;

create or replace function public.lessons_key_request_lesson(p_key text, p_device text, p jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare k private.preacher_keys := private.preacher_key(p_key, p_device);
begin
  return private.preacher_request(k.preacher_id, p);
end; $$;

create or replace function public.lessons_key_withdraw(p_key text, p_device text, p_request uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare k private.preacher_keys := private.preacher_key(p_key, p_device);
begin
  perform private.preacher_withdraw(k.preacher_id, p_request);
end; $$;

-- Through his own account (a preacher who applied, or whose card an admin
-- linked to his account).
create function private.preacher_of_caller() returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare pid uuid;
begin
  if auth.uid() is null or public.is_banned(auth.uid()) then
    raise exception 'Sign in required' using errcode = '42501';
  end if;
  select p.id into pid from public.preachers p where p.linked_profile_id = auth.uid();
  if pid is null then
    raise exception 'This account has no preacher card' using errcode = '42501', hint = 'not_preacher';
  end if;
  return pid;
end; $$;

create function public.lessons_me_page() returns jsonb
language sql security definer set search_path = '' as $$
  select private.preacher_page(private.preacher_of_caller(), jsonb_build_object('kind', 'account'));
$$;

create function public.lessons_me_update_profile(p jsonb) returns uuid
language sql security definer set search_path = '' as $$
  select private.preacher_propose(private.preacher_of_caller(), p);
$$;

create function public.lessons_me_request_lesson(p jsonb) returns uuid
language sql security definer set search_path = '' as $$
  select private.preacher_request(private.preacher_of_caller(), p);
$$;

create function public.lessons_me_withdraw(p_request uuid) returns void
language sql security definer set search_path = '' as $$
  select private.preacher_withdraw(private.preacher_of_caller(), p_request);
$$;

-- ---------------------------------------------------------------------------
-- What reaches the preacher when lessons and card changes are decided
-- ---------------------------------------------------------------------------
create function private.lessons_preacher_events() returns trigger
language plpgsql security definer set search_path = '' as $$
declare is_first boolean := new.seq is null or new.seq = 1;
begin
  if tg_op = 'INSERT' then
    if new.status = 'approved' and new.source = 'admin' and new.lesson_date >= public.lessons_today() then
      perform private.preacher_email('lesson_assigned', new.preacher_id, new.request_id, interval '2 minutes');
      if is_first then
        perform private.preacher_notify(new.preacher_id, 'calendar', 'أُضيف لك درس: ' || new.title_ar,
          'A lesson was added for you: ' || coalesce(nullif(new.title_en, ''), new.title_ar),
          to_char(new.lesson_date, 'YYYY-MM-DD'), to_char(new.lesson_date, 'YYYY-MM-DD'));
      end if;
    end if;
    return null;
  end if;
  if new.status is distinct from old.status then
    if old.status = 'pending' and new.status = 'approved' and new.source = 'preacher' then
      perform private.preacher_email('request_approved', new.preacher_id, new.request_id, interval '15 minutes');
      if is_first then
        perform private.preacher_notify(new.preacher_id, 'check', 'قُبل طلبك: ' || new.title_ar,
          'Your request was approved: ' || coalesce(nullif(new.title_en, ''), new.title_ar),
          to_char(new.lesson_date, 'YYYY-MM-DD'), to_char(new.lesson_date, 'YYYY-MM-DD'));
      end if;
    elsif old.status = 'pending' and new.status = 'rejected' then
      perform private.preacher_email('request_rejected', new.preacher_id, new.request_id, interval '15 minutes');
      if is_first then
        perform private.preacher_notify(new.preacher_id, 'x', 'لم يُقبل طلبك: ' || new.title_ar,
          'Your request was declined: ' || coalesce(nullif(new.title_en, ''), new.title_ar),
          coalesce(new.rejection_reason, ''), coalesce(new.rejection_reason, ''));
      end if;
    elsif new.status = 'pending' and old.status in ('approved','rejected') then
      -- An admin undid the decision: its email is not sent.
      update private.preacher_emails set status = 'cancelled'
       where status = 'queued' and kind in ('request_approved','request_rejected') and ref_id = new.request_id;
    elsif old.status = 'approved' and new.status = 'cancelled' then
      perform private.preacher_email('lesson_cancelled', new.preacher_id, new.id, interval '2 minutes');
      update private.preacher_emails set status = 'cancelled'
       where status = 'queued' and kind in ('lesson_changed','lesson_tomorrow') and ref_id = new.id;
      perform private.preacher_notify(new.preacher_id, 'alert', 'أُلغي موعد: ' || new.title_ar,
        'Cancelled: ' || coalesce(nullif(new.title_en, ''), new.title_ar),
        coalesce(new.cancel_reason, ''), coalesce(new.cancel_reason, ''));
    end if;
  elsif new.status = 'approved' and new.lesson_date >= public.lessons_today()
    and (new.lesson_date, new.slot, new.exact_time, new.mosque_id)
      is distinct from (old.lesson_date, old.slot, old.exact_time, old.mosque_id) then
    perform private.preacher_email('lesson_changed', new.preacher_id, new.id, interval '5 minutes');
    perform private.preacher_notify(new.preacher_id, 'clock', 'تغيّر موعد درسك: ' || new.title_ar,
      'Your lesson moved: ' || coalesce(nullif(new.title_en, ''), new.title_ar),
      to_char(new.lesson_date, 'YYYY-MM-DD'), to_char(new.lesson_date, 'YYYY-MM-DD'));
  end if;
  return null;
end; $$;
create trigger lessons_preacher_events after insert or update of status, lesson_date, slot, exact_time, mosque_id
  on public.lessons for each row execute function private.lessons_preacher_events();

create function private.preacher_edit_events() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.status = 'pending' and new.status in ('approved','rejected') then
    perform private.preacher_email(case when new.status = 'approved' then 'card_approved' else 'card_rejected' end,
      new.preacher_id, new.id, interval '2 minutes');
    perform private.preacher_notify(new.preacher_id, case when new.status = 'approved' then 'check' else 'x' end,
      case when new.status = 'approved' then 'اعتُمد تعديل بطاقتك' else 'لم يُعتمد تعديل بطاقتك' end,
      case when new.status = 'approved' then 'Your card change was approved' else 'Your card change was declined' end,
      coalesce(new.reason, ''), coalesce(new.reason, ''));
  end if;
  return null;
end; $$;
create trigger preacher_edit_events after update of status on public.preacher_edits
  for each row execute function private.preacher_edit_events();

-- ---------------------------------------------------------------------------
-- Sending (service role: the dispatch-preacher-emails function)
-- ---------------------------------------------------------------------------
-- What an email says, read when it is sent. Null when there is nothing to
-- send any more (an undone decision, a revoked link, a lesson cancelled
-- before its reminder).
create function private.preacher_email_data(e private.preacher_emails) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  pr public.preachers;
  ap public.preacher_applications;
  l public.lessons;
  k private.preacher_keys;
  ed public.preacher_edits;
  m public.mosques;
  d jsonb;
  n integer;
  dates jsonb;
  want text;
  today date := public.lessons_today();
begin
  if e.preacher_id is not null then select * into pr from public.preachers where id = e.preacher_id; end if;
  if e.application_id is not null then select * into ap from public.preacher_applications where id = e.application_id; end if;
  d := jsonb_build_object('kind', e.kind,
    'name_ar', coalesce(pr.name_ar, ap.name_ar),
    'name_en', coalesce(nullif(pr.name_en, ''), nullif(ap.name_en, ''), pr.name_ar, ap.name_ar),
    'account', pr.linked_profile_id is not null or ap.id is not null);
  if e.kind = 'invite' then
    select * into k from private.preacher_keys where id = e.ref_id;
    if not found or k.revoked_at is not null or (k.valid_until is not null and k.valid_until < now())
       or not (e.payload ? 'token') then
      return null;
    end if;
    return d || jsonb_build_object('token', e.payload->>'token', 'link_kind', k.kind,
      'valid_from', k.valid_from, 'valid_until', k.valid_until);
  elsif e.kind like 'application\_%' then
    if ap.id is null or ap.status <> (case e.kind when 'application_received' then 'pending'
        when 'application_approved' then 'approved' else 'rejected' end) then
      return null;
    end if;
    select * into m from public.mosques where id = coalesce(pr.home_mosque_id, ap.mosque_id);
    return d || jsonb_build_object('reason', ap.reason,
      'mosque_ar', coalesce(m.name_ar, ap.new_mosque_name), 'mosque_en', coalesce(nullif(m.name_en, ''), m.name_ar, ap.new_mosque_name));
  elsif e.kind in ('lesson_assigned','request_approved','request_rejected') then
    want := case when e.kind = 'request_rejected' then 'rejected' else 'approved' end;
    select count(*), jsonb_agg(x.lesson_date order by x.lesson_date) into n, dates
      from public.lessons x where x.request_id = e.ref_id and x.status = want
       and (want = 'rejected' or x.lesson_date >= today);
    if n = 0 then return null; end if;
    select * into l from public.lessons x where x.request_id = e.ref_id and x.status = want
       and (want = 'rejected' or x.lesson_date >= today) order by x.lesson_date limit 1;
  elsif e.kind in ('lesson_cancelled','lesson_changed','lesson_tomorrow') then
    select * into l from public.lessons where id = e.ref_id;
    if not found or l.status <> (case when e.kind = 'lesson_cancelled' then 'cancelled' else 'approved' end)
       or l.lesson_date < today then
      return null;
    end if;
    n := 1;
    dates := jsonb_build_array(l.lesson_date);
  elsif e.kind in ('card_approved','card_rejected') then
    select * into ed from public.preacher_edits where id = e.ref_id;
    if not found then return null; end if;
    return d || jsonb_build_object('reason', ed.reason);
  else
    return null;
  end if;
  select * into m from public.mosques where id = l.mosque_id;
  return d || jsonb_build_object('title_ar', l.title_ar, 'title_en', coalesce(nullif(l.title_en, ''), l.title_ar),
    'date', l.lesson_date, 'dates', dates, 'count', n, 'slot', l.slot, 'exact_time', l.exact_time,
    'mosque_ar', m.name_ar, 'mosque_en', coalesce(nullif(m.name_en, ''), m.name_ar),
    'maps_url', coalesce(m.maps_url, case when m.latitude is not null
      then 'https://www.google.com/maps/search/?api=1&query=' || m.latitude || ',' || m.longitude end),
    'reason', coalesce(l.rejection_reason, l.cancel_reason));
end; $$;

-- Emails due now, leased for five minutes. Also queues the day-before
-- reminders (from 09:00 Riyadh time, not for a lesson added or approved in
-- the last 12 hours: that email just went).
create function public.claim_preacher_emails(p_limit integer default 25)
returns table(id uuid, kind text, to_email text, data jsonb)
language plpgsql security definer set search_path = '' as $$
declare
  r private.preacher_emails;
  addr text;
  d jsonb;
begin
  if (now() at time zone 'Asia/Riyadh')::time >= time '09:00' then
    insert into private.preacher_emails(kind, preacher_id, ref_id)
    select 'lesson_tomorrow', l.preacher_id, l.id
      from public.lessons l
      join private.preacher_contacts c on c.preacher_id = l.preacher_id and c.email is not null
     where l.status = 'approved' and l.lesson_date = public.lessons_today() + 1
       and coalesce(l.reviewed_at, l.submitted_at) < now() - interval '12 hours'
       and not exists (select 1 from private.preacher_emails x where x.kind = 'lesson_tomorrow' and x.ref_id = l.id)
    on conflict do nothing;
  end if;
  for r in
    select * from private.preacher_emails e
     where e.status = 'queued' and e.send_after <= now() and (e.leased_until is null or e.leased_until < now())
     order by e.send_after
     limit greatest(1, least(coalesce(p_limit, 25), 100))
     for update skip locked
  loop
    addr := case when r.preacher_id is not null
      then (select c.email from private.preacher_contacts c where c.preacher_id = r.preacher_id)
      else (select a.email from public.preacher_applications a where a.id = r.application_id) end;
    d := private.preacher_email_data(r);
    if addr is null or d is null then
      update private.preacher_emails set status = 'skipped', payload = payload - 'token',
        last_error = case when addr is null then 'no_address' else 'nothing_to_send' end
       where preacher_emails.id = r.id;
      continue;
    end if;
    update private.preacher_emails set leased_until = now() + interval '5 minutes', attempts = attempts + 1,
      to_email = addr where preacher_emails.id = r.id;
    id := r.id; kind := r.kind; to_email := addr; data := d;
    return next;
  end loop;
end; $$;

-- The dispatcher's result. A failure is retried with a growing wait, five
-- times in all; a given-up email is logged.
create function public.preacher_email_result(p_id uuid, p_ok boolean, p_error text default null,
  p_provider_id text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare e private.preacher_emails; names record;
begin
  update private.preacher_emails set
    status = case when p_ok then 'sent' when attempts >= 5 then 'failed' else 'queued' end,
    sent_at = case when p_ok then now() end,
    provider_id = left(p_provider_id, 200),
    last_error = case when p_ok then null else left(coalesce(p_error, 'error'), 500) end,
    leased_until = null,
    send_after = case when p_ok then send_after else now() + attempts * interval '10 minutes' end,
    payload = case when p_ok or attempts >= 5 then payload - 'token' else payload end
  where preacher_emails.id = p_id and status = 'queued'
  returning * into e;
  if found and e.status = 'failed' then
    select * into names from private.preacher_names(e.preacher_id);
    perform private.lessons_log('emailFailed', coalesce(names.name_ar, ''), coalesce(names.name_en, ''),
      e.preacher_id, e.kind || ': ' || coalesce(e.last_error, ''));
  end if;
end; $$;

-- Admins: emails sent or waiting (addresses masked), and sending one again.
create function public.lessons_email_log(p_preacher uuid default null) returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', e.id, 'kind', e.kind, 'status', e.status, 'preacher_id', e.preacher_id,
      'application_id', e.application_id, 'to', private.mask_email(coalesce(e.to_email, c.email, a.email)),
      'attempts', e.attempts, 'error', e.last_error, 'created_at', e.created_at, 'sent_at', e.sent_at,
      'send_after', e.send_after, 'name_ar', coalesce(p.name_ar, a.name_ar),
      'name_en', coalesce(nullif(p.name_en, ''), nullif(a.name_en, ''), p.name_ar, a.name_ar),
      'retry', e.status in ('failed','skipped') and e.kind <> 'invite')
    from private.preacher_emails e
    left join public.preachers p on p.id = e.preacher_id
    left join private.preacher_contacts c on c.preacher_id = e.preacher_id
    left join public.preacher_applications a on a.id = e.application_id
   where public.is_lessons_admin() and (p_preacher is null or e.preacher_id = p_preacher)
   order by e.created_at desc
   limit 300;
$$;

create function public.lessons_retry_email(p_email uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.lessons_admin(); e private.preacher_emails; names record;
begin
  update private.preacher_emails set status = 'queued', attempts = 0, last_error = null, send_after = now(),
    leased_until = null
   where id = p_email and status in ('failed','skipped') and kind <> 'invite'
     and not exists (select 1 from private.preacher_emails q where q.status = 'queued'
       and q.kind = preacher_emails.kind
       and coalesce(q.ref_id, q.application_id, q.preacher_id)
         = coalesce(preacher_emails.ref_id, preacher_emails.application_id, preacher_emails.preacher_id))
  returning * into e;
  if not found then raise exception 'This email cannot be sent again' using errcode = '22023'; end if;
  select * into names from private.preacher_names(e.preacher_id);
  perform private.lessons_log('emailRetry', coalesce(names.name_ar, ''), coalesce(names.name_en, ''), e.preacher_id, e.kind);
end; $$;

-- ---------------------------------------------------------------------------
-- Photos
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('preacher-photos', 'preacher-photos', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

-- Admins only, under preachers/. The photos belong to no account, so an
-- admin deleting his own account leaves them in place.
create function public.can_write_preacher_photo(object_name text) returns boolean
language sql stable security invoker set search_path = '' as $$
  select (select auth.uid()) is not null and not public.is_current_user_banned()
    and split_part(object_name, '/', 1) = 'preachers' and public.is_lessons_admin();
$$;
revoke execute on function public.can_write_preacher_photo(text) from public, anon;
grant execute on function public.can_write_preacher_photo(text) to authenticated;

create policy preacher_photos_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'preacher-photos' and public.can_write_preacher_photo(name));
create policy preacher_photos_delete on storage.objects for delete to authenticated
  using (bucket_id = 'preacher-photos' and public.can_write_preacher_photo(name));

-- ---------------------------------------------------------------------------
-- Account deletion: the log keeps no name or email of a deleted account (as
-- delete_my_account does for audit_logs), and a card loses the photo that
-- was in the deleted account's own folder.
-- ---------------------------------------------------------------------------
create function private.lessons_forget_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.lesson_audit set actor_name = 'Deleted account', actor_email = 'deleted'
   where actor_id = old.id;
  update public.preachers set photo_url = null
   where position('/storage/v1/object/public/streamer-assets/' || old.id::text || '/' in photo_url) > 0;
  return old;
end; $$;
create trigger lessons_forget_profile before delete on public.profiles
  for each row execute function private.lessons_forget_profile();

-- ---------------------------------------------------------------------------
-- Function privileges
-- ---------------------------------------------------------------------------
revoke all on function private.mask_email(text), private.clean_email(text),
  private.lessons_log(text, text, text, uuid, text),
  private.preacher_email(text, uuid, uuid, interval, uuid, jsonb),
  private.preacher_notify(uuid, text, text, text, text, text),
  private.preacher_key_revoked(), private.preacher_page(uuid, jsonb), private.preacher_propose(uuid, jsonb),
  private.preacher_request(uuid, jsonb), private.preacher_withdraw(uuid, uuid), private.preacher_of_caller(),
  private.lessons_preacher_events(), private.preacher_edit_events(), private.lessons_forget_profile(),
  private.preacher_email_data(private.preacher_emails)
  from public, anon, authenticated;

do $$
declare f regprocedure;
begin
  for f in select p.oid::regprocedure from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname in ('lessons_reveal_email', 'lessons_create_key', 'lessons_apply',
        'lessons_withdraw_application', 'lessons_decide_application', 'lessons_undo_application',
        'lessons_me_page', 'lessons_me_update_profile', 'lessons_me_request_lesson', 'lessons_me_withdraw',
        'lessons_email_log', 'lessons_retry_email')
  loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

revoke all on function public.claim_preacher_emails(integer), public.preacher_email_result(uuid, boolean, text, text)
  from public, anon, authenticated;
grant execute on function public.claim_preacher_emails(integer), public.preacher_email_result(uuid, boolean, text, text)
  to service_role;

-- ---------------------------------------------------------------------------
-- Data rights: the account export carries the person's applications too.
-- ---------------------------------------------------------------------------
create or replace function public.export_my_data() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v uuid := auth.uid();
begin
  if v is null then raise exception 'Not signed in' using errcode = '42501'; end if;
  return private.export_my_data_core() || jsonb_build_object('lessons', jsonb_build_object(
    'reminders', coalesce((select jsonb_agg(to_jsonb(r) - 'profile_id') from public.lesson_reminders r where r.profile_id = v), '[]'::jsonb),
    'follows', coalesce((select jsonb_agg(to_jsonb(f) - 'profile_id') from public.lesson_follows f where f.profile_id = v), '[]'::jsonb),
    'attendance_log', coalesce((select jsonb_agg(to_jsonb(a) - 'profile_id') from public.lesson_attendance a where a.profile_id = v), '[]'::jsonb),
    'preferences', (select to_jsonb(p) - 'profile_id' from public.lesson_preferences p where p.profile_id = v),
    'notifications', coalesce((select jsonb_agg(to_jsonb(n) - 'profile_id' order by n.created_at) from public.lesson_notifications n where n.profile_id = v), '[]'::jsonb),
    'reports_filed', coalesce((select jsonb_agg(jsonb_build_object('lesson_id', f.lesson_id, 'kind', f.kind,
        'message', f.message, 'status', f.status, 'created_at', f.created_at)) from public.lesson_flags f where f.reporter_id = v), '[]'::jsonb),
    'preacher_card', (select to_jsonb(p) from public.preachers p where p.linked_profile_id = v),
    'preacher_applications', coalesce((select jsonb_agg(to_jsonb(a) - 'profile_id' - 'decided_by' order by a.created_at)
      from public.preacher_applications a where a.profile_id = v), '[]'::jsonb)));
end; $$;
revoke all on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;

commit;
