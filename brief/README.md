# Hadayah Live release brief

**Current phase:** documentation checkpoint only (2026-09-23). Implementation resumes at P6.4 item 1; P0–P4 and P8A are recorded complete, while P6.4 item 1 is implemented but its local SQL verification is failing. This app is **not publish-ready**.

## Status by evidence

- **Implemented and tested (dated evidence):** P0–P4/P8A and P6.1–6.3; the latest broad UI report records 463 passing tests, analyzer 0 and a successful web build. P5 connectivity/offline-map work is partly implemented and widget-tested, but that does not complete its full offline/device acceptance.
- **Implemented, blocked on verification:** P6.4 directory client and migration source; local SQL testing exposed an access-policy regression and malformed pgTAP quoting. Repair and rerun before acceptance.
- **Unverified or blocked:** all real streaming on physical hardware; direct laptop capture; same-Wi-Fi media transport; private authorization/invites; genuine live-media PiP; and full orientation/exit lifecycle. The web Phone route has a recorded platform error. Docker/local Supabase recovery blocks the next SQL checkpoint.
- **Owner-dependent:** upload signing material, public-page verification/account-deletion URL, production migration decisions, legal/store/Play Console actions, device/test-channel access and final release evidence.

## Next actions

1. Recover local Supabase/Docker non-destructively; repair the P6.4 directory policy regression and malformed pgTAP assertions, then rerun the local DB suite.
2. Finish remaining P6 admin work, then reproduce and resolve the P6S OBS, direct-phone, direct-laptop and Local mode paths against real sender/viewer scenarios.
3. Complete P6S access/invites, playback/orientation/exit/account-state checks, then continue P5 → P7 → P8B → P9 and collect every release gate's evidence.

## Release blockers

- P6.4 item 1 has recorded SQL/test defects; later P6.4 items remain open.
- Physical-device streaming has not been verified. Local currently saves a URL; private access is disabled and lacks enforceable authorization; mini-player does not carry live video; web Phone route has a recorded Flutter platform error. Laptop direct broadcast is not established.
- No signed release AAB exists; owner signing material is absent. Store/legal/backend-owner gates also remain.

## Owner actions

Supply signing material locally, verify the supplied privacy page and provide an account-deletion URL, complete Play Console/legal/store decisions, review production migrations and Supabase settings, and provide devices/OBS/test-channel access for the release matrix. Full checklist: [OWNER_ACTIONS.md](OWNER_ACTIONS.md).

## Authoritative documents

- [Canonical release plan](03_WORK_PLAN.md)
- [Decisions and owner-supplied values](05_DECISIONS.md)
- [Verification criteria and evidence limits](06_VERIFICATION.md)
- [Latest checkpoint / RESUME block](LEDGER.md#resume-block-2026-09-22-codex-p64-directory-implemented-db-verification-blocked)
- [Evidence index](evidence/2026-09-22/README.md)

The four-day schedule in the canonical plan is a conditional engineering target, not a publication promise. Only P9 may conclude readiness, and only when its device, security, release-build and owner gates have evidence.

## Follow-up documentation work (out of this pass)

Reconcile `Roadmap.md`, repository `AGENTS.md`, `Core_files/STATUS.md`, `Core_files/progres.md` and relevant `Core_files/` decisions with this brief and current verified evidence. Those files were read for this plan but intentionally not edited here.
