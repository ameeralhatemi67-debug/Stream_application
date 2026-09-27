# Hadayah integration handoff

Branch `codex/hadayah-wave4v2-integration`, isolated worktree `C:/Users/User/.codex/worktrees/hadayah-wave4v2-integration/Streamer_app`. Source merge `c70058914b73ccd5a8cfc1bcd82606fc3e4f880a` combines both preserved source tips; final repaired source is `34d074a5c577cd35944813f0a3db5315f4c85e96`. Artifact identities and SHA-256 are recorded in [identity.json](identity.json). The branch tip is the final evidence commit; its project/supabase tree identities must equal the frozen source.

Start at [README](README.md); first owner testing file is [WAVE4V2_RETEST_SCRIPT.md](WAVE4V2_RETEST_SCRIPT.md), W00 and short smoke. The candidate remains diagnostic until the exact setup checklist is completed and newly hashed configured artifacts pass W00. Do not install intermediate builds or the old maptest package. No owner app was replaced.

Local master has not been merged. Its protected uncommitted `Core_files/STATUS.md`, `brief/LEDGER.md`, `issue_encountered.md` and `skill-observations/log.md` overlap incoming source-branch documentation; additional dirty and untracked owner files are in the baseline. Do not stash/reset/clean/restore the checkout to make a merge convenient. The preservation comparison confirms this overlap; source integration and physical/release acceptance remain separate.

Runtime is ignored `brief/.runtime/hadayah-integration/`. The local test DB is `Hadayah_integration_20260927` (API56021, DB56022), separate from existing P6/P6S stacks. To resume only it, from this worktree root:

```powershell
supabase start --workdir brief/.runtime/hadayah-integration --exclude studio,pgadmin-schema-diff,migra,postgres-meta,logflare,vector,imgproxy,edge-runtime,supavisor,inbucket
```

To stop with backup: `supabase stop --workdir brief/.runtime/hadayah-integration`. Do not use `--all`, `--no-backup`, linked operations or reset shared stacks. Raw startup/status files remain ignored because CLI output may contain local credentials. Both new migrations were applied only here; no hosted backend operation occurred.

Final executable verification: analyzer 0; full Flutter 847 PASS; local SQL 23 files/462 assertions and 3 concurrency checks PASS; repository gates 0 failing; Android/web builds PASS. Exact-build Chrome checked all 52 saved files, real old/new application coexistence, atomic publication failure, worker restart/cleanup, cold Arabic images/map and bounded hangs. Three diagrams render and all local links/case rows validate. Independent cycle 2 met the target at **8/8/8/8**, with no unresolved new critical/high implementation defect; all scores remain provisional for physical/backend acceptance and D8 stays HIGH. Details are in [CRITIC_REVIEW](CRITIC_REVIEW.md). Preservation remains a separate required comparison, including newer concurrent owner edits.

P5/map **NOT ACCEPTED**; P6 **NOT ACCEPTED**; P6S **INCOMPLETE / NOT ACCEPTED**. D8 remains HIGH. See [CLOSURE_MATRIX](CLOSURE_MATRIX.md) for physical evidence, outlines and scope decisions that remain open independently of source integration.

## Preservation and local promotion decision

Local master remains `7b54cb5`; **do not merge this candidate into the current dirty checkout**. Protected `Core_files/STATUS.md`, `brief/LEDGER.md`, `issue_encountered.md` and `skill-observations/log.md` overlap incoming paths. Five main documents changed concurrently; its latest manager RESUME explicitly records those edits and new `brief/management/` records. The original baseline remains unchanged, with a separate CONCURRENT_OWNER_BASELINE.json for the newer work. PRESERVATION_CHECK.json reports the original comparison as changed, accounts for those exact updates, and checks their continued preservation. Source worktrees' protected files/status, source branch tips and both stash identities remain unchanged. No original evidence or runtime artifact was deleted or overwritten.
