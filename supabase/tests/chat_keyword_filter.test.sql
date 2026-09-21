-- P6 — the chat keyword filter: word boundaries, per-keyword substring mode,
-- and Arabic normalization (20260921120000).
--
-- The bug this file exists for: the filter used to be
-- `body ilike '%' || keyword || '%'`, and the seeded blocklist contains
-- 'hell', so 'Hello' was rejected as profanity. Assertion 1 is that case.
--
-- The boundary rule under test (documented in full in the migration):
-- a 'word'-mode keyword matches only as a whole word or whole phrase, after
-- normalization, with any run of non-word characters treated as a separator.
-- An inflected form ('hells', 'stupidly', Arabic 'الغبي') is therefore a
-- different word and does not match -- the deliberate trade for not blocking
-- 'Hello'. A 'substring'-mode row restores the old blunt behaviour for that one
-- keyword.
begin;
select plan(30);

-- The seeded list from 20260826090000 is: damn, hell, idiot, stupid,
-- 'shut up', 'kill yourself'. All of them are 'word' mode by default.
select is(
  (select count(*)::int from public.chat_banned_keywords where match_mode <> 'word'),
  0, 'every seeded keyword defaults to word mode');

-- ---------------------------------------------------------------------------
-- The regression: a longer word that merely contains a keyword.
-- ---------------------------------------------------------------------------
select is(public.chat_first_banned_keyword('Hello'), null,
 'THE BUG: "Hello" is not blocked by the keyword "hell"');
select is(public.chat_first_banned_keyword('Hello everyone, welcome'), null,
 '"Hello everyone" is not blocked');
select is(public.chat_first_banned_keyword('shell'), null,
 '"shell" is not blocked by "hell"');
select is(public.chat_first_banned_keyword('Michelle'), null,
 '"Michelle" is not blocked by "hell"');
select is(public.chat_first_banned_keyword('hells bells'), null,
 'a suffixed form ("hells") is a different word and is not blocked');
select is(public.chat_first_banned_keyword('stupidly'), null,
 'an inflected form ("stupidly") is not blocked by "stupid"');

-- ---------------------------------------------------------------------------
-- The keyword still blocks as a word. Casing and punctuation.
-- ---------------------------------------------------------------------------
select is(public.chat_first_banned_keyword('what the hell'), 'hell',
 'the standalone word is still blocked');
select is(public.chat_first_banned_keyword('What the hell.'), 'hell',
 'trailing punctuation is a word boundary');
select is(public.chat_first_banned_keyword('HELL'), 'hell',
 'matching is case-insensitive');
select is(public.chat_first_banned_keyword('HeLl?!'), 'hell',
 'mixed case with punctuation is blocked');
select is(public.chat_first_banned_keyword('"hell"'), 'hell',
 'a quoted word is blocked');
select is(public.chat_first_banned_keyword('hell'), 'hell',
 'the whole message being the keyword is blocked');
select is(public.chat_first_banned_keyword('you idiot'), 'idiot',
 'a second seeded keyword blocks too');

-- ---------------------------------------------------------------------------
-- Multi-word phrases -- 'shut up' and 'kill yourself' are both seeded, and a
-- naive per-word boundary check would miss them.
-- ---------------------------------------------------------------------------
select is(public.chat_first_banned_keyword('just shut up now'), 'shut up',
 'a multi-word phrase is blocked');
select is(public.chat_first_banned_keyword('shut   up'), 'shut up',
 'a run of whitespace inside a phrase collapses, so it still matches');
select is(public.chat_first_banned_keyword('shut-up'), 'shut up',
 'punctuation inside a phrase is a separator, so it still matches');
select is(public.chat_first_banned_keyword('shutup'), null,
 'the phrase run together is not the phrase');
select is(public.chat_first_banned_keyword('please kill yourself'), 'kill yourself',
 'the longer seeded phrase is blocked');

-- ---------------------------------------------------------------------------
-- A keyword containing regex metacharacters must be data, never a pattern.
-- ---------------------------------------------------------------------------
insert into public.chat_banned_keywords (keyword) values ('a.b*c');
select is(public.chat_first_banned_keyword('say a.b*c out loud'), 'a.b*c',
 'a keyword with regex metacharacters matches literally');
select is(public.chat_first_banned_keyword('axbyc'), null,
 'those metacharacters are not treated as a pattern');

-- ---------------------------------------------------------------------------
-- Arabic normalization. 'غبي' (stupid) as a keyword.
-- ---------------------------------------------------------------------------
insert into public.chat_banned_keywords (keyword) values ('غبي');
select is(public.chat_first_banned_keyword('انت غبي'), 'غبي',
 'Arabic: the bare word is blocked');
select is(public.chat_first_banned_keyword('انت غَبِيّ'), 'غبي',
 'Arabic: tashkeel (harakat) is stripped before comparison');
select is(public.chat_first_banned_keyword('انت غـــبي'), 'غبي',
 'Arabic: tatweel (kashida) elongation is stripped');
select is(public.chat_first_banned_keyword('الغبي'), null,
 'Arabic: a word with the definite article attached is a different word');

-- alef and ya variants, via a keyword written with the plain forms.
insert into public.chat_banned_keywords (keyword) values ('اهانه');
select is(public.chat_first_banned_keyword('هذه إهانة'), 'اهانه',
 'Arabic: alef-hamza and ta-marbuta variants normalize to the plain forms');
select is(public.chat_first_banned_keyword('هذه آهانة'), 'اهانه',
 'Arabic: alef-madda normalizes to plain alef');
-- Alif maqsura is tested against a keyword that actually ends in ya, so the
-- final letter is the variant under test rather than a different letter.
select is(public.chat_first_banned_keyword('انت غبى'), 'غبي',
 'Arabic: alif-maqsura at the end of a word normalizes to ya');

-- ---------------------------------------------------------------------------
-- match_mode = 'substring' restores the blunt behaviour for one keyword only.
-- ---------------------------------------------------------------------------
update public.chat_banned_keywords set match_mode = 'substring' where keyword = 'hell';
select is(public.chat_first_banned_keyword('Hello'), 'hell',
 'substring mode deliberately blocks "Hello" again for that one keyword');
select is(public.chat_first_banned_keyword('you idiots'), null,
 'other keywords keep word mode while one row is set to substring');

select * from finish();
rollback;
