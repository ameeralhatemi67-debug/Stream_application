# LEDGER — Claude Code's run log (template; copy the structure, keep each entry to a line or two)

Created at Step 0. Update at every checkpoint. Never paste long command output here: numbers and one-line verdicts only.

## Run header
- Date/time started:
- Model / effort (do not change mid-run):
- Plan (SINGLE | SPLIT) and why (paste the meter line that decided it):
- Start meter: used_5h=__ resets_in_min=__ cache_ttl=__ weekly=__
- Baselines: analyze=__ issues · tests=__ pass / __ fail (names) · gates (G1..G9 numbers)
- Tooling: flutter=__ · docker=__ · supabase CLI=__ → DB acceptance is E2 or UNVERIFIED-STATIC

## Budget log (one row per checkpoint)
| # | time | phase/step | window | used_5h | cap/soft | headroom | status | cache_warm |
|---|------|------------|--------|---------|----------|----------|--------|------------|

## Phase log
| Phase | Estimate (03) | Start used_5h | End used_5h | Δ actual | Ratio | Commit | Result (done / partial / cut) |
|-------|---------------|---------------|-------------|----------|-------|--------|-------------------------------|

## Decisions (decision + why, one line each; ID from 05 if it exists)

## Evidence (claim → tier E0-E4 → how, one line each; UNVERIFIED-STATIC / UNVERIFIED items are listed here too)

## NOT DONE (item · reason · re-estimate in % of a window)

## Surprises / risks found

## RESUME block (rewrite completely at every phase end and at every stop)
- Next step (phase + exact step):
- Files in flight / stash name (if any):
- Commands to re-run first:
- Open questions for the owner:
- Meter at write time:
