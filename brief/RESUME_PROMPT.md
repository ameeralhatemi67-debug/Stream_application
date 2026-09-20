# RESUME PROMPT — paste this if the first run stopped on budget (OVERRUN_REPORT.md exists) or the terminal was closed

Best time to send it: at the start of a fresh 5-hour window, or with about 60 minutes left in one (cache rule in `brief/04_BUDGET_PROTOCOL.md` §A). Codex/Astra: always start a **fresh** session for this (not `codex resume`, which replays the whole history) and follow `brief/04_BUDGET_PROTOCOL.md` §G. Claude Code: launch from the repo root as before: `claude --permission-mode acceptEdits --settings brief/claude_settings.json`.

--- paste from here ---
MODE: CONTINUE_SPLIT   (CONTINUE_SPLIT = window 2 of a split run, cap 60 unless OWNER_CAP is set, the normal case | NEW_BUDGET = a brand-new single budget, cap 80, only if the owner deliberately wants more)
OWNER_CAP=             (optional; owner-approved cap for THIS window, max 90, e.g. 90. Blank = the plan's cap)
OWNER_READING=         (optional; owner's reading of the Codex usage screen at paste time: five-hour used %, weekly used %, resets in / at. Delete the line if unknown)

You are resuming an autonomous hardening run on this repo. Nobody will answer questions: decide with `brief/05_DECISIONS.md`, log it, continue.

1. The budget protocol in `brief/04_BUDGET_PROTOCOL.md` (read §I first) is binding and outranks finishing. Step 0: CONTINUE_SPLIT ⇒ `node brief/tools/budget_check.mjs --plan split` (never `--new-run`), and when `OWNER_CAP=N` is set add `--cap N` here and on EVERY later check. It must report `window=2` and `cap=60` (or `cap=N cap_source=owner`); window 1 or window 3 ⇒ stop and tell the owner. NEW_BUDGET ⇒ `node brief/tools/budget_check.mjs --plan single --new-run` (once). UNKNOWN (stale log, no snapshot): read your usage from the Codex display (or use `OWNER_READING`) and re-run with `--live-used N --live-weekly W --live-resets-in-min R` (04 §I); a stale log is never a reason to stop by itself, and never a number to trust. Still UNKNOWN or no readable number ⇒ start nothing, say so. Under Codex never wait or nap; a stop means write the RESUME block and quit. Do not edit the meter or its caps.
2. Read only: the RESUME block at the bottom of `brief/LEDGER.md`, `brief/OVERRUN_REPORT.md` if it exists, the current phase in `brief/03_WORK_PLAN.md`, and `brief/05_DECISIONS.md`. Open `brief/01_PROJECT_MAP.md` / `02_AUDIT_DELTA.md` / `06_VERIFICATION.md` only when the step needs them. No other repo exploration.
3. `git --no-optional-locks status` and `git stash list`: finish or drop nothing you did not create. The two owner stashes are historical (their content is already committed): never apply, pop or drop them. Re-run the phase checkpoint (analyze, tests, gates) once to confirm the baseline before new work.
4. Continue from the RESUME block's next step. Same rules as the original run: phase order and cut list, one commit per phase, never push, local Supabase only, evidence tiers, token hygiene, checkpoint after every phase, ledger updated.
5. Stop at a safe place (04 §E) with `brief/OVERRUN_REPORT.md` (budget stop) or `brief/FINAL_REPORT.md` (everything done). Bookkeeping is part of the budget: append short rows to `brief/LEDGER.md` and to the report, never rewrite documents, and start the closing pass at SOFT so it ends before the cap. Final chat message ≤12 lines.
--- end ---
