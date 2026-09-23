# Evidence index — 2026-09-22

These files are dated evidence, not a live status feed. Results below retain the limits recorded by the source reports. The current plan is `../../03_WORK_PLAN.md`; current interpretation is in `../../README.md` and `../../06_VERIFICATION.md`.

## Verification reports

- [`CLAUDE_SONNET_VERIFICATION_REPORT_2026-09-22.md`](../../archive/reports/2026-09-22/CLAUDE_SONNET_VERIFICATION_REPORT_2026-09-22.md): P6.4 directory review; local SQL run exposed an access-policy regression and malformed pgTAP quoting. Directory remains unaccepted.
- [`UI_ISSUES_FIX_REPORT_2026-09-22.md`](../../archive/reports/2026-09-22/UI_ISSUES_FIX_REPORT_2026-09-22.md): 463 Flutter tests passed, analyzer reported zero issues, web build succeeded. No live Chrome or device session in that pass; does not verify streaming.
- [`UI_ISSUES_INVENTORY.md`](../../archive/reports/2026-09-22/UI_ISSUES_INVENTORY.md): original visual issue inventory; source images are below.
- [`Health_And_Audit_Check_for_brief_Progress.md`](../../archive/reports/2026-09-22/Health_And_Audit_Check_for_brief_Progress.md): historical audit only; several owner inputs it describes were supplied later.

## Raw logs

`logs/` preserves analyzer, Flutter, gate, SQL, layout, Chrome and debug-APK scan outputs by original filename. Their individual provenance and pass limits are described in the linked reports and ledger. The debug APK scanner result is not an AAB scan.

## Screenshots

- `screenshots/`: P6.4 Chrome/emulator captures, 2026-09-22 UI verification captures, and the web Phone-route Flutter error supplied for the release review.
- `ui-issues/`: original screenshots that drove the UI inventory; retained without edits.
- [`../2026-09-21/screenshots/`](../2026-09-21/screenshots/): earlier Scheme A UI evidence.

Physical-device streaming evidence is absent. None of these artifacts makes the app publish-ready.
