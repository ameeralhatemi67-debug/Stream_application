# BONUS PROMPT — spend the leftover of the current window (Codex / Astra)

Use when the split run stopped early (forecast stop) and the same 5-hour window still has unused points that would expire at the reset. This is owner-approved extra spend INSIDE that window only. It never crosses the reset: the fresh window stays the split plan's window 2 (cap 60) for `RESUME_PROMPT.md` (`MODE: CONTINUE_SPLIT`).

Owner: paste as soon as possible (the leftover window time is the real limit). Same model, effort medium, fast mode off, fresh session from the repo root. Nothing else to do first.

--- paste from here ---
MODE: BONUS  (extra spend inside the current 5-hour window; window 1 of the split plan is already used)

Autonomous run, nobody answers questions. Same rules as the first run (`AGENTS.md`, `brief/05_DECISIONS.md`): never push, local Supabase only, no secrets anywhere, explicit-path staging, no keystore, no subagents, owner-only things go to `brief/OWNER_ACTIONS.md`, ADR-006 and the "custom placeholder cards" feature untouched.

**Start (in this order, keep it short).**
1. The owner files are already committed (cd0b698). `git stash list` shows two historical owner stashes: never apply, pop or drop them.
2. `node brief/tools/budget_check.mjs --plan bonus --bonus-start` (this once). It records the used % now (S) and sets the bonus cap = min(94, S + 40), soft = cap - 6. If it says UNKNOWN (stale log), read Codex's live usage and re-run with `--live-used N --live-weekly W --live-resets-in-min R` (04 §I); the start is only recorded from a fresh or live reading. Afterwards run `node brief/tools/budget_check.mjs --plan bonus` (no flag) before each item and every 10-15 tool calls. If Codex's live usage is higher than the file snapshot, use the higher number. Never `--new-run`; never edit the meter or its caps.
3. Obey the status: OK continue; SOFT finish only the current item; STOP or UNKNOWN start nothing and go to "Stop". The meter also stops you when the window reset is closer than 4 minutes: **never run into the reset**. Time is the tighter limit here, so before each item estimate its minutes and start it only if `resets_in_min - 4` covers it; otherwise take a smaller item or stop.

**Work (03 P1 rows; smallest and most independent first).** 1.8 private-streaming const, then 1.9 hygiene, then 1.6 remove dev identity, then the RPC ban audit (named in LEDGER "NOT DONE"), then 1.10 RLS policy quality (do the access matrix and the worst gaps first). Do NOT touch 1.2 / 1.7 (live-state and multi-device RPCs) or anything from P2 on: they need 25-35 points in one go and belong to window 2. One self-contained local commit per item, each after `flutter analyze` (0 issues) and the focused tests for what you changed; skip the full suite and `gates.mjs` per item. If at least 6 minutes remain before the reset, run the full suite and `node brief/tools/gates.mjs` once before the last commit; otherwise label the result UNVERIFIED in the ledger. No builds, nothing that runs over 2 minutes. SQL stays UNVERIFIED-STATIC without Docker. Do not start a half-item you cannot finish: no half-written migration, no red analyzer.

**Stop (at a STOP, at SOFT once the current item is done, or when items run out).** Tree clean (all committed, nothing stashed), analyzer at 0. Then ONE bookkeeping pass, minimal (earlier bookkeeping cost about 10 points, so do not rewrite the documents): in `brief/LEDGER.md` add the bonus rows to the budget log and phase log (start S, end used, minutes), update NOT DONE, and rewrite the RESUME block (next = P1.2 together with 1.7, then the rest of P1, in a FRESH session after the reset with `brief/archive/prompts/RESUME_PROMPT.md` `MODE: CONTINUE_SPLIT`, window 2 cap 60, never a third window; remove the stash instructions because the files are restored); append a short "Bonus session" note (at most 6 lines: what was done, points spent, why it stopped) to `brief/archive/reports/2026-09-22/OVERRUN_REPORT.md`; commit these two files. Final message: at most 8 lines.

Begin with step 1.
--- end ---
