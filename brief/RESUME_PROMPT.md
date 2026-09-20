# RESUME PROMPT — paste this if the first run stopped on budget (OVERRUN_REPORT.md exists) or the terminal was closed

Best time to send it: at the start of a fresh 5-hour window, or with about 60 minutes left in one (cache rule in `brief/04_BUDGET_PROTOCOL.md` §A). Codex/Astra: always start a **fresh** session for this (not `codex resume`, which replays the whole history) and follow `brief/04_BUDGET_PROTOCOL.md` §G. Claude Code: launch from the repo root as before: `claude --permission-mode acceptEdits --settings brief/claude_settings.json`.

--- paste from here ---
PLAN: AUTO (or set SINGLE / SPLIT)

You are resuming an autonomous hardening run on this repo. Nobody will answer questions: decide with `brief/05_DECISIONS.md`, log it, continue.

1. The budget protocol in `brief/04_BUDGET_PROTOCOL.md` is binding and outranks finishing. Do its Step 0 first (`node brief/tools/budget_check.mjs --plan single`); if the meter is unreadable, stop and say so. A resumed run starts a NEW budget: pick the plan again from the meter (a resume is a fresh SINGLE or SPLIT; never a third window of an old split).
2. Read only: the RESUME block at the bottom of `brief/LEDGER.md`, `brief/OVERRUN_REPORT.md` if it exists, the current phase in `brief/03_WORK_PLAN.md`, and `brief/05_DECISIONS.md`. Open `brief/01_PROJECT_MAP.md` / `02_AUDIT_DELTA.md` / `06_VERIFICATION.md` only when the step needs them. No other repo exploration.
3. `git --no-optional-locks status` and `git stash list`: finish or drop nothing you did not create; pop the named stash if the RESUME block says so. Re-run the phase checkpoint (analyze, tests, gates) once to confirm the baseline before new work.
4. Continue from the RESUME block's next step. Same rules as the original run: phase order and cut list, one commit per phase, never push, local Supabase only, evidence tiers, token hygiene, checkpoint after every phase, ledger updated.
5. Stop at a safe place (04 §E) with `brief/OVERRUN_REPORT.md` (budget stop) or `brief/FINAL_REPORT.md` (everything done). Final chat message ≤12 lines.
--- end ---
