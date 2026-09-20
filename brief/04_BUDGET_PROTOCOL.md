# 04 — Budget protocol (binding; outranks finishing the work)

**Meter** = `rate_limits.five_hour.used_percentage` from Claude Code's status line (verified in the official statusline docs; Pro/Max only, available after the first API response). It is *account-wide*, so it already includes anything else the owner spends in the same 5-hour window. All caps below are absolute values of this meter. You read it with `node brief/tools/budget_check.mjs`; `brief/tools/cc_statusline_snapshot.mjs` (the status-line command) keeps the snapshot fresh. Never edit `budget_check.mjs`, `cc_statusline_snapshot.mjs`, `.runtime/` or the caps to gain room (the permission rules block it too).

## A. Owner set-up (before pasting the prompt) — ~2 minutes
1. `brief/claude_settings.json` holds the status-line meter and safe permission rules (it denies `git push`, any `supabase db push/link/secrets/functions`, hard resets, reading key files). Launch from the **repo root**: `claude --permission-mode acceptEdits --settings brief/claude_settings.json`. After Claude's first reply the status line must read like `5h 41% (reset 58m) | 7d 22% | cache 1h warm`. `5h n/a` ⇒ not Pro/Max, or Claude Code older than the statusline `rate_limits`/`prompt_cache` fields. The permission rules are written for the Bash tool (Git for Windows); if your Claude Code uses PowerShell instead they won't match, so watch the prompts, and the master prompt's own rules (never push, local Supabase only) still hold.
2. Pick the model and effort **once** and don't change them (each model/effort has its own prompt cache; switching re-reads everything uncached).
3. Paste the prompt when ~60 minutes remain in the window (the status line shows it). Keep the terminal open and don't leave a permission prompt unanswered: the main conversation gets a **1-hour** cache only while requests keep flowing (each hit refreshes it); one hour of silence = a cold, expensive restart.

## B. Plans and caps
| Plan | Window 1 | Window 2 | Rule |
|---|---|---|---|
| **SINGLE** | cap **80**, soft 74 | — | If the window rolls over, STOP (no second window). |
| **SPLIT** | cap **70**, soft 64 | cap **60**, soft 54 | Never a third window. Requires a warm 1-hour cache (see D). |
Weekly guard: `seven_day` ≥ 90 ⇒ STOP under any plan.
**AUTO** (default in the Claude Code prompt header), decided in Step 0 (the Astra prompt sets `PLAN: split` explicitly): if `cache_ttl=1h` **and** `resets_in_min ≤ 90` ⇒ SPLIT (window 1 is too short for this job); otherwise SINGLE. Log the choice and the numbers. You may switch SINGLE→SPLIT at a phase boundary only if the tail of 03 clearly can't fit and the cache is 1h; never switch to gain room mid-step.

## Step 0 (first actions, ≤5 tool calls)
1. `node brief/tools/budget_check.mjs --plan single --new-run` (`--new-run` forgets windows recorded by earlier sessions such as the design run; use it here only, never again in this run). `UNKNOWN`: make one cheap call (`date`) and retry once. Still unknown ⇒ **stop now** and tell the owner to do section A (cost ≈ nothing; fail closed).
2. Choose the plan (B). From now on pass `--plan <plan>` on every check (no `--new-run`).
3. Fill in the run header of `brief/LEDGER.md` (it ships as a template; keep its structure): start `used_5h`, `resets_in_min`, cache ttl, plan, date.

## C. Checkpoint routine
Run the meter at every phase start, after every ~10-15 tool calls, after any command that took >2 min, and before a full test run/build. Act on `status`:
- **OK** — continue. Before a step, estimate its cost from the ledger's measured burn; if it can't fit in `headroom − 3`, pick a smaller step or close the phase.
- **SOFT** — finish only the step in progress, run the phase checkpoint (analyze, tests, gates, commit, ledger), start nothing new. Then: SPLIT + window 1 + `resets_in_min ≤ 75` ⇒ section D; otherwise section E.
- **STOP** — start nothing. If a step is half-done, `git stash push -u -m unfinished-step` (never discard work), then D (SPLIT window 1, wait ≤75 min) or E.
- **UNKNOWN** — obey the printed action; never assume OK.
Record burn per phase in the ledger: `Δ = used_5h(end) − used_5h(start)` (sum both sides across a roll-over). Re-estimate the remaining phases from real numbers after P1 and again after P4.
Cost hygiene: see the prompt's token-hygiene rule; also avoid re-reading files you just edited, and re-run only the failing test file, not the full suite, until the phase checkpoint.

