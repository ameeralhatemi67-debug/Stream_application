---
type: audit
project: Streamer_app
phase: 6c of 8 (role: Organization)
created: 2026-08-20
status: complete
---

# 🏢 Phase 6c — Organization Side: Deep Audit

**Method:** Same approach as 6b — opened the actual org-specific wizard and admin screens rather than re-quoting Phase 4.

---

## Corrections to Phase 4's inventory

- **"Main location + additional branches" pattern for orgs — confirmed already built the way your notes asked for it.** `ApplyStep4Location` takes a single primary `venueController`/`selectedCoordinates` pair (the main campus) plus a separate `orgBranches: List<OrgBranchVenue>` with `onAddBranch`/`onRemoveBranch` callbacks for everything else. That matches your note's request ("a main location and a + button to add the other locations") structurally. **Status: Done** at the data/callback level — I didn't independently confirm the on-screen layout visually distinguishes "main" from "additional" clearly enough (that's a UI polish question, not a missing-feature one), worth a quick look next time you're in the wizard yourself.
- **Step 3.5 "add streamers to your organization" flow — confirmed implemented**, including the exact interaction pattern from your notes: a form with name/handle/bio/YouTube/role fields, an auto-fill-on-handle-match lookup against existing streamers (shared with the individual-application flow, see Phase 6b), and a running list of added speakers. **Status: Done**, not "Partial" as Phase 4 had it.

## Still open

- **Dedicated Organization profile screen** (spatial pin, affiliated roster, schedules, capacities) — confirmed still not built; this is explicitly your own current active-sprint item in `roadmap to publishing.md` Phase 5, not a doc-reading error on my part. This is the one clearly missing *screen* for this role, as opposed to missing wiring within existing screens.
- Everything flagged in Phase 4's Organization section that I didn't re-verify this pass (granular broadcast permissions UI depth, multi-branch venue management's actual on-screen presentation) carries forward as "Partial" rather than being newly confirmed either way.

## Security & governance notes specific to this role (from Phase 1)

This is the role where the client-side-only RBAC finding (VULN-RBAC-02) bites hardest: an organization's "granular permissions" over its own speakers (who can go live with video vs. audio-only, who can set location) are enforced entirely by `AppProvider`/`AdminDatabaseService` running on whichever device is using the app. A technically-minded affiliated speaker could, in principle, grant themselves permissions the organization didn't give them, simply by manipulating local app state — there's no server checking that the permission actually came from the org owner. This doesn't need fixing today if the app's real-world usage is genuinely limited to trusted, known institutions early on, but it's the kind of gap that becomes a real incident risk the moment the org roster grows past people who know and trust each other personally. Flagging it here specifically (rather than only in Phase 1) because it's this role's core value proposition — organizational control over who broadcasts under its name — that the current architecture can't actually guarantee.

## Audit trail

`OrgAuditLogEntry` and the seeded examples in `admin_database_service.dart` work and are a genuinely good idea for institutional trust — just remember it's a client-side log (same caveat as above: a determined bad actor with device access could, in theory, tamper with or clear it, since nothing external verifies it).

## Priority fixes for this role

1. Build the Organization profile screen — the one clearly missing piece, and your own stated next sprint.
2. When the backend conversation from Phase 1 happens, make the org-permission enforcement (not just the audit log) one of the first things moved server-side — it's this role's core trust promise.
3. Quick visual pass to make sure "main campus" vs "additional branches" reads clearly on screen, since the data model already supports it correctly.
