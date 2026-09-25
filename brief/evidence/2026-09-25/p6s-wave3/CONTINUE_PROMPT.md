# Prompt to continue P6S wave 3 in a new session

Paste the text below into a new Claude Code session opened on the repository `C:\Users\User\Documents\Amir Ob\projects\Ideas\Current\Streamer_app`.

---

Continue the P6S wave 3 implementation as the implementation engineer. Work only in the existing isolated worktree `C:\Users\User\Documents\Amir Ob\projects\Ideas\Current\Streamer_app\.claude\worktrees\p6s-wave3` on branch `opus/p6s-wave3-implementation`. Do not switch branches in the main checkout, and do not create a new branch or worktree.

Read these first, in the worktree:
1. `brief/evidence/2026-09-25/p6s-wave3/SESSION_HANDOFF.md`. It is authoritative for state, the exact next steps, saved scripts, the disposable DB and the critic history.
2. `CLAUDE.md`, and `AGENTS.md` in the main checkout (Context7 rule for library and API decisions).
3. The original brief and research, only where the handoff points to them. The research is in the main checkout at `brief/research/p6s-streaming-architecture/` and the owner retest at `brief/evidence/2026-09-24/p6-retest-repair/REPAIR_RETEST_RESULTS.md`. Read them by absolute path. Do not copy, stage or edit them.

Then continue exactly from the handoff's "Group 2: in progress" list:
- Apply `brief/.runtime/p6s-wave3/handoff/edit_g2_studio.py`. The analyzer is broken until you do.
- Add the listed en/ar keys, fix the `'OBS'` tab tests, and add the Group 2 tests.
- Get the analyzer to 0, the full suite green and the gates passing.
- Run the independent critic loop for Group 2. Score four dimensions 0–10 (functionality; accessibility and platform compatibility; integration and connectivity; ease of use), with evidence and a remaining defect for each. The loop stops if all four are 10, or three are 10 and one is 9 with no critical defect. Run at most 3 cycles, never inflate scores, and mark external or owner blockers BLOCKED.
- Commit Group 2.

Then do Groups 3–5 within the handoff's safe scope (persistent localized End control and leave confirmation; truthful presets and the 740/720 decision record; Local kept unavailable with a decision record; real player commands, a single retained room player, an honest mini-player, YouTube PiP unavailable; mode-specific en/ar streamer guidance). Each group gets its own critic loop and commit.

Finally produce:
- the dated implementation and evidence report (a table per group with critic scores per cycle, P6S-1..7 mapping, and the demo, Play and App Store checkpoints kept separate);
- the owner decision record (D1–D8, draft in `handoff/decisions_draft.md`);
- the exact two-phone/Chrome/YouTube and Local retest script (draft in `handoff/retest_draft.md`);
- `HANDOFF_TO_ASTRA.md` at the worktree root.

Stop after a clean branch handoff.

Hard rules:
- Never run the app with or print `project/dart_define.local.json` (it points at hosted production).
- No hosted migration, push, PR, merge, deploy or store action.
- Stage explicit paths only.
- Before each commit, restore `project/windows/flutter/generated_*` line-ending-only changes.
- Never log or screenshot a stream key.
- Use the disposable local stack `P6S_wave3_20260925` (`bash brief/.runtime/p6s-wave3/sqlrun.sh`). If Docker stopped it, restart it with the Supabase CLI and `--workdir brief/.runtime/p6s-wave3`.
- Keep E1/E2/E3/E4 evidence separate. Nothing is physically accepted without the owner's E4 run.
- The Opus budget waiver (§K) applies.
