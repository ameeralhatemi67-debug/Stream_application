# Wave 4v2 repair candidate

Status: **BLOCKED for release acceptance**. Final critic round3/3: **8/7/7/7** (functionality/accessibility/integration/ease); target not met. An introduced P2 remains: the unconfirmed viewer notice overlaps the controls-toggle button. The owner explicitly retained server-side YouTube authorization (D8) as a release blocker. P6 and P6S are NOT ACCEPTED. Repairs and diagnostic builds can be tested while that blocker is open.

Branch `codex/p6s-wave4v2-repair`, base `7b54cb5e565011c33dcd03351735b7cc45a0926a`. Worktree `C:/Users/User/.codex/worktrees/p6s-wave4v2-repair/Streamer_app`. Final app source: `5162addcc8a659d3c66dafde3f243565cc85acf7`. Candidate identities are in [VERIFICATION.md](VERIFICATION.md) and `identity.json`. A local-backend/no-YouTube-key diagnostic build is not an end-to-end acceptance build.

Start with [setup and numbered testing instructions](WAVE4V2_RETEST_SCRIPT.md). Fill [new results](WAVE4V2_ACCEPTANCE_RESULTS.md), leaving every unexecuted subcheck NOT RUN. Then assess [P6 and P6S separately](P6_P6S_CLOSURE_MATRIX.md).

- [Repair report and remaining decisions](REPAIR_REPORT.md)
- [Verification and build evidence](VERIFICATION.md)
- [Independent critic rounds](CRITIC_REVIEW.md)
- [Build, setup and integration handoff](HANDOFF.md)

Historical Wave 4 observations and five screenshots remain untouched in the main checkout. Their hashes are in STARTING_STATE.json. The prior budget stop was superseded by the owner's explicit instruction to continue until all four critic scores reach at least 8 or three review rounds have been used. This applies to this task; no shared budget meter was changed.

The native probe produced fixed-canvas output but showed a System UI ANR and only48 frames in37.603s. Cause is unresolved. Chrome media confirmation is unavailable; its safe reload hands off to native controls with an unconfirmed label. Full physical AV/recovery, TalkBack/IME, Home/lock and long-duration results remain required. Read NATIVE_PROBE.md and BROWSER_PROBE.md before assigning a result.