## D. SPLIT: crossing the reset without losing the cache
1. At the window-1 stop: finish/stash the step, checkpoint, write the ledger **RESUME block** (next step, files in flight, commands to re-run).
2. Wait for the reset with naps: repeat `node brief/tools/budget_check.mjs --plan split --nap 540` (Bash timeout 590000 ms). Each nap is a real API request, so the 1-hour cache stays warm; do nothing else while waiting (no reads, no thinking out loud). Stop waiting when the output shows `window=2`. Budget at most ~9 naps (~75 min); the naps themselves are metered.
3. If at the stop `resets_in_min > 75`, don't wait — go to E (the owner resumes with `brief/RESUME_PROMPT.md`).
4. On `window=2`: re-read only the RESUME block and the current phase in 03, `git status`, continue under cap 60. If the cache went cold (`cache_warm=false`) just continue — it only costs more.

## E. Safe stop (all must be true before you finish)
Last commit holds only complete steps · working tree clean or stashed (name the stash) · `flutter analyze` at the recorded baseline or better · tests green (or the baseline failures listed by name) · no half-written migration (each file self-consistent; committed or removed) · ledger + RESUME block current.
Then write **`brief/OVERRUN_REPORT.md`** (budget-driven stop) or **`brief/FINAL_REPORT.md`** (all done). The overrun report must explain *why* — with numbers:
1. Stop reason (paste the meter line), plan, windows used, final `used_5h`.
2. Table: phase · estimate · actual Δ · ratio.
3. The 3 biggest consumers and the concrete cause (e.g. re-reading a 4,800-line file, repeated full test runs, a migration redone twice, a wrong estimate) with ledger evidence.
4. What is left, re-estimated, in priority order per the 03 cut list.
5. Safe-state proof (commands + outputs) and what the owner should run next (`brief/RESUME_PROMPT.md`, split or raise the cap).
Final chat message ≤12 lines pointing to the report.

