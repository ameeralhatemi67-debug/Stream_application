# RESUME PROMPT — paste this if the first run stopped on budget (OVERRUN_REPORT.md exists) or the terminal was closed

Best time to send it: at the start of a fresh 5-hour window, or with about 60 minutes left in one (cache rule in `brief/04_BUDGET_PROTOCOL.md` §A). Codex/Astra: always start a **fresh** session for this (not `codex resume`, which replays the whole history) and follow `brief/04_BUDGET_PROTOCOL.md` §G. Claude Code: launch from the repo root as before: `claude --permission-mode acceptEdits --settings brief/claude_settings.json`.

--- paste from here ---
MODE: CONTINUE_SPLIT   (CONTINUE_SPLIT = window 2 of a split run, cap 60, the normal case | NEW_BUDGET = a brand-new single budget, cap 80, only if the owner deliberately wants more)

You are resuming an autonomous hardening run on this repo. Nobody will answer questions: decide with `brief/05_DECISIONS.md`, log it, continue.

1. The budget protocol in `brief/04_BUDGET_PROTOCOL.md` is binding and outranks finishing. Step 0: CONTINUE_SPLIT ⇒ `node brief/tools/budget_check.mjs --plan split` (never `--new-run`); it must report `window=2` and `cap=60`, and if it says window 1 or window 3 stop and tell the owner. NEW_BUDGET ⇒ `node brief/tools/budget_check.mjs --plan single --new-run` (once). If the meter is unreadable, stop and say so. Under Codex never wait or nap; a stop means write the RESUME block and quit.
2. Read only: the RESUME block at the bottom of `brief/LEDGER.md`, `brief/OVERRUN_REPORT.md` if it exists, the current phase in `brief/03_WORK_PLAN.md`, and `brief/05_DECISIONS.md`. Open `brief/01_PROJECT_MAP.md` / `02_AUDIT_DELTA.md` / `06_VERIFICATION.md` only when the step needs them. No other repo exploration.
3. `git --no-optional-locks status` and `git stash list`: finish or drop nothing you did not create; pop the named stash if the RESUME block says so. Re-run the phase checkpoint (analyze, tests, gates) once to confirm the baseline before new work.
4. Continue from the RESUME block's next step. Same rules as the original run: phase order and cut list, one commit per phase, never push, local Supabase only, evidence tiers, token hygiene, checkpoint after every phase, ledger updated.
5. Stop at a safe place (04 §E) with `brief/OVERRUN_REPORT.md` (budget stop) or `brief/FINAL_REPORT.md` (everything done). Final chat message ≤12 lines.
--- end ---
