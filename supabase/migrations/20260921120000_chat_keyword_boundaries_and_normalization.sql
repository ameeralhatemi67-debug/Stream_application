-- P6 — the banned-keyword filter matched bare substrings.
--
-- `20260826090000_chat_keyword_filter.sql` tested every message with
-- `new.body ilike '%' || k.keyword || '%'`. The seeded starter list contains
-- `hell`, so the message **`Hello` was rejected as profanity** -- along with
-- "shell", "hello there", "Michelle", "classic" (`ass` is not seeded, but any
-- admin adding it would break a dozen ordinary words), and so on. This was
-- found the first time `chat_rate_limit.test.sql` was actually executed
-- against a database (P1d): its first assertion sent the body 'Hello'.
--
-- Two changes here.
--
-- 1. MATCHING IS NOW WORD-BOUNDED (the default, `match_mode = 'word'`).
--    Both the message and the keyword are normalized, then every run of
--    non-word characters is collapsed to a single space and both strings are
--    padded with one space at each end. The test is then an ordinary substring
--    search for ' keyword ' inside ' body '. That gives exact word-boundary
--    semantics with no regular expression built from admin-supplied text, so a
--    keyword containing `.`, `*`, `(` or `[` cannot turn into a pattern or a
--    catastrophic backtrack. It also handles multi-word phrases -- `shut up`
--    and `kill yourself` are both on the seeded list -- which a per-word check
--    would not.
--
--    The boundary rule, precisely:
--      'hell'          in 'What the hell.'      -> BLOCKED (punctuation is a boundary)
--      'hell'          in 'Hello there'         -> allowed
--      'hell'          in 'hells bells'         -> allowed (suffixed = a different word)
--      'hell'          in 'shell'               -> allowed
--      'hell'          in 'HELL'                -> BLOCKED (case-insensitive)
--      'shut up'       in 'just shut up now'    -> BLOCKED
--      'shut up'       in 'shut   up'           -> BLOCKED (whitespace runs collapse)
--      'shut up'       in 'shutup'              -> allowed
--
--    So an inflected form is a DIFFERENT keyword: 'stupidly' is no longer
--    caught by 'stupid'. That is the deliberate trade for not blocking
--    'Hello', and it is a curation matter, not a code matter -- the blocklist
--    is an admin-managed table precisely so variants can be added. The P6.4
--    keyword-manager UI is where that happens.
--
-- 2. AN ADMIN CAN OPT A SINGLE KEYWORD BACK INTO SUBSTRING MATCHING via
--    `match_mode = 'substring'`, for the cases where catching every inflection
--    matters more than a few false positives (slurs, spam domains). It is
--    per-row and off by default, so the blunt behaviour is a deliberate choice
--    about one word rather than the silent default for all of them. Nothing is
--    weakened into an allowlist: every listed keyword still blocks, and a
--    'substring' row behaves exactly as the whole filter did before.
--
-- Normalization (applied to the message and the keyword alike) makes the
-- filter work for Arabic, which the P6 plan requires and the old `ilike` did
-- not do at all:
--   * case folded (Latin);
--   * tashkeel / harakat removed (U+064B-U+0655, U+0670, plus the Quranic
--     annotation range U+06D6-U+06ED) -- so 'غَبِيّ' matches the keyword 'غبي';
--   * tatweel (U+0640, the kashida elongation) removed -- 'غـــبي' matches;
--   * alef variants unified: أ إ آ ٱ -> ا;
--   * alif maqsura ى -> ya ي;
--   * ta marbuta ة -> ha ه;
--   * hamza carriers ؤ ئ -> و ي.
--
-- Note the limit of a word boundary in Arabic: clitics attach directly to the
-- word, so 'الغبي' (definite article + the word) does NOT match the keyword
-- 'غبي', exactly as 'hells' does not match 'hell'. Same trade, same remedy
-- (add the form, or set that row to 'substring').
begin;

