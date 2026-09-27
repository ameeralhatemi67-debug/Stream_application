Continue the Streamer three-city map upgrade from a paused session.

Read first, in this order:
1. C:/Users/User/.codex/worktrees/p5-basemap-spike/Streamer_app/brief/evidence/2026-09-26/p5-tricity-map-upgrade/HANDOFF_TO_ASTRA.md (current state and ordered remaining work)
2. CRITIC_REVIEW.md in the same folder (round 1 findings D1-D12; rounds used 1 of 3)
3. C:/Users/User/Documents/Amir Ob/projects/Ideas/Current/Streamer_app/brief/research/p5-tricity-map-upgrade/OPUS_EXECUTION_PROMPT.md (governing rules: isolation, critic scoring, three-round cap, evidence honesty)

Work only in the worktree C:/Users/User/.codex/worktrees/p5-basemap-spike/Streamer_app on branch codex/tricity-map-upgrade (tip d11e9f2). Do not touch the main checkout, its uncommitted files or stashes; never read project/dart_define.local.json; no merge, push, deploy, hosted DB change or install over the owner's app. Never commit project/windows/flutter/generated_plugin* (line-ending noise). Commit with explicit file lists; first commit the uncommitted evidence files (CRITIC_REVIEW.md, HANDOFF_TO_ASTRA.md, SESSION_HANDOFF_PROMPT.md).

Do the "Remaining work, in order" list in HANDOFF_TO_ASTRA.md:
1. Chrome re-verification of the round-1 repairs on project/build/web (rebuild with --dart-define=SUPABASE_URL=http://127.0.0.1:9 --dart-define=SUPABASE_ANON_KEY=local-placeholder-not-a-key if needed), including the long-session D1 case and an Arabic offline cold start; save screenshots/raw logs into the evidence folder.
2. Evidence updates (D10 relabels, ADR-008 wording, VERIFICATION/REPORT/ACCEPTANCE with 732 tests and the repairs, D8 disclosure).
3. Independent critic round 2 with a separate subagent (same prompt and rubric as round 1, reviewing the new tip). Stop when all four categories are >= 8 with no high defect; otherwise one repair pass and round 3 (final).
4. Update HANDOFF_TO_ASTRA.md with final scores, why each is below 10, unmet items (A11 outlines, SM-S936B runs, backend runs, D8 owner decision) and next steps. Leave the branch for Astra's audit.