## F. Never
Claim `OK` without a fresh meter line · run past a STOP "to finish quickly" · lower evidence standards to save budget (cut scope instead) · use up the reserve (the 20 %/30 % headroom belongs to the owner's other work).

## G. Running under Codex (GPT-6 Astra) instead of Claude Code
Facts as researched on 2026-09-20 (sources in the chat reply; confirm with `/status` in Codex): Astra draws on the shared Work+Codex allowance with a **5-hour and a weekly window**; OpenAI's estimate per 5 hours is Plus 5-45 messages, Pro 5x 25-225, Pro 20x 100-900; there are public reports (openai/codex #42987) of one or two turns using 50-100 % of a Plus window at Medium effort; fast mode spends more; the documented Astra prompt-cache idle TTL is about 30 minutes. Nothing here has been run against a real Codex install: treat the meter as unverified until the probe below passes.
1. **Owner set-up (5 minutes).** In Codex run `/statusline` and enable `five-hour-limit` and `weekly-limit` (they show what is *remaining*). Start `codex` from the repo root, send one message, then run `node brief/tools/budget_check.mjs --probe`: it must print `chosen: "codex"` and a `primary:` line whose `used=` roughly equals 100 minus your remaining %. If it prints a `problem`, do not start the run (the tool fails closed). Copy `brief/codex_hardening.rules` to `.codex/rules/hadayah.rules` (the project must be trusted) and check it with `codex execpolicy check --pretty --rules .codex/rules/hadayah.rules -- git push origin master` (must say forbidden). Select Astra, effort **medium**, fast mode **off**, and leave them alone. Optional `config.toml` keys worth setting (confirm the names in your Codex version): `model_verbosity = "low"`, a `tool_output_token_limit`, an earlier `model_auto_compact_token_limit`.
2. **Prompt.** Paste `brief/00_MASTER_PROMPT_ASTRA.md` (slim on purpose: OpenAI advises against long scaffolding for Astra). `AGENTS.md` is read by Codex automatically: do not repeat it.
3. **Plan.** Default for Astra is **SPLIT**: window 1 cap 70 (soft 64), window 2 cap 60 (soft 54), never a third; SINGLE (cap 80, one window) if you prefer. No nap loop: each nap re-sends the whole context, which is exactly what burns quota, and the cache lives ~30 minutes anyway. At the window-1 stop it writes the RESUME block and quits. After the reset, open a **fresh** session (not `codex resume`, which replays the whole history) and paste `brief/RESUME_PROMPT.md` with `MODE: CONTINUE_SPLIT`: the window counter is kept in `brief/.runtime/budget_state.json`, so the meter reports `window=2, cap=60`. The old "send it with an hour left" advice is about Claude's 1-hour cache and does not apply here; pasting with an hour left only means window 1 spends what remains of it.
4. **Hygiene.** No subagents (one issue measured 68 % of parent input tokens spent polling `wait_agent`). Read by line range, tail long output, use `graft`. A manual `/compact` is allowed once, at a phase boundary after the RESUME block is written, if context is above ~60 %.
5. **Quota reality check.** If two consecutive steps each move `used_5h` by more than 25 points, stop at a safe state and tell the owner the plan/effort is too small for this job (use a bigger plan, or Claude Code). Never keep going because "the cap is 80".
6. **Model per session (05 D-23).** A new session is free to change model: hardest phases (P1, P3, P6) on the strongest model, mechanical ones (P4 renames/i18n/emoji, P8B docs) on a cheaper one at lower effort.

## §H Bonus session (owner-approved spend of a leftover window)
If a split run stops early and the same window still has unused points, `BONUS_PROMPT.md` may spend them: `budget_check.mjs --plan bonus --bonus-start` records the used % at the start (S); cap = min(94, S + 40), soft = cap - 6. It never crosses the window reset (STOP when fewer than 4 minutes remain; SOFT at 6), does not touch the split window counter, and leaves the fresh window as window 2 (cap 60) for `RESUME_PROMPT.md` `MODE: CONTINUE_SPLIT`. The owner, not the agent, decides to run it.

## §I Meter freshness, live readings and the owner cap (added 2026-09-20)
Why the meter gave two false STOPs (reproduced with synthetic logs; not yet checked against a real Codex install): it took an old Codex log line (17,000+ s old, 1 % five-hour, 98 % weekly) as current, its weekly guard fired before the staleness check, and the bonus start recorded that 1 % as the starting point. Rules now:
1. A reading older than 15 min, or from a window that has already reset, is UNKNOWN. It never yields STOP, never initialises a bonus and never writes `brief/.runtime/budget_state.json`. The printed `stale_file_*` numbers are diagnostics, not usage.
2. When the log lags, read your usage from Codex's own display (status line or `/status`) and pass it: `--live-used N --live-weekly W --live-resets-in-min R`. With a fresh log the higher number wins; with a stale log all three are required. Never invent a number: if you cannot read the display, the answer is UNKNOWN, so start nothing.
3. Once a window is recorded its reset time is kept; a live "resets in" only matters on the first call of a new window. A "new" window before the recorded one has ended, or a log reading older than the recorded window, is UNKNOWN.
4. `--cap N` (max 90, soft N-6) is the owner's one-off cap for the current window, given in the paste as `OWNER_CAP=N`. The agent never chooses it. Pass it on EVERY check of that session (otherwise the plan's cap applies). The third-window STOP and the weekly guard (>= 90) still apply.
5. Closing bookkeeping costs points (about 10 last time because documents were rewritten). Append short rows to the ledger, never rewrite documents, and leave at least 6 points under the cap for it.