-- ---------------------------------------------------------------------------
-- 1. Normalization. IMMUTABLE so it can be used in an index or a generated
--    column later; every function it calls is immutable.
-- ---------------------------------------------------------------------------
create or replace function public.chat_normalize_text(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select translate(
           regexp_replace(
             lower(coalesce(p_text, '')),
             '[ً-ٰٕـۖ-ۭ]', '', 'g'),
           'أإآٱؤئىة',
           'ااااوييه');
$$;

comment on function public.chat_normalize_text(text) is
  'Case-folds Latin text and normalizes Arabic for comparison: strips tashkeel and tatweel, unifies alef/alif-maqsura/ta-marbuta/hamza-carrier variants. Used by the chat keyword filter so a decorated or elongated spelling cannot slip past the blocklist.';

-- ---------------------------------------------------------------------------
-- 2. Word-boundary form: collapse every non-word run to a single space and pad
--    both ends, so a plain substring search means "contains this whole word or
--    phrase". No regex is ever built from the keyword itself.
--    [[:alnum:]] matches Arabic letters under this database's collation
--    (verified on the local stack), so Arabic words survive the collapse.
-- ---------------------------------------------------------------------------
create or replace function public.chat_boundary_form(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select ' ' || regexp_replace(
                  public.chat_normalize_text(p_text),
                  '[^[:alnum:]_]+', ' ', 'g') || ' ';
$$;

comment on function public.chat_boundary_form(text) is
  'Normalized text with every run of non-word characters collapsed to one space and a space padded at each end, so `position(boundary_form(keyword) in boundary_form(body)) > 0` is an exact whole-word (or whole-phrase) match.';

-- EXECUTE on a new function defaults to PUBLIC in PostgreSQL (unlike a new
-- table's privileges), so both helpers would be callable by `anon` and
-- `authenticated` unless revoked -- D-21's "revoke, then grant back only what
-- is needed". No client calls either one; the filter reaches them through
-- chat_first_banned_keyword and the trigger, both SECURITY DEFINER and owned.
-- (Caught by R5a in rls_catalog.test.sql.)
revoke execute on function public.chat_normalize_text(text) from public, anon, authenticated;
revoke execute on function public.chat_boundary_form(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Per-keyword matching mode.
-- ---------------------------------------------------------------------------
alter table public.chat_banned_keywords
  add column match_mode text not null default 'word'
    check (match_mode in ('word', 'substring'));

comment on column public.chat_banned_keywords.match_mode is
  '''word'' (default): the keyword blocks only as a whole word or phrase, so ''hell'' does not block ''Hello''. ''substring'': the keyword blocks anywhere it appears, catching every inflection at the cost of false positives. Both compare normalized text (see chat_normalize_text).';

comment on table public.chat_banned_keywords is
  'Keywords and phrases that block a chat_messages insert. Compared against normalized text (case-folded, Arabic tashkeel/tatweel stripped, alef/ya/ta-marbuta unified). Each row matches as a whole word by default, or anywhere in the message when match_mode = ''substring''. Managed by admin tiers.';

-- ---------------------------------------------------------------------------
-- 4. The probe. Returns the keyword that matched, or null.
--
--    Kept out of every client role's reach, like is_banned(uuid): it would
--    otherwise let any signed-in account brute-force the blocklist one guess
--    at a time. Admins do not need it -- their policy on
--    chat_banned_keywords lets them read the list directly -- and the trigger
--    and pgTAP both run as the owner.
-- ---------------------------------------------------------------------------
create or replace function public.chat_first_banned_keyword(p_body text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select k.keyword
    from public.chat_banned_keywords k
   where case k.match_mode
           when 'substring' then
             position(public.chat_normalize_text(k.keyword)
                   in public.chat_normalize_text(p_body)) > 0
           else
             position(public.chat_boundary_form(k.keyword)
                   in public.chat_boundary_form(p_body)) > 0
         end
     and btrim(public.chat_normalize_text(k.keyword)) <> ''
   order by length(k.keyword) desc
   limit 1;
$$;

revoke execute on function public.chat_first_banned_keyword(text) from public, anon, authenticated;

comment on function public.chat_first_banned_keyword(text) is
  'Returns the blocklist entry a message trips, or null. Not executable by any client role: it would otherwise be an oracle for enumerating the blocklist. Admins read chat_banned_keywords directly instead.';

-- ---------------------------------------------------------------------------
-- 5. The trigger. Same error code and message as before, so existing client
--    handling and the P6.2 composer copy do not change; SECURITY DEFINER for
--    the same reason as before (the sender has no read on the blocklist).
--    search_path is now pinned to '' (D-21 / R5c) with everything qualified.
-- ---------------------------------------------------------------------------
create or replace function public.chat_check_banned_keywords()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.chat_first_banned_keyword(new.body) is not null then
    raise exception 'Message rejected: contains a banned keyword.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

commit;
